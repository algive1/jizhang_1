package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** Kept warm by the foreground service, including when the review Activity closes. */
object AutoBookkeepingEngine {
    const val CACHE_ID = "autobookkeeping-confirmation"
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private var requested = false

    fun warmUp(context: Context): FlutterEngine {
        engine?.let { return it }
        val app = context.applicationContext
        val created = FlutterEngine(app)
        engine = created
        FlutterEngineCache.getInstance().put(CACHE_ID, created)
        AutoBookkeepingChannels.bind(app, created.dartExecutor.binaryMessenger)
        channel = MethodChannel(created.dartExecutor.binaryMessenger, "jizhang/autobookkeeping_overlay").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "engineReady" -> {
                        ready = true
                        if (requested) prepare(app)
                        AutoBookkeepingLogStore.record(app, "confirmation_engine_ready", "confirmation engine warmed")
                        result.success(null)
                    }
                    "prepared" -> {
                        AutoBillOverlayService.instance?.confirmationPrepared(call.argument<String>("fingerprint").orEmpty())
                        result.success(null)
                    }
                    "close" -> {
                        AutoBillOverlayService.instance?.closeConfirmation("flutter_close",
                            drainAutomatic = call.argument<Boolean>("drainAutomatic") == true)
                            ?: AutoBookkeepingConfirmActivity.instance?.finish()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        created.navigationChannel.setInitialRoute(AutoBookkeepingConfirmActivity.CONFIRM_ROUTE)
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
            FlutterInjector.instance().flutterLoader().findAppBundlePath(), "autoBookkeepingOverlayMain",
        ))
        AutoBookkeepingLogStore.record(app, "confirmation_engine_warming", "preparing reusable confirmation engine")
        return created
    }

    fun prepare(context: Context) {
        requested = true
        warmUp(context)
        if (ready) {
            val service = AutoBillOverlayService.instance
            service?.trace("confirmation_show_sent", "awaiting Flutter content")
            channel?.invokeMethod("show", AutoBookkeepingPendingStore.read(context), object : MethodChannel.Result {
                override fun success(result: Any?) { service?.trace("confirmation_show_ack", "Flutter accepted show") }
                override fun error(code: String, message: String?, details: Any?) {
                    service?.trace("confirmation_show_failed", "code=$code")
                }
                override fun notImplemented() { service?.trace("confirmation_show_failed", "code=not_implemented") }
            })
        }
    }

    fun clearReview() {
        requested = false
        channel?.invokeMethod("hide", null)
    }

    fun dispose() {
        val disposed = engine
        engine = null
        FlutterEngineCache.getInstance().remove(CACHE_ID)
        channel = null
        ready = false
        requested = false
        disposed?.let { BookkeepingChangeBus.unbind(it.dartExecutor.binaryMessenger); it.destroy() }
    }
}
