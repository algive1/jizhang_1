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
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingOverlayPermission
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.repository.PendingEnqueueDecision
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "jizhang/payment_notifications"
    private val fileChannelName = "jizhang/file_opener"
    private var navigationChannel: MethodChannel? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        AutoBookkeepingNotificationController.sync(this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val granted = isNotificationGranted()
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
            AutoBookkeepingNotificationController.sync(this)
        }
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/push")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentToken" -> {
                        val cached = getSharedPreferences(PUSH_PREFS, MODE_PRIVATE)
                            .getString(PUSH_TOKEN_KEY, null)
                        if (!cached.isNullOrBlank()) {
                            result.success(
                                mapOf(
                                    "platform" to "android",
                                    "provider" to "fcm",
                                    "token" to cached,
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        val messaging = firebaseMessagingOrNull()
                        if (messaging == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        messaging.token.addOnCompleteListener { task ->
                            if (!task.isSuccessful || task.result.isNullOrBlank()) {
                                result.success(null)
                            } else {
                                val token = task.result
                                getSharedPreferences(PUSH_PREFS, MODE_PRIVATE)
                                    .edit()
                                    .putString(PUSH_TOKEN_KEY, token)
                                    .apply()
                                result.success(
                                    mapOf(
                                        "platform" to "android",
                                        "provider" to "fcm",
                                        "token" to token,
                                    ),
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

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
                        openNotificationListenerSettings(result)
                    }
                    "isEnabled" -> result.success(notificationPreferences().getBoolean(KEY_ENABLED, false))
                    "setEnabled" -> {
                        val enabled = call.arguments as? Boolean ?: false
                        if (enabled && !isNotificationAccessGranted()) {
                            result.error(
                                "NOTIFICATION_ACCESS_REQUIRED",
                                "请先允许「好好记账」读取通知",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        notificationPreferences().edit()
                            .putBoolean(KEY_ENABLED, enabled)
                            .apply()
                        if (enabled) {
                            runCatching {
                                android.service.notification.NotificationListenerService
                                    .requestRebind(
                                        ComponentName(
                                            this,
                                            PaymentNotificationListenerService::class.java,
                                        ),
                                    )
                            }
                        }
                        result.success(null)
                    }
                    "isNotificationGranted" -> result.success(isNotificationGranted())
                    "requestNotificationPermission" -> {
                        requestNotificationPermission(result)
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
                        openAccessibilitySettings(result)
                    }
                    "isOverlayGranted" -> result.success(AutoBookkeepingOverlayPermission.isGranted(this))
                    "openOverlaySettings" -> {
                        openOverlaySettings(result)
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
                        if (enabled &&
                            !AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
                        ) {
                            result.error(
                                "NOTIFICATION_REQUIRED",
                                "请先允许通知并确保「自动记账状态」通知渠道未被关闭",
                                null,
                            )
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
                        val decision = AutoBookkeepingPendingStore.enqueueDecision(this, candidate)
                        if (decision == PendingEnqueueDecision.ACCEPTED) {
                            val shown = AutoBillOverlayService.instance?.offer(candidate) == true
                            if (!shown) {
                                AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
                            }
                            AutoBookkeepingLogStore.record(
                                this,
                                "notification_candidate_queued",
                                "payment notification queued for confirmation",
                            )
                        } else {
                            AutoBookkeepingLogStore.record(
                                this,
                                "notification_candidate_${decision.name.lowercase()}",
                                "payment notification was not queued",
                            )
                        }
                        result.success(mapOf("status" to decision.name.lowercase()))
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/local_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "OCR image path is empty", null)
                    return@setMethodCallHandler
                }
                val file = File(path)
                if (!file.exists() || !file.isFile) {
                    result.error("IMAGE_NOT_FOUND", "OCR image does not exist", null)
                    return@setMethodCallHandler
                }
                val image = try {
                    InputImage.fromFilePath(this, Uri.fromFile(file))
                } catch (error: Exception) {
                    result.error("IMAGE_DECODE", error.localizedMessage, null)
                    return@setMethodCallHandler
                }
                val recognizer = TextRecognition.getClient(
                    ChineseTextRecognizerOptions.Builder().build(),
                )
                recognizer.process(image)
                    .addOnSuccessListener { recognized ->
                        result.success(
                            mapOf(
                                "text" to recognized.text,
                                "blocks" to recognized.textBlocks.map { it.text },
                                "elements" to recognized.textBlocks.flatMap { block ->
                                    block.lines.flatMap { line ->
                                        line.elements.mapNotNull { element ->
                                            element.boundingBox?.let { box ->
                                                mapOf(
                                                    "text" to element.text,
                                                    "box" to mapOf(
                                                        "left" to box.left.toDouble(),
                                                        "top" to box.top.toDouble(),
                                                        "right" to box.right.toDouble(),
                                                        "bottom" to box.bottom.toDouble(),
                                                    ),
                                                )
                                            }
                                        }
                                    }
                                },
                            ),
                        )
                    }
                    .addOnFailureListener { error ->
                        result.error("OCR_FAILED", error.localizedMessage, null)
                    }
                    .addOnCompleteListener {
                        recognizer.close()
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

    private fun hasRuntimeNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

    private fun isNotificationGranted(): Boolean =
        hasRuntimeNotificationPermission() &&
            AutoBookkeepingNotificationController.statusNotificationsAvailable(this)

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (isNotificationGranted()) {
            result.success(true)
            return
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasRuntimeNotificationPermission()
        ) {
            if (pendingNotificationPermissionResult != null) {
                result.error("PERMISSION_REQUEST_BUSY", "通知权限请求正在处理中", null)
                return
            }
            pendingNotificationPermissionResult = result
            requestPermissions(
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
            return
        }

        // Permission is granted but notifications or the status channel were
        // disabled in system settings. Open the app's notification settings;
        // the Flutter page re-checks the state when the user returns.
        openAppNotificationSettings(result, successValue = false)
    }

    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        openSystemSettings(
            result,
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openOverlaySettings(result: MethodChannel.Result) {
        openSystemSettings(
            result,
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ),
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openNotificationListenerSettings(result: MethodChannel.Result) {
        val component = ComponentName(this, PaymentNotificationListenerService::class.java)
        val detailIntent = Intent("android.settings.NOTIFICATION_LISTENER_DETAIL_SETTINGS")
            .putExtra(
                "android.provider.extra.NOTIFICATION_LISTENER_COMPONENT_NAME",
                component.flattenToString(),
            )
        openSystemSettings(
            result,
            detailIntent,
            Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
        )
    }

    private fun openAppNotificationSettings(
        result: MethodChannel.Result,
        successValue: Boolean = true,
    ) {
        openSystemSettings(
            result,
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ),
            successValue = successValue,
        )
    }

    private fun openSystemSettings(
        result: MethodChannel.Result,
        vararg intents: Intent,
        successValue: Boolean = true,
    ) {
        for (intent in intents) {
            val opened = runCatching {
                startActivity(intent)
                true
            }.getOrDefault(false)
            if (opened) {
                result.success(successValue)
                return
            }
        }
        result.error("SETTINGS_UNAVAILABLE", "无法打开对应的系统设置页面", null)
    }

    private fun dispatchPendingRoute() {
        val route = intent?.getStringExtra(OPEN_ROUTE_EXTRA)
            ?: intent?.getStringExtra("route")
            ?: return
        intent?.removeExtra(OPEN_ROUTE_EXTRA)
        window.decorView.postDelayed({
            navigationChannel?.invokeMethod("openRoute", route)
        }, 700)
    }

    private fun notificationPreferences() = getSharedPreferences(PaymentNotificationStore.PREFS_NAME, MODE_PRIVATE)

    private fun firebaseMessagingOrNull(): FirebaseMessaging? {
        if (BuildConfig.FIREBASE_APP_ID.isBlank() ||
            BuildConfig.FIREBASE_API_KEY.isBlank() ||
            BuildConfig.FIREBASE_PROJECT_ID.isBlank() ||
            BuildConfig.FIREBASE_SENDER_ID.isBlank()
        ) {
            return null
        }
        if (FirebaseApp.getApps(this).isEmpty()) {
            val options = FirebaseOptions.Builder()
                .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                .setApiKey(BuildConfig.FIREBASE_API_KEY)
                .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
                .build()
            FirebaseApp.initializeApp(this, options)
        }
        return FirebaseMessaging.getInstance()
    }

    companion object {
        const val OPEN_ROUTE_EXTRA = "open_route"
        private const val KEY_ENABLED = "enabled"
        private const val NOTIFICATION_PERMISSION_REQUEST = 2402
        const val PUSH_PREFS = "haohao_push"
        const val PUSH_TOKEN_KEY = "fcm_token"
    }
}
