package com.algive.jizhang_app.autobookkeeping.model

data class ScreenNode(
    val text: String = "",
    val contentDescription: String = "",
    val viewId: String = "",
    val className: String = "",
    val bounds: List<Int> = emptyList(),
    val depth: Int = 0,
) {
    val label: String get() = text.ifBlank { contentDescription }.trim()
}

data class PaymentScene(
    val sourceApp: String = "WECHAT",
    val scene: String = "PAYMENT_SUCCESS",
    val confidence: Double,
)

/**
 * Canonical transaction candidate produced by any Android capture source.
 *
 * Existing code can continue using the PaymentCandidate alias while new
 * fields/scenes are migrated incrementally. This keeps the capture layer
 * backwards compatible without freezing the model to expense-only payments.
 */
data class TransactionCandidate(
    val amountInCents: Long,
    val merchantRaw: String,
    val merchantNormalized: String,
    val paymentMethod: String,
    val timestamp: Long,
    val scene: PaymentScene,
    val amountConfidence: Double,
    val merchantConfidence: Double,
    val sourceApp: String = "WECHAT",
    val transactionType: String = "EXPENSE",
    val orderId: String? = null,
    val note: String? = null,
    val originalAmountInCents: Long? = null,
    val discountAmountInCents: Long? = null,
    val identifierSuffix: String? = null,
) {
    fun toMap(): Map<String, Any> = buildMap {
        put("amountInCents", amountInCents)
        put("merchant", merchantNormalized)
        put("paymentMethod", paymentMethod)
        put("timestamp", timestamp)
        put("sourceApp", sourceApp)
        put("scene", scene.scene)
        put("transactionType", transactionType)
        orderId?.let { put("orderId", it) }
        note?.let { put("note", it) }
        originalAmountInCents?.let { put("originalAmountInCents", it) }
        discountAmountInCents?.let { put("discountAmountInCents", it) }
        identifierSuffix?.let { put("identifierSuffix", it) }
    }
}

typealias PaymentCandidate = TransactionCandidate
