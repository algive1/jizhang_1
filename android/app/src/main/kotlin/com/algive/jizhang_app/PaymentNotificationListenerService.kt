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
        if (!isLikelyCompletedOutgoingPayment(packageName, content)) return

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

    private fun isLikelyCompletedOutgoingPayment(packageName: String, content: String): Boolean {
        if (REJECT_WORDS.any { content.contains(it) }) return false
        if (INCOMING_WORDS.any { content.contains(it) }) return false

        val hasStrongSuccess = SUCCESS_WORDS.any { content.contains(it) }
        if (packageName in MARKETPLACE_PACKAGES) {
            // Marketplace apps emit many order/marketing notifications containing
            // the word "支付". Only completed-payment semantics are allowed into
            // the bookkeeping queue.
            return hasStrongSuccess
        }

        if (hasStrongSuccess) return true

        // Wallet/bank apps sometimes publish terse debit notifications without
        // the word "成功"; "消费/扣款/支出" are sufficiently strong for these apps.
        return packageName in WALLET_PACKAGES &&
            DEBIT_WORDS.any { content.contains(it) }
    }

    private fun postedAt(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(Date(millis))
    }

    companion object {
        private const val KEY_ENABLED = "enabled"

        private val WALLET_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.unionpay",
        )
        private val MARKETPLACE_PACKAGES = setOf(
            "com.sankuai.meituan",
            "com.sankuai.meituan.takeout",
            "com.jingdong.app.mall",
            "com.xunmeng.pinduoduo",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.mobile",
        )
        private val SUPPORTED_PACKAGES = WALLET_PACKAGES + MARKETPLACE_PACKAGES

        private val SUCCESS_WORDS = setOf(
            "支付成功",
            "付款成功",
            "交易成功",
            "扣款成功",
            "消费成功",
            "已支付",
            "已付款",
            "支付完成",
            "付款完成",
            "订单支付成功",
            "订单已支付",
        )
        private val DEBIT_WORDS = setOf("消费", "扣款", "支出")
        private val INCOMING_WORDS = setOf(
            "收款到账",
            "收款成功",
            "转入",
            "入账",
            "到账",
            "退款",
            "退回",
        )
        private val REJECT_WORDS = setOf(
            "待支付",
            "去支付",
            "未支付",
            "支付失败",
            "付款失败",
            "交易失败",
            "支付取消",
            "付款取消",
            "取消支付",
            "重新支付",
            "支付提醒",
            "支付优惠",
            "支付立减",
            "预计支付",
            "应付",
            "付款码",
        )
    }
}
