package com.algive.jizhang_app.autobookkeeping.detector

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.MeituanPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser
import com.algive.jizhang_app.autobookkeeping.parser.TransactionStatusParser
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiProfilePageParserRegistry
import com.algive.jizhang_app.autobookkeeping.parser.QianjiWechatPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiAlipayPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiPddPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiDouyinPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiUnionpayPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiJingDongPageParser
import com.algive.jizhang_app.autobookkeeping.parser.QianjiMeituanPageParser
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import com.algive.jizhang_app.autobookkeeping.rules.PaymentParserKind
import com.algive.jizhang_app.autobookkeeping.rules.PaymentRule

data class PaymentDetectionResult(
    val candidate: PaymentCandidate?,
    val rejectionReason: String?,
)

class PaymentSceneDetector(
    val registry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn(),
    private val transactionStatusParser: TransactionStatusParser =
        TransactionStatusParser(registry),
) {
    private val qianjiPageParsers = QianjiProfilePageParserRegistry(
        listOf(
            QianjiWechatPageParser(),
            QianjiAlipayPageParser(),
            QianjiPddPageParser(),
            QianjiDouyinPageParser(),
            QianjiUnionpayPageParser(),
            QianjiJingDongPageParser(),
            QianjiMeituanPageParser(),
        ),
    )
    private val weChatRule =
        registry.ruleForKind(PaymentParserKind.WECHAT)
            ?: error("Missing WeChat payment rule")
    private val meituanRule =
        registry.ruleForKind(PaymentParserKind.MEITUAN)
            ?: error("Missing Meituan payment rule")
    private val weChatParser = WeChatPaymentParser(PaymentRule.from(weChatRule))
    private val appParser = PaymentAppParser(registry)
    private val meituanParser = MeituanPaymentParser(meituanRule)

    fun detect(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long = System.currentTimeMillis(),
    ): PaymentCandidate? = inspect(packageName, nodes, timestamp).candidate

    fun inspect(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long = System.currentTimeMillis(),
        activityClassName: String? = null,
    ): PaymentDetectionResult {
        if (registry.ruleFor(packageName) == null) {
            return PaymentDetectionResult(null, "UNSUPPORTED_PACKAGE")
        }

        // A legacy WeChat confirmation layout carries a transfer recipient but
        // also the generic 支付成功 label. Preserve its specific transfer result
        // before the Qianji payment-success page can claim that sparse layout.
        if (
            packageName == "com.tencent.mm" &&
            nodes.any { it.label.contains("确认收款") } &&
            nodes.any { it.label == "支付成功" }
        ) {
            transactionStatusParser.parse(packageName, nodes, timestamp)?.let {
                return PaymentDetectionResult(it, null)
            }
        }

        val qianjiResult = qianjiPageParsers.inspect(
            packageName = packageName,
            nodes = nodes,
            observedAt = timestamp,
            activityClassName = activityClassName,
        )
        if (qianjiResult?.blocksLegacyFallback == true) {
            return PaymentDetectionResult(
                qianjiResult.candidate,
                qianjiResult.rejectionReason
                    ?: if (qianjiResult.candidate == null) "QIANJI_PAGE_REJECTED" else null,
            )
        }

        val typedCandidate =
            transactionStatusParser.parse(packageName, nodes, timestamp)
        if (typedCandidate != null) {
            return PaymentDetectionResult(typedCandidate, null)
        }

        val rule = registry.ruleFor(packageName)
            ?: return PaymentDetectionResult(null, "UNSUPPORTED_PACKAGE")
        val candidate = when (rule.parserKind) {
            PaymentParserKind.WECHAT ->
                weChatParser.parse(nodes, timestamp)
            PaymentParserKind.MEITUAN ->
                meituanParser.parse(packageName, nodes, timestamp)
            PaymentParserKind.GENERIC ->
                appParser.parse(packageName, nodes, timestamp)
        }
        if (candidate != null) {
            return PaymentDetectionResult(candidate, null)
        }

        val typedReason =
            transactionStatusParser.rejectionReason(packageName, nodes)
        val reason = when {
            typedReason != null -> typedReason
            rule.parserKind == PaymentParserKind.MEITUAN ->
                meituanParser.rejectionReason(packageName, nodes)
            nodes.none { it.label.isNotBlank() } ->
                "NO_VISIBLE_LABELS"
            else ->
                "NO_MATCHING_PAYMENT_SCENE"
        }
        return PaymentDetectionResult(null, reason)
    }
}
