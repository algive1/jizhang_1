package com.algive.jizhang_app.autobookkeeping.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import com.algive.jizhang_app.autobookkeeping.AppNotice
import androidx.core.content.ContextCompat
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingNotificationController
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingSettings
import com.algive.jizhang_app.PaymentNotificationListenerService
import com.algive.jizhang_app.autobookkeeping.BookkeepingChangeBus
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics as Diagnostics
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.parser.QianjiPageCatalog
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.repository.PendingEnqueueDecision
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry

class AutoBookkeepingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val reader = AccessibilityTreeReader()
    private val detectionThread = HandlerThread("PaymentPageReader").apply { start() }
    private val detectionHandler = Handler(detectionThread.looper)
    private var readingPage = false
    private var scanAgain = false
    @Volatile private var destroyed = false

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
    private val scanThrottle = ScanThrottle()
    private val scheduled get() = scanThrottle.pending
    private var lastPage: String? = null
    private var lastWindow = -1
    private var offeredFingerprint: String? = null
    private var enrichUntil = 0L
    private val enrichScan = Runnable {
        if (AutoBookkeepingSettings.enabled(this)) {
            detectionHandler.post {
                val detected = runCatching { detectCandidateFromVisibleWindows() }.getOrNull()
                handler.post {
                    if (destroyed || !AutoBookkeepingSettings.enabled(this)) return@post
                    detected?.let { (candidate, windowId, _) ->
                        if (pageIdentity(candidate) == lastPage && windowId == lastWindow) enrichNote(candidate)
                    }
                }
            }
        }
    }
    private var absentSince = 0L
    private var lastDebugAt = 0L
    private var lastEventLogAt = 0L
    private var lastRejectedSnapshotAt = 0L
    private var lastFeedbackAt = 0L
    private var lastFeedbackKey: String? = null
    private var lastPaymentActivityAt = 0L
    private var lastActivityPackage: String? = null
    private val paymentJourney = PaymentJourney()
    private var lastActivityClassName: String? = null
    private var rootRetryCount = 0
    private var visibleWindowCount = 0
    private var lastWindowSummary = ""
    private val completionGate = PaymentCompletionGate()
    var completionClickedAt = 0L; private set

    fun waitForPaymentCompletion(candidate: com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate): Boolean {
        val deferred = completionGate.defer(candidate.sourceApp, candidate.transactionType, candidate.scene.scene)
        if (deferred) AutoBookkeepingLogStore.record(this, "payment_waiting_complete", "source=WECHAT shown=false")
        return deferred
    }

    private fun handleCompleteClick(event: AccessibilityEvent) {
        val source = runCatching { event.source }.getOrNull()
        val labels = event.text.map { it.toString() } + listOfNotNull(source?.text?.toString(), source?.contentDescription?.toString())
        source?.recycle()
        if (labels.none { completionGate.complete(event.packageName?.toString(), it) }) return
        completionClickedAt = SystemClock.elapsedRealtime()
        AutoBookkeepingLogStore.record(this, "payment_complete_clicked", "clickedAt=$completionClickedAt eventDelayMs=${SystemClock.uptimeMillis() - event.eventTime}")
        handler.postDelayed({
            val heldResult = completionGate.heldResult
            completionGate.release()
            if (destroyed || !AutoBookkeepingSettings.enabled(this)) return@postDelayed
            val candidate = AutoBookkeepingPendingStore.readCandidate(this)
            if (!heldResult || candidate == null || candidate.sourceApp != "WECHAT") {
                AutoBookkeepingLogStore.record(this, "payment_review_missing", "shown=false reason=no_waiting_payment")
                return@postDelayed
            }
            AutoBookkeepingLogStore.record(this, "payment_review_after_complete", "sinceCompleteMs=${SystemClock.elapsedRealtime() - completionClickedAt}")
            if (AutoBillOverlayService.instance?.offer(candidate) != true) ensureOverlayService()
        }, 200)
    }
    override fun onServiceConnected() {
        Diagnostics.accessibilityConnected = true
        instance = this
        if (basePackages.isEmpty()) {
            basePackages = serviceInfo?.packageNames?.toSet().orEmpty()
        }
        applyRulesAndWhitelist()
        Diagnostics.ruleSchemaVersion = ruleRegistry.schemaVersion
        Thread(
            {
                AutoBookkeepingPendingStore.cleanupOrphanedScreenshots(
                    applicationContext,
                )
            },
            "AutoBookkeepingCleanup",
        ).start()
        ensureOverlayService()
        PaymentNotificationListenerService.ensureConnected(this)
        AutoBookkeepingLogStore.record(
            this,
            "service_connected",
            "accessibility service connected rules=" +
                "${Diagnostics.ruleVersions} source=${Diagnostics.ruleSource} " +
                "packages=${basePackages.size + ruleRegistry.customPackages.size}",
        )
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "accessibility_service_connected",
            "rules=${Diagnostics.ruleVersions} source=${Diagnostics.ruleSource} " +
                "packages=${basePackages + ruleRegistry.customPackages}",
        )
        // Rebinding can happen while a payment result is already stationary;
        // waiting for another content-change event would leave that page unread.
        if (AutoBookkeepingSettings.enabled(this)) {
            paymentActivity = true
            rootRetryCount = 0
            handler.removeCallbacks(scan)
            scanThrottle.consumed()
            scheduleScan(40)
        }
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
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "accessibility_rules_applied",
            "packages=${merged.sorted()} rules=${Diagnostics.ruleVersions} source=${Diagnostics.ruleSource}",
        )
    }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val actualEvent = event ?: return
        val eventPackage = actualEvent.packageName?.toString()
        val eventRule = eventPackage?.let(ruleRegistry::ruleFor)
        val enabled = AutoBookkeepingSettings.enabled(this)
        val now = System.currentTimeMillis()
        if (eventRule != null && now - lastEventLogAt >= EVENT_LOG_INTERVAL_MS) {
            lastEventLogAt = now
            val delay = (SystemClock.uptimeMillis() - actualEvent.eventTime).coerceAtLeast(0)
            if (enabled && delay >= 500) {
                AutoBookkeepingLogStore.record(this, "accessibility_event_delayed", "package=$eventPackage delayMs=$delay")
            }
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "accessibility_event",
                "package=$eventPackage type=${AccessibilityEvent.eventTypeToString(actualEvent.eventType)} " +
                    "class=${actualEvent.className} eventTime=${actualEvent.eventTime} " +
                    "window=${actualEvent.windowId} changeTypes=${actualEvent.contentChangeTypes} " +
                    "enabled=$enabled rule=${eventRule.sourceApp} text=${actualEvent.text.joinToString(" ")}",
            )
        }
        if (!enabled) return
        if (actualEvent.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            if (eventPackage == "com.tencent.mm") handleCompleteClick(actualEvent)
            return
        }
        // Overlay removal can reveal a stationary payment page without a new app event.
        if (eventRule == null) {
            if (actualEvent.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED && paymentActivity && !scheduled) {
                rootRetryCount = 0
                scheduleScan(40)
            }
            return
        }
        when (actualEvent.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> Unit
            else -> return
        }
        if (eventRule.sourceApp != "WECHAT" || eventPackage in QianjiPageCatalog.pageTypesByPackage) {
            // Qianji covers WeChat detail, transfer and red-packet pages outside
            // the narrow legacy payment Activity hints. Each page recognizer
            // still decides whether its ordered parser can produce a candidate.
            paymentActivity = true
            lastPaymentActivityAt = System.currentTimeMillis()
        }
        if (actualEvent.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val activity = actualEvent.className?.toString().orEmpty()
            if (eventPackage == "com.tencent.mm") {
                if (activity.endsWith(".UIPageFragmentActivity")) {
                    if (!completionGate.waiting) completionClickedAt = 0L
                    completionGate.begin()
                } else if (activity.endsWith(".LauncherUI") || activity.endsWith(".RemittanceBusiUI") ||
                    activity.endsWith(".MMWebViewUI") || activity.endsWith(".BaseScanUI")) {
                    if (completionGate.waiting && !completionGate.clicked) {
                        if (completionGate.heldResult) {
                            AutoBookkeepingPendingStore.deferCurrent(this)
                            AutoBookkeepingNotificationController.notifyConfirmationAvailable(this, showToast = false)
                            AutoBookkeepingLogStore.record(this, "payment_complete_not_observed", "shown=false retained in inbox")
                        }
                        completionGate.release()
                    }
                }
            }
            // Window-state callbacks also arrive for framework/custom views
            // (for example android.widget.LinearLayout). Keep only a class from
            // the emitting app so an incidental child view cannot fail an
            // Activity-level profile gate such as UnionPay's main-page exclusion.
            val appActivity = activity.startsWith("${eventPackage.orEmpty()}.") ||
                (eventRule.sourceApp == "ALIPAY" && activity.startsWith("com.alipay.")) ||
                (eventRule.sourceApp == "MEITUAN" &&
                    (activity.startsWith("com.meituan.") || activity.startsWith("com.sankuai.")))
            val activityChanged =
                appActivity &&
                    (lastActivityPackage != eventPackage ||
                        lastActivityClassName != activity)
            if (appActivity) {
                paymentJourney.foreground(eventPackage.orEmpty(), System.currentTimeMillis(),
                    activityChanged && activity.endsWith(".UIPageFragmentActivity"))
                lastActivityPackage = eventPackage
                lastActivityClassName = activity
            }
            if (activityChanged) {
                Log.i(TAG, "window event class=$activity")
                AutoBookkeepingLogStore.record(
                    this,
                    "window_event",
                    "${eventPackage.orEmpty()}:${activity.substringAfterLast('.')}",
                )
            }
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
                } else if (
                    eventPackage !in QianjiPageCatalog.pageTypesByPackage &&
                    System.currentTimeMillis() - lastPaymentActivityAt > PAYMENT_ACTIVITY_GRACE_MS
                ) {
                    paymentActivity = false
                    lastPage = null
                }
            }
        }
        Diagnostics.lastEventAt = System.currentTimeMillis()
        // Leading-edge coalescing: refreshes cannot postpone this 40 ms read.
        scheduleScan(40)
    }
    private fun scheduleScan(delay: Long) {
        if (readingPage) { scanAgain = true; return }
        if (scanThrottle.request()) handler.postDelayed(scan, delay)
    }
    private val scan = Runnable { scanThrottle.consumed(); scanPage() }
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
            debug("overlay unavailable, using notification fallback")
        }
        if (!paymentActivity) {
            debug("scan blocked paymentActivity=false")
            return
        }
        readingPage = true
        detectionHandler.post {
            val detected = runCatching { detectCandidateFromVisibleWindows() }
                .onFailure { debug("window read failed: ${it.javaClass.simpleName}") }.getOrNull()
            handler.post {
                readingPage = false
                if (destroyed) return@post
                if (AutoBookkeepingSettings.enabled(this@AutoBookkeepingAccessibilityService)) {
                    processDetectedPage(detected)
                    if (scanAgain) { scanAgain = false; scheduleScan(40) }
                }
            }
        }
    }

    private fun processDetectedPage(detected: Triple<com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate, Int, String?>?) {
        if (detected == null) {
            debug("scan windows=$visibleWindowCount candidate=false")
            // Our confirmation Activity temporarily covers the payment page.
            // Do not treat that as leaving the page, otherwise returning after
            // Save creates a fresh timestamp and reopens the same transaction.
            if (AutoBillOverlayService.instance?.isShowing != true) {
                if (absentSince == 0L) absentSince = System.currentTimeMillis()
                if (System.currentTimeMillis() - absentSince > 1500) lastPage = null
            }
            retryScanIfNeeded()
            return
        }
        rootRetryCount = 0
        absentSince = 0
        val candidate = paymentJourney.associate(detected.first, System.currentTimeMillis())
        val windowId = detected.second
        val matchedPageType = detected.third
        if (matchedPageType == "WeChatPaySuccess" && completionClickedAt == 0L) completionGate.begin()
        debug("scan windows=$visibleWindowCount candidate=true")
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "candidate_detected_detail",
            candidate.toMap().toString(),
        )
        val identity = pageIdentity(candidate)
        AutoBookkeepingLogStore.record(this, "candidate_detected", "page=${matchedPageType ?: candidate.scene.scene} window=$windowId")
        if (identity == lastPage && windowId == lastWindow) {
            AutoBookkeepingLogStore.record(this, "deduplicated", "same page and fingerprint")
            enrichNote(candidate)
            return
        }
        val enqueueDecision = AutoBookkeepingPendingStore.enqueueDecision(this, candidate)
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "candidate_enqueue_decision",
            "decision=$enqueueDecision candidate=${candidate.toMap()}",
        )
        if (enqueueDecision != PendingEnqueueDecision.ACCEPTED) {
            AutoBookkeepingLogStore.record(this, "deduplicated", "pending store: $enqueueDecision")
            when (enqueueDecision) {
                PendingEnqueueDecision.DUPLICATE -> notifyDetectionFeedback(
                    key = "duplicate:$identity",
                    message = "本页面已经记录过了",
                )
                PendingEnqueueDecision.BUSY -> notifyDetectionFeedback(
                    key = "busy:" + matchedPageType.orEmpty(),
                    message = "已命中页面 · 已有一笔待确认记录",
                )
                PendingEnqueueDecision.ACCEPTED -> Unit
                PendingEnqueueDecision.QUEUED -> {
                    BookkeepingChangeBus.publish(this)
                    lastPage = identity
                    lastWindow = windowId
                    AutoBookkeepingNotificationController.notifyConfirmationAvailable(this, showToast = false)
                    notifyDetectionFeedback("queued:$identity", "已识别到新账单 · 已保留待确认")
                }
            }
            return
        }

        BookkeepingChangeBus.publish(this)

        if (AutoBookkeepingSettings.screenshotEnabled(this)) {
            val fingerprint = AutoBookkeepingPendingStore.read(this)?.get("fingerprint") as? String
                ?: BillFingerprint.of(candidate)
            // The Flutter confirmation surface does not display the evidence image.
            // Start it first; save the screenshot asynchronously afterward.
            offerCandidate(candidate, identity, windowId)
            AutoBookkeepingScreenshotCapture.capture(
                service = this,
                candidate = candidate,
                // On API 34+ capture only the paying app's window so the status
                // bar, our own overlay and the IME stay out of the evidence PNG.
                preferredWindowId = windowId,
                onCaptured = {},
                onComplete = { path ->
                    if (path != null) {
                        val attached = AutoBookkeepingPendingStore.attachScreenshotIfCurrent(
                            this,
                            fingerprint,
                            path,
                        )
                        AutoBookkeepingLogStore.recordDetailed(
                            this,
                            "screenshot_attached",
                            "path=$path attached=$attached",
                        )
                    } else {
                        AutoBookkeepingLogStore.recordDetailed(
                            this,
                            "screenshot_missing",
                            "candidate=${candidate.toMap()}",
                        )
                    }
                },
            )
        } else {
            offerCandidate(candidate, identity, windowId)
        }
    }
    private fun pageIdentity(candidate: com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate): String =
        if (!candidate.orderId.isNullOrBlank()) BillFingerprint.of(candidate)
        else BillFingerprint.hash(BillFingerprint.identity(candidate))

    private fun enrichNote(candidate: com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate) {
        if (android.os.SystemClock.elapsedRealtime() > enrichUntil) return
        val fingerprint = offeredFingerprint ?: return
        val note = candidate.note?.takeIf { it.isNotBlank() } ?: return
        if (AutoBookkeepingPendingStore.enrichNoteIfCurrent(this, fingerprint, note)) {
            AutoBillOverlayService.instance?.enrichNote(fingerprint, note)
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
            AutoBookkeepingLogStore.recordDetailed(
                this,
                "overlay_skipped_detail",
                "offered=${candidate.toMap()} current=${current?.toMap()}",
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
        offeredFingerprint = BillFingerprint.of(current)
        enrichUntil = android.os.SystemClock.elapsedRealtime() + 1200
        handler.removeCallbacks(enrichScan)
        handler.postDelayed(enrichScan, 350)
        handler.postDelayed(enrichScan, 1000)
        Diagnostics.lastScene = current.scene.scene
        Diagnostics.lastResult =
            "source=${current.sourceApp} amountConfidence=${current.amountConfidence} " +
                "merchantConfidence=${current.merchantConfidence}"
        Log.i(TAG, "payment candidate offered")
        AutoBookkeepingLogStore.record(this, "overlay_offered", "payment candidate offered")
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "overlay_offer_result",
            "shown=${AutoBillOverlayService.instance?.isShowing == true} candidate=${current.toMap()}",
        )
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
            AutoBookkeepingLogStore.recordDetailed(this, "manual_capture_ignored", "reason=disabled")
            return
        }
        paymentActivity = true
        lastPaymentActivityAt = System.currentTimeMillis()
        lastPage = null
        lastActivityPackage = null
        lastActivityClassName = null
        rootRetryCount = 0
        handler.removeCallbacks(scan)
        handler.removeCallbacks(enrichScan)
        scanThrottle.consumed()
        AutoBookkeepingLogStore.record(this, "manual_capture", "quick settings tile requested a scan")
        AutoBookkeepingLogStore.recordDetailed(this, "manual_capture", "source=quick_settings_tile")
        scheduleScan(0)
    }

    private var paymentActivity = false

    @Suppress("DEPRECATION")
    private fun detectCandidateFromVisibleWindows(): Triple<com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate, Int, String?>? {
        val roots = mutableListOf<Pair<Int, AccessibilityNodeInfo>>()
        rootInActiveWindow?.let { roots.add(it.windowId to it) }
        val activePackage = roots.firstOrNull()?.second?.packageName?.toString()
        val interactiveWindows = runCatching { windows }.getOrDefault(emptyList())
        val windowStates = mutableListOf<PaymentWindow>()
        return try {
            interactiveWindows.forEach { window ->
                val root = runCatching { window.root }.getOrNull()
                val rootPackage = root?.packageName?.toString()
                    ?: activePackage?.takeIf { roots.firstOrNull()?.first == window.id }.orEmpty()
                windowStates.add(PaymentWindow(rootPackage, window.type == AccessibilityWindowInfo.TYPE_APPLICATION, window.layer))
                if (root == null) return@forEach
                if (ruleRegistry.ruleFor(rootPackage) == null) {
                    root.recycle()
                    return@forEach
                }
                if (roots.any { it.first == window.id }) {
                    root.recycle()
                } else {
                    roots.add(window.id to root)
                }
            }
            val foregroundPackage = PaymentWindowPolicy.foregroundPackage(
                windowStates, activePackage, packageName, AutoBillOverlayService.instance?.isShowing == true,
            )
            val summary = "active=$activePackage foreground=$foregroundPackage windows=" +
                windowStates.joinToString(",") { "${it.packageName}:${if (it.application) "app" else "overlay"}:${it.layer}" }
            if (summary != lastWindowSummary) {
                lastWindowSummary = summary
                AutoBookkeepingLogStore.record(this, "scan_windows", summary)
            }
            val eligibleRoots = roots.filter { it.second.packageName?.toString() == foregroundPackage }
            visibleWindowCount = eligibleRoots.size
            if (ruleRegistry.ruleFor(foregroundPackage.orEmpty()) == null) {
                debug("scan blocked foreground=$foregroundPackage active=$activePackage windows=${windowStates.size}")
                return null
            }
            if (roots.none { ruleRegistry.ruleFor(it.second.packageName?.toString().orEmpty()) != null }) {
                debug(
                    "no supported root: roots=${roots.size} windows=${interactiveWindows.size} " +
                        "packages=${roots.map { it.second.packageName }.distinct().joinToString(",")} " +
                        "flags=${serviceInfo?.flags}",
                )
            }
            eligibleRoots.firstNotNullOfOrNull { (windowId, root) ->
                if (ruleRegistry.ruleFor(root.packageName?.toString().orEmpty()) == null) return@firstNotNullOfOrNull null
                val packageName = root.packageName?.toString().orEmpty()
                val snapshot = reader.readSnapshot(root)
                val activityClassName = lastActivityClassName
                    ?.takeIf { lastActivityPackage == packageName }
                val result = detector.inspect(
                    packageName = packageName,
                    nodes = snapshot.nodes,
                    activityClassName = activityClassName,
                )
                if (result.candidate == null) {
                    if (result.matchedPage) {
                        notifyDetectionFeedback(
                            key = "matched:" + result.pageType + ":" + result.rejectionReason,
                            message = "已命中页面 · 未识别到可记账交易",
                        )
                    }
                    val now = System.currentTimeMillis()
                    if (now - lastRejectedSnapshotAt >= REJECTED_SNAPSHOT_INTERVAL_MS) {
                        lastRejectedSnapshotAt = now
                        AutoBookkeepingLogStore.recordDetailed(
                            this,
                            "page_rejected_snapshot",
                            "package=$packageName reason=${result.rejectionReason} " +
                                "labels=${snapshot.nodes.map { it.label }.filter { it.isNotBlank() }.joinToString(" | ")}",
                        )
                    }
                    debug(
                        "pkg=$packageName page=${result.pageType} reject=${result.rejectionReason} " +
                            "n=${snapshot.nodes.size} readMs=${snapshot.elapsedMs} cut=${snapshot.truncationReason} " +
                            "visited=${snapshot.visited} depth=${snapshot.maxDepth}",
                    )
                    null
                } else {
                    Triple(result.candidate, windowId, result.pageType)
                }
            }
        } finally {
            roots.forEach { (_, root) -> root.recycle() }
            interactiveWindows.forEach { it.recycle() }
        }
    }

    private fun notifyDetectionFeedback(key: String, message: String) {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            handler.post { notifyDetectionFeedback(key, message) }
            return
        }
        val now = System.currentTimeMillis()
        if (key == lastFeedbackKey && now - lastFeedbackAt < DETECTION_FEEDBACK_DEDUP_MS) {
            return
        }
        lastFeedbackKey = key
        lastFeedbackAt = now
        val overlay = AutoBillOverlayService.instance
        if (overlay != null) {
            overlay.showDetectionFeedback(message)
        } else {
            AppNotice.show(this, message)
        }
        AutoBookkeepingLogStore.recordDetailed(
            this,
            "page_match_feedback",
            "key=$key message=$message",
        )
    }

    private fun retryScanIfNeeded() {
        if (!paymentActivity || rootRetryCount >= MAX_ROOT_RETRIES) {
            rootRetryCount = 0
            return
        }
        rootRetryCount += 1
        scheduleScan(ROOT_RETRY_DELAY_MS)
    }

    private fun ensureOverlayService() {
        val enabled = AutoBookkeepingSettings.enabled(this)
        val notificationAvailable =
            AutoBookkeepingNotificationController.statusNotificationsAvailable(this)
        if (
            !enabled ||
            !notificationAvailable ||
            AutoBillOverlayService.instance != null
        ) {
            Log.i(
                TAG,
                "overlay start skipped: enabled=$enabled " +
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
        AutoBookkeepingLogStore.recordDetailed(this, "scan_trace", message)
        Log.i(TAG, message)
        AutoBookkeepingLogStore.record(this, "scan", message)
    }

    override fun onInterrupt() {
        // This callback interrupts feedback; the system binding remains connected.
        AutoBookkeepingLogStore.record(
            this,
            "service_interrupted",
            "accessibility feedback interrupted; service remains connected",
        )
    }
    override fun onUnbind(intent: Intent?): Boolean {
        handler.removeCallbacks(scan)
        handler.removeCallbacks(enrichScan)
        scanThrottle.consumed()
        Diagnostics.accessibilityConnected = false
        if (instance === this) instance = null
        AutoBookkeepingLogStore.record(this, "service_disconnected", "accessibility service unbound")
        return super.onUnbind(intent)
    }
    override fun onDestroy() {
        destroyed = true
        AutoBookkeepingLogStore.recordDetailed(this, "accessibility_service_destroyed", "service destroyed")
        handler.removeCallbacksAndMessages(null)
        detectionThread.quitSafely()
        Diagnostics.accessibilityConnected = false
        instance = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AutoBookkeeping"
        private const val PAYMENT_ACTIVITY_GRACE_MS = 5000L
        private const val ROOT_RETRY_DELAY_MS = 120L
        private const val EVENT_LOG_INTERVAL_MS = 500L
        private const val REJECTED_SNAPSHOT_INTERVAL_MS = 1_000L
        private const val DETECTION_FEEDBACK_DEDUP_MS = 1_500L
        private const val MAX_ROOT_RETRIES = 10

        /** The live service, or `null` while the user has it switched off. */
        @Volatile
        var instance: AutoBookkeepingAccessibilityService? = null
            private set

        /** Whether auto bookkeeping is actually able to run right now. */
        val isRunning: Boolean get() = instance != null
    }
}
