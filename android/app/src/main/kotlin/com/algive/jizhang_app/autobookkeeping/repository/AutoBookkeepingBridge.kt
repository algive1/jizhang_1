package com.algive.jizhang_app.autobookkeeping.repository

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One process-owned worker, no Activity and no UI navigation. */
object AutoBookkeepingBridge {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private val pending = mutableListOf<() -> Unit>()
    private val handler = Handler(Looper.getMainLooper())
    var foreground: MethodChannel? = null
    fun call(context: Context, method: String, data: Map<String, Any?>, done: (Any?, String?) -> Unit) {
        var completed = false
        val timeout = Runnable { if (!completed) { completed = true; done(null, "后台处理超时，请重试；已提交的账单不会重复保存") } }
        handler.postDelayed(timeout, 20000)
        val operation = {
            if (!completed) channel!!.invokeMethod(method, data, object : MethodChannel.Result {
                override fun success(result: Any?) { if (!completed) { completed = true; handler.removeCallbacks(timeout); if (method == "save") foreground?.invokeMethod("dataChanged", null); done(result, null) } }
                override fun error(code: String, message: String?, details: Any?) { if (!completed) { completed = true; handler.removeCallbacks(timeout); done(null, "处理失败，请检查账本、账户与分类后重试") } }
                override fun notImplemented() = error("UNAVAILABLE", null, null)
            })
            Unit
        }
        if (ready) { operation(); return }
        pending.add(operation)
        if (engine != null) return
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context.applicationContext)
        loader.ensureInitializationComplete(context.applicationContext, null)
        engine = FlutterEngine(context.applicationContext)
        channel = MethodChannel(engine!!.dartExecutor.binaryMessenger, "jizhang/autobookkeeping_worker")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                ready = true; result.success(null)
                val queued = pending.toList(); pending.clear(); queued.forEach { it() }
            } else result.notImplemented()
        }
        engine!!.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "autoBookkeepingMain"))
    }
}
