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
    private val ruleRegistry = AutoBookkeepingRuleRegistry.builtIn()
    private val realtimeParser = PaymentNotificationCandidateParser(ruleRegistry)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListenerConnected() {
        super.onListenerConnected()
        connected = true
        AutoBookkeepingLogStore.record(
            this,
            "notification_listener_connected",
            "notification listener connected",
        )
    }

    override fun onListenerDisconnected() {
        connected = false
        AutoBookkeepingLogStore.record(
            this,
            "notification_listener_disconnected",
            "notification listener disconnected",
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
        if (!enabled) return

        val extras = statusBarNotification.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = notificationText(extras)
        if (title.isBlank() && text.isBlank()) return

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
            return
        }

        val id = "$packageName:${statusBarNotification.key}:${statusBarNotification.postTime}"
        PaymentNotificationStore.append(
            this,
            JSONObject()
                .put("id", id)
                .put("packageName", packageName)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt(statusBarNotification.postTime)),
        )

        when (AutoBookkeepingPendingStore.enqueueDecision(this, candidate)) {
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
        connected = false
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    companion object {
        @Volatile
        var connected: Boolean = false
            private set

        private const val KEY_ENABLED = "enabled"
        private const val OVERLAY_START_GRACE_MS = 350L
        private const val LISTENER_REBIND_DELAY_MS = 1000L

    }
}
