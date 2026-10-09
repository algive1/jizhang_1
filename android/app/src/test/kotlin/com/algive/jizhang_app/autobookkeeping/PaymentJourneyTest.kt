package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.accessibility.PaymentJourney
import com.algive.jizhang_app.autobookkeeping.dedup.PaymentInboxDedup
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import org.junit.Assert.*
import org.junit.Test

class PaymentJourneyTest {
    private val at = 1_800_000_000_000L
    private fun payment(source: String, amount: Long = 2500, offset: Long = 1000) = PaymentCandidate(
        amount, if (source == "WECHAT") "美团平台" else "测试餐厅", if (source == "WECHAT") "美团平台" else "测试餐厅",
        if (source == "WECHAT") "零钱" else "微信支付", at + offset,
        PaymentScene(source, if (source == "WECHAT") "QIANJI_WeChatPaySuccess" else "QIANJI_MeiTuanPaySuccess", 1.0),
        1.0, 1.0, source, orderId = "$source-ORDER",
    )
    private fun enter(journey: PaymentJourney) {
        journey.foreground("com.sankuai.meituan", at)
        journey.foreground("com.tencent.mm", at + 100)
    }

    @Test fun paymentAndMarketplaceReturnShareIdentityDespiteDifferentMerchantAndOrder() {
        val journey = PaymentJourney()
        enter(journey)
        val wechat = journey.associate(payment("WECHAT"), at + 1000)
        journey.foreground("com.algive.jizhang_app", at + 2000)
        journey.foreground("com.sankuai.meituan", at + 3000)
        val marketplace = journey.associate(payment("MEITUAN", offset = 3000), at + 3000)
        assertNotNull(wechat.paymentSessionId)
        assertEquals(wechat.paymentSessionId, marketplace.paymentSessionId)
        assertEquals(PaymentInboxDedup.Match.PAYMENT_SESSION, PaymentInboxDedup.match(wechat.toMap(), marketplace.toMap()))
        assertFalse(PaymentInboxDedup.handledKeys(wechat.toMap()).intersect(PaymentInboxDedup.handledKeys(marketplace.toMap())).isEmpty())
        assertNull(journey.associate(payment("MEITUAN").copy(orderId = "ANOTHER-ORDER"), at + 4000).paymentSessionId)
    }

    @Test fun unrelatedSameAmountPagesHaveNoPaymentSession() {
        val journey = PaymentJourney()
        journey.foreground("com.tencent.mm", at)
        assertNull(journey.associate(payment("WECHAT"), at + 1000).paymentSessionId)
        journey.foreground("com.sankuai.meituan", at + 3000)
        assertNull(journey.associate(payment("MEITUAN"), at + 3000).paymentSessionId)
        assertNull(PaymentInboxDedup.match(payment("WECHAT").toMap(), payment("MEITUAN").toMap()))
    }

    @Test fun differentAmountExpiredAndOldDetailsStaySeparate() {
        val journey = PaymentJourney()
        enter(journey)
        journey.associate(payment("WECHAT"), at + 1000)
        journey.foreground("com.sankuai.meituan", at + 3000)
        assertNull(journey.associate(payment("MEITUAN", amount = 2600), at + 3000).paymentSessionId)
        assertNull(journey.associate(payment("MEITUAN"), at + 130_000).paymentSessionId)
        val old = payment("MEITUAN", offset = -60_000).copy(transactionTimeKnown = true)
        assertNull(journey.associate(old, at + 3000).paymentSessionId)
    }

    @Test fun nextMarketplacePaymentStartsANewSession() {
        val journey = PaymentJourney()
        enter(journey)
        val first = journey.associate(payment("WECHAT"), at + 1000)
        journey.foreground("com.sankuai.meituan", at + 3000)
        journey.foreground("com.tencent.mm", at + 4000)
        val next = journey.associate(payment("WECHAT", offset = 5000), at + 5000)
        assertNotEquals(first.paymentSessionId, next.paymentSessionId)
        assertTrue(PaymentInboxDedup.handledKeys(first.toMap()).filter { it !in PaymentInboxDedup.handledKeys(next.toMap()) }.isNotEmpty())
    }

    @Test fun newWechatPaymentWithoutReturningToTheMarketplaceDoesNotReuseTheSession() {
        val journey = PaymentJourney()
        enter(journey)
        journey.associate(payment("WECHAT"), at + 1000)
        journey.foreground("com.tencent.mm", at + 4000, newPaymentPage = true)
        assertNull(journey.associate(payment("WECHAT", offset = 5000), at + 5000).paymentSessionId)
    }

    @Test fun anotherAppBreaksTheReturnChain() {
        val journey = PaymentJourney()
        enter(journey)
        journey.associate(payment("WECHAT"), at + 1000)
        journey.foreground("com.eg.android.AlipayGphone", at + 2000)
        journey.foreground("com.sankuai.meituan", at + 3000)
        assertNull(journey.associate(payment("MEITUAN"), at + 3000).paymentSessionId)
    }
}
