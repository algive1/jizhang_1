package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService

/** Transparent Flutter host for confirming a detected payment over the source app. */
class AutoBookkeepingConfirmActivity : MainActivity() {
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
    }
}
