package com.algive.jizhang_app.autobookkeeping.repository

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import org.json.JSONObject
import java.io.File
import kotlin.math.abs

enum class PendingEnqueueDecision {
    ACCEPTED,
    DUPLICATE,
    BUSY,
}

/**
 * Keeps one payment candidate between native capture sources and Flutter.
 *
 * There is still a single visible confirmation slot, but it is no longer
 * "first writer wins": a high-confidence accessibility payment-success result
 * can replace a lower-confidence notification candidate. Cross-source
 * observations of the same payment are deduplicated before reaching the UI.
 */
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

    private const val PRIORITY_NOTIFICATION = 1
    private const val PRIORITY_ACCESSIBILITY = 2

    fun enqueueIfAbsent(context: Context, candidate: PaymentCandidate): Boolean =
        enqueueDecision(context, candidate) == PendingEnqueueDecision.ACCEPTED

    fun enqueueDecision(
        context: Context,
        candidate: PaymentCandidate,
    ): PendingEnqueueDecision {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val incoming = payload(candidate, now)
        val pending = parse(preferences.getString(KEY_PENDING, null))

        if (pending != null) {
            val createdAt = pending.optLong(KEY_CREATED_AT, 0L)
            if (createdAt <= 0L || now - createdAt > PENDING_TTL_MILLIS) {
                deleteScreenshot(context, pending.optString("screenshotPath"))
                preferences.edit().remove(KEY_PENDING).apply()
            } else {
                val sameTransaction = isLikelySameTransaction(pending, incoming)
                val existingPriority = pending.optInt(
                    KEY_PRIORITY,
                    priorityFor(pending.optString("scene")),
                )
                val incomingPriority = incoming.optInt(KEY_PRIORITY)

                if (sameTransaction) {
                    if (incomingPriority > existingPriority) {
                        deleteScreenshot(context, pending.optString("screenshotPath"))
                        preferences.edit()
                            .putString(KEY_PENDING, incoming.toString())
                            .apply()
                        return PendingEnqueueDecision.ACCEPTED
                    }
                    return PendingEnqueueDecision.DUPLICATE
                }

                // A low-confidence notification must never block a real
                // payment-success page for the whole pending TTL.
                if (incomingPriority > existingPriority) {
                    deleteScreenshot(context, pending.optString("screenshotPath"))
                    preferences.edit()
                        .putString(KEY_PENDING, incoming.toString())
                        .apply()
                    return PendingEnqueueDecision.ACCEPTED
                }
                return PendingEnqueueDecision.BUSY
            }
        }

        val fingerprint = incoming.optString(KEY_FINGERPRINT)
        val handledFingerprint = preferences.getString(KEY_HANDLED_FINGERPRINT, null)
        val handledAt = preferences.getLong(KEY_HANDLED_AT, 0L)
        if (
            handledFingerprint == fingerprint &&
            now - handledAt <= HANDLED_TTL_MILLIS
        ) {
            return PendingEnqueueDecision.DUPLICATE
        }

        val handledPayload = parse(preferences.getString(KEY_HANDLED_PAYLOAD, null))
        if (
            handledPayload != null &&
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
        val transactionType =
            (arguments["transactionType"] as? String)?.trim().orEmpty().ifBlank { "EXPENSE" }
        val orderId = (arguments["orderId"] as? String)?.trim()?.takeIf { it.isNotBlank() }
        val note = (arguments["note"] as? String)?.trim()?.takeIf { it.isNotBlank() }
        val originalAmount =
            (arguments["originalAmountInCents"] as? Number)?.toLong()
        val discountAmount =
            (arguments["discountAmountInCents"] as? Number)?.toLong()
        val identifierSuffix =
            (arguments["identifierSuffix"] as? String)?.trim()?.takeIf { it.isNotBlank() }
        val targetIdentifierSuffix =
            (arguments["targetIdentifierSuffix"] as? String)
                ?.trim()
                ?.takeIf { it.isNotBlank() }
        val targetAccountHint =
            (arguments["targetAccountHint"] as? String)
                ?.trim()
                ?.takeIf { it.isNotBlank() }
        val screenshotPath =
            (arguments["screenshotPath"] as? String)?.trim()?.takeIf { it.isNotBlank() }

        if (
            amount !in 1..99_999_999_999L ||
            merchant.isBlank() ||
            merchant.length > 80 ||
            paymentMethod.length > 80 ||
            sourceApp !in SUPPORTED_SOURCE_APPS ||
            scene.length !in 1..80 ||
            transactionType !in SUPPORTED_TRANSACTION_TYPES ||
            timestamp <= 0L ||
            (originalAmount != null && originalAmount !in amount..99_999_999_999L) ||
            (discountAmount != null && discountAmount !in 0..99_999_999_999L) ||
            (identifierSuffix != null && !identifierSuffix.matches(Regex("\\d{4}"))) ||
            (targetIdentifierSuffix != null &&
                !targetIdentifierSuffix.matches(Regex("\\d{4}"))) ||
            (targetAccountHint != null && targetAccountHint.length > 120) ||
            (screenshotPath != null && screenshotPath.length > 500)
        ) {
            return null
        }

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant,
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = paymentMethod,
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = sourceApp,
                scene = scene,
                confidence = .9,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .9,
            sourceApp = sourceApp,
            transactionType = transactionType,
            orderId = orderId?.take(64),
            note = note?.take(160),
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
            identifierSuffix = identifierSuffix,
            targetIdentifierSuffix = targetIdentifierSuffix,
            targetAccountHint = targetAccountHint?.take(120),
            screenshotPath = screenshotPath,
        )
    }

    fun readCandidate(context: Context): PaymentCandidate? {
        val value = readValidPayload(context) ?: return null
        return candidateFromMap(
            mapOf(
                "amountInCents" to value.optLong("amountInCents"),
                "merchant" to value.optString("merchant"),
                "paymentMethod" to value.optString("paymentMethod"),
                "timestamp" to value.optLong("timestamp"),
                "sourceApp" to value.optString("sourceApp"),
                "scene" to value.optString("scene"),
                "transactionType" to value.optString("transactionType"),
                "orderId" to value.optString("orderId").takeIf { it.isNotBlank() },
                "note" to value.optString("note").takeIf { it.isNotBlank() },
                "originalAmountInCents" to
                    value.optLong("originalAmountInCents").takeIf { value.has("originalAmountInCents") },
                "discountAmountInCents" to
                    value.optLong("discountAmountInCents").takeIf { value.has("discountAmountInCents") },
                "identifierSuffix" to
                    value.optString("identifierSuffix").takeIf { it.isNotBlank() },
                "targetIdentifierSuffix" to
                    value.optString("targetIdentifierSuffix").takeIf { it.isNotBlank() },
                "targetAccountHint" to
                    value.optString("targetAccountHint").takeIf { it.isNotBlank() },
                "screenshotPath" to
                    value.optString("screenshotPath").takeIf { it.isNotBlank() },
            ),
        )
    }

    fun read(context: Context): Map<String, Any>? {
        val value = readValidPayload(context) ?: return null
        return mapOf(
            KEY_FINGERPRINT to value.optString(KEY_FINGERPRINT),
            "amountInCents" to value.optLong("amountInCents"),
            "merchant" to value.optString("merchant"),
            "paymentMethod" to value.optString("paymentMethod"),
            "timestamp" to value.optLong("timestamp"),
            "sourceApp" to value.optString("sourceApp"),
            "scene" to value.optString("scene"),
            "transactionType" to value.optString("transactionType"),
            "orderId" to value.optString("orderId"),
            "note" to value.optString("note"),
            "originalAmountInCents" to value.optLong("originalAmountInCents"),
            "discountAmountInCents" to value.optLong("discountAmountInCents"),
            "identifierSuffix" to value.optString("identifierSuffix"),
            "targetIdentifierSuffix" to value.optString("targetIdentifierSuffix"),
            "targetAccountHint" to value.optString("targetAccountHint"),
            "screenshotPath" to value.optString("screenshotPath"),
        )
    }

    fun complete(
        context: Context,
        remember: Boolean = true,
        keepScreenshot: Boolean = false,
    ) {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = parse(preferences.getString(KEY_PENDING, null))
        val fingerprint = value?.optString(KEY_FINGERPRINT).orEmpty()
        val screenshotPath = value?.optString("screenshotPath").orEmpty()
        val editor = preferences.edit().remove(KEY_PENDING)

        if (!keepScreenshot) {
            deleteScreenshot(context, screenshotPath)
        }

        if (
            remember &&
            value != null &&
            fingerprint.isNotBlank()
        ) {
            val handled = JSONObject(value.toString()).apply {
                remove("screenshotPath")
            }
            editor
                .putString(KEY_HANDLED_FINGERPRINT, fingerprint)
                .putString(KEY_HANDLED_PAYLOAD, handled.toString())
                .putLong(KEY_HANDLED_AT, System.currentTimeMillis())
        }

        editor.apply()
    }

    fun attachScreenshotIfCurrent(
        context: Context,
        fingerprint: String,
        path: String,
    ): Boolean {
        if (!isManagedScreenshot(context, path)) {
            return false
        }
        val file = File(path)
        if (!file.isFile) return false

        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = parse(preferences.getString(KEY_PENDING, null))
        if (
            pending == null ||
            pending.optString(KEY_FINGERPRINT) != fingerprint
        ) {
            deleteScreenshot(context, path)
            return false
        }

        val oldPath = pending.optString("screenshotPath")
        if (oldPath.isNotBlank() && oldPath != path) {
            deleteScreenshot(context, oldPath)
        }
        pending.put("screenshotPath", path)
        preferences.edit().putString(KEY_PENDING, pending.toString()).apply()
        return true
    }

    private fun readValidPayload(context: Context): JSONObject? {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = parse(preferences.getString(KEY_PENDING, null)) ?: return null
        val createdAt = value.optLong(KEY_CREATED_AT, 0L)

        if (
            createdAt <= 0L ||
            System.currentTimeMillis() - createdAt > PENDING_TTL_MILLIS
        ) {
            complete(context, remember = false)
            return null
        }

        return value
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
            .apply {
                candidate.orderId?.let { put("orderId", it) }
                candidate.note?.let { put("note", it) }
                candidate.originalAmountInCents?.let { put("originalAmountInCents", it) }
                candidate.discountAmountInCents?.let { put("discountAmountInCents", it) }
                candidate.identifierSuffix?.let { put("identifierSuffix", it) }
                candidate.targetIdentifierSuffix?.let {
                    put("targetIdentifierSuffix", it)
                }
                candidate.targetAccountHint?.let { put("targetAccountHint", it) }
                candidate.screenshotPath?.let { put("screenshotPath", it) }
            }

    private fun priorityFor(scene: String): Int =
        if (scene.startsWith("PAYMENT_NOTIFICATION")) {
            PRIORITY_NOTIFICATION
        } else {
            PRIORITY_ACCESSIBILITY
        }

    /**
     * Cross-source duplicate matching intentionally ignores paymentMethod and
     * merchant when one observation is a notification and the other is an
     * accessibility page. Marketplace notifications often say "美团外卖"
     * while the payment page exposes the actual store name.
     */
    private fun isLikelySameTransaction(
        first: JSONObject,
        second: JSONObject,
    ): Boolean {
        val sameSource =
            first.optString("sourceApp") == second.optString("sourceApp")
        val firstNotification =
            first.optString("scene").startsWith("PAYMENT_NOTIFICATION")
        val secondNotification =
            second.optString("scene").startsWith("PAYMENT_NOTIFICATION")
        val crossCaptureSource = firstNotification != secondNotification
        if (
            !transactionTypesCompatible(
                first.optString("transactionType", "EXPENSE"),
                second.optString("transactionType", "EXPENSE"),
                crossCaptureSource,
            )
        ) {
            return false
        }
        if (first.optLong("amountInCents") != second.optLong("amountInCents")) {
            return false
        }

        val firstOrderId = first.optString("orderId").trim()
        val secondOrderId = second.optString("orderId").trim()
        if (
            firstOrderId.isNotBlank() &&
            secondOrderId.isNotBlank() &&
            firstOrderId == secondOrderId
        ) {
            return true
        }

        val firstAt = first.optLong("timestamp", 0L)
        val secondAt = second.optLong("timestamp", 0L)
        if (
            firstAt <= 0L ||
            secondAt <= 0L ||
            abs(firstAt - secondAt) > CROSS_SOURCE_MATCH_MILLIS
        ) {
            return false
        }

        val firstMerchant = MerchantNormalizer.normalize(first.optString("merchant"))
        val secondMerchant = MerchantNormalizer.normalize(second.optString("merchant"))
        val sameMerchant =
            firstMerchant.isNotBlank() &&
                secondMerchant.isNotBlank() &&
                firstMerchant == secondMerchant

        if (crossCaptureSource) {
            // The same marketplace payment may be observed from the merchant
            // app page and from the underlying Alipay/WeChat/UnionPay
            // notification. Merchant labels often differ, so also correlate
            // the page's explicit payment method with the other source app.
            val samePaymentRail =
                paymentMethodMatchesSource(
                    first.optString("paymentMethod"),
                    second.optString("sourceApp"),
                ) ||
                    paymentMethodMatchesSource(
                        second.optString("paymentMethod"),
                        first.optString("sourceApp"),
                    )
            return sameSource || sameMerchant || samePaymentRail
        }

        return sameSource && sameMerchant
    }

    internal fun transactionTypesCompatible(
        first: String,
        second: String,
        crossCaptureSource: Boolean,
    ): Boolean {
        if (first == second) return true
        if (!crossCaptureSource) return false
        val pair = setOf(first, second)
        return pair == setOf("EXPENSE", "TRANSFER") ||
            pair == setOf("EXPENSE", "REPAYMENT")
    }

    private fun paymentMethodMatchesSource(
        paymentMethod: String,
        sourceApp: String,
    ): Boolean {
        val normalized = paymentMethod.trim()
        if (normalized.isEmpty()) return false
        return when (sourceApp) {
            "ALIPAY" -> normalized.contains("支付宝")
            "WECHAT" -> normalized.contains("微信")
            "UNIONPAY" ->
                normalized.contains("云闪付") ||
                    normalized.contains("银行卡") ||
                    normalized.contains("信用卡") ||
                    normalized.contains("储蓄卡")
            else -> false
        }
    }

    private fun isManagedScreenshot(context: Context, path: String): Boolean {
        if (path.isBlank()) return false
        return runCatching {
            val root = File(
                context.filesDir,
                "autobookkeeping/pending_screenshots",
            ).canonicalFile
            val file = File(path).canonicalFile
            file.path.startsWith(root.path + File.separator)
        }.getOrDefault(false)
    }

    private fun deleteScreenshot(context: Context, path: String) {
        if (!isManagedScreenshot(context, path)) return
        runCatching { File(path).delete() }
    }

    fun cleanupOrphanedScreenshots(context: Context) {
        val validPath = readValidPayload(context)
            ?.optString("screenshotPath")
            .orEmpty()
        val directory = File(
            context.filesDir,
            "autobookkeeping/pending_screenshots",
        )
        directory.listFiles()
            ?.filter { file ->
                file.isFile &&
                    (validPath.isBlank() ||
                        runCatching {
                            file.canonicalPath != File(validPath).canonicalPath
                        }.getOrDefault(true))
            }
            ?.forEach { file -> runCatching { file.delete() } }
    }

    fun promoteScreenshot(
        context: Context,
        path: String,
    ): String? {
        if (!isManagedScreenshot(context, path)) return null
        val source = File(path)
        if (!source.isFile) return null

        val directory = File(
            context.filesDir,
            "autobookkeeping/attachments",
        )
        if (!directory.exists() && !directory.mkdirs()) return null

        val destination = File(directory, source.name)
        if (destination.exists()) {
            runCatching { source.delete() }
            return destination.absolutePath
        }
        return runCatching {
            if (!source.renameTo(destination)) {
                source.copyTo(destination, overwrite = false)
                source.delete()
            }
            destination.absolutePath
        }.getOrNull()
    }

    private fun parse(raw: String?): JSONObject? = raw?.let {
        runCatching { JSONObject(it) }.getOrNull()
    }

    private val SUPPORTED_TRANSACTION_TYPES = setOf(
        "EXPENSE",
        "INCOME",
        "REFUND",
        "REIMBURSEMENT",
        "REPAYMENT",
        "TRANSFER",
    )

    private val SUPPORTED_SOURCE_APPS = setOf(
        "WECHAT",
        "ALIPAY",
        "UNIONPAY",
        "MEITUAN",
        "JD",
        "PINDUODUO",
        "DOUYIN",
    )
}
