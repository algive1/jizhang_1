package com.algive.jizhang_app.autobookkeeping.model

data class ScreenNode(val text: String = "", val contentDescription: String = "", val viewId: String = "", val className: String = "", val bounds: List<Int> = emptyList(), val depth: Int = 0) {
    val label: String get() = text.ifBlank { contentDescription }.trim()
}
data class PaymentScene(val sourceApp: String = "WECHAT", val scene: String = "PAYMENT_SUCCESS", val confidence: Double)
data class PaymentCandidate(val amountInCents: Long, val merchantRaw: String, val merchantNormalized: String, val paymentMethod: String, val timestamp: Long, val scene: PaymentScene, val amountConfidence: Double, val merchantConfidence: Double) {
    val sourceApp = "WECHAT"
    val transactionType = "EXPENSE"
    fun toMap(): Map<String, Any> = mapOf("amountInCents" to amountInCents, "merchant" to merchantNormalized, "paymentMethod" to paymentMethod, "timestamp" to timestamp, "sourceApp" to sourceApp, "scene" to scene.scene)
}
