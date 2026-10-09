package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.dedup.PaymentInboxDedup as Dedup
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.QianjiPageSupport
import org.junit.Assert.*
import org.junit.Test

class PaymentInboxDedupTest {
    private val at = 1_800_000_000_000L
    private fun payment(scene: String = "QIANJI_WeChatPaySuccess", time: Long = at + 321,
                        order: String = "", known: Boolean = false, method: String = "UNKNOWN") = mapOf<String, Any>(
        "fingerprint" to "$scene:$time:$order:$method", "created_at" to time,
        "sourceApp" to "WECHAT", "transactionType" to "EXPENSE", "amountInCents" to 18L,
        "merchant" to "测试商户", "paymentMethod" to method, "timestamp" to time,
        "scene" to scene, "orderId" to order, "transactionTimeKnown" to known, "status" to "pending",
    )
    private fun detail(order: String = "ORDER-1", time: Long = at) =
        payment("QIANJI_WeChatBillDetail", time, order, true, "零钱") + ("created_at" to at + 20_000)

    @Test fun successThenDetailWithOrderKeepsOnePayment() {
        val success = payment()
        val bill = detail()
        assertEquals(Dedup.Match.SUCCESS_DETAIL, Dedup.match(success, bill))
        val combined = Dedup.collapse(listOf(success, bill)).single()
        assertEquals("ORDER-1", combined["orderId"])
        assertEquals("零钱", combined["paymentMethod"])
    }

    @Test fun revisitingAnUnorderedDetailUsesTransactionTimeInsteadOfPaymentMethod() {
        val first = detail("")
        val later = first + mapOf("fingerprint" to "new-observation", "paymentMethod" to "微信支付", "created_at" to at + 600_000)
        assertEquals(Dedup.Match.TRANSACTION_TIME, Dedup.match(first, later))
        assertEquals(1, Dedup.collapse(listOf(first, later)).size)
    }

    @Test fun differentOrdersNeverFallBackToTimeOrAmount() {
        assertNull(Dedup.match(detail("ORDER-1"), detail("ORDER-2")))
        assertEquals(2, Dedup.collapse(listOf(detail("ORDER-1"), detail("ORDER-2"))).size)
        assertTrue(Dedup.handledKeys(detail("ORDER-1")).intersect(Dedup.handledKeys(detail("ORDER-2"))).isEmpty())
    }

    @Test fun twoUnorderedSuccessPaymentsSecondsApartStaySeparate() {
        val next = payment(time = at + 3_321)
        assertNull(Dedup.match(payment(), next))
        assertEquals(2, Dedup.collapse(listOf(payment(), next)).size)
    }

    @Test fun differentActualTransactionTimesStaySeparate() {
        assertNull(Dedup.match(detail(""), detail("", at + 1_000)))
    }

    @Test fun matchingOrderStillRequiresSourceAmountAndCompatibleType() {
        val first = detail()
        assertNull(Dedup.match(first, first + mapOf("fingerprint" to "other", "sourceApp" to "ALIPAY")))
        assertNull(Dedup.match(first, first + mapOf("fingerprint" to "other", "amountInCents" to 19L)))
        assertNull(Dedup.match(first, first + mapOf("fingerprint" to "other", "transactionType" to "REFUND")))
    }

    @Test fun notificationAndSuccessMergeAndPreserveScreenshotAndReviewIdentity() {
        val notification = payment("PAYMENT_NOTIFICATION", at + 500) + ("screenshotPath" to "original.png")
        val success = payment(method = "微信支付")
        assertEquals(Dedup.Match.NOTIFICATION, Dedup.match(notification, success))
        val merged = Dedup.merge(notification, success)
        assertEquals(notification["fingerprint"], merged["fingerprint"])
        assertEquals("original.png", merged["screenshotPath"])
        assertEquals(at + 500, merged["notificationAt"])
        assertEquals(at + 321, merged["successAt"])
    }

    @Test fun pairedNotificationDoesNotConsumeTheNextSameAmountNotification() {
        val first = payment("PAYMENT_NOTIFICATION", at + 500)
        val paired = Dedup.merge(first, payment())
        assertNull(Dedup.match(paired, payment("PAYMENT_NOTIFICATION", at + 3_500)))
    }

    @Test fun oldBillDetailCannotConsumeANewSuccessPage() {
        val older = detail() + ("created_at" to at + 200)
        assertNull(Dedup.match(older, payment(time = at + 3_000)))
    }

    @Test fun ambiguousSameAmountPaymentsAreKeptForReview() {
        val successes = listOf(payment(), payment(time = at + 3_321))
        assertNull(Dedup.find(successes, detail()))
        assertEquals(3, Dedup.collapse(successes + detail()).size)
        val orders = listOf(detail("ORDER-1"), detail("ORDER-2"))
        assertNull(Dedup.find(orders, detail("")))
        assertEquals(3, Dedup.collapse(orders + detail("")).size)
    }

    @Test fun oneWeakObservationCannotBridgeTwoKnownOrders() {
        val grouped = Dedup.collapse(listOf(payment(), detail("ORDER-1"), detail("ORDER-2")))
        assertEquals(3, grouped.size)
    }

    @Test fun anActiveReviewAlsoCountsWhenCheckingHistoricalAmbiguity() {
        assertEquals(2, Dedup.collapse(listOf(payment(), detail()),
            listOf(payment(), detail(), payment(time = at + 3_321))).size)
    }

    @Test fun activeReviewCannotMergeWithADetailThatAlsoMatchesAnotherSuccess() {
        val active = payment()
        val inbox = listOf(detail(), payment(time = at + 3_321))
        assertNull(Dedup.find(inbox, active, inbox + active))
        assertNull(Dedup.find(inbox, active))
    }

    @Test fun differentMerchantOrOldNotificationIsNotMerged() {
        val notification = payment("PAYMENT_NOTIFICATION", at + 500)
        assertNull(Dedup.match(payment(), notification + ("merchant" to "其他商户")))
        assertNull(Dedup.match(payment(), payment("PAYMENT_NOTIFICATION", at + 20_000)))
    }

    @Test fun crossAppNotificationNeedsTheSameMerchantAndExplicitPaymentRail() {
        val page = payment(method = "支付宝") + ("sourceApp" to "MEITUAN")
        val notification = payment("PAYMENT_NOTIFICATION", at + 500) + ("sourceApp" to "ALIPAY")
        assertEquals(Dedup.Match.NOTIFICATION, Dedup.match(page, notification))
        assertNull(Dedup.match(page + ("paymentMethod" to "UNKNOWN"), notification))
    }

    @Test fun ignoredChoiceSurvivesHistoricalMergeAndKeepsRicherDetails() {
        val ignored = payment() + ("status" to "ignored")
        val combined = Dedup.collapse(listOf(ignored, detail())).single()
        assertEquals("ignored", combined["status"])
        assertEquals("ORDER-1", combined["orderId"])
    }

    @Test fun stableHandledOrderKeySurvivesAnUpgradedFingerprint() {
        val original = detail()
        val enriched = original + mapOf("fingerprint" to "alias", "paymentMethod" to "微信支付")
        assertFalse(Dedup.handledKeys(original).intersect(Dedup.handledKeys(enriched)).isEmpty())
    }

    @Test fun dateOrMinutePrecisionIsInsufficientForAutomaticTimeMatching() {
        assertNull(QianjiPageSupport.preciseTimestampFromText("2026-10-01"))
        assertNull(QianjiPageSupport.preciseTimestampFromText("2026-10-01 11:13"))
        assertNotNull(QianjiPageSupport.preciseTimestampFromText("2026-10-01 11:13:00"))
    }

    @Test fun legacyDetailedOrderCanRecoverItsParsedSecondsWithoutTrustingObservationTime() {
        val time = QianjiPageSupport.timestampFromText("2026-10-01 11:13:42")!!
        val legacy = (detail().minus("transactionTimeKnown")) + mapOf("timestamp" to time, "created_at" to time + 18_000)
        assertTrue(Dedup.legacyTransactionTimeKnown(legacy))
        assertFalse(Dedup.legacyTransactionTimeKnown(legacy + ("orderId" to "")))
        assertFalse(Dedup.legacyTransactionTimeKnown(legacy + ("timestamp" to time + 476)))
        assertFalse(Dedup.legacyTransactionTimeKnown(legacy + ("transactionTimeKnown" to false)))
    }

    @Test fun legacyMinuteOrDatePrecisionAndImmediateObservationAreKeptConservatively() {
        val time = QianjiPageSupport.timestampFromText("2026-10-01 11:13:00")!!
        val legacy = detail().minus("transactionTimeKnown") + mapOf("timestamp" to time, "created_at" to time + 18_000)
        assertFalse(Dedup.legacyTransactionTimeKnown(legacy))
        assertFalse(Dedup.legacyTransactionTimeKnown(legacy + mapOf("timestamp" to time + 42_000, "created_at" to time + 42_010)))
    }

    @Test fun parsedTransactionTimeIsExplicitAndSuccessObservationTimeIsNot() {
        val detector = PaymentSceneDetector()
        fun nodes(vararg labels: String) = labels.map { ScreenNode(text = it, className = "android.widget.TextView") }
        val result = detector.inspect("com.tencent.mm", nodes(
            "扫二维码付款-给测试商户", "-0.18", "当前状态", "支付成功", "收款方备注", "二维码收款", "转账时间", "2026年10月1日 11:13:42",
            "支付方式", "零钱", "转账单号", "10001073012026100101990426730526", "全部账单",
        ), at)
        assertNotNull(result.rejectionReason, result.candidate)
        assertTrue(result.candidate!!.transactionTimeKnown)
        val success = detector.inspect("com.tencent.mm", listOf(
            ScreenNode(contentDescription = "支付成功", className = "android.view.ViewGroup"),
            ScreenNode(text = "支付成功", className = "android.widget.TextView"),
            ScreenNode(text = "测试收款人（**明）", className = "android.widget.TextView"),
            ScreenNode(text = "¥0.18", className = "android.widget.TextView"),
            ScreenNode(contentDescription = "完成", className = "android.widget.Button"),
            ScreenNode(text = "完成", className = "android.widget.TextView"),
        ), at, "com.tencent.mm.framework.app.UIPageFragmentActivity")
        assertNotNull(success.rejectionReason, success.candidate)
        assertFalse(success.candidate!!.transactionTimeKnown)
    }
}
