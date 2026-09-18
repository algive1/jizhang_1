package com.algive.jizhang_app.autobookkeeping.repository

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import org.json.JSONObject

/**
 * Keeps one payment candidate between the accessibility service and Flutter.
 * A single pending item is intentional: it prevents a stream of accessibility
 * events from opening multiple confirmation pages at the same time.
 */
object AutoBookkeepingPendingStore {
    private const val PREFS = "autobookkeeping.pending"
    private const val KEY_PENDING = "pending"
    private const val KEY_HANDLED_FINGERPRINT = "handled_fingerprint"
    private const val KEY_HANDLED_AT = "handled_at"
    private const val KEY_FINGERPRINT = "fingerprint"
    private const val KEY_CREATED_AT = "created_at"
    private const val PENDING_TTL_MILLIS = 30 * 60 * 1000L
    private const val HANDLED_TTL_MILLIS = 10 * 60 * 1000L

    fun enqueueIfAbsent(context: Context, candidate: PaymentCandidate): Boolean {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val pending = parse(preferences.getString(KEY_PENDING, null))
        if (pending != null) {
            val createdAt = pending.optLong(KEY_CREATED_AT, 0L)
            if (createdAt > 0L && now - createdAt <= PENDING_TTL_MILLIS) return false
            preferences.edit().remove(KEY_PENDING).apply()
        }

        val fingerprint = BillFingerprint.of(candidate)
        val handledFingerprint = preferences.getString(KEY_HANDLED_FINGERPRINT, null)
        val handledAt = preferences.getLong(KEY_HANDLED_AT, 0L)
        if (handledFingerprint == fingerprint && now - handledAt <= HANDLED_TTL_MILLIS) {
            return false
        }

        val payload = JSONObject()
            .put(KEY_FINGERPRINT, fingerprint)
            .put(KEY_CREATED_AT, now)
            .put("amountInCents", candidate.amountInCents)
            .put("merchant", candidate.merchantNormalized)
            .put("paymentMethod", candidate.paymentMethod)
            .put("timestamp", candidate.timestamp)
            .put("sourceApp", candidate.sourceApp)
            .put("scene", candidate.scene.scene)
            .put("transactionType", candidate.transactionType)
        preferences.edit().putString(KEY_PENDING, payload.toString()).apply()
        return true
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
        val payload = parse(preferences.getString(KEY_PENDING, null)) ?: return null
        val createdAt = payload.optLong(KEY_CREATED_AT, 0L)
        if (createdAt <= 0L || System.currentTimeMillis() - createdAt > PENDING_TTL_MILLIS) {
            complete(context, remember = false)
            return null
        }
        return candidateFromMap(
            mapOf(
                "amountInCents" to payload.optLong("amountInCents"),
                "merchant" to payload.optString("merchant"),
                "paymentMethod" to payload.optString("paymentMethod"),
                "timestamp" to payload.optLong("timestamp"),
                "sourceApp" to payload.optString("sourceApp"),
                "scene" to payload.optString("scene"),
            ),
        )
    }

    fun read(context: Context): Map<String, Any>? {
        val payload = parse(
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_PENDING, null),
        ) ?: return null
        val createdAt = payload.optLong(KEY_CREATED_AT, 0L)
        if (createdAt <= 0L || System.currentTimeMillis() - createdAt > PENDING_TTL_MILLIS) {
            complete(context, remember = false)
            return null
        }
        return mapOf(
            KEY_FINGERPRINT to payload.optString(KEY_FINGERPRINT),
            "amountInCents" to payload.optLong("amountInCents"),
            "merchant" to payload.optString("merchant"),
            "paymentMethod" to payload.optString("paymentMethod"),
            "timestamp" to payload.optLong("timestamp"),
            "sourceApp" to payload.optString("sourceApp"),
            "scene" to payload.optString("scene"),
            "transactionType" to payload.optString("transactionType"),
        )
    }

    fun complete(context: Context, remember: Boolean = true) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val payload = parse(preferences.getString(KEY_PENDING, null))
        val fingerprint = payload?.optString(KEY_FINGERPRINT).orEmpty()
        val editor = preferences.edit().remove(KEY_PENDING)
        if (remember && fingerprint.isNotBlank()) {
            editor
                .putString(KEY_HANDLED_FINGERPRINT, fingerprint)
                .putLong(KEY_HANDLED_AT, System.currentTimeMillis())
        }
        editor.apply()
    }

    private fun parse(raw: String?): JSONObject? = raw?.let {
        runCatching { JSONObject(it) }.getOrNull()
    }

    private val SUPPORTED_SOURCE_APPS = setOf("WECHAT", "ALIPAY", "UNIONPAY", "MEITUAN", "PAYMENT_APP")
}
