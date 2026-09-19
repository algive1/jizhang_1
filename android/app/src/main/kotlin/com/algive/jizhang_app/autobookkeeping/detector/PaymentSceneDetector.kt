package com.algive.jizhang_app.autobookkeeping.detector

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.MeituanPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser

data class PaymentDetectionResult(
    val candidate: PaymentCandidate?,
    val rejectionReason: String?,
)

class PaymentSceneDetector(
    private val weChatParser: WeChatPaymentParser = WeChatPaymentParser(),
    private val appParser: PaymentAppParser = PaymentAppParser(),
    private val meituanParser: MeituanPaymentParser = MeituanPaymentParser(),
) {
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
        val candidate = when {
            packageName == weChatParser.rule.app ->
                weChatParser.parse(nodes, timestamp)
            packageName in MEITUAN_PACKAGES ->
                meituanParser.parse(packageName, nodes, timestamp)
            else ->
                appParser.parse(packageName, nodes, timestamp)
        }
        if (candidate != null) return PaymentDetectionResult(candidate, null)

        val reason = when {
            packageName in MEITUAN_PACKAGES ->
                meituanParser.rejectionReason(packageName, nodes)
            nodes.none { it.label.isNotBlank() } ->
                "NO_VISIBLE_LABELS"
            else ->
                "NO_MATCHING_PAYMENT_SCENE"
        }
        return PaymentDetectionResult(null, reason)
    }

    private companion object {
        val MEITUAN_PACKAGES = setOf(
            "com.sankuai.meituan",
            "com.sankuai.meituan.takeout",
        )
    }
}
