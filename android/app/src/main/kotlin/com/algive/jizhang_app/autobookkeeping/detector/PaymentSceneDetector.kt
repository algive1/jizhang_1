package com.algive.jizhang_app.autobookkeeping.detector

import com.algive.jizhang_app.autobookkeeping.model.*
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser

class PaymentSceneDetector(private val parser: WeChatPaymentParser = WeChatPaymentParser()) {
    fun detect(packageName: String, nodes: List<ScreenNode>, timestamp: Long = System.currentTimeMillis()): PaymentCandidate? =
        if (packageName == parser.rule.app) parser.parse(nodes, timestamp) else null
}
