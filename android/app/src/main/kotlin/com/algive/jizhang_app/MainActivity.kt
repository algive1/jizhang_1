package com.algive.jizhang_app

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "jizhang/payment_notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessGranted" -> result.success(isNotificationAccessGranted())
                    "openAccessSettings" -> {
                        startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                        result.success(null)
                    }
                    "isEnabled" -> result.success(notificationPreferences().getBoolean(KEY_ENABLED, false))
                    "setEnabled" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        notificationPreferences().edit()
                            .putBoolean(KEY_ENABLED, enabled)
                            .apply()
                        result.success(null)
                    }
                    "getPending" -> result.success(PaymentNotificationStore.read(this))
                    "acknowledge" -> {
                        val ids = call.arguments as? List<*> ?: emptyList<Any>()
                        PaymentNotificationStore.acknowledge(this, ids.mapNotNull { it as? String })
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(":").any { ComponentName.unflattenFromString(it)?.packageName == packageName }
    }

    private fun notificationPreferences() = getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE)

    companion object {
        private const val KEY_ENABLED = "enabled"
    }
}
