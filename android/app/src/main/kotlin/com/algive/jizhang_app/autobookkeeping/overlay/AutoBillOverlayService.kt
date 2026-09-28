package com.algive.jizhang_app.autobookkeeping.overlay

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
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
    private var flutterConfirmationOpen = false
    private val mainHandler = Handler(Looper.getMainLooper())
    val isShowing: Boolean get() = root != null || flutterConfirmationOpen

    override fun onBind(intent: Intent?): IBinder? = null

    fun offer(candidate: PaymentCandidate): Boolean {
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "overlay_offer_requested",
            "candidate=${candidate.toMap()} showing=$isShowing",
        )
        if (flutterConfirmationOpen) return true
        remove()
        if (!offerNativePrompt(candidate)) return openConfirmation(candidate)
        // A visible overlay grants the foreground transition on Android/MIUI.
        // Keep it in place until the confirmation Activity is actually resumed.
        // Launch before screenshot capture can occupy the accessibility main
        // thread for several seconds on some Xiaomi builds.
        openConfirmation(candidate)
        return true
    }

    /** Visible prompt also provides a manual fallback if Android blocks the automatic transition. */
    private fun offerNativePrompt(candidate: PaymentCandidate): Boolean {
        if (root != null) {
            // enqueueIfAbsent only allows this path when the pending candidate
            // was replaced (for example, accessibility superseded a lower
            // confidence notification). Refresh the visible card so it matches
            // the candidate Flutter will read from PendingStore.
            AutoBookkeepingLogStore.record(this, "overlay_replaced", "refresh visible confirmation candidate")
            remove()
        }

        val transactionLabel = when (candidate.transactionType) {
            "INCOME" -> "收入"
            "REFUND" -> "退款"
            "REIMBURSEMENT" -> "报销回款"
            "TRANSFER" -> "转账"
            else -> "支出"
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 20, 28, 20)
            setBackgroundColor(Color.rgb(38, 38, 42))
            addView(TextView(context).apply {
                text = "好好记账 · %s\n¥%.2f  %s\n%s\n请打开应用确认记账方式与账户".format(
                    transactionLabel,
                    candidate.amountInCents / 100.0,
                    candidate.merchantNormalized,
                    candidate.paymentMethod,
                )
                setTextColor(Color.WHITE)
                textSize = 16f
            })
            addView(TextView(context).apply {
                text = "正在打开确认页；若未自动弹出，请点“去确认”。"
                setTextColor(Color.LTGRAY)
                textSize = 13f
                setPadding(0, 12, 0, 12)
            })
            addView(TextView(context).apply {
                text = "识别到$transactionLabel，确认后记账"
                setTextColor(Color.WHITE)
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(12, 12, 12, 12)
            })
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                addView(action("忽略") {
                    AutoBookkeepingLogStore.record(context, "overlay_ignored", "user ignored candidate")
                    AutoBookkeepingLogStore.recordDetailed(
                        context,
                        "overlay_ignored",
                        "candidate=${candidate.toMap()}",
                    )
                    AutoBookkeepingPendingStore.complete(context)
                    remove()
                    PaymentNotificationListenerService.instance
                        ?.retryStoredNotifications()
                })
                addView(action("去确认") { openConfirmation(candidate) })
            })
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            y = 180
            x = 24
        }
        return runCatching {
            val manager = getSystemService(WINDOW_SERVICE) as WindowManager
            manager.addView(box, params)
            root = box
            wm = manager
            AutoBookkeepingLogStore.record(this, "overlay_shown", "confirmation overlay added")
        }.onFailure { error ->
            Log.e(TAG, "overlay addView failed", error)
            AutoBookkeepingLogStore.record(this, "overlay_add_failed", error.javaClass.simpleName)
        }.isSuccess
    }

    private fun remove() {
        root?.let {
            runCatching { wm?.removeView(it) }
        }
        root = null
    }

    private fun action(label: String, onClick: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(18, 14, 18, 14)
            setOnClickListener { onClick() }
        }

    private fun openConfirmation(candidate: PaymentCandidate): Boolean {
        AutoBookkeepingLogStore.record(this, "confirm_open_requested", "opening confirmation page")
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
        }.getOrDefault(false)
    }

    fun confirmationOpened() {
        flutterConfirmationOpen = true
        remove()
    }

    fun confirmationClosed() {
        flutterConfirmationOpen = false
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
        remove()
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
