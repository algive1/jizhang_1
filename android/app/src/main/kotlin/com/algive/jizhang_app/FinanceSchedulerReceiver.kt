package com.algive.jizhang_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class FinanceSchedulerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            FinanceScheduler.schedule(context)
            // Rebuild one-shot recurring-bill reminders immediately after a
            // reboot instead of waiting for the next 03:10 daily run.
            context.sendBroadcast(
                Intent(context, FinanceSchedulerReceiver::class.java).apply {
                    action = FinanceScheduler.ACTION_RUN
                },
            )
            return
        }
        if (intent?.action != FinanceScheduler.ACTION_RUN) return

        val pendingResult = goAsync()
        val appContext = context.applicationContext
        Handler(Looper.getMainLooper()).post {
            val engine = FlutterEngine(appContext)
            GeneratedPluginRegistrant.registerWith(engine)
            val channel = MethodChannel(
                engine.dartExecutor.binaryMessenger,
                "jizhang/finance_scheduler",
            )
            val budgetChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "jizhang/budget_notifications")
            budgetChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(
                        androidx.core.app.NotificationManagerCompat.from(appContext).areNotificationsEnabled() &&
                            (android.os.Build.VERSION.SDK_INT < 33 || appContext.checkSelfPermission(
                                android.Manifest.permission.POST_NOTIFICATIONS,
                            ) == android.content.pm.PackageManager.PERMISSION_GRANTED),
                    )
                    "requestPermission" -> result.success(null)
                    "show" -> {
                        val id = call.argument<String>("id")
                        val title = call.argument<String>("title")
                        val body = call.argument<String>("body")
                        val route = call.argument<String>("route")
                        if (id.isNullOrBlank() || title == null || body == null || route.isNullOrBlank()) {
                            result.error("INVALID_BUDGET_NOTICE", "预算提醒参数不完整", null)
                        } else {
                            BudgetNotificationScheduler.show(appContext, id, title, body, route)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            val finish = {
                channel.setMethodCallHandler(null)
                budgetChannel.setMethodCallHandler(null)
                engine.destroy()
                pendingResult.finish()
            }
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleReminder" -> {
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
                                appContext,
                                id,
                                title,
                                body,
                                timestamp,
                                route,
                            )
                            result.success(null)
                        }
                    }
                    "cancelReminder" -> {
                        val id = call.argument<String>("id")
                        if (id.isNullOrBlank()) {
                            result.error("INVALID_REMINDER", "周期账单提醒 ID 为空", null)
                        } else {
                            RecurringBillNotificationScheduler.cancel(appContext, id)
                            result.success(null)
                        }
                    }
                    "completed", "failed" -> {
                        result.success(null)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "scheduledFinanceMain",
                ),
            )
        }
    }
}
