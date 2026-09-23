package com.algive.jizhang_app.autobookkeeping.accessibility

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.accessibility.AccessibilityWindowInfo
import androidx.annotation.RequiresApi
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Captures the payment screen through the accessibility service — no
 * MediaProjection consent dialog, no screen-sharing notice.
 *
 * The screenshot is **evidence, not recognition input**: detection already
 * happened on the notification text and the accessibility node tree, and the
 * PNG is attached to the pending candidate so the user can see what was parsed.
 *
 * Two improvements over the plain `takeScreenshot(Display.DEFAULT_DISPLAY)`:
 *
 *  * On API 34+ it targets the paying app's own window, so the status bar, this
 *    app's own confirmation overlay and the IME stay out of the frame.
 *  * Decoding runs on a private executor instead of the main thread; the
 *    callbacks are posted back to the main looper so callers keep the threading
 *    contract they had before.
 */
internal object AutoBookkeepingScreenshotCapture {

    private val captureExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "autobook-screenshot").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    /** The system throttles screenshot requests; retry once after this delay. */
    private const val THROTTLED_RETRY_DELAY_MS = 600L

    /** ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT */
    private const val ERROR_INTERVAL_TOO_SHORT = 3

    fun capture(
        service: AccessibilityService,
        candidate: PaymentCandidate,
        preferredWindowId: Int? = null,
        onCaptured: () -> Unit,
        onComplete: (String?) -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            onCaptured()
            onComplete(null)
            return
        }
        captureApi30(service, candidate, preferredWindowId, onCaptured, onComplete, attempt = 0)
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun captureApi30(
        service: AccessibilityService,
        candidate: PaymentCandidate,
        preferredWindowId: Int?,
        onCaptured: () -> Unit,
        onComplete: (String?) -> Unit,
        attempt: Int,
    ) {
        val callback = object : AccessibilityService.TakeScreenshotCallback {
            override fun onSuccess(
                screenshot: AccessibilityService.ScreenshotResult,
            ) {
                val bitmap = decode(screenshot, service)

                // The pixels are already captured, so the overlay may be shown
                // now without ending up inside its own screenshot.
                mainHandler.post { onCaptured() }

                if (bitmap == null) {
                    mainHandler.post { onComplete(null) }
                    return
                }
                captureExecutor.execute {
                    val path = runCatching { save(service, candidate, bitmap) }
                        .onFailure { error ->
                            AutoBookkeepingLogStore.record(
                                service,
                                "screenshot_failed",
                                error.javaClass.simpleName,
                            )
                        }
                        .getOrNull()
                    bitmap.recycle()
                    mainHandler.post { onComplete(path) }
                }
            }

            override fun onFailure(errorCode: Int) {
                AutoBookkeepingLogStore.record(
                    service,
                    "screenshot_failed",
                    "errorCode=$errorCode",
                )
                // The system rate-limits captures; one delayed retry recovers
                // the common "two payments in quick succession" case.
                if (errorCode == ERROR_INTERVAL_TOO_SHORT && attempt == 0) {
                    mainHandler.postDelayed(
                        {
                            captureApi30(
                                service,
                                candidate,
                                preferredWindowId,
                                onCaptured,
                                onComplete,
                                attempt = 1,
                            )
                        },
                        THROTTLED_RETRY_DELAY_MS,
                    )
                    return
                }
                mainHandler.post {
                    onCaptured()
                    onComplete(null)
                }
            }
        }

        val windowId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            preferredWindowId?.takeIf { it >= 0 } ?: findPayingWindowId(service)
        } else {
            -1
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && windowId >= 0) {
                service.takeScreenshotOfWindow(windowId, captureExecutor, callback)
            } else {
                service.takeScreenshot(Display.DEFAULT_DISPLAY, captureExecutor, callback)
            }
        } catch (error: Throwable) {
            AutoBookkeepingLogStore.record(
                service,
                "screenshot_failed",
                error.javaClass.simpleName,
            )
            mainHandler.post {
                onCaptured()
                onComplete(null)
            }
        }
    }

    /** The topmost active application window, i.e. the app the user is paying in. */
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun findPayingWindowId(service: AccessibilityService): Int {
        val windows = runCatching { service.windows }.getOrNull().orEmpty()
        return windows.firstOrNull {
            it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isActive
        }?.id ?: windows.firstOrNull {
            it.type == AccessibilityWindowInfo.TYPE_APPLICATION
        }?.id ?: -1
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun decode(
        screenshot: AccessibilityService.ScreenshotResult,
        service: AccessibilityService,
    ): Bitmap? = runCatching {
        val buffer = screenshot.hardwareBuffer
        try {
            val hardware = Bitmap.wrapHardwareBuffer(buffer, screenshot.colorSpace)
                ?: error("Unable to wrap screenshot buffer")
            try {
                // `copy` also normalises the hardware buffer's row stride, which
                // a raw buffer read would have to strip by hand.
                hardware.copy(Bitmap.Config.ARGB_8888, false)
            } finally {
                hardware.recycle()
            }
        } finally {
            buffer.close()
        }
    }.onFailure { error ->
        AutoBookkeepingLogStore.record(
            service,
            "screenshot_failed",
            error.javaClass.simpleName,
        )
    }.getOrNull()

    private fun save(
        service: AccessibilityService,
        candidate: PaymentCandidate,
        bitmap: Bitmap,
    ): String {
        val directory = File(
            service.filesDir,
            "autobookkeeping/pending_screenshots",
        )
        if (!directory.exists() && !directory.mkdirs()) {
            error("Unable to create screenshot directory")
        }
        purgeExpiredPending(directory)
        val fingerprint = BillFingerprint.of(candidate).take(16)
        val file = File(
            directory,
            "payment-${candidate.timestamp}-$fingerprint.png",
        )
        FileOutputStream(file).use { output ->
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                error("Unable to encode screenshot")
            }
        }
        AutoBookkeepingLogStore.record(
            service,
            "screenshot_captured",
            "local payment screenshot stored",
        )
        return file.absolutePath
    }

    private fun purgeExpiredPending(directory: File) {
        val cutoff = System.currentTimeMillis() - PENDING_FILE_TTL_MILLIS
        directory.listFiles()
            ?.filter { it.isFile && it.lastModified() < cutoff }
            ?.forEach { runCatching { it.delete() } }
    }

    private const val PENDING_FILE_TTL_MILLIS = 24 * 60 * 60 * 1000L
}
