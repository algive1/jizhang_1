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
            val finish = {
                channel.setMethodCallHandler(null)
                engine.destroy()
                pendingResult.finish()
            }
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
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
