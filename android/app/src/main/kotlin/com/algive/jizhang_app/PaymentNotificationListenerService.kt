package com.algive.jizhang_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class PaymentNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(statusBarNotification: StatusBarNotification) {
        val packageName = statusBarNotification.packageName
        if (packageName !in SUPPORTED_PACKAGES) return
        val enabled = getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
        if (!enabled) return
        val extras = statusBarNotification.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return
        val content = "$title $text".lowercase(Locale.ROOT)
        if (PAYMENT_WORDS.none { content.contains(it) }) return
        val id = "$packageName:${statusBarNotification.key}:${statusBarNotification.postTime}"
        PaymentNotificationStore.append(
            this,
            JSONObject()
                .put("id", id)
                .put("packageName", packageName)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt(statusBarNotification.postTime)),
        )
    }

    private fun postedAt(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(Date(millis))
    }

    companion object {
        private const val KEY_ENABLED = "enabled"
        private val SUPPORTED_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.unionpay",
        )
        private val PAYMENT_WORDS = setOf("支付", "付款", "消费", "扣款", "收款")
    }
}
