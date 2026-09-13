package com.algive.jizhang_app.autobookkeeping.confidence
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate

data class ConfidenceReport(val amountConfidence: Double, val merchantConfidence: Double, val accountConfidence: Double, val categoryConfidence: Double, val sceneConfidence: Double) {
    val overallConfidence get() = amountConfidence * .3 + merchantConfidence * .2 + accountConfidence * .15 + categoryConfidence * .15 + sceneConfidence * .2
}
object ConfidenceEngine {
    fun evaluate(c: PaymentCandidate, account: Double, category: Double) = ConfidenceReport(c.amountConfidence, c.merchantConfidence, account, category, c.scene.confidence)
}
