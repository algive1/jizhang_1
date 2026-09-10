package com.algive.jizhang_app

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "jizhang/payment_notifications"
    private val fileChannelName = "jizhang/file_opener"

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "openFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                val path = arguments?.get("path") as? String
                if (path.isNullOrBlank()) {
                    result.error("INVALID_FILE_PATH", "Attachment path is empty", null)
                    return@setMethodCallHandler
                }
                val file = File(path)
                if (!file.exists() || !file.isFile) {
                    result.error("FILE_NOT_FOUND", "Attachment file does not exist", null)
                    return@setMethodCallHandler
                }
                val uri = try {
                    FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.fileprovider",
                        file,
                    )
                } catch (error: IllegalArgumentException) {
                    result.error(
                        "INVALID_FILE_PATH",
                        "Attachment is outside the app storage scope",
                        null,
                    )
                    return@setMethodCallHandler
                }
                val mimeType = arguments?.get("mimeType") as? String
                    ?: "application/octet-stream"
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (error: ActivityNotFoundException) {
                    result.error("NO_HANDLER", "No application can open this file", null)
                } catch (error: SecurityException) {
                    result.error("NO_HANDLER", "No application can open this file", null)
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
