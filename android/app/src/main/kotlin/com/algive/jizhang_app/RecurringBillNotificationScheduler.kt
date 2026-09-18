package com.algive.jizhang_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.abs

object RecurringBillNotificationScheduler {
    const val ACTION_SHOW = "com.algive.jizhang_app.SHOW_RECURRING_BILL_REMINDER"

    private const val CHANNEL_ID = "recurring_bill_reminders"
    private const val CHANNEL_NAME = "周期账单提醒"
    private const val EXTRA_ID = "recurring_bill_notification_id"
    private const val EXTRA_TITLE = "recurring_bill_notification_title"
    private const val EXTRA_BODY = "recurring_bill_notification_body"
    private const val EXTRA_ROUTE = "recurring_bill_notification_route"

    fun schedule(
        context: Context,
        id: String,
        title: String,
        body: String,
        timestamp: Long,
        route: String,
    ) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = pendingIntent(context, id, title, body, route)
        alarmManager.cancel(pendingIntent)
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            timestamp,
            pendingIntent,
        )
    }

    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        alarmManager.cancel(pendingIntent(context, id, "", "", ""))
    }

    fun show(
        context: Context,
        id: String,
        title: String,
        body: String,
        route: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        createChannel(context)
        val contentIntent = PendingIntent.getActivity(
            context,
            requestCode("open:$id"),
            Intent(context, MainActivity::class.java).apply {
                putExtra(MainActivity.OPEN_ROUTE_EXTRA, route)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val icon = context.applicationInfo.icon.takeIf { it != 0 }
            ?: android.R.drawable.ic_popup_reminder
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        NotificationManagerCompat.from(context).notify(requestCode(id), notification)
    }

    private fun pendingIntent(
        context: Context,
        id: String,
        title: String,
        body: String,
        route: String,
    ): PendingIntent {
        val intent = Intent(context, RecurringBillNotificationReceiver::class.java).apply {
            action = ACTION_SHOW
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_ROUTE, route)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode(id),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "周期账单到期前提醒"
        }
        context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    private fun requestCode(id: String): Int = abs(id.hashCode()).coerceAtLeast(1)
}
