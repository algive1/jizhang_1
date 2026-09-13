package com.algive.jizhang_app.autobookkeeping.accessibility

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics as Diagnostics
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingBridge

class AutoBookkeepingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val reader = AccessibilityTreeReader()
    private val detector = PaymentSceneDetector()
    private var scheduled = false
    private var lastPage: String? = null
    private var lastWindow = -1
    private var absentSince = 0L
    override fun onServiceConnected() { Diagnostics.accessibilityConnected = true }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!AutoBookkeepingSettings.enabled(this) || event?.packageName?.toString() != "com.tencent.mm") return
        if (event.eventType !in setOf(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, AccessibilityEvent.TYPE_WINDOWS_CHANGED)) return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val activity = event.className?.toString().orEmpty()
            if (activity.startsWith("com.tencent.mm.")) {
                paymentActivity = listOf("WalletPayUI", "WalletOrderInfo", "WalletOfflineCoinPurseUI", "WalletOrderInfoNewUI").any { activity.substringAfterLast('.').startsWith(it) }
                if (!paymentActivity) lastPage = null
            }
        }
        Diagnostics.lastEventAt = System.currentTimeMillis()
        // Read the latest root after 500 ms; continuous refreshes cannot starve parsing.
        if (!scheduled) { scheduled = true; handler.postDelayed(scan, 500) }
    }
    private val scan = Runnable { scheduled = false; scanPage() }
    @Suppress("DEPRECATION")
    private fun scanPage() {
        if (!AutoBookkeepingSettings.enabled(this)) { lastPage = null; return }
        val root = rootInActiveWindow ?: return
        try {
            if (root.packageName?.toString() != "com.tencent.mm") return
            // Fail closed outside known payment activities. In particular, never traverse LauncherUI chats/contacts.
            // Payment activities differ by WeChat version; unsupported versions need a reviewed local rule update.
            // Root class is often a layout; service event class provides the activity gate below.
            if (!paymentActivity) return
            val nodes = reader.read(root)
            val candidate = detector.detect("com.tencent.mm", nodes)
            if (candidate == null) {
                if (absentSince == 0L) absentSince = System.currentTimeMillis()
                if (System.currentTimeMillis() - absentSince > 1500) lastPage = null
                return
            }
            absentSince = 0
            val identity = BillFingerprint.hash(BillFingerprint.identity(candidate))
            if (identity == lastPage && root.windowId == lastWindow) return
            if (AutoBillOverlayService.instance?.offer(candidate) != true) {
                Diagnostics.error = "请返回自动记账设置开启后台运行和悬浮窗"
                return
            }
            lastPage = identity; lastWindow = root.windowId
            AutoBookkeepingBridge.call(this, "catalog", mapOf("merchant" to candidate.merchantNormalized)) { _, _ -> }
            Diagnostics.lastScene = "微信支付成功"
            Diagnostics.lastResult = "金额已识别 · 商户已脱敏"
        } finally { root.recycle() }
    }
    private var paymentActivity = false
    override fun onInterrupt() { handler.removeCallbacks(scan); scheduled = false; Diagnostics.error = "无障碍服务已中断" }
    override fun onDestroy() { handler.removeCallbacksAndMessages(null); Diagnostics.accessibilityConnected = false; super.onDestroy() }
}
