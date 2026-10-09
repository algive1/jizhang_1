package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.accessibility.PaymentWindow
import com.algive.jizhang_app.autobookkeeping.accessibility.PaymentWindowPolicy
import org.junit.Assert.assertEquals
import org.junit.Test

class PaymentWindowPolicyTest {
    private val own = "com.algive.jizhang_app"
    private val wechat = "com.tencent.mm"
    private fun front(windows: List<PaymentWindow>, active: String?, review: Boolean = false) =
        PaymentWindowPolicy.foregroundPackage(windows, active, own, review)

    @Test fun externalOverlayDoesNotHidePaymentApplication() {
        for (overlay in listOf("com.wangc.bill", "com.android.systemui", "keyboard")) {
            assertEquals(wechat, front(listOf(
                PaymentWindow(overlay, false, 20), PaymentWindow(wechat, true, 1),
            ), overlay))
        }
    }

    @Test fun realApplicationSwitchBlocksUnderlyingOldPayment() {
        assertEquals("browser", front(listOf(
            PaymentWindow(wechat, true, 1), PaymentWindow("browser", true, 10),
        ), "browser"))
    }

    @Test fun onlyVisibleConfirmationHostCanExposeUnderlyingPayment() {
        val windows = listOf(PaymentWindow(own, true, 10), PaymentWindow(wechat, true, 1))
        assertEquals(own, front(windows, own))
        assertEquals(wechat, front(windows, own, review = true))
    }

    @Test fun missingWindowMetadataUsesActivePackageWithoutGuessing() {
        assertEquals(wechat, front(emptyList(), wechat))
        assertEquals("com.android.systemui", front(emptyList(), "com.android.systemui"))
        assertEquals(null, front(emptyList(), null))
    }

    @Test fun unreadableForegroundApplicationCannotExposeBackgroundPayment() {
        assertEquals("", front(listOf(
            PaymentWindow("", true, 10), PaymentWindow(wechat, true, 1),
        ), null))
    }

    @Test fun laggingMetadataDuringAppSwitchCannotCreateAnOldBill() {
        assertEquals("browser", front(listOf(PaymentWindow(wechat, true, 1)), "browser"))
    }
}
