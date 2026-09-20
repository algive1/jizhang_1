package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import android.os.Build

object AutoBookkeepingSettings {
    private const val PREFS = "autobookkeeping"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_SCREENSHOT_ENABLED = "screenshot_enabled"

    fun enabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, value: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, value)
            .apply()
    }

    fun screenshotSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    fun screenshotEnabled(context: Context): Boolean =
        screenshotSupported() &&
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_SCREENSHOT_ENABLED, false)

    fun setScreenshotEnabled(context: Context, value: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SCREENSHOT_ENABLED, value && screenshotSupported())
            .apply()
    }
}
