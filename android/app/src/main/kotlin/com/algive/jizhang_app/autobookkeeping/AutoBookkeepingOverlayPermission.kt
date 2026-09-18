package com.algive.jizhang_app.autobookkeeping

import android.app.AppOpsManager
import android.content.Context
import android.os.Build
import android.provider.Settings

object AutoBookkeepingOverlayPermission {
    fun isGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (runCatching { Settings.canDrawOverlays(context) }.getOrDefault(false)) return true

        val appOps = context.getSystemService(AppOpsManager::class.java) ?: return false
        return runCatching {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                context.applicationInfo.uid,
                context.packageName,
            ) == AppOpsManager.MODE_ALLOWED
        }.getOrDefault(false)
    }
}
