package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import android.app.ActivityManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import com.algive.jizhang_app.PaymentNotificationListenerService
import com.algive.jizhang_app.PaymentNotificationStore
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore as Store
import com.algive.jizhang_app.autobookkeeping.repository.PendingEnqueueDecision
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** The same durable queue is used by both Flutter engines. No Activity is needed to warm it. */
object AutoBookkeepingChannels {
    fun bind(context: Context, messenger: BinaryMessenger, includeLogs: Boolean = true) {
        val app = context.applicationContext
        AppNotice.bind(context, messenger)
        BookkeepingChangeBus.bind(app, messenger)
        MethodChannel(messenger, "jizhang/autobookkeeping_pending").setMethodCallHandler { call, result ->
            try {
                val fingerprint = call.argument<String>("fingerprint").orEmpty()
                when (call.method) {
                    "canAutoRecord" -> result.success(
                        AutoBookkeepingSettings.enabled(app) &&
                            AutoBookkeepingDiagnostics.accessibilityConnected &&
                            AutoBookkeepingDiagnostics.foregroundRunning &&
                            AutoBookkeepingOverlayPermission.isGranted(app) &&
                            AutoBookkeepingNotificationController.statusNotificationsAvailable(app) &&
                            app.packageName in NotificationManagerCompat.getEnabledListenerPackages(app) &&
                            (!app.getSharedPreferences(PaymentNotificationStore.PREFS_NAME, Context.MODE_PRIVATE)
                                .getBoolean("enabled", false) || PaymentNotificationListenerService.connected) &&
                            !(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
                                app.getSystemService(ActivityManager::class.java).isBackgroundRestricted),
                    )
                    "getPending" -> result.success(Store.read(app))
                    "getInbox" -> result.success(Store.inbox(app))
                    "select" -> result.success(
                        AutoBillOverlayService.instance?.isShowing != true && Store.select(app, fingerprint),
                    )
                    "ignore" -> {
                        result.success(Store.ignore(app, fingerprint))
                        changed(app)
                    }
                    "defer" -> {
                        if (fingerprint.isNotEmpty() && Store.read(app)?.get("fingerprint") != fingerprint) {
                            result.success(false)
                        } else {
                            Store.deferCurrent(app)
                            changed(app)
                            result.success(true)
                        }
                    }
                    "enqueue" -> {
                        val candidate = (call.arguments as? Map<*, *>)?.let(Store::candidateFromMap)
                        if (candidate == null) {
                            result.error("INVALID_CANDIDATE", "自动记账候选数据无效", null)
                        } else {
                            val decision = Store.enqueueDecision(app, candidate)
                            if (decision == PendingEnqueueDecision.ACCEPTED &&
                                AutoBillOverlayService.instance?.offer(candidate) != true) {
                                AutoBookkeepingNotificationController.notifyConfirmationAvailable(app)
                            }
                            if (decision == PendingEnqueueDecision.QUEUED) changed(app)
                            else if (decision == PendingEnqueueDecision.ACCEPTED) BookkeepingChangeBus.publish(app)
                            result.success(mapOf("status" to decision.name.lowercase()))
                        }
                    }
                    "promoteScreenshot" -> result.success(
                        call.argument<String>("path")?.let { Store.promoteScreenshot(app, it) },
                    )
                    "complete" -> {
                        Store.complete(app, keepScreenshot = call.argument<Boolean>("keepScreenshot") == true,
                            fingerprint = fingerprint.takeIf { it.isNotBlank() })
                        changed(app)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("PENDING_FAILED", error.message, null)
            }
        }
        if (includeLogs) MethodChannel(messenger, "jizhang/autobookkeeping_logs").setMethodCallHandler { call, result ->
            if (call.method == "recordDetailed") {
                AutoBookkeepingLogStore.recordDetailed(app, call.argument<String>("stage").orEmpty(), call.argument<String>("detail").orEmpty())
                result.success(null)
            } else when (call.method) {
                "get" -> result.success(AutoBookkeepingLogStore.read(app))
                "clear" -> { AutoBookkeepingLogStore.clear(app); result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "jizhang/bookkeeping_feedback").setMethodCallHandler { call, result ->
            if (call.method == "notifySuccess") {
                BookkeepingChangeBus.publish(app)
                AutoBookkeepingNotificationController.notifyBookkeepingSuccess(app, call.argument<Number>("count")?.toInt() ?: 1)
                result.success(null)
            } else result.notImplemented()
        }
    }

    private fun changed(context: Context) {
        BookkeepingChangeBus.publish(context)
        AutoBookkeepingNotificationController.notifyConfirmationAvailable(context, showToast = false)
    }
}
