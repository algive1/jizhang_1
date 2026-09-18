package com.algive.jizhang_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class RecurringBillNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != RecurringBillNotificationScheduler.ACTION_SHOW) return
        RecurringBillNotificationScheduler.show(
            context = context,
            id = intent.getStringExtra("recurring_bill_notification_id") ?: return,
            title = intent.getStringExtra("recurring_bill_notification_title") ?: "周期账单提醒",
            body = intent.getStringExtra("recurring_bill_notification_body") ?: "",
            route = intent.getStringExtra("recurring_bill_notification_route") ?: "/profile/recurring-bills",
        )
    }
}
