package com.algive.jizhang_app.autobookkeeping.diagnostics

object AutoBookkeepingDiagnostics {
    var accessibilityConnected = false
    var foregroundRunning = false
    var lastEventAt: Long = 0
    var lastScene = "尚未识别"
    var lastResult = "暂无"
    var error = ""
    // Never retain node trees, raw event text, account numbers or merchant names here.
    fun snapshot(): Map<String, Any> = mapOf("connected" to accessibilityConnected, "running" to foregroundRunning, "lastEventAt" to lastEventAt, "lastScene" to lastScene, "lastResult" to lastResult, "error" to error)
}
