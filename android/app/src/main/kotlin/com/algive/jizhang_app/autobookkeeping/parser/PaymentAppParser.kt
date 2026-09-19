package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import java.math.BigDecimal

/** Conservative parser for payment apps whose accessibility layouts vary. */
class PaymentAppParser {
    private val packages = mapOf(
        "com.eg.android.AlipayGphone" to "ALIPAY",
        "com.unionpay" to "UNIONPAY",
        "com.sankuai.meituan" to "MEITUAN",
        "com.sankuai.meituan.takeout" to "MEITUAN",
        "com.jingdong.app.mall" to "JD",
        "com.xunmeng.pinduoduo" to "PINDUODUO",
        "com.ss.android.ugc.aweme" to "DOUYIN",
        "com.ss.android.ugc.aweme.mobile" to "DOUYIN",
    )
    private val keywords = setOf("支付成功", "付款成功", "交易成功", "已支付", "支付完成", "付款完成", "订单支付成功")
    private val merchantKeys = setOf("收款方", "商户", "商户名称", "商家", "店铺", "门店")
    private val amountKeys = setOf("实付", "实付金额", "付款金额", "支付金额", "实际支付", "消费金额", "扣款金额")
    private val excluded = setOf("优惠", "余额", "订单", "时间", "积分", "原价", "商品金额", "合计", "立减", "红包")
    private val amountPatterns = listOf(
        Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])"),
        Regex("(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
    )

    fun parse(packageName: String, nodes: List<ScreenNode>, timestamp: Long): PaymentCandidate? {
        val sourceApp = packages[packageName] ?: return null
        val labels = nodes.map { it.label }.filter { it.isNotBlank() }
        if (labels.none { label -> keywords.any { key -> label == key || label.startsWith("$key ") } }) return null

        val merchant = (CandidateFieldExtractor.field(labels, merchantKeys) ?: fallbackMerchant(labels))
            ?.takeIf { value -> value.isNotBlank() && value !in keywords && amountKeys.none { value.contains(it) } }
            ?: return null
        val method = CandidateFieldExtractor
            .field(labels, setOf("支付方式", "付款方式", "支付渠道"))
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"
        val amounts = mutableListOf<Pair<Long, Int>>()
        labels.forEachIndexed { index, label ->
            if (excluded.any { label.contains(it) }) return@forEachIndexed
            val previous = labels.getOrNull(index - 1).orEmpty()
            val explicit = amountKeys.any { label.startsWith(it) || previous == it }
            if (!explicit && excluded.any { previous.contains(it) }) return@forEachIndexed
            val matches = amountPatterns.flatMap { pattern ->
                pattern.findAll(label).map { it.groupValues[1] }.toList()
            }.distinct()
            val raw = if (matches.isEmpty() && explicit && label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))) listOf(label) else matches
            raw.forEach { value ->
                val cents = value.toBigDecimalOrNull()?.multiply(BigDecimal(100))
                    ?.let { runCatching { it.longValueExact() }.getOrNull() }
                if (cents != null && cents in 1..99_999_999_999L) amounts += cents to if (explicit) 3 else 1
            }
        }
        val best = amounts.maxOfOrNull { it.second } ?: return null
        val winners = amounts.filter { it.second == best }.map { it.first }.distinct()
        if (winners.size != 1) return null
        val paidAmount = winners.single()
        val (originalAmount, discountAmount) =
            CandidateFieldExtractor.amountBreakdown(labels, paidAmount)
        return PaymentCandidate(
            paidAmount,
            merchant.take(80),
            MerchantNormalizer.normalize(merchant),
            method.take(80),
            timestamp,
            PaymentScene(sourceApp = sourceApp, scene = "${sourceApp}_PAYMENT_SUCCESS", confidence = if (method != "UNKNOWN") .95 else .88),
            if (best == 3) 1.0 else .9,
            .9,
            sourceApp,
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
            identifierSuffix = CandidateFieldExtractor.identifierSuffix(method, labels),
        )
    }

    private fun fallbackMerchant(labels: List<String>): String? = labels.firstOrNull { label ->
        label.length in 2..80 && label !in keywords &&
            label !in amountKeys && label !in excluded &&
            amountPatterns.none { it.containsMatchIn(label) } &&
            !label.contains("支付方式") && !label.contains("付款方式")
    }
}
