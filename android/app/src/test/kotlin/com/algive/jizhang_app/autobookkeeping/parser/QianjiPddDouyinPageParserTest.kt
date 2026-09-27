package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QianjiPddDouyinPageParserTest {
    private val observedAt = QianjiPageSupport.timestampFromText("2026-09-27 12:00:00")!!
    private val pdd = QianjiPddPageParser()
    private val douyin = QianjiDouyinPageParser()

    @Test
    fun registersAllSevenPagesInQianjiOrderAndProducesEachPageCandidate() {
        assertEquals("com.xunmeng.pinduoduo", pdd.packageName)
        assertEquals(
            listOf("PddOrderDetail", "PddPayFirstDialog", "PddWalletBillDetail"),
            pdd.registeredPageTypes,
        )
        assertEquals("com.ss.android.ugc.aweme", douyin.packageName)
        assertEquals(
            listOf(
                "DouyingTransferWaiting",
                "DouyingTransferReceived",
                "DouyingWalletBillDetail",
                "DouyingPaySuccess",
            ),
            douyin.registeredPageTypes,
        )

        val fixtures = listOf(
            pdd to pddOrderPending(),
            pdd to pddPayFirstPending(),
            pdd to pddWalletSuccess(),
            douyin to douyinTransferWaiting(),
            douyin to douyinTransferReceived(),
            douyin to douyinWalletSuccess(),
            douyin to douyinPaySuccess(),
        )
        fixtures.forEach { (parser, nodes) ->
            val result = parser.parse(nodes, observedAt)
            assertNotNull("page fixture should match and produce a candidate: ${result.pageType}", result.candidate)
            assertEquals("EXPENSE", result.candidate?.transactionType)
            assertEquals("QIANJI_${result.pageType}", result.candidate?.scene?.scene)
        }
    }

    @Test
    fun pddOrderUsesNetGroupPriceAndKeepsPendingStateForConfirmation() {
        val result = pdd.parse(pddOrderPending(), observedAt)
        val candidate = result.candidate
        assertEquals("PddOrderDetail", result.pageType)
        assertEquals(4_000L, candidate?.amountInCents)
        assertEquals(4_800L, candidate?.originalAmountInCents)
        assertEquals(800L, candidate?.discountAmountInCents)
        assertEquals("拼多多", candidate?.merchantRaw)
        assertEquals("收纳盒；待收货", candidate?.note)
        assertEquals("EXPENSE", candidate?.transactionType)
        assertEquals(
            QianjiPageSupport.timestampFromText("2026-09-01 09:30:00"),
            candidate?.timestamp,
        )
    }

    @Test
    fun pddPayFirstDialogProducesReviewCandidateForFutureAutoPayment() {
        val result = pdd.parse(pddPayFirstPending(), observedAt)
        assertEquals("PddPayFirstDialog", result.pageType)
        assertEquals(1_750L, result.candidate?.amountInCents)
        assertEquals("EXPENSE", result.candidate?.transactionType)
        assertTrue(result.candidate?.note.orEmpty().contains("等待收货后自动扣款"))
    }

    @Test
    fun pddWalletUsesSuccessfulBillAmountAndCapturesDiscount() {
        val candidate = pdd.parse(pddWalletSuccess(), observedAt).candidate
        assertEquals(1_280L, candidate?.amountInCents)
        assertEquals(1_400L, candidate?.originalAmountInCents)
        assertEquals(120L, candidate?.discountAmountInCents)
        assertEquals("茶饮店", candidate?.merchantRaw)
        assertEquals("微信支付", candidate?.paymentMethod)
        assertEquals("抹茶拿铁", candidate?.note)
    }

    @Test
    fun douyinWaitingTransferCreatesExpenseCandidateWithPendingContext() {
        val candidate = douyin.parse(douyinTransferWaiting(), observedAt).candidate
        assertEquals(8_800L, candidate?.amountInCents)
        assertEquals("张三", candidate?.merchantRaw)
        assertEquals("EXPENSE", candidate?.transactionType)
        assertTrue(candidate?.note.orEmpty().contains("待对方收款"))
        assertTrue(candidate?.note.orEmpty().contains("聚餐AA"))
    }

    @Test
    fun douyinReceivedTransferPrefersReceiveTimeAndUsesRawZeroExpenseMapping() {
        val candidate = douyin.parse(douyinTransferReceived(), observedAt).candidate
        assertEquals("DouyingTransferReceived", candidate?.scene?.scene?.removePrefix("QIANJI_"))
        assertEquals("EXPENSE", candidate?.transactionType)
        assertEquals("李四", candidate?.merchantRaw)
        assertEquals(6_200L, candidate?.amountInCents)
        assertTrue(candidate?.note.orEmpty().contains("对方已收款"))
        assertEquals(
            QianjiPageSupport.timestampFromText("2026-09-02 12:00:00"),
            candidate?.timestamp,
        )
    }

    @Test
    fun douyinReceivedTransferFallsBackToTransferTimeWhenReceiveTimeIsUnreadable() {
        val nodes = douyinTransferReceived().map { node ->
            if (node.label.startsWith("2026-09-02")) node.copy(text = "时间隐藏") else node
        }
        val candidate = douyin.parse(nodes, observedAt).candidate
        assertNotNull(candidate)
        assertEquals(
            QianjiPageSupport.timestampFromText("2026-09-01 11:00:00"),
            candidate?.timestamp,
        )
    }

    @Test
    fun douyinWalletExtractsMerchantPaymentMethodAndProductRemark() {
        val candidate = douyin.parse(douyinWalletSuccess(), observedAt).candidate
        assertEquals(3_000L, candidate?.amountInCents)
        assertEquals(3_200L, candidate?.originalAmountInCents)
        assertEquals(200L, candidate?.discountAmountInCents)
        assertEquals("好物商城", candidate?.merchantRaw)
        assertEquals("支付宝", candidate?.paymentMethod)
        assertEquals("会员充值", candidate?.note)
    }

    @Test
    fun douyinPaySuccessUsesFlattenTextPaymentAndDefaultRemark() {
        val candidate = douyin.parse(douyinPaySuccess(), observedAt).candidate
        assertEquals(999L, candidate?.amountInCents)
        assertEquals("抖音购物", candidate?.merchantRaw)
        assertEquals("支付宝", candidate?.paymentMethod)
        assertEquals("抖音购物", candidate?.note)
        assertEquals(
            QianjiPageSupport.timestampFromText("2026-09-10 15:16:17"),
            candidate?.timestamp,
        )
    }

    @Test
    fun similarPagesWithoutTheirRequiredGateDoNotMatch() {
        assertNull(pdd.parse(pddOrderPending().filterNot { it.label == "申请退款" }, observedAt).pageType)
        assertNull(pdd.parse(pddPayFirstPending().filterNot { it.label == "等待收货" }, observedAt).pageType)
        assertNull(pdd.parse(pddWalletSuccess().filterNot { it.label == "支付成功" }, observedAt).pageType)
        assertNull(douyin.parse(douyinTransferWaiting().filterNot { it.label.startsWith("24小时内") }, observedAt).pageType)
        assertNull(douyin.parse(douyinTransferReceived().filterNot { it.label.contains("已收款") }, observedAt).pageType)
        assertNull(douyin.parse(douyinWalletSuccess().filterNot { it.className == "android.webkit.WebView" }, observedAt).pageType)
        assertNull(douyin.parse(douyinPaySuccess(failed = true), observedAt).pageType)
    }

    private fun pddOrderPending() = nodes(
        "下单时间：2026-09-01 09:30:00",
        "待收货",
        "申请退款",
        "商品名称：收纳盒",
        "拼单价",
        "¥48.00",
        "店铺优惠",
        "¥8.00",
        "支付方式",
        "多多钱包",
        "订单编号",
        "O-2026001",
    )

    private fun pddPayFirstPending() = nodes(
        "使用“先用后付”下单成功",
        "先用后付下单，实付¥17.50",
        "等待收货",
        "确认收货后，自动付款¥17.50",
        "知道了",
        "查看订单",
    )

    private fun pddWalletSuccess() = nodes(
        "账单详情",
        "当前状态",
        "支付成功",
        "商品详情",
        "抹茶拿铁",
        "支付时间",
        "2026-09-05 10:11:12",
        "支付方式",
        "微信支付",
        "交易单号",
        "PDD12345",
        "商户单号",
        "MERCHANT123",
        "茶饮店",
        "¥12.80",
        "优惠",
        "¥1.20",
    )

    private fun douyinTransferWaiting() = nodes(
        "转账详情",
        "待张三收款",
        "转账金额",
        "¥88.00",
        "转账时间",
        "2026-09-03 09:08:07",
        "转账附言",
        "聚餐AA",
        "提醒对方收款",
        "24小时内对方未收款，将退还给你",
    )

    private fun douyinTransferReceived() = listOf(
        ScreenNode(text = "转账详情"),
        ScreenNode(text = "李四已收款", className = "android.widget.LinearLayout"),
        ScreenNode(text = "收款时间"),
        ScreenNode(text = "2026-09-02 12:00:00"),
        ScreenNode(text = "转账时间"),
        ScreenNode(text = "2026-09-01 11:00:00"),
        ScreenNode(text = "转账附言"),
        ScreenNode(text = "请收款"),
        ScreenNode(text = "转账金额"),
        ScreenNode(text = "¥62.00"),
    )

    private fun douyinWalletSuccess() = listOf(
        ScreenNode(text = "详情页", className = "android.webkit.WebView"),
        ScreenNode(text = "申请电子交易凭证"),
        ScreenNode(text = "点击展开", className = "android.widget.Button"),
        ScreenNode(text = "支付成功"),
        ScreenNode(text = "好物商城"),
        ScreenNode(text = "¥30.00"),
        ScreenNode(text = "支付时间"),
        ScreenNode(text = "2026-09-06 13:14:15"),
        ScreenNode(text = "支付方式"),
        ScreenNode(text = "抖音支付（支付宝）"),
        ScreenNode(text = "交易单号"),
        ScreenNode(text = "DY12345"),
        ScreenNode(text = "商品订单"),
        ScreenNode(text = "聊天转账-会员充值"),
        ScreenNode(text = "抖音支付优惠"),
        ScreenNode(text = "¥2.00"),
    )

    private fun douyinPaySuccess(failed: Boolean = false) = listOf(
        ScreenNode(text = if (failed) "支付失败" else "支付成功", className = FLATTEN),
        ScreenNode(text = "¥9.99", className = FLATTEN),
        ScreenNode(text = "支付方式", className = FLATTEN),
        ScreenNode(text = "抖音支付（支付宝）", className = FLATTEN),
        ScreenNode(text = "支付时间", className = FLATTEN),
        ScreenNode(text = "2026-09-10 15:16:17", className = FLATTEN),
        ScreenNode(text = "完成", className = FLATTEN),
    )

    private fun nodes(vararg labels: String) = labels.map(::ScreenNode)

    private companion object {
        const val FLATTEN = "com.lynx.tasm.behavior.ui.text.FlattenUIText"
    }
}
