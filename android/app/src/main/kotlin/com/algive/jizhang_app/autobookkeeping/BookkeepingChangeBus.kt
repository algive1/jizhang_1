package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Shares committed changes between the app and the reusable confirmation engine. */
object BookkeepingChangeBus {
    private val channels = mutableMapOf<BinaryMessenger, MethodChannel>()

    fun bind(context: Context, messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, "jizhang/bookkeeping_changes")
        channels[messenger] = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method == "revision") result.success(revision(context))
            else result.notImplemented()
        }
    }

    fun unbind(messenger: BinaryMessenger) {
        channels.remove(messenger)?.setMethodCallHandler(null)
    }

    private fun revision(context: Context) =
        context.getSharedPreferences("bookkeeping_changes", Context.MODE_PRIVATE).getLong("revision", 0)

    fun publish(context: Context) {
        val next = revision(context) + 1
        context.getSharedPreferences("bookkeeping_changes", Context.MODE_PRIVATE).edit()
            .putLong("revision", next).apply()
        channels.values.toList().forEach { it.invokeMethod("changed", next) }
    }
}
