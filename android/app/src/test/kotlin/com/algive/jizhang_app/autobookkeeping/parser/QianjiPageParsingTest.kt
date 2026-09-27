package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class QianjiPageParsingTest {
    private fun nodes(vararg text: String) = text.map { ScreenNode(text = it) }

    @Test
    fun catalogMatchesAllSevenProfilesAndFiftySixPages() {
        val pageTypes = QianjiPageCatalog.pageTypesByPackage.values.flatten()

        assertEquals(7, QianjiPageCatalog.pageTypesByPackage.size)
        assertEquals(56, pageTypes.size)
        assertEquals(56, pageTypes.toSet().size)
        assertEquals(
            mapOf(
                "com.tencent.mm" to 12,
                "com.eg.android.AlipayGphone" to 16,
                "com.xunmeng.pinduoduo" to 3,
                "com.unionpay" to 5,
                "com.jingdong.app.mall" to 6,
                "com.sankuai.meituan" to 10,
                "com.ss.android.ugc.aweme" to 4,
            ),
            QianjiPageCatalog.pageTypesByPackage.mapValues { it.value.size },
        )
    }

    @Test
    fun parsesSignedCurrencyAndGroupedAmountsAsPositiveCents() {
        assertEquals(listOf(123450L), QianjiPageSupport.moneyValues("已支付 ￥1,234.50"))
        assertEquals(listOf(520L), QianjiPageSupport.moneyValues("-¥5.20"))
        assertEquals(listOf(520L), QianjiPageSupport.moneyValues("￥-5.20"))
        assertEquals(emptyList<Long>(), QianjiPageSupport.moneyValues("2026-09-27 12:30:00"))
        assertEquals(emptyList<Long>(), QianjiPageSupport.moneyValues("订单号123456"))
    }

    @Test
    fun amountAfterLabelRequiresOneUnambiguousValue() {
        assertEquals(
            3650L,
            QianjiPageSupport.uniqueMoneyAfter(
                nodes("支付金额", "￥36.50", "订单号", "ORDER_123456"),
                setOf("支付金额"),
            ),
        )
        assertNull(
            QianjiPageSupport.uniqueMoneyAfter(
                nodes("支付金额", "￥36.50 / ￥30.00"),
                setOf("支付金额"),
            ),
        )
        assertNull(QianjiPageSupport.moneyValues("￥0.00").singleOrNull())
    }

    @Test
    fun dateOnlyTextIsAcceptedWithoutInventingAnInvalidTime() {
        assertEquals(
            QianjiPageSupport.timestampFromText("2026-09-27"),
            QianjiPageSupport.timestampFromText("2026-09-27 00:00:00"),
        )
        assertNull(QianjiPageSupport.timestampFromText("2026-02-30 12:00:00"))
    }

    @Test
    fun candidateRejectsMissingMerchantAndKeepsExplicitPageTypeAndDirection() {
        assertNull(
            QianjiPageSupport.candidate(
                sourceApp = "DOUYIN",
                pageType = "DouyingTransferReceived",
                amountInCents = 1000L,
                merchant = " ",
                observedAt = 100_000L,
                transactionType = "INCOME",
            ),
        )
        val candidate = QianjiPageSupport.candidate(
            sourceApp = "DOUYIN",
            pageType = "DouyingTransferReceived",
            amountInCents = 1000L,
            merchant = "张三",
            observedAt = 100_000L,
            transactionType = "INCOME",
        )
        assertNotNull(candidate)
        assertEquals("INCOME", candidate?.transactionType)
        assertEquals("QIANJI_DouyingTransferReceived", candidate?.scene?.scene)
    }
}
