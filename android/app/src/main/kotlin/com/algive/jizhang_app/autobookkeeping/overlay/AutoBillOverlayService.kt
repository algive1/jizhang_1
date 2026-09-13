package com.algive.jizhang_app.autobookkeeping.overlay

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate

class AutoBillOverlayService : Service() {
    private var root: LinearLayout? = null
    private var wm: WindowManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    fun offer(candidate: PaymentCandidate): Boolean {
        if (!android.provider.Settings.canDrawOverlays(this)) return false
        if (root != null) return true

        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 20, 28, 20)
            setBackgroundColor(Color.rgb(38, 38, 42))
            addView(TextView(context).apply {
                text = "好好记账\n¥%.2f  %s\n%s\n请打开应用确认账本、账户与分类".format(
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
                text = "关闭"
                setTextColor(Color.WHITE)
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(12, 12, 12, 12)
                setOnClickListener { remove() }
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
        }.isSuccess
    }

    private fun remove() {
        root?.let { runCatching { wm?.removeView(it) } }
        root = null
    }

    companion object {
        var instance: AutoBillOverlayService? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        remove()
        instance = null
        super.onDestroy()
    }
}
