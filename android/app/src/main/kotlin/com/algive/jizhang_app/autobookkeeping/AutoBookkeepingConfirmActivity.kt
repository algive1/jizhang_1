package com.algive.jizhang_app.autobookkeeping

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Transparent Flutter business-logic host for the native payment review card.
 *
 * The user-facing overlay is owned by [AutoBillOverlayService]. This Activity
 * warms Flutter behind it, supplies real bookkeeping options and executes the
 * existing Dart save path when the native card submits a draft.
 */
class AutoBookkeepingConfirmActivity : MainActivity() {
    private var nativeReviewChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this

        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        window.attributes = window.attributes.apply {
            dimAmount = 0f
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeReviewChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_REVIEW_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val payload = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        AutoBillOverlayService.instance?.flutterReviewReady(payload)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun revealFlutterEditor() {
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.attributes = window.attributes.apply {
            dimAmount = VISIBLE_EDITOR_DIM_AMOUNT
        }
    }

    fun submitNativeReview(
        draft: Map<String, Any?>,
        callback: (Boolean, String?) -> Unit,
    ) {
        val channel = nativeReviewChannel
        if (channel == null) {
            callback(false, "保存引擎尚未就绪")
            return
        }
        channel.invokeMethod(
            "submit",
            draft,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val payload = result as? Map<*, *>
                    val success = payload?.get("success") == true
                    val message = payload?.get("message")?.toString()
                    callback(success, message)
                }

                override fun error(
                    errorCode: String,
                    errorMessage: String?,
                    errorDetails: Any?,
                ) {
                    callback(false, errorMessage ?: errorCode)
                }

                override fun notImplemented() {
                    callback(false, "保存桥接尚未就绪")
                }
            },
        )
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getBackgroundMode(): BackgroundMode =
        BackgroundMode.transparent

    override fun getInitialRoute(): String = CONFIRM_ROUTE

    override fun onResume() {
        super.onResume()
        // The user may cancel the native overlay while this transparent host is
        // still cold-starting. Do not leave an empty Activity above the payment
        // app when the pending candidate has already been completed.
        if (AutoBookkeepingPendingStore.readCandidate(this) == null) {
            finish()
            return
        }
        AutoBillOverlayService.instance?.confirmationOpened()
    }

    override fun onDestroy() {
        nativeReviewChannel?.setMethodCallHandler(null)
        nativeReviewChannel = null
        if (instance === this) instance = null
        AutoBillOverlayService.instance?.confirmationClosed()
        super.onDestroy()
    }

    companion object {
        @Volatile
        var instance: AutoBookkeepingConfirmActivity? = null
            private set

        const val CONFIRM_ROUTE = "/profile/autobookkeeping/confirm?overlay=1"
        const val EXTRA_BACKGROUND_MODE = "background_mode"
        const val BACKGROUND_MODE_TRANSPARENT = "transparent"
        const val NATIVE_REVIEW_CHANNEL = "jizhang/autobookkeeping_native_review"
        private const val VISIBLE_EDITOR_DIM_AMOUNT = 0.32f
    }
}
