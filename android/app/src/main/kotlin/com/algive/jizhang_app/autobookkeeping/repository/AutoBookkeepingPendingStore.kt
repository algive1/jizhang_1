package com.algive.jizhang_app.autobookkeeping.repository

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.dedup.PaymentInboxDedup
import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import org.json.JSONObject
import org.json.JSONArray
import java.io.File

enum class PendingEnqueueDecision {
    ACCEPTED,
    DUPLICATE,
    BUSY,
    QUEUED,
}

/**
 * Keeps one active review and a durable inbox of deferred/ignored payments.
 * Higher-confidence observations enrich the same payment; unrelated payments
 * are queued without replacing the review the user is editing.
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
    private const val KEY_INBOX = "inbox"
    private const val KEY_HANDLED_HISTORY = "handled_history"
    private const val KEY_HANDLED_IDENTITIES = "handled_identities"

    private const val HANDLED_TTL_MILLIS = 10 * 60 * 1000L

    private const val PRIORITY_NOTIFICATION = 1
    private const val PRIORITY_ACCESSIBILITY = 2

    fun enqueueIfAbsent(context: Context, candidate: PaymentCandidate): Boolean =
        enqueueDecision(context, candidate) == PendingEnqueueDecision.ACCEPTED

    @Synchronized
    fun enqueueDecision(
        context: Context,
        candidate: PaymentCandidate,
    ): PendingEnqueueDecision {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val incoming = payload(candidate, now)
        val inbox = normalizeInbox(context)
        val pending = parse(preferences.getString(KEY_PENDING, null))
        if (handledMatch(context, rawMap(incoming))) {
            AutoBookkeepingLogStore.record(context, "pending_deduplicated", "reason=already_handled")
            return PendingEnqueueDecision.DUPLICATE
        }
        val values = listOfNotNull(pending) + inbox
        val duplicate = PaymentInboxDedup.find(values.map(::rawMap), rawMap(incoming))
        val existing = duplicate?.takeIf { pending == null || it > 0 }?.let { values[it] }
        if (existing != null) {
            val merged = mergePayload(existing, incoming)
            writeInbox(context, inbox.map { if (it === existing) merged else it })
            AutoBookkeepingLogStore.record(context, "pending_deduplicated", "reason=inbox_${PaymentInboxDedup.match(rawMap(existing), rawMap(incoming))}")
            return PendingEnqueueDecision.DUPLICATE
        }
        AutoBookkeepingLogStore.recordDetailed(
            context,
            "pending_enqueue_requested",
            "candidate=${candidate.toMap()} current=$pending",
        )

        if (pending != null) {
                val sameTransaction = duplicate == 0
                val existingPriority = pending.optInt(
                    KEY_PRIORITY,
                    priorityFor(pending.optString("scene")),
                )
                val incomingPriority = incoming.optInt(KEY_PRIORITY)

                if (sameTransaction) {
                    if (incomingPriority > existingPriority) {
                        preferences.edit()
                            .putString(KEY_PENDING, mergePayload(pending, incoming).toString())
                            .apply()
                        logEnqueueDecision(context, PendingEnqueueDecision.ACCEPTED, candidate, "same transaction upgraded")
                        return PendingEnqueueDecision.ACCEPTED
                    }
                    preferences.edit().putString(KEY_PENDING, mergePayload(pending, incoming).toString()).apply()
                    AutoBookkeepingLogStore.record(context, "pending_deduplicated", "reason=active_${PaymentInboxDedup.match(rawMap(pending), rawMap(incoming))}")
                    logEnqueueDecision(context, PendingEnqueueDecision.DUPLICATE, candidate, "same transaction")
                    return PendingEnqueueDecision.DUPLICATE
                }

                writeInbox(context, inbox + incoming.put("status", "pending").put("autoReviewRequested", true))
                logEnqueueDecision(context, PendingEnqueueDecision.QUEUED, candidate, "another bill is being reviewed")
                return PendingEnqueueDecision.QUEUED
        }

        preferences.edit().putString(KEY_PENDING, incoming.toString()).apply()
        logEnqueueDecision(context, PendingEnqueueDecision.ACCEPTED, candidate, "new pending candidate")
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
                confidence = (arguments["sceneConfidence"] as? Number)?.toDouble()?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0) ?: 0.0,
            ),
            amountConfidence = (arguments["amountConfidence"] as? Number)?.toDouble()?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0) ?: 0.0,
            merchantConfidence = (arguments["merchantConfidence"] as? Number)?.toDouble()?.takeIf { it.isFinite() }?.coerceIn(0.0, 1.0) ?: 0.0,
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
            transactionTimeKnown = arguments["transactionTimeKnown"] == true,
            paymentSessionId = (arguments["paymentSessionId"] as? String)?.take(80),
            paymentOriginApp = (arguments["paymentOriginApp"] as? String)?.take(20),
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
                "transactionTimeKnown" to value.optBoolean("transactionTimeKnown"),
                "paymentSessionId" to value.optString("paymentSessionId"),
                "paymentOriginApp" to value.optString("paymentOriginApp"),
                "sourceApp" to value.optString("sourceApp"),
                "scene" to value.optString("scene"),
                "transactionType" to value.optString("transactionType"),
                "amountConfidence" to value.optDouble("amountConfidence", 0.0),
                "merchantConfidence" to value.optDouble("merchantConfidence", 0.0),
                "sceneConfidence" to value.optDouble("sceneConfidence", 0.0),
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
        return payloadMap(value)
    }

    private fun payloadMap(value: JSONObject): Map<String, Any> = mapOf(
            KEY_FINGERPRINT to value.optString(KEY_FINGERPRINT),
            "amountInCents" to value.optLong("amountInCents"),
            "merchant" to value.optString("merchant"),
            "paymentMethod" to value.optString("paymentMethod"),
            "timestamp" to value.optLong("timestamp"),
            "transactionTimeKnown" to value.optBoolean("transactionTimeKnown"),
            "sourceApp" to value.optString("sourceApp"),
            "scene" to value.optString("scene"),
            "transactionType" to value.optString("transactionType"),
            "amountConfidence" to value.optDouble("amountConfidence", 0.0),
            "merchantConfidence" to value.optDouble("merchantConfidence", 0.0),
            "sceneConfidence" to value.optDouble("sceneConfidence", 0.0),
            "orderId" to value.optString("orderId"),
            "note" to value.optString("note"),
            "originalAmountInCents" to value.optLong("originalAmountInCents"),
            "discountAmountInCents" to value.optLong("discountAmountInCents"),
            "identifierSuffix" to value.optString("identifierSuffix"),
            "targetIdentifierSuffix" to value.optString("targetIdentifierSuffix"),
            "targetAccountHint" to value.optString("targetAccountHint"),
            "screenshotPath" to value.optString("screenshotPath"),
            "status" to value.optString("status", "pending"),
        )

    private fun jsonList(raw: String?): List<JSONObject> = runCatching {
        val array = JSONArray(raw ?: "[]")
        (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }.getOrDefault(emptyList())

    private fun inboxPayloads(context: Context) = jsonList(
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_INBOX, null),
    )

    private fun writeInbox(context: Context, values: List<JSONObject>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_INBOX, JSONArray(values).toString()).apply()
    }

    @Synchronized
    fun inbox(context: Context): List<Map<String, Any>> =
        (normalizeInbox(context) + listOfNotNull(readValidPayload(context)))
            .sortedByDescending { it.optLong(KEY_CREATED_AT) }.map(::payloadMap)

    fun pendingCount(context: Context): Int = inbox(context).count { it["status"] == "pending" }
    fun pendingCreatedAt(context: Context): Long = readValidPayload(context)?.optLong(KEY_CREATED_AT) ?: 0L

    @Synchronized
    fun deferCurrent(context: Context) {
        normalizeInbox(context)
        val current = readValidPayload(context) ?: return
        val values = inboxPayloads(context).filter { it.optString(KEY_FINGERPRINT) != current.optString(KEY_FINGERPRINT) }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_INBOX, JSONArray(values + current.put("status", "pending").put("autoReviewRequested", false)).toString())
            .remove(KEY_PENDING).apply()
    }

    @Synchronized
    fun select(context: Context, fingerprint: String): Boolean {
        normalizeInbox(context)
        if (readValidPayload(context)?.optString(KEY_FINGERPRINT) == fingerprint) return true
        val selected = inboxPayloads(context).firstOrNull { it.optString(KEY_FINGERPRINT) == fingerprint } ?: return false
        deferCurrent(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_PENDING, selected.put("status", "pending").toString())
            .putString(KEY_INBOX, JSONArray(inboxPayloads(context).filter { it.optString(KEY_FINGERPRINT) != fingerprint }).toString())
            .apply()
        return true
    }

    @Synchronized
    fun selectNextAutomatic(context: Context): PaymentCandidate? {
        if (readValidPayload(context) == null) {
            val next = normalizeInbox(context).filter {
                it.optString("status") == "pending" && it.optBoolean("autoReviewRequested")
            }.minByOrNull { it.optLong(KEY_CREATED_AT) } ?: return null
            if (!select(context, next.optString(KEY_FINGERPRINT))) return null
        }
        return readCandidate(context)
    }

    @Synchronized
    fun ignore(context: Context, fingerprint: String): Boolean {
        normalizeInbox(context)
        if (readValidPayload(context)?.optString(KEY_FINGERPRINT) == fingerprint) deferCurrent(context)
        val values = inboxPayloads(context)
        val selected = values.firstOrNull { it.optString(KEY_FINGERPRINT) == fingerprint } ?: return false
        selected.put("status", "ignored")
        writeInbox(context, values)
        return true
    }

    @Synchronized
    fun complete(
        context: Context,
        remember: Boolean = true,
        keepScreenshot: Boolean = false,
        fingerprint: String? = null,
    ) {
        normalizeInbox(context)
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = parse(preferences.getString(KEY_PENDING, null))
        val target = fingerprint ?: pending?.optString(KEY_FINGERPRINT).orEmpty()
        if (target.isBlank()) return
        val value = pending?.takeIf { it.optString(KEY_FINGERPRINT) == target }
            ?: inboxPayloads(context).firstOrNull { it.optString(KEY_FINGERPRINT) == target }
        val screenshotPath = value?.optString("screenshotPath").orEmpty()
        AutoBookkeepingLogStore.recordDetailed(
            context,
            "pending_completed",
            "remember=$remember keepScreenshot=$keepScreenshot fingerprint=$target candidate=$value",
        )
        val editor = preferences.edit()
            .putString(KEY_INBOX, JSONArray(inboxPayloads(context).filter {
                it.optString(KEY_FINGERPRINT) != target
            }).toString())
        if (pending?.optString(KEY_FINGERPRINT) == target) editor.remove(KEY_PENDING)

        if (!keepScreenshot) {
            deleteScreenshot(context, screenshotPath)
        }

        if (
            remember &&
            value != null &&
            target.isNotBlank()
        ) {
            val handled = JSONObject(value.toString()).apply {
                remove("screenshotPath")
            }
            editor
                .putString(KEY_HANDLED_FINGERPRINT, target)
                .putString(KEY_HANDLED_PAYLOAD, handled.toString())
                .putLong(KEY_HANDLED_AT, System.currentTimeMillis())
                .putString(KEY_HANDLED_HISTORY, JSONArray(
                    (jsonList(preferences.getString(KEY_HANDLED_HISTORY, null)) +
                        JSONObject(handled.toString()).put(KEY_HANDLED_AT, System.currentTimeMillis())).takeLast(1000),
                ).toString())
        }

        if (remember) {
            editor.putStringSet(KEY_HANDLED_IDENTITIES,
                preferences.getStringSet(KEY_HANDLED_IDENTITIES, emptySet()).orEmpty() + target +
                    (value?.let { PaymentInboxDedup.handledKeys(rawMap(it)) } ?: emptySet()))
        }
        editor.apply()
        AutoBookkeepingLogStore.record(context, "pending_recorded", "fingerprint=${target.take(16)} located=${value != null} active=${pending?.optString(KEY_FINGERPRINT) == target}")
    }

    @Synchronized
    fun enrichNoteIfCurrent(context: Context, fingerprint: String, note: String): Boolean {
        if (note.isBlank()) return false
        val pending = readValidPayload(context) ?: return false
        if (pending.optString(KEY_FINGERPRINT) != fingerprint ||
            pending.optString("note").isNotBlank()) return false
        pending.put("note", note)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_PENDING, pending.toString()).apply()
        return true
    }

    @Synchronized
    fun attachScreenshotIfCurrent(
        context: Context,
        fingerprint: String,
        path: String,
    ): Boolean {
        if (!isManagedScreenshot(context, path)) {
            AutoBookkeepingLogStore.recordDetailed(context, "pending_screenshot_rejected", "reason=unmanaged path=$path")
            return false
        }
        val file = File(path)
        if (!file.isFile) {
            AutoBookkeepingLogStore.recordDetailed(context, "pending_screenshot_rejected", "reason=missing_file path=$path")
            return false
        }

        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val active = parse(preferences.getString(KEY_PENDING, null))
        val pending = active?.takeIf { it.optString(KEY_FINGERPRINT) == fingerprint }
            ?: inboxPayloads(context).firstOrNull { it.optString(KEY_FINGERPRINT) == fingerprint }
        if (
            pending == null ||
            pending.optString(KEY_FINGERPRINT) != fingerprint
        ) {
            AutoBookkeepingLogStore.recordDetailed(
                context,
                "pending_screenshot_rejected",
                "reason=candidate_changed fingerprint=$fingerprint path=$path current=${pending?.optString(KEY_FINGERPRINT)}",
            )
            deleteScreenshot(context, path)
            return false
        }

        val oldPath = pending.optString("screenshotPath")
        if (oldPath.isNotBlank() && oldPath != path) {
            deleteScreenshot(context, oldPath)
        }
        pending.put("screenshotPath", path)
        if (active?.optString(KEY_FINGERPRINT) == fingerprint) {
            preferences.edit().putString(KEY_PENDING, pending.toString()).apply()
        } else {
            writeInbox(context, inboxPayloads(context).map { if (it.optString(KEY_FINGERPRINT) == fingerprint) pending else it })
        }
        AutoBookkeepingLogStore.recordDetailed(context, "pending_screenshot_attached", "fingerprint=$fingerprint path=$path")
        return true
    }

    private fun logEnqueueDecision(
        context: Context,
        decision: PendingEnqueueDecision,
        candidate: PaymentCandidate,
        reason: String,
    ) = AutoBookkeepingLogStore.recordDetailed(
        context,
        "pending_enqueue_decision",
        "decision=$decision reason=$reason candidate=${candidate.toMap()}",
    )

    private fun readValidPayload(context: Context): JSONObject? {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return parse(preferences.getString(KEY_PENDING, null))
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
            .put("transactionTimeKnown", candidate.transactionTimeKnown)
            .put("sourceApp", candidate.sourceApp)
            .put("scene", candidate.scene.scene)
            .put("transactionType", candidate.transactionType)
            .put("amountConfidence", candidate.amountConfidence)
            .put("merchantConfidence", candidate.merchantConfidence)
            .put("sceneConfidence", candidate.scene.confidence)
            .apply {
                candidate.paymentSessionId?.let { put("paymentSessionId", it) }
                candidate.paymentOriginApp?.let { put("paymentOriginApp", it) }
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

    private fun rawMap(value: JSONObject): Map<String, Any> = buildMap {
        value.keys().forEach { key -> value.opt(key)?.takeIf { it != JSONObject.NULL }?.let { put(key, it) } }
        if (PaymentInboxDedup.legacyTransactionTimeKnown(this)) put("transactionTimeKnown", true)
    }

    private fun mergePayload(existing: JSONObject, incoming: JSONObject) =
        JSONObject(PaymentInboxDedup.merge(rawMap(existing), rawMap(incoming)))

    private fun handledMatch(context: Context, candidate: Map<String, Any>): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val keys = prefs.getStringSet(KEY_HANDLED_IDENTITIES, emptySet()).orEmpty()
        if (PaymentInboxDedup.handledKeys(candidate).any(keys::contains)) return true
        if (candidate[KEY_FINGERPRINT] == prefs.getString(KEY_HANDLED_FINGERPRINT, null) &&
            System.currentTimeMillis() - prefs.getLong(KEY_HANDLED_AT, 0L) <= HANDLED_TTL_MILLIS) return true
        val history = jsonList(prefs.getString(KEY_HANDLED_HISTORY, null)) +
            listOfNotNull(parse(prefs.getString(KEY_HANDLED_PAYLOAD, null))?.put(KEY_HANDLED_AT, prefs.getLong(KEY_HANDLED_AT, 0L)))
        val observations = history.distinctBy { it.optString(KEY_FINGERPRINT) }.map(::rawMap)
        val eligible = observations.filter {
            val match = PaymentInboxDedup.match(it, candidate)
            match != null && (match.strong || match == PaymentInboxDedup.Match.SUCCESS_DETAIL ||
                System.currentTimeMillis() - ((it[KEY_HANDLED_AT] as? Number)?.toLong() ?: 0L) <= HANDLED_TTL_MILLIS)
        }
        return PaymentInboxDedup.find(eligible, candidate, observations + candidate) != null
    }

    /** Migrate only identifiable duplicates; keep the active review fingerprint stable. */
    private fun normalizeInbox(context: Context): List<JSONObject> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val original = inboxPayloads(context)
        val active = readValidPayload(context)
        val observations = original.map(::rawMap)
        val values = PaymentInboxDedup.collapse(observations, observations + listOfNotNull(active?.let(::rawMap)))
            .filterNot { handledMatch(context, it) }.toMutableList()
        var mergedActive = false
        if (active != null) {
            PaymentInboxDedup.find(values, rawMap(active), observations + rawMap(active))?.let { index ->
                val current = rawMap(active) + ("status" to "pending")
                prefs.edit().putString(KEY_PENDING, JSONObject(PaymentInboxDedup.merge(current, values.removeAt(index))).toString()).apply()
                mergedActive = true
            }
        }
        val normalized = values.map(::JSONObject)
        val serialized = JSONArray(normalized).toString()
        if (serialized != prefs.getString(KEY_INBOX, "[]")) {
            prefs.edit().putString(KEY_INBOX, serialized).apply()
        }
        if (original.size != normalized.size || mergedActive) {
            AutoBookkeepingLogStore.record(context, "inbox_deduplicated", "before=${original.size} after=${normalized.size} activeMerged=$mergedActive")
        }
        return normalized
    }

    internal fun transactionTypesCompatible(first: String, second: String, crossCaptureSource: Boolean): Boolean =
        PaymentInboxDedup.typesCompatible(first, second, crossCaptureSource)

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
        val validPaths = inbox(context).mapNotNull { (it["screenshotPath"] as? String)?.takeIf(String::isNotBlank) }
            .mapNotNull { runCatching { File(it).canonicalPath }.getOrNull() }.toSet()
        val directory = File(
            context.filesDir,
            "autobookkeeping/pending_screenshots",
        )
        directory.listFiles()
            ?.filter { file ->
                file.isFile &&
                    runCatching { file.canonicalPath !in validPaths }.getOrDefault(false)
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
