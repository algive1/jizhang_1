package com.algive.jizhang_app.autobookkeeping.overlay

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.algive.jizhang_app.PaymentNotificationListenerService
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingConfirmActivity
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore

class AutoBillOverlayService : Service() {
    private var root: View? = null
    private var wm: WindowManager? = null
    private var reviewUi: NativeAutoBookkeepingReviewOverlay? = null
    private var flutterConfirmationOpen = false
    private var flutterReviewReady = false
    private var pendingNativeSubmit = false
    private var revealFlutterWhenReady = false
    private var currentCandidate: PaymentCandidate? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    val isShowing: Boolean get() = root != null || flutterConfirmationOpen

    override fun onBind(intent: Intent?): IBinder? = null

    fun offer(candidate: PaymentCandidate): Boolean {
        val requestedAt = SystemClock.elapsedRealtime()
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "overlay_offer_requested",
            "candidate=${candidate.toMap()} showing=$isShowing",
        )
        if (flutterConfirmationOpen && root != null) return true

        removeNativeView()
        currentCandidate = candidate
        flutterReviewReady = false
        pendingNativeSubmit = false
        revealFlutterWhenReady = false

        val nativeShown = showNativeReview(candidate)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "native_review_visible",
            "shown=$nativeShown elapsedMs=${SystemClock.elapsedRealtime() - requestedAt} candidate=${candidate.toMap()}",
        )
        if (!nativeShown) return openConfirmation(candidate)

        // Warm the existing Flutter confirmation flow behind the native overlay.
        // The native card is already interactive, so Flutter startup latency is
        // no longer user-visible. Once ready, Flutter only supplies real
        // books/accounts/categories and executes the existing save logic.
        openConfirmation(candidate)
        return true
    }

    private fun showNativeReview(candidate: PaymentCandidate): Boolean {
        val ui = NativeAutoBookkeepingReviewOverlay(
            context = this,
            candidate = candidate,
            onCancel = { cancelNativeReview(candidate) },
            onSubmit = { submitNativeDraft(it) },
            onAdvanced = { revealFlutterEditor() },
        )
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.FILL
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        }
        return runCatching {
            val manager = getSystemService(WINDOW_SERVICE) as WindowManager
            ViewCompat.setOnApplyWindowInsetsListener(ui.root) { _, insets ->
                val navigation = insets.getInsets(WindowInsetsCompat.Type.navigationBars())
                ui.setBottomInset(navigation.bottom)
                insets
            }
            manager.addView(ui.root, params)
            ViewCompat.requestApplyInsets(ui.root)
            ui.root.requestFocus()
            reviewUi = ui
            root = ui.root
            wm = manager
            AutoBookkeepingLogStore.record(this, "overlay_shown", "native review overlay added")
        }.onFailure { error ->
            Log.e(TAG, "overlay addView failed", error)
            AutoBookkeepingLogStore.record(this, "overlay_add_failed", error.javaClass.simpleName)
            AutoBookkeepingLogStore.recordDetailed(this, "overlay_add_failed", Log.getStackTraceString(error))
        }.isSuccess
    }

    private fun submitNativeDraft(draft: Map<String, Any?>) {
        val amount = (draft["amountInCents"] as? Number)?.toLong() ?: 0L
        if (amount <= 0L) {
            reviewUi?.showMessage("请输入有效金额")
            return
        }
        val activity = AutoBookkeepingConfirmActivity.instance
        if (!flutterReviewReady || activity == null) {
            pendingNativeSubmit = true
            reviewUi?.showMessage("正在准备保存引擎…")
            reviewUi?.setSaving(true)
            return
        }
        pendingNativeSubmit = false
        reviewUi?.setSaving(true)
        reviewUi?.showMessage(null)
        activity.submitNativeReview(draft) { success, message ->
            mainHandler.post {
                if (success) {
                    reviewUi?.showMessage("已保存")
                    removeNativeView()
                } else {
                    reviewUi?.setSaving(false)
                    reviewUi?.showMessage(message ?: "保存失败，请检查分类和账户")
                }
            }
        }
    }

    fun flutterReviewReady(payload: Map<*, *>) {
        flutterReviewReady = true
        reviewUi?.syncFromFlutter(payload)
        reviewUi?.setFlutterReady(true)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "native_review_flutter_ready",
            "books=${(payload["books"] as? List<*>)?.size ?: 0} " +
                "accounts=${(payload["accounts"] as? List<*>)?.size ?: 0} " +
                "categories=${(payload["categories"] as? List<*>)?.size ?: 0}",
        )

        if (revealFlutterWhenReady) {
            revealFlutterWhenReady = false
            AutoBookkeepingConfirmActivity.instance?.revealFlutterEditor()
            removeNativeView()
            return
        }
        if (pendingNativeSubmit) {
            reviewUi?.setSaving(false)
            submitNativeDraft(reviewUi?.currentDraft().orEmpty())
        }
    }

    private fun revealFlutterEditor() {
        val activity = AutoBookkeepingConfirmActivity.instance
        if (flutterReviewReady && activity != null) {
            activity.revealFlutterEditor()
            removeNativeView()
            return
        }
        revealFlutterWhenReady = true
        reviewUi?.showMessage("正在打开完整设置…")
    }

    private fun cancelNativeReview(candidate: PaymentCandidate) {
        AutoBookkeepingLogStore.record(this, "overlay_ignored", "user cancelled native review")
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "overlay_ignored",
            "candidate=${candidate.toMap()}",
        )
        AutoBookkeepingPendingStore.complete(this)
        pendingNativeSubmit = false
        revealFlutterWhenReady = false
        removeNativeView()
        AutoBookkeepingConfirmActivity.instance?.finish()
        PaymentNotificationListenerService.instance?.retryStoredNotifications()
    }

    private fun removeNativeView() {
        root?.let {
            runCatching { wm?.removeView(it) }
        }
        root = null
        reviewUi = null
    }

    private fun openConfirmation(candidate: PaymentCandidate): Boolean {
        if (flutterConfirmationOpen && AutoBookkeepingConfirmActivity.instance != null) return true
        AutoBookkeepingLogStore.record(this, "confirm_open_requested", "warming Flutter confirmation engine")
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "confirm_open_requested",
            "candidate=${candidate.toMap()} confirmationOpen=$flutterConfirmationOpen",
        )
        return runCatching {
            startActivity(
                Intent(this, AutoBookkeepingConfirmActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(
                        AutoBookkeepingConfirmActivity.EXTRA_BACKGROUND_MODE,
                        AutoBookkeepingConfirmActivity.BACKGROUND_MODE_TRANSPARENT,
                    )
                },
            )
            true
        }.onFailure { error ->
            AutoBookkeepingLogStore.record(this, "confirm_open_failed", error.javaClass.simpleName)
            AutoBookkeepingLogStore.recordDetailed(this, "confirm_open_failed", Log.getStackTraceString(error))
            reviewUi?.showMessage("保存引擎启动失败，可稍后从通知重新确认")
        }.getOrDefault(false)
    }

    fun confirmationOpened() {
        flutterConfirmationOpen = true
        // Keep the native overlay visible. It is the actual confirmation UI;
        // the transparent Flutter Activity is only warming data/business logic.
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "confirmation_host_opened",
            "nativeVisible=${root != null}",
        )
    }

    fun confirmationClosed() {
        flutterConfirmationOpen = false
        flutterReviewReady = false
        val pending = AutoBookkeepingPendingStore.readCandidate(this)
        if (pending == null) {
            removeNativeView()
            currentCandidate = null
            pendingNativeSubmit = false
            revealFlutterWhenReady = false
            return
        }
        if (root == null) {
            // If the transparent host was killed before save/cancel completed,
            // restore the immediate native review rather than losing the bill.
            mainHandler.post { offer(pending) }
        } else {
            reviewUi?.setFlutterReady(false)
            reviewUi?.setSaving(false)
        }
    }

    companion object {
        var instance: AutoBillOverlayService? = null
        private const val TAG = "AutoBookkeeping"
    }

    override fun onCreate() {
        super.onCreate()
        val foregroundStarted = runCatching {
            if (!AutoBookkeepingSettings.enabled(this)) {
                error("auto bookkeeping is disabled")
            }
            if (!AutoBookkeepingNotificationController.statusNotificationsAvailable(this)) {
                error("status notification is not available")
            }
            startForeground(
                AutoBookkeepingNotificationController.NOTIFICATION_ID,
                AutoBookkeepingNotificationController.buildNotification(this),
            )
        }
        if (foregroundStarted.isFailure) {
            val error = foregroundStarted.exceptionOrNull()
            Log.e(TAG, "overlay foreground initialization failed", error)
            AutoBookkeepingDiagnostics.foregroundRunning = false
            AutoBookkeepingDiagnostics.error = "自动记账常驻通知不可用，请检查通知权限"
            AutoBookkeepingLogStore.record(
                this,
                "overlay_foreground_failed",
                error?.javaClass?.simpleName ?: "notification unavailable",
            )
            stopSelf()
            return
        }
        instance = this
        AutoBookkeepingDiagnostics.foregroundRunning = true
        Log.i(TAG, "overlay service created")
        AutoBookkeepingLogStore.record(this, "overlay_service", "foreground service created")
    }

    override fun onDestroy() {
        removeNativeView()
        mainHandler.removeCallbacksAndMessages(null)
        instance = null
        AutoBookkeepingDiagnostics.foregroundRunning = false
        AutoBookkeepingLogStore.record(this, "overlay_service", "foreground service destroyed")
        AutoBookkeepingLogStore.recordDetailed(this, "overlay_service_destroyed", "foreground service destroyed")
        AutoBookkeepingNotificationController.cancelStatus(this)
        super.onDestroy()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (
            !AutoBookkeepingSettings.enabled(this) ||
            !AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
        ) {
            AutoBookkeepingLogStore.record(
                this,
                "overlay_service_stop",
                "service restarted without valid runtime conditions",
            )
            stopSelf()
            return START_NOT_STICKY
        }
        if (!isShowing) {
            mainHandler.post {
                AutoBookkeepingPendingStore.readCandidate(this)?.let { pending ->
                    AutoBookkeepingLogStore.record(
                        this,
                        "pending_recovered",
                        "showing stored confirmation candidate",
                    )
                    offer(pending)
                }
            }
        }
        return START_STICKY
    }
}
