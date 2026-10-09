package com.algive.jizhang_app.autobookkeeping.overlay

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import com.algive.jizhang_app.autobookkeeping.*
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.accessibility.AutoBookkeepingAccessibilityService
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore as Store

/** Owns one visible, warmed Flutter review; additional bills stay in the durable inbox. */
class AutoBillOverlayService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var fingerprint: String? = null
    private var prepared = false
    private var visible = false
    private var completedAt = 0L
    var offeredAt = 0L
        private set
    val isShowing get() = fingerprint != null

    fun trace(stage: String, detail: String) = AutoBookkeepingLogStore.record(this, stage,
        "request=$offeredAt elapsedMs=${(SystemClock.elapsedRealtime() - offeredAt).coerceAtLeast(0)} " +
            (if (completedAt > 0) "sinceCompleteMs=${SystemClock.elapsedRealtime() - completedAt} " else "") + detail)

    fun confirmationVisible() {
        if (!isShowing || !prepared || visible) return
        visible = true
        trace("confirmation_visible", "shown=true contentFrame=true windowFocus=true")
    }
    override fun onBind(intent: Intent?): IBinder? = null

    fun showDetectionFeedback(message: String) {
        AppNotice.show(this, message)
    }

    fun enrichNote(fingerprint: String, note: String) {
        // The current Flutter draft owns user edits. Late evidence stays in the pending store.
    }

    fun offer(candidate: PaymentCandidate): Boolean {
        if (AutoBookkeepingAccessibilityService.instance?.waitForPaymentCompletion(candidate) == true) return true
        if (isShowing) {
            trace("confirmation_offer_skipped", "reason=review_active shown=$visible")
            return true
        }
        val current = Store.read(this) ?: return false
        fingerprint = current["fingerprint"] as? String ?: BillFingerprint.of(candidate)
        offeredAt = SystemClock.elapsedRealtime()
        completedAt = if (candidate.sourceApp == "WECHAT") AutoBookkeepingAccessibilityService.instance?.completionClickedAt ?: 0L else 0L
        prepared = false
        visible = false
        trace("confirmation_requested", "shown=false preparing review")
        runCatching {
            AutoBookkeepingEngine.prepare(this)
            // The warmed engine needs an attached view to render its prepared frame.
            openConfirmation()
        }.onFailure {
            AutoBookkeepingLogStore.record(this, "confirmation_prepare_failed", it.javaClass.simpleName)
            closeConfirmation("prepare_failed")
            return false
        }
        val requested = fingerprint
        handler.postDelayed({
            if (fingerprint == requested && !visible) {
                trace("confirmation_not_visible", "shown=false contentFrame=$prepared reason=timeout")
                if (!prepared) closeConfirmation("content_timeout")
                AutoBookkeepingNotificationController.notifyConfirmationAvailable(this, showToast = false)
            }
        }, 20000)
        return true
    }

    fun confirmationPrepared(prepared: String) {
        if (fingerprint != prepared || Store.read(this)?.get("fingerprint") != prepared) {
            trace("confirmation_frame_rejected", "reason=pending_changed")
            return
        }
        if (this.prepared) return
        this.prepared = true
        trace("confirmation_content_frame", "shown=$visible")
        showDetectionFeedback("已识别到付款 · 请确认记账")
        AutoBookkeepingConfirmActivity.instance?.reportVisibility()
    }

    private fun openConfirmation() {
        if (AutoBookkeepingConfirmActivity.instance != null) {
            trace("confirmation_launch_skipped", "reason=host_exists")
            return
        }
        runCatching {
            startActivity(Intent(this, AutoBookkeepingConfirmActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
                putExtra(AutoBookkeepingConfirmActivity.EXTRA_BACKGROUND_MODE, AutoBookkeepingConfirmActivity.BACKGROUND_MODE_TRANSPARENT)
            })
            trace("confirmation_launch_returned", "awaiting window; shown=false")
        }.onFailure {
            AutoBookkeepingLogStore.record(this, "confirmation_open_failed", it.javaClass.simpleName)
            closeConfirmation("launch_failed")
        }
    }

    fun closeConfirmation(reason: String = "user_close", drainAutomatic: Boolean = false) {
        val closingFingerprint = fingerprint
        if (fingerprint != null) trace("confirmation_closed", "shown=$visible contentFrame=$prepared reason=$reason")
        fingerprint = null
        prepared = false
        visible = false
        handler.removeCallbacksAndMessages(null)
        if (Store.read(this)?.get("fingerprint") == closingFingerprint) Store.deferCurrent(this)
        AutoBookkeepingNotificationController.notifyConfirmationAvailable(this, showToast = false)
        BookkeepingChangeBus.publish(this)
        AutoBookkeepingConfirmActivity.instance?.finish()
        AutoBookkeepingEngine.clearReview()
        if (drainAutomatic && AutoBookkeepingSettings.enabled(this)) handler.post {
            Store.selectNextAutomatic(this)?.let { offer(it) }
        }
    }

    fun confirmationOpened() = Unit

    fun confirmationClosed() {
        // Back, process/window recreation and outside dismissal all preserve an unsaved bill.
        if (fingerprint != null) closeConfirmation("host_destroyed")
    }

    override fun onCreate() {
        super.onCreate()
        if (!AutoBookkeepingSettings.enabled(this) || !AutoBookkeepingNotificationController.statusNotificationsAvailable(this)) {
            stopSelf()
            return
        }
        runCatching {
            startForeground(AutoBookkeepingNotificationController.NOTIFICATION_ID,
                AutoBookkeepingNotificationController.buildNotification(this))
        }.onFailure {
            AutoBookkeepingLogStore.record(this, "foreground_start_failed", it.javaClass.simpleName)
            stopSelf()
            return
        }
        instance = this
        AutoBookkeepingDiagnostics.foregroundRunning = true
        com.algive.jizhang_app.PaymentNotificationListenerService.ensureConnected(this)
        // onStartCommand distinguishes a newly detected payment from an old stored review.
        AutoBookkeepingNotificationController.notifyConfirmationAvailable(this, showToast = false)
        handler.post {
            runCatching { AutoBookkeepingEngine.warmUp(this) }.onFailure {
                AutoBookkeepingLogStore.record(this, "confirmation_warm_failed", it.javaClass.simpleName)
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!AutoBookkeepingSettings.enabled(this)) { stopSelf(); return START_NOT_STICKY }
        if (!isShowing) {
            val candidate = Store.readCandidate(this)
            if (candidate != null && System.currentTimeMillis() - Store.pendingCreatedAt(this) < 10000) offer(candidate)
            else Store.deferCurrent(this)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        closeConfirmation("service_destroyed")
        if (AutoBookkeepingConfirmActivity.instance == null) AutoBookkeepingEngine.dispose()
        instance = null
        AutoBookkeepingDiagnostics.foregroundRunning = false
        AutoBookkeepingNotificationController.cancelStatus(this)
        super.onDestroy()
    }

    companion object { var instance: AutoBillOverlayService? = null; private set }
}
