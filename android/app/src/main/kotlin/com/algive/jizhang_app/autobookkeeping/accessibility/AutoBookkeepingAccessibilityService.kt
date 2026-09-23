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
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry

class AutoBookkeepingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val reader = AccessibilityTreeReader()

    // Rebuilt by [applyRulesAndWhitelist] whenever the user edits the custom app
    // list, so these cannot be `by lazy` caches.
    private var ruleRegistry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn()
    private var detector: PaymentSceneDetector = PaymentSceneDetector(ruleRegistry)

    /**
     * The whitelist declared in `autobookkeeping_accessibility_service.xml`,
     * captured on the first connect *before* any merge. Everything afterwards is
     * this set plus the user's own apps.
     */
    private var basePackages: Set<String> = emptySet()
    private var scheduled = false
    private var lastPage: String? = null
    private var lastWindow = -1
    private var absentSince = 0L
    private var lastDebugAt = 0L
    private var lastPaymentActivityAt = 0L
    private var rootRetryCount = 0
    private var visibleWindowCount = 0
    private var overlayWaits = 0
    override fun onServiceConnected() {
        Diagnostics.accessibilityConnected = true
        instance = this
        if (basePackages.isEmpty()) {
            basePackages = serviceInfo?.packageNames?.toSet().orEmpty()
        }
        applyRulesAndWhitelist()
        Diagnostics.ruleSchemaVersion = ruleRegistry.schemaVersion
        AutoBookkeepingPendingStore.cleanupOrphanedScreenshots(this)
        ensureOverlayService()
        AutoBookkeepingLogStore.record(
            this,
            "service_connected",
            "accessibility service connected rules=" +
                "${Diagnostics.ruleVersions} source=${Diagnostics.ruleSource} " +
                "packages=${basePackages.size + ruleRegistry.customPackages.size}",
        )
    }

    /**
     * Reload the packaged rules, fold in the user's custom apps, and hand the
     * merged package whitelist to the accessibility framework.
     *
     * The whitelist matters because the system only delivers events for packages
     * named in `serviceInfo.packageNames`: without this call a user-added app is
     * never watched, no matter what the rule registry says. Call it on connect
     * and after every edit of the custom list.
     */
    fun applyRulesAndWhitelist() {
        ruleRegistry = AutoBookkeepingRuleRegistry.load(this)
        detector = PaymentSceneDetector(ruleRegistry)

        val merged = basePackages + ruleRegistry.customPackages
        serviceInfo?.let { info ->
            if (merged.isNotEmpty()) {
                info.packageNames = merged.toTypedArray()
                serviceInfo = info
            }
        }

        Diagnostics.ruleVersions = ruleRegistry.versionsSummary()
        Diagnostics.ruleSource =
            (if (ruleRegistry.loadedFromAsset) "asset" else "built_in") +
                if (ruleRegistry.customPackages.isEmpty()) "" else "+custom"
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
        // The overlay is only the *presentation* channel. When it cannot run
        // (overlay permission refused, or the foreground status notification
        // suppressed) we still detect and persist the candidate and fall back to
        // a normal notification — previously the whole scan was skipped, so a
        // single missing permission silently disabled auto bookkeeping.
        if (AutoBillOverlayService.instance == null) {
            ensureOverlayService()
            val overlayCanStillStart =
                AutoBookkeepingOverlayPermission.isGranted(this) &&
                    AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
            if (AutoBillOverlayService.instance == null && overlayCanStillStart) {
                // The foreground service is starting asynchronously; give it a
                // bounded number of frames before falling back.
                if (overlayWaits < MAX_OVERLAY_WAITS) {
                    overlayWaits += 1
                    debug("waiting for overlay instance ($overlayWaits)")
                    handler.postDelayed(scan, 200)
                    return
                }
            }
            debug("overlay unavailable, using notification fallback")
        } else {
            overlayWaits = 0
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
                // On API 34+ capture only the paying app's window so the status
                // bar, our own overlay and the IME stay out of the evidence PNG.
                preferredWindowId = windowId,
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
            // Keep the candidate. The overlay is only the prompt; dropping it
            // here threw away a correctly parsed bill whenever the overlay
            // permission was missing. Flutter's confirmation page reads the
            // pending store, so a notification still gets the user there.
            Log.e(TAG, "overlay offer failed")
            AutoBookkeepingLogStore.record(this, "overlay_failed", "offer returned false")
            AutoBookkeepingNotificationController.notifyConfirmationAvailable(this)
            Diagnostics.error = "悬浮窗不可用，已改为通知提醒"
        } else {
            Diagnostics.error = ""
        }
        lastPage = identity
        lastWindow = windowId
        Diagnostics.lastScene = current.scene.scene
        Diagnostics.lastResult =
            "source=${current.sourceApp} amountConfidence=${current.amountConfidence} " +
                "merchantConfidence=${current.merchantConfidence}"
        Log.i(TAG, "payment candidate offered")
        AutoBookkeepingLogStore.record(this, "overlay_offered", "payment candidate offered")
    }

    /**
     * Manual trigger used by the Quick Settings tile and any in-app button.
     *
     * Unlike [onAccessibilityEvent] this deliberately ignores the payment-activity
     * gate: the user explicitly asked for a scan of whatever is on screen now.
     * It still goes through the same detector, so a non-payment screen simply
     * yields no candidate rather than a bogus one.
     */
    fun triggerManualCapture() {
        if (!AutoBookkeepingSettings.enabled(this)) {
            Diagnostics.error = "自动记账未开启"
            return
        }
        paymentActivity = true
        lastPaymentActivityAt = System.currentTimeMillis()
        lastPage = null
        overlayWaits = 0
        handler.removeCallbacks(scan)
        scheduled = true
        AutoBookkeepingLogStore.record(this, "manual_capture", "quick settings tile requested a scan")
        handler.post(scan)
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

    override fun onInterrupt() {
        handler.removeCallbacks(scan)
        scheduled = false
        Diagnostics.accessibilityConnected = false
        Diagnostics.error = "无障碍服务已中断"
        AutoBookkeepingLogStore.record(
            this,
            "service_interrupted",
            "accessibility service interrupted",
        )
    }
    override fun onDestroy() { handler.removeCallbacksAndMessages(null); Diagnostics.accessibilityConnected = false; instance = null; super.onDestroy() }

    companion object {
        private const val TAG = "AutoBookkeeping"
        private const val PAYMENT_ACTIVITY_GRACE_MS = 5000L
        private const val ROOT_RETRY_DELAY_MS = 200L
        private const val MAX_ROOT_RETRIES = 10

        /** How many 200 ms frames to wait for the overlay before falling back. */
        private const val MAX_OVERLAY_WAITS = 10

        /** The live service, or `null` while the user has it switched off. */
        @Volatile
        var instance: AutoBookkeepingAccessibilityService? = null
            private set

        /** Whether auto bookkeeping is actually able to run right now. */
        val isRunning: Boolean get() = instance != null
    }
}
