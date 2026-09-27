package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.MainActivity

/** Transparent Flutter host for confirming a detected payment over the source app. */
class AutoBookkeepingConfirmActivity : MainActivity() {
    override fun getInitialRoute(): String = CONFIRM_ROUTE

    companion object {
        const val CONFIRM_ROUTE = "/profile/autobookkeeping/confirm?overlay=1"
        const val EXTRA_BACKGROUND_MODE = "background_mode"
        const val BACKGROUND_MODE_TRANSPARENT = "transparent"
    }
}
