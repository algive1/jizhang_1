package com.algive.jizhang_app.autobookkeeping.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.content.ContextCompat
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingOverlayPermission
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics as Diagnostics
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingBridge
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore

class AutoBookkeepingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val reader = AccessibilityTreeReader()
    private val detector = PaymentSceneDetector()
    private var scheduled = false
    private var lastPage: String? = null
    private var lastWindow = -1
    private var absentSince = 0L
    private var lastDebugAt = 0L
    private var lastPaymentActivityAt = 0L
    private var rootRetryCount = 0
    private var visibleWindowCount = 0
    override fun onServiceConnected() {
        Diagnostics.accessibilityConnected = true
        ensureOverlayService()
        AutoBookkeepingLogStore.record(this, "service_connected", "accessibility service connected")
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val actualEvent = event ?: return
        val eventPackage = actualEvent.packageName?.toString()
        if (!AutoBookkeepingSettings.enabled(this) || eventPackage !in SUPPORTED_PACKAGES) return
        if (actualEvent.eventType !in setOf(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, AccessibilityEvent.TYPE_WINDOWS_CHANGED)) return
        if (actualEvent.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val activity = actualEvent.className?.toString().orEmpty()
            Log.i(TAG, "window event class=$activity")
            AutoBookkeepingLogStore.record(this, "window_event", activity.substringAfterLast('.'))
            if (eventPackage == "com.tencent.mm" && activity.startsWith("com.tencent.mm.")) {
                val isPaymentActivity = listOf(
                    "WalletPayUI",
                    "WalletOrderInfo",
                    "WalletOfflineCoinPurseUI",
                    "WalletOrderInfoNewUI",
                    // New WeChat transfer/payment pages are hosted by this
                    // generic container; the parser still requires a payment
                    // success marker before accepting the page.
                    "UIPageFragmentActivity",
                ).any { activity.substringAfterLast('.').startsWith(it) }
                if (isPaymentActivity) {
                    paymentActivity = true
                    lastPaymentActivityAt = System.currentTimeMillis()
                } else if (System.currentTimeMillis() - lastPaymentActivityAt > PAYMENT_ACTIVITY_GRACE_MS) {
                    paymentActivity = false
                    lastPage = null
                }
            } else if (eventPackage in SUPPORTED_PACKAGES) {
                // Other supported payment apps do not expose stable activity
                // names; the generic parser still requires an exact success
                // marker before accepting a page.
                paymentActivity = true
                lastPaymentActivityAt = System.currentTimeMillis()
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
        if (AutoBillOverlayService.instance == null) {
            ensureOverlayService()
            debug("overlay instance missing")
            handler.postDelayed(scan, 200)
            return
        }
        if (!paymentActivity) {
            debug("scan blocked paymentActivity=false")
            return
        }
        val detected = detectCandidateFromVisibleWindows()
        if (detected == null) {
            debug("scan windows=$visibleWindowCount candidate=false")
            if (absentSince == 0L) absentSince = System.currentTimeMillis()
            if (System.currentTimeMillis() - absentSince > 1500) lastPage = null
            retryScanIfNeeded()
            return
        }
        rootRetryCount = 0
        absentSince = 0
        val candidate = detected.first
        val windowId = detected.second
        debug("scan windows=$visibleWindowCount candidate=true")
        val identity = BillFingerprint.hash(BillFingerprint.identity(candidate))
        AutoBookkeepingLogStore.record(this, "candidate_detected", "payment success candidate")
        if (identity == lastPage && windowId == lastWindow) {
            AutoBookkeepingLogStore.record(this, "deduplicated", "same page and fingerprint")
            return
        }
        if (!AutoBookkeepingPendingStore.enqueueIfAbsent(this, candidate)) {
            AutoBookkeepingLogStore.record(this, "deduplicated", "pending store rejected duplicate")
            return
        }
        if (AutoBillOverlayService.instance?.offer(candidate) != true) {
            Log.e(TAG, "overlay offer failed")
            AutoBookkeepingLogStore.record(this, "overlay_failed", "offer returned false")
            AutoBookkeepingPendingStore.complete(this, remember = false)
            Diagnostics.error = "请返回自动记账设置开启后台运行和悬浮窗"
            return
        }
        lastPage = identity; lastWindow = windowId
        AutoBookkeepingBridge.call(this, "catalog", mapOf("merchant" to candidate.merchantNormalized)) { _, _ -> }
        Diagnostics.lastScene = "微信支付成功"
        Diagnostics.lastResult = "金额已识别 · 商户已脱敏"
        Log.i(TAG, "payment candidate offered")
        AutoBookkeepingLogStore.record(this, "overlay_offered", "payment candidate offered")
    }
    private var paymentActivity = false

    @Suppress("DEPRECATION")
    private fun detectCandidateFromVisibleWindows(): Pair<com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate, Int>? {
        val roots = mutableListOf<Pair<Int, AccessibilityNodeInfo>>()
        rootInActiveWindow?.let { roots.add(it.windowId to it) }
        runCatching { windows }.getOrDefault(emptyList()).forEach { window ->
            val root = runCatching { window.root }.getOrNull() ?: return@forEach
            if (root.packageName?.toString() !in SUPPORTED_PACKAGES) {
                root.recycle()
                return@forEach
            }
            if (roots.any { it.first == window.id }) {
                root.recycle()
            } else {
                roots.add(window.id to root)
            }
        }
        visibleWindowCount = roots.size
        return try {
            roots.firstNotNullOfOrNull { (windowId, root) ->
                if (root.packageName?.toString() !in SUPPORTED_PACKAGES) return@firstNotNullOfOrNull null
                val nodes = reader.read(root)
                detector.detect(root.packageName?.toString().orEmpty(), nodes)?.let { it to windowId }
            }
        } finally {
            roots.forEach { (_, root) -> root.recycle() }
        }
    }

    private fun retryScanIfNeeded() {
        if (!paymentActivity || rootRetryCount >= MAX_ROOT_RETRIES) {
            rootRetryCount = 0
            return
        }
        rootRetryCount += 1
        handler.postDelayed(scan, ROOT_RETRY_DELAY_MS)
    }

    private fun ensureOverlayService() {
        val enabled = AutoBookkeepingSettings.enabled(this)
        val overlayGranted = AutoBookkeepingOverlayPermission.isGranted(this)
        if (!enabled || !overlayGranted || AutoBillOverlayService.instance != null) {
            Log.i(TAG, "overlay start skipped: enabled=$enabled overlayGranted=$overlayGranted running=${AutoBillOverlayService.instance != null}")
            return
        }
        runCatching {
            ContextCompat.startForegroundService(this, Intent(this, AutoBillOverlayService::class.java))
            Log.i(TAG, "overlay foreground start requested")
        }.onFailure { error -> Log.e(TAG, "overlay foreground start failed", error) }
    }

    private fun debug(message: String) {
        val now = System.currentTimeMillis()
        if (now - lastDebugAt < 1000) return
        lastDebugAt = now
        Log.i(TAG, message)
        AutoBookkeepingLogStore.record(this, "scan", message)
    }

    override fun onInterrupt() { handler.removeCallbacks(scan); scheduled = false; Diagnostics.error = "无障碍服务已中断" }
    override fun onDestroy() { handler.removeCallbacksAndMessages(null); Diagnostics.accessibilityConnected = false; super.onDestroy() }

    private companion object {
        const val TAG = "AutoBookkeeping"
        const val PAYMENT_ACTIVITY_GRACE_MS = 5000L
        const val ROOT_RETRY_DELAY_MS = 200L
        const val MAX_ROOT_RETRIES = 10
        val SUPPORTED_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.unionpay",
            "com.sankuai.meituan",
            "com.sankuai.meituan.takeout",
            "com.jingdong.app.mall",
            "com.xunmeng.pinduoduo",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.mobile",
        )
    }
}
