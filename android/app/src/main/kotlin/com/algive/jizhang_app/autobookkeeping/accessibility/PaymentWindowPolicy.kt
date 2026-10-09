package com.algive.jizhang_app.autobookkeeping.accessibility

internal data class PaymentWindow(val packageName: String, val application: Boolean, val layer: Int)

internal object PaymentWindowPolicy {
    // System, keyboard and accessibility overlays do not replace the foreground app.
    // A real app switch does; never scan the old payment app behind it.
    fun foregroundPackage(
        windows: List<PaymentWindow>,
        activePackage: String?,
        ownPackage: String,
        reviewShowing: Boolean,
    ): String? {
        // Metadata can lag during an app switch. Do not treat a missing new window as an overlay.
        if (activePackage != null && !(reviewShowing && activePackage == ownPackage) &&
            windows.none { it.packageName == activePackage }) return activePackage
        return windows.asSequence()
            .filter { it.application && !(reviewShowing && it.packageName == ownPackage) }
            .maxByOrNull { it.layer }
            ?.packageName
            ?: activePackage?.takeUnless { reviewShowing && it == ownPackage }
    }
}
