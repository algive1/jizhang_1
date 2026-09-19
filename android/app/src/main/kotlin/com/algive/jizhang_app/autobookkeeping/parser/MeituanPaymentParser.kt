package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import java.math.BigDecimal

/**
 * Dedicated Meituan parser.
 *
 * Meituan mixes native, WebView and dynamically rendered order pages. The
 * parser therefore does not depend on a specific Activity name or view id, but
 * it still requires an explicit completed-payment status plus one unambiguous
 * paid amount before producing a candidate.
 */
class MeituanPaymentParser {
    private val supportedPackages = setOf(
        "com.sankuai.meituan",
        "com.sankuai.meituan.takeout",
    )

    private val successMarkers = setOf(
        "支付成功",
        "付款成功",
        "交易成功",
        "订单支付成功",
        "订单已支付",
        "订单支付完成",
        "支付完成",
        "付款完成",
        "支付已完成",
        "付款已完成",
        "交易已完成",
        "已支付",
        "已付款",
    )

    private val rejectMarkers = setOf(
        "待支付",
        "待付款",
        "去支付",
        "去付款",
        "未支付",
        "未付款",
        "支付失败",
        "付款失败",
        "交易失败",
        "支付取消",
        "付款取消",
        "取消支付",
        "重新支付",
        "支付提醒",
    )

    private val merchantKeys = setOf(
        "商户",
        "商户名称",
        "商家",
        "商家名称",
        "订单商家",
        "店铺",
        "店铺名称",
        "门店",
        "收款方",
    )

    private val amountKeys = setOf(
        "实付",
        "实付金额",
        "付款金额",
        "支付金额",
        "实际支付",
        "消费金额",
        "扣款金额",
        "订单实付",
    )

    private val excludedAmountLabels = setOf(
        "优惠",
        "红包",
        "立减",
        "原价",
        "商品金额",
        "配送费",
        "打包费",
        "会员",
        "积分",
        "应付",
    )

    private val amountPatterns = listOf(
        Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])"),
        Regex("(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
    )

    fun parse(packageName: String, nodes: List<ScreenNode>, timestamp: Long): PaymentCandidate? {
        if (packageName !in supportedPackages) return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return null
        if (labels.any { label -> rejectMarkers.any { marker -> label.contains(marker) } }) return null
        if (labels.none(::isSuccessLabel)) return null

        val merchant = CandidateFieldExtractor.field(labels, merchantKeys)
            ?: fallbackMerchant(labels)
            ?: return null
        val method = CandidateFieldExtractor
            .field(labels, setOf("支付方式", "付款方式", "支付渠道"))
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"
        val amount = findPaidAmount(labels) ?: return null
        val (originalAmount, discountAmount) =
            CandidateFieldExtractor.amountBreakdown(labels, amount)

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant.take(80),
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = method.take(80),
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = "MEITUAN",
                scene = "MEITUAN_PAYMENT_SUCCESS",
                confidence = if (method == "UNKNOWN") .93 else .97,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .92,
            sourceApp = "MEITUAN",
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
            identifierSuffix = CandidateFieldExtractor.identifierSuffix(method, labels),
        )
    }

    fun rejectionReason(packageName: String, nodes: List<ScreenNode>): String {
        if (packageName !in supportedPackages) return "UNSUPPORTED_PACKAGE"
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return "NO_VISIBLE_LABELS"
        if (labels.any { label -> rejectMarkers.any { marker -> label.contains(marker) } }) {
            return "REJECTED_STATUS"
        }
        if (labels.none(::isSuccessLabel)) return "NO_SUCCESS_MARKER"
        if (findPaidAmount(labels) == null) return "NO_UNIQUE_PAID_AMOUNT"
        if (CandidateFieldExtractor.field(labels, merchantKeys) == null && fallbackMerchant(labels) == null) {
            return "NO_MERCHANT"
        }
        return "UNSUPPORTED_LAYOUT"
    }

    private fun isSuccessLabel(label: String): Boolean =
        successMarkers.any { marker -> label == marker || label.startsWith(marker) }

    private fun findPaidAmount(labels: List<String>): Long? {
        val candidates = mutableListOf<Pair<Long, Int>>()
        labels.forEachIndexed { index, label ->
            val previous = labels.getOrNull(index - 1).orEmpty()
            if (excludedAmountLabels.any { label.contains(it) }) return@forEachIndexed
            val explicit = amountKeys.any { key ->
                label == key ||
                    label.startsWith("$key：") ||
                    label.startsWith("$key:") ||
                    previous == key
            }
            if (!explicit && excludedAmountLabels.any { previous.contains(it) }) {
                return@forEachIndexed
            }

            val matched = amountPatterns
                .flatMap { pattern -> pattern.findAll(label).map { it.groupValues[1] }.toList() }
                .distinct()
            val raw = if (
                matched.isEmpty() &&
                explicit &&
                label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))
            ) {
                listOf(label)
            } else {
                matched
            }

            raw.forEach { value ->
                val cents = value.toBigDecimalOrNull()
                    ?.multiply(BigDecimal(100))
                    ?.let { runCatching { it.longValueExact() }.getOrNull() }
                if (cents != null && cents in 1..99_999_999_999L) {
                    candidates += cents to if (explicit) 3 else 1
                }
            }
        }

        val bestScore = candidates.maxOfOrNull { it.second } ?: return null
        val winners = candidates
            .filter { it.second == bestScore }
            .map { it.first }
            .distinct()
        return winners.singleOrNull()
    }

    private fun fallbackMerchant(labels: List<String>): String? {
        val generic = successMarkers + rejectMarkers + amountKeys + setOf(
            "美团",
            "美团外卖",
            "订单详情",
            "支付详情",
            "查看订单",
            "完成",
            "返回",
            "支付方式",
            "付款方式",
            "支付渠道",
        )
        val genericFragments = setOf(
            "订单",
            "支付",
            "付款",
            "金额",
            "优惠",
            "完成",
            "详情",
            "返回",
            "时间",
            "方式",
            "渠道",
            "美团",
        )
        return labels.firstOrNull { label ->
            label.length in 2..80 &&
                label !in generic &&
                genericFragments.none { label.contains(it) } &&
                amountPatterns.none { it.containsMatchIn(label) } &&
                excludedAmountLabels.none { label.contains(it) } &&
                merchantKeys.none { label == it } &&
                !label.matches(Regex("[A-Za-z0-9_-]{6,}"))
        }
    }
}
