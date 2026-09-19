package com.algive.jizhang_app

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingOverlayPermission
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "jizhang/payment_notifications"
    private val fileChannelName = "jizhang/file_opener"
    private var navigationChannel: MethodChannel? = null

    override fun onResume() {
        super.onResume()
        AutoBookkeepingNotificationController.sync(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchPendingRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "jizhang/navigation",
        )
        dispatchPendingRoute()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/app_update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appInfo" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "platform" to "android",
                                "version" to (info.versionName ?: "0.0.0"),
                                "build" to build,
                            ),
                        )
                    }
                    "openStore" -> {
                        val url = call.argument<String>("url")
                        val uri = url?.let(Uri::parse)
                        if (uri == null || uri.scheme != "https") {
                            result.error("INVALID_STORE_URL", "更新地址必须使用 HTTPS", null)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(true)
                        } catch (error: ActivityNotFoundException) {
                            result.error("NO_HANDLER", "没有可打开更新地址的应用", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
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
                    "isNotificationGranted" -> result.success(isNotificationGranted())
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST,
                            )
                        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/autobookkeeping")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityGranted" -> result.success(isAccessibilityGranted())
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "isOverlayGranted" -> result.success(AutoBookkeepingOverlayPermission.isGranted(this))
                    "openOverlaySettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(null)
                    }
                    "isEnabled" -> result.success(AutoBookkeepingSettings.enabled(this))
                    "isNotificationGranted" -> result.success(isNotificationGranted())
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST,
                            )
                        }
                        result.success(null)
                    }
                    "setEnabled" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        if (enabled && !isAccessibilityGranted()) {
                            result.error("ACCESSIBILITY_REQUIRED", "请先允许无障碍服务", null)
                            return@setMethodCallHandler
                        }
                        if (enabled && !AutoBookkeepingOverlayPermission.isGranted(this)) {
                            result.error("OVERLAY_REQUIRED", "请先允许悬浮窗权限", null)
                            return@setMethodCallHandler
                        }
                        AutoBookkeepingSettings.setEnabled(this, enabled)
                        AutoBookkeepingLogStore.record(this, "setting_changed", "enabled=$enabled")
                        if (enabled) {
                            ContextCompat.startForegroundService(this, Intent(this, AutoBillOverlayService::class.java))
                        } else {
                            stopService(Intent(this, AutoBillOverlayService::class.java))
                            AutoBookkeepingPendingStore.complete(this, remember = false)
                        }
                        AutoBookkeepingNotificationController.sync(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/bookkeeping_feedback")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "notifySuccess" -> {
                        val count = (call.argument<Number>("count")?.toInt() ?: 0)
                        AutoBookkeepingNotificationController.notifyBookkeepingSuccess(this, count)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/autobookkeeping_pending")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPending" -> result.success(AutoBookkeepingPendingStore.read(this))
                    "enqueue" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val candidate = arguments?.let {
                            AutoBookkeepingPendingStore.candidateFromMap(it)
                        }
                        if (candidate == null) {
                            result.error("INVALID_CANDIDATE", "自动记账候选数据无效", null)
                            return@setMethodCallHandler
                        }
                        val accepted = AutoBookkeepingPendingStore.enqueueIfAbsent(this, candidate)
                        if (accepted) {
                            val shown = AutoBillOverlayService.instance?.offer(candidate) == true
                            if (!shown) {
                                AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
                            }
                            AutoBookkeepingLogStore.record(
                                this,
                                "notification_candidate_queued",
                                "payment notification queued for confirmation",
                            )
                        }
                        result.success(accepted)
                    }
                    "complete" -> {
                        AutoBookkeepingPendingStore.complete(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/autobookkeeping_logs")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(AutoBookkeepingLogStore.read(this))
                    "clear" -> {
                        AutoBookkeepingLogStore.clear(this)
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
                val mimeType = arguments.get("mimeType") as? String
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/finance_scheduler")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        FinanceScheduler.schedule(applicationContext)
                        result.success(null)
                    }
                    "cancel" -> {
                        FinanceScheduler.cancel(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/budget_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(isNotificationGranted())
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST,
                            )
                        }
                        result.success(null)
                    }
                    "show" -> {
                        val id = call.argument<String>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        val route = call.argument<String>("route")
                        if (id.isNullOrBlank() || title.isNullOrBlank() ||
                            body.isNullOrBlank() || route.isNullOrBlank()
                        ) {
                            result.error("INVALID_BUDGET_ALERT", "预算预警参数不完整", null)
                        } else {
                            BudgetNotificationScheduler.show(
                                applicationContext,
                                id,
                                title,
                                body,
                                route,
                            )
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/recurring_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_REQUEST,
                            )
                        }
                        result.success(null)
                    }
                    "schedule" -> {
                        val id = call.argument<String>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        val timestamp = call.argument<Number>("timestamp")?.toLong()
                        val route = call.argument<String>("route")
                        if (id.isNullOrBlank() || title == null || body == null ||
                            timestamp == null || route.isNullOrBlank()
                        ) {
                            result.error("INVALID_REMINDER", "周期账单提醒参数不完整", null)
                        } else {
                            RecurringBillNotificationScheduler.schedule(
                                applicationContext,
                                id,
                                title,
                                body,
                                timestamp,
                                route,
                            )
                            result.success(null)
                        }
                    }
                    "cancel" -> {
                        val id = call.argument<String>("id")
                        if (id.isNullOrBlank()) {
                            result.error("INVALID_REMINDER", "周期账单提醒 ID 为空", null)
                        } else {
                            RecurringBillNotificationScheduler.cancel(applicationContext, id)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(":").any { ComponentName.unflattenFromString(it)?.packageName == packageName }
    }

    private fun isAccessibilityGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
            ?: return false
        val expected = ComponentName(this, "${packageName}.autobookkeeping.accessibility.AutoBookkeepingAccessibilityService")
        return enabled.split(":").any { ComponentName.unflattenFromString(it) == expected }
    }

    private fun isNotificationGranted(): Boolean =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        }

    private fun dispatchPendingRoute() {
        val route = intent?.getStringExtra(OPEN_ROUTE_EXTRA) ?: return
        intent?.removeExtra(OPEN_ROUTE_EXTRA)
        window.decorView.postDelayed({
            navigationChannel?.invokeMethod("openRoute", route)
        }, 700)
    }

    private fun notificationPreferences() = getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE)

    companion object {
        const val OPEN_ROUTE_EXTRA = "open_route"
        private const val KEY_ENABLED = "enabled"
        private const val NOTIFICATION_PERMISSION_REQUEST = 2402
    }
}
