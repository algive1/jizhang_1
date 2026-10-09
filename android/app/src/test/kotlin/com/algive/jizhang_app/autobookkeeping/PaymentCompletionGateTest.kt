package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.accessibility.PaymentCompletionGate
import org.junit.Assert.*
import org.junit.Test

class PaymentCompletionGateTest {
    @Test fun successPageAndNotificationBothWaitForComplete() {
        val gate = PaymentCompletionGate()
        gate.begin()
        assertTrue(gate.defer("WECHAT", "EXPENSE", "QIANJI_WeChatPaySuccess"))
        assertTrue(gate.heldResult)
        assertTrue(gate.complete("com.tencent.mm", "完成"))
        // A notification arriving during the exit animation must still wait.
        assertTrue(gate.defer("WECHAT", "EXPENSE", "PAYMENT_NOTIFICATION_WECHAT"))
        gate.release()
        assertFalse(gate.defer("WECHAT", "EXPENSE"))
    }
    @Test fun unrelatedCompleteButtonsCannotTriggerPaymentReview() {
        val gate = PaymentCompletionGate()
        assertFalse(gate.complete("com.tencent.mm", "完成"))
        gate.begin()
        // A password/keypad Complete before a payment result is not the trigger.
        assertFalse(gate.complete("com.tencent.mm", "完成"))
        gate.defer("WECHAT", "EXPENSE")
        assertFalse(gate.complete("another.app", "完成"))
        assertFalse(gate.complete("com.tencent.mm", "取消"))
        assertTrue(gate.complete("com.tencent.mm", "完成"))
        assertFalse(gate.complete("com.tencent.mm", "完成"))
    }
    @Test fun otherAppsAndWechatIncomeKeepTheirExistingTrigger() {
        val gate = PaymentCompletionGate()
        gate.begin()
        assertFalse(gate.defer("ALIPAY", "EXPENSE"))
        assertFalse(gate.defer("WECHAT", "INCOME"))
        assertFalse(gate.defer("WECHAT", "EXPENSE", "QIANJI_WeChatBillDetail"))
        assertFalse(gate.heldResult)
    }
    @Test fun leavingWithoutCompleteResetsNextPayment() {
        val gate = PaymentCompletionGate()
        gate.begin()
        gate.defer("WECHAT", "EXPENSE")
        assertFalse(gate.clicked)
        gate.release()
        gate.begin()
        assertTrue(gate.defer("WECHAT", "EXPENSE"))
        assertTrue(gate.complete("com.tencent.mm", "完成"))
    }
}
