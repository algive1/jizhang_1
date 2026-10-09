package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
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
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener

/** One transparent host for the real confirmation UI, with no native-to-Flutter handoff. */
class AutoBookkeepingConfirmActivity : MainActivity() {
    private var reviewEngine: FlutterEngine? = null
    private val displayListener = object : FlutterUiDisplayListener {
        override fun onFlutterUiDisplayed() {
            AutoBillOverlayService.instance?.trace("confirmation_host_first_frame", "hostFrame=true; visibility checked separately")
            reportVisibility()
        }
        override fun onFlutterUiNoLongerDisplayed() = Unit
    }

    override fun provideFlutterEngine(context: Context) = AutoBookkeepingEngine.warmUp(context)
    override fun getCachedEngineId() = AutoBookkeepingEngine.CACHE_ID
    override fun shouldDestroyEngineWithHost() = false

    override fun onCreate(savedInstanceState: Bundle?) {
        reviewEngine = AutoBookkeepingEngine.warmUp(this)
        super.onCreate(savedInstanceState)
        instance = this
        AutoBillOverlayService.instance?.trace("confirmation_host_created", "shown=false")
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.decorView.setBackgroundColor(Color.TRANSPARENT)
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.attributes = window.attributes.apply { dimAmount = 0f }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setBackgroundDrawable(GradientDrawable().apply {
                cornerRadius = 22 * resources.displayMetrics.density
                setColor(Color.TRANSPARENT)
            })
            window.setBackgroundBlurRadius((5 * resources.displayMetrics.density).toInt())
        }
        reviewEngine?.renderer?.addIsDisplayingFlutterUiListener(displayListener)
    }

    override fun getRenderMode() = RenderMode.texture
    override fun getBackgroundMode() = BackgroundMode.transparent
    override fun getInitialRoute() = CONFIRM_ROUTE

    override fun onResume() {
        super.onResume()
        val pending = AutoBookkeepingPendingStore.read(this)
        val candidate = AutoBookkeepingPendingStore.readCandidate(this)
        AutoBillOverlayService.instance?.trace("confirmation_host_resumed", "pending=${pending != null} valid=${candidate != null}")
        if (candidate == null) {
            AutoBillOverlayService.instance?.trace("confirmation_missing_pending", "shown=false pending=${pending != null}")
            finish()
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        AutoBillOverlayService.instance?.trace("confirmation_window_focus", "focused=$hasFocus decorShown=${window.decorView.isShown}")
        reportVisibility()
    }

    fun reportVisibility() {
        if (hasWindowFocus() && window.decorView.isShown && !isFinishing && !isDestroyed) {
            AutoBillOverlayService.instance?.confirmationVisible()
        }
    }

    override fun finish() {
        val caller = Throwable().stackTrace.firstOrNull { it.methodName != "finish" }
        AutoBillOverlayService.instance?.trace("confirmation_finish_requested", "caller=${caller?.className?.substringAfterLast('.')}.${caller?.methodName}")
        super.finish()
    }

    override fun onDestroy() {
        AutoBillOverlayService.instance?.trace("confirmation_host_destroyed", "finishing=$isFinishing changingConfig=$isChangingConfigurations")
        reviewEngine?.renderer?.removeIsDisplayingFlutterUiListener(displayListener)
        if (instance === this) instance = null
        super.onDestroy()
        if (!isChangingConfigurations) AutoBillOverlayService.instance?.confirmationClosed()
        if (AutoBillOverlayService.instance == null) AutoBookkeepingEngine.dispose()
    }

    companion object {
        var instance: AutoBookkeepingConfirmActivity? = null; private set
        const val CONFIRM_ROUTE = "/profile/autobookkeeping/confirm?overlay=1"
        const val EXTRA_BACKGROUND_MODE = "background_mode"
        const val BACKGROUND_MODE_TRANSPARENT = "transparent"
    }
}
