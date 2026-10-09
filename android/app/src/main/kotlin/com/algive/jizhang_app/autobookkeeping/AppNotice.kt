package com.algive.jizhang_app.autobookkeeping

import android.app.Activity
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import com.algive.jizhang_app.autobookkeeping.accessibility.AutoBookkeepingAccessibilityService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** Theme-aware feedback, including while a payment app is in front. */
object AppNotice {
    private const val PREFS = "app_notice_appearance"
    private val handler = Handler(Looper.getMainLooper())
    private var activity = WeakReference<Activity>(null)
    private var dismiss: Runnable? = null

    fun bind(context: Context, messenger: BinaryMessenger) {
        if (context is Activity) activity = WeakReference(context)
        MethodChannel(messenger, "jizhang/notice_theme").setMethodCallHandler { call, result ->
            if (call.method == "show") {
                result.success(show(context, call.argument<String>("message").orEmpty()))
                return@setMethodCallHandler
            }
            if (call.method != "setColors") { result.notImplemented(); return@setMethodCallHandler }
            val background = call.argument<Number>("background")
            val foreground = call.argument<Number>("foreground")
            if (background == null || foreground == null) {
                result.error("INVALID_COLORS", "Missing notice colors", null)
            } else {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putInt("background", background.toInt()).putInt("foreground", foreground.toInt()).apply()
                result.success(null)
            }
        }
    }

    fun show(context: Context, message: String, durationMs: Long = 2500): Boolean {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { show(context, message, durationMs) }; return true
        }
        dismiss?.let { handler.removeCallbacks(it); it.run() }
        val host = activity.get()?.takeIf { !it.isFinishing && !it.isDestroyed && it.hasWindowFocus() }
        val service = AutoBookkeepingAccessibilityService.instance
        val source: Context = host ?: service ?: context.applicationContext
        val type = when {
            host != null -> WindowManager.LayoutParams.TYPE_APPLICATION_PANEL
            service != null -> WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            Settings.canDrawOverlays(context) -> WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else -> return false
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        fun dp(value: Int) = (value * source.resources.displayMetrics.density).toInt()
        val view = TextView(source).apply {
            text = message
            textSize = 14f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(prefs.getInt("foreground", 0xFF1E241C.toInt()))
            setPadding(dp(20), dp(14), dp(20), dp(14))
            background = GradientDrawable().apply {
                setColor(prefs.getInt("background", 0xFFFFFFFF.toInt()))
                cornerRadius = dp(16).toFloat()
                setStroke(dp(1).coerceAtLeast(1), 0x22747A70)
            }
            elevation = dp(4).toFloat()
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dp(112)
            token = host?.window?.decorView?.windowToken
            setTitle("好好记账提示")
        }
        val manager = source.getSystemService(WindowManager::class.java)
        view.maxWidth = source.resources.displayMetrics.widthPixels - dp(32)
        try {
            manager.addView(view, params)
            val remove = Runnable { runCatching { manager.removeView(view) }; dismiss = null }
            dismiss = remove
            handler.postDelayed(remove, durationMs)
            return true
        } catch (error: RuntimeException) {
            Log.w("AppNotice", "Unable to attach feedback", error)
            return false
        }
    }
}
