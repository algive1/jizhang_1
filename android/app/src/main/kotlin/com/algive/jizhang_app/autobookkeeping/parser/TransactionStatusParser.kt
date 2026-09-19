package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import java.math.BigDecimal

/**
 * Conservative accessibility parser for non-expense completed transaction
 * states. It intentionally requires an exact status, a unique amount and an
 * explicit counterparty field; it never falls back to arbitrary page text.
 */
class TransactionStatusParser {
    fun parse(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long,
    ): PaymentCandidate? {
        val sourceApp = SOURCES[packageName] ?: return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return null

        val hasRefund = labels.any(::isRefundStatus)
        val hasIncome = labels.any(::isIncomeStatus)
        if (hasRefund == hasIncome) return null

        val transactionType = if (hasRefund) "REFUND" else "INCOME"
        val merchant = if (hasRefund) {
            explicitValue(
                labels,
                setOf("退款方", "退款商户", "商户", "商家", "店铺", "门店", "对方"),
                setOf("退款方", "退款商户", "来自", "对方"),
            )
        } else {
            explicitValue(
                labels,
                setOf("付款方", "付款人", "对方"),
                setOf("来自", "付款方", "付款人", "对方"),
            )
        } ?: return null

        val amount = uniqueAmount(
            labels,
            if (hasRefund) {
                setOf("退款金额", "到账金额", "退款")
            } else {
                setOf("收款金额", "到账金额", "收入金额", "收款")
            },
        ) ?: return null

        val method = CandidateFieldExtractor
            .field(labels, setOf("退款方式", "收款方式", "支付方式", "付款方式"))
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant.take(80),
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = method.take(80),
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = sourceApp,
                scene = if (hasRefund) {
                    "${sourceApp}_REFUND_SUCCESS"
                } else {
                    "${sourceApp}_INCOME_SUCCESS"
                },
                confidence = if (method == "UNKNOWN") .92 else .96,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .94,
            sourceApp = sourceApp,
            transactionType = transactionType,
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            identifierSuffix = CandidateFieldExtractor.identifierSuffix(
                method,
                labels,
            ),
        )
    }

    fun rejectionReason(
        packageName: String,
        nodes: List<ScreenNode>,
    ): String? {
        if (packageName !in SOURCES) return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        val hasRefund = labels.any(::isRefundStatus)
        val hasIncome = labels.any(::isIncomeStatus)
        if (!hasRefund && !hasIncome) return null
        if (hasRefund && hasIncome) return "AMBIGUOUS_TRANSACTION_STATUS"

        val merchant = if (hasRefund) {
            explicitValue(
                labels,
                setOf("退款方", "退款商户", "商户", "商家", "店铺", "门店", "对方"),
                setOf("退款方", "退款商户", "来自", "对方"),
            )
        } else {
            explicitValue(
                labels,
                setOf("付款方", "付款人", "对方"),
                setOf("来自", "付款方", "付款人", "对方"),
            )
        }
        if (merchant == null) return "NO_COUNTERPARTY"

        val amount = uniqueAmount(
            labels,
            if (hasRefund) {
                setOf("退款金额", "到账金额", "退款")
            } else {
                setOf("收款金额", "到账金额", "收入金额", "收款")
            },
        )
        if (amount == null) return "NO_UNIQUE_TRANSACTION_AMOUNT"
        return "UNSUPPORTED_TRANSACTION_LAYOUT"
    }

    private fun isRefundStatus(label: String): Boolean =
        REFUND_STATUSES.any { label == it || label.startsWith(it) }

    private fun isIncomeStatus(label: String): Boolean =
        INCOME_STATUSES.any { label == it || label.startsWith(it) }

    private fun explicitValue(
        labels: List<String>,
        keys: Set<String>,
        prefixes: Set<String>,
    ): String? {
        CandidateFieldExtractor.field(labels, keys)?.let { value ->
            if (validCounterparty(value)) return value
        }
        for (label in labels) {
            for (prefix in prefixes.sortedByDescending { it.length }) {
                val value = when {
                    label.startsWith("$prefix：") ||
                        label.startsWith("$prefix:") ->
                        label.substring(prefix.length + 1).trim()
                    label.startsWith(prefix) && label.length > prefix.length ->
                        label.substring(prefix.length).trim()
                    else -> null
                }
                if (value != null && validCounterparty(value)) return value
            }
        }
        return null
    }

    private fun validCounterparty(value: String): Boolean =
        value.length in 2..80 &&
            !value.contains("金额") &&
            !value.contains("时间") &&
            !CURRENCY_PATTERN.containsMatchIn(value)

    private fun uniqueAmount(labels: List<String>, keys: Set<String>): Long? {
        CandidateFieldExtractor.labeledAmount(labels, keys)?.let { return it }

        val candidates = labels
            .filterNot { label ->
                label.contains("订单") ||
                    label.contains("原价") ||
                    label.contains("优惠") ||
                    label.contains("余额")
            }
            .flatMap { label ->
                CURRENCY_PATTERN.findAll(label)
                    .mapNotNull { match -> toCents(match.groupValues[1]) }
                    .toList()
            }
            .toSet()
        return candidates.singleOrNull()
    }

    private fun toCents(raw: String): Long? =
        raw.toBigDecimalOrNull()
            ?.multiply(BigDecimal(100))
            ?.let { runCatching { it.longValueExact() }.getOrNull() }
            ?.takeIf { it in 1..99_999_999_999L }

    private companion object {
        val REFUND_STATUSES = setOf(
            "退款成功",
            "退款到账",
            "退款已到账",
            "已退款",
            "退款完成",
        )
        val INCOME_STATUSES = setOf(
            "收款到账",
            "收款成功",
            "收款已到账",
            "收入到账",
        )
        val CURRENCY_PATTERN = Regex(
            "[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])",
        )
        val SOURCES = mapOf(
            "com.tencent.mm" to "WECHAT",
            "com.eg.android.AlipayGphone" to "ALIPAY",
            "com.unionpay" to "UNIONPAY",
            "com.sankuai.meituan" to "MEITUAN",
            "com.sankuai.meituan.takeout" to "MEITUAN",
            "com.jingdong.app.mall" to "JD",
            "com.xunmeng.pinduoduo" to "PINDUODUO",
            "com.ss.android.ugc.aweme" to "DOUYIN",
            "com.ss.android.ugc.aweme.mobile" to "DOUYIN",
        )
    }
}
