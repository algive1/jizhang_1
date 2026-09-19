package com.algive.jizhang_app.autobookkeeping.detector

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.MeituanPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser
import com.algive.jizhang_app.autobookkeeping.parser.TransactionStatusParser
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
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
        TransactionStatusParser(),
) {
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
    ): PaymentDetectionResult {
        if (registry.ruleFor(packageName) == null) {
            return PaymentDetectionResult(null, "UNSUPPORTED_PACKAGE")
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
