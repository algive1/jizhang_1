package com.algive.jizhang_app.autobookkeeping.repository

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import org.json.JSONObject
import kotlin.math.abs

/**
 * Keeps one payment candidate between native capture sources and Flutter.
 *
 * There is still a single visible confirmation slot, but the slot is no longer
 * "first writer wins": an accessibility payment-success result can replace a
 * lower-confidence notification candidate. Cross-source observations of the
 * same payment are also deduplicated before they reach the overlay.
 */
enum class PendingEnqueueDecision {
    ACCEPTED,
    DUPLICATE,
    BUSY,
}

object AutoBookkeepingPendingStore {
    private const val PREFS = "autobookkeeping.pending"
    private const val KEY_PENDING = "pending"
    private const val KEY_HANDLED_FINGERPRINT = "handled_fingerprint"
    private const val KEY_HANDLED_AT = "handled_at"
    private const val KEY_HANDLED_PAYLOAD = "handled_payload"
    private const val KEY_FINGERPRINT = "fingerprint"
    private const val KEY_CREATED_AT = "created_at"
    private const val KEY_PRIORITY = "priority"

    private const val PENDING_TTL_MILLIS = 30 * 60 * 1000L
    private const val HANDLED_TTL_MILLIS = 10 * 60 * 1000L
    private const val CROSS_SOURCE_MATCH_MILLIS = 2 * 60 * 1000L

    fun enqueueIfAbsent(context: Context, candidate: PaymentCandidate): Boolean =
        enqueueDecision(context, candidate) == PendingEnqueueDecision.ACCEPTED

    fun enqueueDecision(context: Context, candidate: PaymentCandidate): PendingEnqueueDecision {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val incoming = payload(candidate, now)
        val pending = parse(preferences.getString(KEY_PENDING, null))

        if (pending != null) {
            if (isInvalidLegacyNotification(pending)) {
                preferences.edit().remove(KEY_PENDING).apply()
            } else {
            val createdAt = pending.optLong(KEY_CREATED_AT, 0L)
            if (createdAt <= 0L || now - createdAt > PENDING_TTL_MILLIS) {
                preferences.edit().remove(KEY_PENDING).apply()
            } else {
                val sameTransaction = isLikelySameTransaction(pending, incoming)
                val existingPriority = pending.optInt(KEY_PRIORITY, priorityFor(pending.optString("scene")))
                val incomingPriority = incoming.optInt(KEY_PRIORITY)

                if (sameTransaction) {
                    if (incomingPriority > existingPriority) {
                        preferences.edit().putString(KEY_PENDING, incoming.toString()).apply()
                        return PendingEnqueueDecision.ACCEPTED
                    }
                    return PendingEnqueueDecision.DUPLICATE
                }

                // A low-confidence notification must never block a real
                // accessibility payment-success page for up to 30 minutes.
                if (incomingPriority > existingPriority) {
                    preferences.edit().putString(KEY_PENDING, incoming.toString()).apply()
                    return PendingEnqueueDecision.ACCEPTED
                }
                return PendingEnqueueDecision.BUSY
            }
            }
        }

        val fingerprint = incoming.optString(KEY_FINGERPRINT)
        val handledFingerprint = preferences.getString(KEY_HANDLED_FINGERPRINT, null)
        val handledAt = preferences.getLong(KEY_HANDLED_AT, 0L)
        if (handledFingerprint == fingerprint && now - handledAt <= HANDLED_TTL_MILLIS) {
            return PendingEnqueueDecision.DUPLICATE
        }

        val handledPayload = parse(preferences.getString(KEY_HANDLED_PAYLOAD, null))
        if (handledPayload != null &&
            now - handledAt <= HANDLED_TTL_MILLIS &&
            isLikelySameTransaction(handledPayload, incoming)
        ) {
            return PendingEnqueueDecision.DUPLICATE
        }

        preferences.edit().putString(KEY_PENDING, incoming.toString()).apply()
        return PendingEnqueueDecision.ACCEPTED
    }

    /** Converts a parsed, already-redacted Flutter notification candidate. */
    fun candidateFromMap(arguments: Map<*, *>): PaymentCandidate? {
        val amount = (arguments["amountInCents"] as? Number)?.toLong() ?: return null
        val merchant = (arguments["merchant"] as? String)?.trim().orEmpty()
        val paymentMethod = (arguments["paymentMethod"] as? String)?.trim().orEmpty()
        val timestamp = (arguments["timestamp"] as? Number)?.toLong() ?: return null
        val sourceApp = (arguments["sourceApp"] as? String)?.trim().orEmpty()
        val scene = (arguments["scene"] as? String)?.trim().orEmpty()
        if (amount !in 1..99_999_999_999L || merchant.isBlank() ||
            merchant.length > 80 || paymentMethod.length > 80 ||
            sourceApp !in SUPPORTED_SOURCE_APPS || scene.length !in 1..80 ||
            timestamp <= 0L
        ) return null
        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant,
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = paymentMethod,
            timestamp = timestamp,
            scene = PaymentScene(sourceApp = sourceApp, scene = scene, confidence = .9),
            amountConfidence = 1.0,
            merchantConfidence = .9,
            sourceApp = sourceApp,
        )
    }

    fun readCandidate(context: Context): PaymentCandidate? {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = parse(preferences.getString(KEY_PENDING, null)) ?: return null
        if (isInvalidLegacyNotification(value)) {
            complete(context, remember = false)
            return null
        }
        val createdAt = value.optLong(KEY_CREATED_AT, 0L)
        if (createdAt <= 0L || System.currentTimeMillis() - createdAt > PENDING_TTL_MILLIS) {
            complete(context, remember = false)
            return null
        }
        return candidateFromMap(
            mapOf(
                "amountInCents" to value.optLong("amountInCents"),
                "merchant" to value.optString("merchant"),
                "paymentMethod" to value.optString("paymentMethod"),
                "timestamp" to value.optLong("timestamp"),
                "sourceApp" to value.optString("sourceApp"),
                "scene" to value.optString("scene"),
            ),
        )
    }

    fun read(context: Context): Map<String, Any>? {
        val value = parse(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PENDING, null),
        ) ?: return null
        if (isInvalidLegacyNotification(value)) {
            complete(context, remember = false)
            return null
        }
        val createdAt = value.optLong(KEY_CREATED_AT, 0L)
        if (createdAt <= 0L || System.currentTimeMillis() - createdAt > PENDING_TTL_MILLIS) {
            complete(context, remember = false)
            return null
        }
        return mapOf(
            KEY_FINGERPRINT to value.optString(KEY_FINGERPRINT),
            "amountInCents" to value.optLong("amountInCents"),
            "merchant" to value.optString("merchant"),
            "paymentMethod" to value.optString("paymentMethod"),
            "timestamp" to value.optLong("timestamp"),
            "sourceApp" to value.optString("sourceApp"),
            "scene" to value.optString("scene"),
            "transactionType" to value.optString("transactionType"),
        )
    }

    fun complete(context: Context, remember: Boolean = true) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = parse(preferences.getString(KEY_PENDING, null))
        val fingerprint = value?.optString(KEY_FINGERPRINT).orEmpty()
        val editor = preferences.edit().remove(KEY_PENDING)
        if (remember && value != null && fingerprint.isNotBlank()) {
            editor
                .putString(KEY_HANDLED_FINGERPRINT, fingerprint)
                .putString(KEY_HANDLED_PAYLOAD, value.toString())
                .putLong(KEY_HANDLED_AT, System.currentTimeMillis())
        }
        editor.apply()
    }

    private fun payload(candidate: PaymentCandidate, now: Long): JSONObject =
        JSONObject()
            .put(KEY_FINGERPRINT, BillFingerprint.of(candidate))
            .put(KEY_CREATED_AT, now)
            .put(KEY_PRIORITY, priorityFor(candidate.scene.scene))
            .put("amountInCents", candidate.amountInCents)
            .put("merchant", candidate.merchantNormalized)
            .put("paymentMethod", candidate.paymentMethod)
            .put("timestamp", candidate.timestamp)
            .put("sourceApp", candidate.sourceApp)
            .put("scene", candidate.scene.scene)
            .put("transactionType", candidate.transactionType)

    private fun priorityFor(scene: String): Int =
        if (scene == "PAYMENT_NOTIFICATION") PRIORITY_NOTIFICATION else PRIORITY_ACCESSIBILITY

    /**
     * Cross-source duplicate matching intentionally ignores paymentMethod and
     * merchant when one observation is a notification and the other is an
     * accessibility page. Marketplace notifications often say "美团外卖"
     * while the payment page exposes the actual store name.
     */
    private fun isLikelySameTransaction(first: JSONObject, second: JSONObject): Boolean {
        if (first.optString("sourceApp") != second.optString("sourceApp")) return false
        if (first.optLong("amountInCents") != second.optLong("amountInCents")) return false
        val firstAt = first.optLong("timestamp", 0L)
        val secondAt = second.optLong("timestamp", 0L)
        if (firstAt <= 0L || secondAt <= 0L || abs(firstAt - secondAt) > CROSS_SOURCE_MATCH_MILLIS) {
            return false
        }

        val firstNotification = first.optString("scene") == "PAYMENT_NOTIFICATION"
        val secondNotification = second.optString("scene") == "PAYMENT_NOTIFICATION"
        if (firstNotification != secondNotification) return true

        val firstMerchant = MerchantNormalizer.normalize(first.optString("merchant"))
        val secondMerchant = MerchantNormalizer.normalize(second.optString("merchant"))
        return firstMerchant.isNotBlank() && firstMerchant == secondMerchant
    }

    private fun isInvalidLegacyNotification(value: JSONObject): Boolean {
        if (value.optString("scene") != "PAYMENT_NOTIFICATION") return false
        val merchant = value.optString("merchant").trim()
        return merchant.isBlank() || merchant == "支付通知待确认"
    }

    private fun parse(raw: String?): JSONObject? = raw?.let {
        runCatching { JSONObject(it) }.getOrNull()
    }

    private const val PRIORITY_NOTIFICATION = 1
    private const val PRIORITY_ACCESSIBILITY = 2

    private val SUPPORTED_SOURCE_APPS = setOf(
        "WECHAT",
        "ALIPAY",
        "UNIONPAY",
        "MEITUAN",
        "JD",
        "PINDUODUO",
        "DOUYIN",
        "PAYMENT_APP",
    )
}
