package com.algive.jizhang_app

import android.app.Notification
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.content.ContextCompat
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingOverlayPermission
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.parser.PaymentNotificationCandidateParser
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.repository.PendingEnqueueDecision
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class PaymentNotificationListenerService : NotificationListenerService() {
    // Rebuilt by [refreshRules] when the user edits the custom app list, so these
    // cannot be `by lazy` caches.
    private var ruleRegistry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn()
    private var realtimeParser: PaymentNotificationCandidateParser =
        PaymentNotificationCandidateParser(ruleRegistry)
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Re-read the packaged rules and the user's custom apps.
     *
     * Custom packages matter on this channel too: a user-added app's payment
     * notification should be parsed even when its result page is never seen.
     */
    fun refreshRules() {
        ruleRegistry = AutoBookkeepingRuleRegistry.load(this)
        realtimeParser = PaymentNotificationCandidateParser(ruleRegistry)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_rules_applied",
            "rules=${ruleRegistry.versionsSummary()} packages=${ruleRegistry.customPackages}",
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        connected = true
        refreshRules()
        AutoBookkeepingLogStore.record(
            this,
            "notification_listener_connected",
            "notification listener connected",
        )
        mainHandler.post { retryStoredNotifications() }
    }

    override fun onListenerDisconnected() {
        connected = false
        instance = null
        AutoBookkeepingLogStore.record(
            this,
            "notification_listener_disconnected",
            "notification listener disconnected",
        )
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_listener_disconnected",
            "enabled=${getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE).getBoolean(KEY_ENABLED, false)}",
        )
        val enabled = getSharedPreferences(
            PaymentNotificationStore.PREFS_NAME,
            MODE_PRIVATE,
        ).getBoolean(KEY_ENABLED, false)
        if (enabled) {
            mainHandler.postDelayed(
                {
                    runCatching {
                        requestRebind(
                            android.content.ComponentName(
                                this,
                                PaymentNotificationListenerService::class.java,
                            ),
                        )
                    }.onFailure { error ->
                        AutoBookkeepingLogStore.record(
                            this,
                            "notification_listener_rebind_failed",
                            error.javaClass.simpleName,
                        )
                    }
                },
                LISTENER_REBIND_DELAY_MS,
            )
        }
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(statusBarNotification: StatusBarNotification) {
        val packageName = statusBarNotification.packageName
        if (ruleRegistry.ruleFor(packageName) == null) return

        val enabled = getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
        val extras = statusBarNotification.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = notificationText(extras)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_posted",
            "package=$packageName key=${statusBarNotification.key} id=${statusBarNotification.id} " +
                "postTime=${statusBarNotification.postTime} enabled=$enabled " +
                "title=$title text=$text extras=${extras.keySet().sorted()}",
        )
        if (!enabled) return
        if (title.isBlank() && text.isBlank()) {
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "notification_ignored",
                "reason=empty_content package=$packageName key=${statusBarNotification.key}",
            )
            return
        }

        val candidate = realtimeParser.parse(
            packageName = packageName,
            title = title,
            text = text,
            timestamp = statusBarNotification.postTime,
        ) ?: run {
            AutoBookkeepingLogStore.record(
                this,
                "notification_rejected",
                "$packageName no high-confidence completed payment",
            )
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "notification_parse_rejected",
                "package=$packageName title=$title text=$text",
            )
            return
        }
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_candidate_parsed",
            candidate.toMap().toString(),
        )

        val id = "$packageName:${statusBarNotification.key}:${statusBarNotification.postTime}"
        PaymentNotificationStore.append(
            this,
            JSONObject()
                .put("id", id)
                .put("packageName", packageName)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt(statusBarNotification.postTime))
                .put("postedAtMillis", statusBarNotification.postTime),
        )

        val decision = AutoBookkeepingPendingStore.enqueueDecision(this, candidate)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_enqueue_decision",
            "decision=$decision candidate=${candidate.toMap()}",
        )
        when (decision) {
            PendingEnqueueDecision.ACCEPTED -> {
                PaymentNotificationStore.acknowledge(this, listOf(id))
                AutoBookkeepingLogStore.record(
                    this,
                    "notification_candidate_accepted",
                    "source=${candidate.sourceApp}",
                )
                showRealtimeCandidate(candidate)
            }
            PendingEnqueueDecision.DUPLICATE -> {
                PaymentNotificationStore.acknowledge(this, listOf(id))
                AutoBookkeepingLogStore.record(
                    this,
                    "notification_candidate_duplicate",
                    "source=${candidate.sourceApp}",
                )
            }
            PendingEnqueueDecision.BUSY -> {
                // Keep the raw notification in PaymentNotificationStore. The
                // foreground recovery processor can retry it after the current
                // confirmation slot is cleared.
                AutoBookkeepingLogStore.record(
                    this,
                    "notification_candidate_busy",
                    "source=${candidate.sourceApp}",
                )
            }
        }
    }

    fun retryStoredNotifications() {
        if (!connected) {
            AutoBookkeepingLogStore.recordDetailed(this, "notification_recovery_skipped", "reason=listener_disconnected")
            return
        }
        val enabled = getSharedPreferences(
            PaymentNotificationStore.PREFS_NAME,
            MODE_PRIVATE,
        ).getBoolean(KEY_ENABLED, false)
        if (!enabled) {
            AutoBookkeepingLogStore.recordDetailed(this, "notification_recovery_skipped", "reason=disabled")
            return
        }

        for (raw in PaymentNotificationStore.read(this)) {
            val packageName = raw["packageName"].orEmpty()
            val title = raw["title"].orEmpty()
            val text = raw["text"].orEmpty()
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "notification_recovery_attempt",
                "id=${raw["id"]} package=$packageName title=$title text=$text",
            )
            val timestamp = raw["postedAtMillis"]
                ?.toLongOrNull()
                ?.takeIf { it > 0L }
                ?: continue
            val candidate = realtimeParser.parse(
                packageName = packageName,
                title = title,
                text = text,
                timestamp = timestamp,
            )
            if (candidate == null) {
                val rejectedId = raw["id"].orEmpty()
                if (rejectedId.isNotEmpty()) {
                    PaymentNotificationStore.acknowledge(
                        this,
                        listOf(rejectedId),
                    )
                }
                AutoBookkeepingLogStore.recordDetailed(
                    this,
                    "notification_recovery_rejected",
                    "id=$rejectedId package=$packageName title=$title text=$text",
                )
                continue
            }
            val id = raw["id"].orEmpty()
            val decision = AutoBookkeepingPendingStore.enqueueDecision(this, candidate)
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "notification_recovery_decision",
                "id=$id decision=$decision candidate=${candidate.toMap()}",
            )
            when (decision) {
                PendingEnqueueDecision.ACCEPTED -> {
                    if (id.isNotEmpty()) {
                        PaymentNotificationStore.acknowledge(this, listOf(id))
                    }
                    AutoBookkeepingLogStore.record(
                        this,
                        "notification_candidate_recovered",
                        "source=${candidate.sourceApp}",
                    )
                    showRealtimeCandidate(candidate)
                    return
                }
                PendingEnqueueDecision.DUPLICATE -> {
                    if (id.isNotEmpty()) {
                        PaymentNotificationStore.acknowledge(this, listOf(id))
                    }
                }
                PendingEnqueueDecision.BUSY -> return
            }
        }
    }

    override fun onNotificationRemoved(
        statusBarNotification: StatusBarNotification,
        rankingMap: RankingMap?,
        reason: Int,
    ) {
        val packageName = statusBarNotification.packageName
        if (ruleRegistry.ruleFor(packageName) != null) {
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "notification_removed",
                "package=$packageName key=${statusBarNotification.key} " +
                    "id=${statusBarNotification.id} reason=$reason",
            )
        }
        super.onNotificationRemoved(statusBarNotification, rankingMap, reason)
    }

    private fun notificationText(extras: android.os.Bundle): String {
        val parts = linkedSetOf<String>()
        extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(parts::add)
        extras.getCharSequence(Notification.EXTRA_TEXT)
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(parts::add)
        extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(parts::add)
        extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(parts::add)
        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.map { it.toString() }
            ?.filter(String::isNotBlank)
            ?.forEach { parts.add(it) }
        return parts.joinToString(" ")
    }

    private fun showRealtimeCandidate(candidate: PaymentCandidate) {
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "notification_candidate_presentation_requested",
            "candidate=${candidate.toMap()} overlayRunning=${AutoBillOverlayService.instance != null}",
        )
        val runningOverlay = AutoBillOverlayService.instance
        if (runningOverlay != null) {
            val shown = runningOverlay.offer(candidate)
            if (!shown) AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
            return
        }

        val canStartOverlay =
            AutoBookkeepingSettings.enabled(this) &&
                AutoBookkeepingOverlayPermission.isGranted(this) &&
                AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
        if (!canStartOverlay) {
            AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
            return
        }

        val started = runCatching {
            ContextCompat.startForegroundService(
                this,
                Intent(this, AutoBillOverlayService::class.java),
            )
        }
        if (started.isFailure) {
            AutoBookkeepingLogStore.record(
                this,
                "notification_overlay_start_failed",
                started.exceptionOrNull()?.javaClass?.simpleName ?: "unknown",
            )
            AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
            return
        }

        mainHandler.postDelayed(
            {
                // Accessibility may have replaced the lower-confidence
                // notification candidate while the foreground service was
                // starting. Always render the current PendingStore value.
                val current = AutoBookkeepingPendingStore.readCandidate(this)
                    ?: return@postDelayed
                val shown = AutoBillOverlayService.instance?.offer(current) == true
                if (!shown) {
                    AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
                }
            },
            OVERLAY_START_GRACE_MS,
        )
    }

    private fun postedAt(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(Date(millis))
    }

    override fun onDestroy() {
        AutoBookkeepingLogStore.recordDetailed(this, "notification_listener_destroyed", "service destroyed")
        connected = false
        if (instance === this) instance = null
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    companion object {
        @Volatile
        var connected: Boolean = false
            private set

        @Volatile
        var instance: PaymentNotificationListenerService? = null
            private set

        private const val KEY_ENABLED = "enabled"
        private const val OVERLAY_START_GRACE_MS = 350L
        private const val LISTENER_REBIND_DELAY_MS = 1000L

    }
}
