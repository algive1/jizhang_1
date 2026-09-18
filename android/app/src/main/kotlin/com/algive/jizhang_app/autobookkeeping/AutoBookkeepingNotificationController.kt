package com.algive.jizhang_app.autobookkeeping

import android.Manifest
import android.app.NotificationChannel
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.algive.jizhang_app.MainActivity

object AutoBookkeepingNotificationController {
    const val ACTION_DISABLE = "com.algive.jizhang_app.AUTOB_BOOKKEEPING_DISABLE"

    private const val CHANNEL_ID = "autobookkeeping_status"
    const val NOTIFICATION_ID = 2401
    private const val RESULT_CHANNEL_ID = "autobookkeeping_result"
    private const val RESULT_NOTIFICATION_ID = 2402
    private const val CONFIRM_NOTIFICATION_ID = 2403

    fun sync(context: Context) {
        val manager = NotificationManagerCompat.from(context)
        if (!AutoBookkeepingSettings.enabled(context)) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        createChannel(context)
        manager.notify(NOTIFICATION_ID, buildNotification(context))
    }

    fun buildNotification(context: Context): Notification {
        createChannel(context)
        val openIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(MainActivity.OPEN_ROUTE_EXTRA, "/profile/autobookkeeping")
            },
            pendingFlags(),
        )
        val disableIntent = PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, AutoBookkeepingNotificationReceiver::class.java).apply {
                action = ACTION_DISABLE
            },
            pendingFlags(),
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("好好记账 · 自动记账已开启")
            .setContentText("正在监听支持的付款页面，点击查看设置")
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(0, "关闭自动记账", disableIntent)
            .build()
    }

    fun notifyBookkeepingSuccess(context: Context, count: Int) {
        if (count <= 0) return
        val text = "已记录 $count 笔自动记账流水"
        Toast.makeText(context.applicationContext, text, Toast.LENGTH_LONG).show()
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) return
        createResultChannel(context)
        val openIntent = PendingIntent.getActivity(
            context,
            2,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(MainActivity.OPEN_ROUTE_EXTRA, "/transactions")
            },
            pendingFlags(),
        )
        runCatching {
            manager.notify(
                RESULT_NOTIFICATION_ID,
                NotificationCompat.Builder(context, RESULT_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_popup_sync)
                    .setContentTitle("好好记账 · 记账成功")
                    .setContentText(text)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                    .setContentIntent(openIntent)
                    .setAutoCancel(true)
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setShowWhen(true)
                    .build(),
            )
        }
    }

    /** Fallback when a confirmation overlay cannot be attached. */
    fun notifyConfirmationAvailable(context: Context) {
        val text = "识别到支付通知，请打开好好记账确认"
        Toast.makeText(context.applicationContext, text, Toast.LENGTH_LONG).show()
        val manager = NotificationManagerCompat.from(context)
        if (!manager.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) return
        createResultChannel(context)
        val openIntent = PendingIntent.getActivity(
            context,
            3,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(MainActivity.OPEN_ROUTE_EXTRA, "/profile/autobookkeeping/confirm")
            },
            pendingFlags(),
        )
        runCatching {
            manager.notify(
                CONFIRM_NOTIFICATION_ID,
                NotificationCompat.Builder(context, RESULT_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_popup_sync)
                    .setContentTitle("好好记账 · 待确认流水")
                    .setContentText(text)
                    .setContentIntent(openIntent)
                    .setAutoCancel(true)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .build(),
            )
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "自动记账状态",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "显示自动记账是否正在运行"
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun createResultChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            RESULT_CHANNEL_ID,
            "自动记账结果",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "提示自动记账是否已经成功写入流水"
            setShowBadge(true)
        }
        context.getSystemService(NotificationManager::class.java)
            ?.createNotificationChannel(channel)
    }

    private fun pendingFlags(): Int = PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
}
