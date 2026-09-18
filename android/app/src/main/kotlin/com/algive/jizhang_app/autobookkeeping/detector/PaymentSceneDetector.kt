package com.algive.jizhang_app.autobookkeeping.detector

import com.algive.jizhang_app.autobookkeeping.model.*
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser

class PaymentSceneDetector(
    private val parser: WeChatPaymentParser = WeChatPaymentParser(),
    private val appParser: PaymentAppParser = PaymentAppParser(),
) {
    fun detect(packageName: String, nodes: List<ScreenNode>, timestamp: Long = System.currentTimeMillis()): PaymentCandidate? =
        if (packageName == parser.rule.app) parser.parse(nodes, timestamp) else appParser.parse(packageName, nodes, timestamp)
}
