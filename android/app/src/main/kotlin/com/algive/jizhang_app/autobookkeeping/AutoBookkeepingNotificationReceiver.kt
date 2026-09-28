package com.algive.jizhang_app.autobookkeeping

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore

class AutoBookkeepingNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AutoBookkeepingNotificationController.ACTION_DISABLE) return
        AutoBookkeepingLogStore.recordDetailed(
            context,
            "status_notification_disable_clicked",
            "action=${intent.action}",
        )
        AutoBookkeepingSettings.setEnabled(context, false)
        context.stopService(Intent(context, AutoBillOverlayService::class.java))
        AutoBookkeepingPendingStore.complete(context, remember = false)
        AutoBookkeepingNotificationController.cancelStatus(context)
    }
}
