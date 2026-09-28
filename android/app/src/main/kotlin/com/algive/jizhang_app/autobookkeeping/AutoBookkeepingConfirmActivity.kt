package com.algive.jizhang_app.autobookkeeping

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import com.algive.jizhang_app.MainActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService

/** Transparent Flutter host for confirming a detected payment over the source app. */
class AutoBookkeepingConfirmActivity : MainActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep the source payment app visible behind the confirmation card.
        // Flutter renders only the card; dimming belongs to the native window
        // so the transparent area never falls back to the app launch color.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        window.attributes = window.attributes.apply {
            dimAmount = BACKGROUND_DIM_AMOUNT
        }
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode =
        TransparencyMode.transparent

    override fun getInitialRoute(): String = CONFIRM_ROUTE

    override fun onResume() {
        super.onResume()
        AutoBillOverlayService.instance?.confirmationOpened()
    }

    override fun onDestroy() {
        AutoBillOverlayService.instance?.confirmationClosed()
        super.onDestroy()
    }

    companion object {
        const val CONFIRM_ROUTE = "/profile/autobookkeeping/confirm?overlay=1"
        const val EXTRA_BACKGROUND_MODE = "background_mode"
        const val BACKGROUND_MODE_TRANSPARENT = "transparent"
        private const val BACKGROUND_DIM_AMOUNT = 0.32f
    }
}
