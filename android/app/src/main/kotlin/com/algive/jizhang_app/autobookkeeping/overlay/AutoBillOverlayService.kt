package com.algive.jizhang_app.autobookkeeping.overlay

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingOverlayPermission
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore

class AutoBillOverlayService : Service() {
    private var root: LinearLayout? = null
    private var wm: WindowManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    fun offer(candidate: PaymentCandidate): Boolean {
        if (!AutoBookkeepingOverlayPermission.isGranted(this)) {
            AutoBookkeepingLogStore.record(this, "overlay_permission_denied", "overlay permission check returned false")
            return false
        }
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
            else -> "支出"
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 20, 28, 20)
            setBackgroundColor(Color.rgb(38, 38, 42))
            addView(TextView(context).apply {
                text = "好好记账 · %s\n¥%.2f  %s\n%s\n请打开应用确认账本、账户与分类".format(
                    transactionLabel,
                    candidate.amountInCents / 100.0,
                    candidate.merchantNormalized,
                    candidate.paymentMethod,
                )
                setTextColor(Color.WHITE)
                textSize = 16f
            })
            addView(TextView(context).apply {
                text = "当前悬浮层只展示识别结果，不会在未确认账本和分类时自动保存。"
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
                    AutoBookkeepingPendingStore.complete(context)
                    remove()
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
        root?.let { runCatching { wm?.removeView(it) } }
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

    private fun openConfirmation(candidate: PaymentCandidate) {
        AutoBookkeepingLogStore.record(this, "confirm_open_requested", "user opened confirmation page")
        remove()
        runCatching {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(MainActivity.OPEN_ROUTE_EXTRA, "/profile/autobookkeeping/confirm")
                },
            )
        }.onFailure { error ->
            AutoBookkeepingLogStore.record(this, "confirm_open_failed", error.javaClass.simpleName)
            offer(candidate)
        }
    }

    companion object {
        var instance: AutoBillOverlayService? = null
        private const val TAG = "AutoBookkeeping"
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        val foregroundStarted = runCatching {
            if (!AutoBookkeepingSettings.enabled(this)) {
                error("auto bookkeeping is disabled")
            }
            if (!AutoBookkeepingNotificationController.statusNotificationsAvailable(this)) {
                error("status notification is not available")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForeground(
                    AutoBookkeepingNotificationController.NOTIFICATION_ID,
                    AutoBookkeepingNotificationController.buildNotification(this),
                )
            } else {
                AutoBookkeepingNotificationController.sync(this)
            }
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
        AutoBookkeepingDiagnostics.foregroundRunning = true
        Log.i(TAG, "overlay service created")
        AutoBookkeepingLogStore.record(this, "overlay_service", "foreground service created")
    }

    override fun onDestroy() {
        remove()
        instance = null
        AutoBookkeepingDiagnostics.foregroundRunning = false
        AutoBookkeepingLogStore.record(this, "overlay_service", "foreground service destroyed")
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
        return START_STICKY
    }

}
