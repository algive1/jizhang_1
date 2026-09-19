package com.algive.jizhang_app.autobookkeeping.accessibility

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.view.Display
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingLogStore
import com.algive.jizhang_app.autobookkeeping.dedup.BillFingerprint
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import java.io.File
import java.io.FileOutputStream

internal object AutoBookkeepingScreenshotCapture {
    fun capture(
        service: AccessibilityService,
        candidate: PaymentCandidate,
        onCaptured: () -> Unit,
        onComplete: (String?) -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            onCaptured()
            onComplete(null)
            return
        }
        captureApi30(service, candidate, onCaptured, onComplete)
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun captureApi30(
        service: AccessibilityService,
        candidate: PaymentCandidate,
        onCaptured: () -> Unit,
        onComplete: (String?) -> Unit,
    ) {
        service.takeScreenshot(
            Display.DEFAULT_DISPLAY,
            ContextCompat.getMainExecutor(service),
            object : AccessibilityService.TakeScreenshotCallback {
                override fun onSuccess(
                    screenshot: AccessibilityService.ScreenshotResult,
                ) {
                    val bitmap = runCatching {
                        val buffer = screenshot.hardwareBuffer
                        try {
                            val hardware = Bitmap.wrapHardwareBuffer(
                                buffer,
                                screenshot.colorSpace,
                            ) ?: error("Unable to wrap screenshot buffer")
                            try {
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

                    // The screen pixels have already been captured at this
                    // point, so the overlay may now be shown without ending
                    // up inside the payment screenshot.
                    onCaptured()

                    if (bitmap == null) {
                        onComplete(null)
                        return
                    }
                    Thread {
                        val path = runCatching {
                            save(service, candidate, bitmap)
                        }.onFailure { error ->
                            AutoBookkeepingLogStore.record(
                                service,
                                "screenshot_failed",
                                error.javaClass.simpleName,
                            )
                        }.getOrNull()
                        bitmap.recycle()
                        onComplete(path)
                    }.start()
                }

                override fun onFailure(errorCode: Int) {
                    AutoBookkeepingLogStore.record(
                        service,
                        "screenshot_failed",
                        "errorCode=$errorCode",
                    )
                    onCaptured()
                    onComplete(null)
                }
            },
        )
    }

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
