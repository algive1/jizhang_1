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
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics as Diagnostics
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingBridge
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry

class AutoBookkeepingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val reader = AccessibilityTreeReader()
    private val ruleRegistry by lazy {
        AutoBookkeepingRuleRegistry.load(this)
    }
    private val detector by lazy {
        PaymentSceneDetector(ruleRegistry)
    }
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
        Diagnostics.ruleSchemaVersion = ruleRegistry.schemaVersion
        Diagnostics.ruleVersions = ruleRegistry.versionsSummary()
        Diagnostics.ruleSource =
            if (ruleRegistry.loadedFromAsset) "asset" else "built_in"
        ensureOverlayService()
        AutoBookkeepingLogStore.record(
            this,
            "service_connected",
            "accessibility service connected rules=" +
                "${Diagnostics.ruleVersions} source=${Diagnostics.ruleSource}",
        )
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val actualEvent = event ?: return
        val eventPackage = actualEvent.packageName?.toString()
        val eventRule = eventPackage?.let(ruleRegistry::ruleFor)
        if (!AutoBookkeepingSettings.enabled(this) || eventRule == null) return
        if (actualEvent.eventType !in setOf(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, AccessibilityEvent.TYPE_WINDOWS_CHANGED)) return
        if (eventRule.sourceApp != "WECHAT") {
            // Marketplace/payment apps frequently update WebView/Compose content
            // without a stable Activity transition. Any relevant accessibility
            // event may therefore trigger a scan; parsers still require explicit
            // completed-payment evidence before accepting a candidate.
            paymentActivity = true
            lastPaymentActivityAt = System.currentTimeMillis()
        }
        if (actualEvent.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val activity = actualEvent.className?.toString().orEmpty()
            Log.i(TAG, "window event class=$activity")
            AutoBookkeepingLogStore.record(
                this,
                "window_event",
                "${eventPackage.orEmpty()}:${activity.substringAfterLast('.')}",
            )
            if (
                eventRule.sourceApp == "WECHAT" &&
                activity.startsWith("${eventPackage.orEmpty()}.")
            ) {
                val activityName = activity.substringAfterLast('.')
                val isPaymentActivity = eventRule.activityHints.any {
                    activityName.startsWith(it)
                }
                if (isPaymentActivity) {
                    paymentActivity = true
                    lastPaymentActivityAt = System.currentTimeMillis()
                } else if (System.currentTimeMillis() - lastPaymentActivityAt > PAYMENT_ACTIVITY_GRACE_MS) {
                    paymentActivity = false
                    lastPage = null
                }
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

        if (AutoBookkeepingSettings.screenshotEnabled(this)) {
            val fingerprint = BillFingerprint.of(candidate)
            AutoBookkeepingScreenshotCapture.capture(
                service = this,
                candidate = candidate,
                onCaptured = {
                    offerCandidate(candidate, identity, windowId)
                },
                onComplete = { path ->
                    if (path != null) {
                        AutoBookkeepingPendingStore.attachScreenshotIfCurrent(
                            this,
                            fingerprint,
                            path,
                        )
                    }
                },
            )
        } else {
            offerCandidate(candidate, identity, windowId)
        }
    }
    private fun offerCandidate(
        candidate: com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate,
        identity: String,
        windowId: Int,
    ) {
        val current = AutoBookkeepingPendingStore.readCandidate(this)
        if (
            current == null ||
            BillFingerprint.of(current) != BillFingerprint.of(candidate)
        ) {
            AutoBookkeepingLogStore.record(
                this,
                "overlay_skipped",
                "pending candidate changed before overlay",
            )
            return
        }

        if (AutoBillOverlayService.instance?.offer(current) != true) {
            Log.e(TAG, "overlay offer failed")
            AutoBookkeepingLogStore.record(this, "overlay_failed", "offer returned false")
            AutoBookkeepingPendingStore.complete(this, remember = false)
            Diagnostics.error = "请返回自动记账设置开启后台运行和悬浮窗"
            return
        }
        lastPage = identity
        lastWindow = windowId
        AutoBookkeepingBridge.call(
            this,
            "catalog",
            mapOf("merchant" to current.merchantNormalized),
        ) { _, _ -> }
        Diagnostics.lastScene = current.scene.scene
        Diagnostics.lastResult =
            "source=${current.sourceApp} amountConfidence=${current.amountConfidence} " +
                "merchantConfidence=${current.merchantConfidence}"
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
            if (ruleRegistry.ruleFor(root.packageName?.toString().orEmpty()) == null) {
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
                if (ruleRegistry.ruleFor(root.packageName?.toString().orEmpty()) == null) return@firstNotNullOfOrNull null
                val packageName = root.packageName?.toString().orEmpty()
                val snapshot = reader.readSnapshot(root)
                val result = detector.inspect(packageName, snapshot.nodes)
                if (result.candidate == null) {
                    debug(
                        "scan package=$packageName nodes=${snapshot.nodes.size} " +
                            "visited=${snapshot.visited} depth=${snapshot.maxDepth} " +
                            "truncated=${snapshot.truncated} reject=${result.rejectionReason}",
                    )
                    null
                } else {
                    result.candidate to windowId
                }
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
        val notificationAvailable =
            AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
        if (
            !enabled ||
            !overlayGranted ||
            !notificationAvailable ||
            AutoBillOverlayService.instance != null
        ) {
            Log.i(
                TAG,
                "overlay start skipped: enabled=$enabled overlayGranted=$overlayGranted " +
                    "notificationAvailable=$notificationAvailable " +
                    "running=${AutoBillOverlayService.instance != null}",
            )
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
    }
}
