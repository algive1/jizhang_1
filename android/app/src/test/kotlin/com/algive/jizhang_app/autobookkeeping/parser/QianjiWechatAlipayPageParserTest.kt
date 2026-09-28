package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QianjiWechatAlipayPageParserTest {
    private data class Fixture(
        val pageType: String,
        val nodes: List<ScreenNode>,
        val transactionType: String,
        val expectedSourceApp: String,
    )

    private fun text(vararg values: String): List<ScreenNode> = values.map(::ScreenNodeText)

    private fun ScreenNodeText(value: String) = ScreenNode(text = value)

    private fun view(value: String, className: String) =
        ScreenNode(text = value, className = className)

    private val wechat = QianjiWechatPageParser()
    private val alipay = QianjiAlipayPageParser()

    @Test
    fun qrBillDetailReadsUnlabelledAmountAndRecipient() {
        val nodes = text(
            "扫二维码付款-给测试商户", "-1.00", "当前状态", "支付成功",
            "收款方备注", "二维码收款", "支付方式", "零钱",
            "转账时间", "2026年9月28日 19:27:59", "转账单号",
            "10001073012026092801730776732517", "全部账单",
        )
        val result = wechat.parse(nodes, 1_800_000_000_000L)
        assertEquals("WeChatBillDetail", result.pageType)
        assertEquals(100L, result.candidate?.amountInCents)
        assertEquals("测试商户", result.candidate?.merchantRaw)
        assertEquals("EXPENSE", result.candidate?.transactionType)
        assertEquals("10001073012026092801730776732517", result.candidate?.orderId)
        assertNull(wechat.parse(nodes + text("-2.00"), 1_800_000_000_000L).candidate)
        assertNull(wechat.parse(nodes.filterNot { it.label == "-1.00" }, 1_800_000_000_000L).candidate)
    }

    private val wechatFixtures = listOf(
        Fixture(
            "WechatPersonalRedPacketSend",
            text("小王的红包", "红包金额5.00元，等待对方领取"),
            "EXPENSE",
            "WECHAT",
        ),
        Fixture(
            "WechatGroupRedPacketDetail",
            listOf(
                *text("小王的红包", "已领取1/1个，共5.00/5.00元", "5.00", "元", "1个红包被抢光").toTypedArray(),
                view("返回", "android.widget.ImageView"),
                view("更多", "android.widget.ImageView"),
            ),
            "INCOME",
            "WECHAT",
        ),
        Fixture(
            "WechatPersonalRedPacketReceive",
            text("小王的红包", "5.00", "5.00元"),
            "INCOME",
            "WECHAT",
        ),
        Fixture(
            "WechatPersonalRedPacketReceive2",
            listOf(
                *text("小王的红包", "5.00", "元").toTypedArray(),
                view("返回", "android.widget.ImageView"),
                view("更多", "android.widget.ImageView"),
            ),
            "INCOME",
            "WECHAT",
        ),
        Fixture(
            "WeChatTransferDetail",
            text(
                "转账-转给小王", "当前状态", "待对方收款", "转账时间", "2026-09-27 12:30:00",
                "支付方式", "零钱", "转账金额", "20.00",
            ),
            "EXPENSE",
            "WECHAT",
        ),
        Fixture(
            "WeChatTransferInDetail",
            text(
                "商家转账-来自商家A", "付款商家", "商家A", "收款方式", "零钱",
                "转账时间", "2026-09-27 12:31:00", "转账金额", "8.00",
            ),
            "INCOME",
            "WECHAT",
        ),
        Fixture(
            "WeChatBillDetail",
            text(
                "当前状态", "已退款（￥5.00）", "支付时间", "2026-09-27 12:32:00",
                "支付金额", "5.00", "商户全称", "咖啡店",
            ),
            "EXPENSE",
            "WECHAT",
        ),
        Fixture(
            "WeChatTransferDetailWaiting",
            text("待小王收款", "转账金额", "30.00", "转账时间", "2026-09-27 12:33:00"),
            "EXPENSE",
            "WECHAT",
        ),
        Fixture(
            "WechatWithdrawSuccess",
            text(
                "零钱提现", "发起提现申请", "提现金额", "40.00", "到账银行卡", "招商银行(尾号1234)",
            ),
            "TRANSFER",
            "WECHAT",
        ),
        Fixture(
            "WechatWithdrawDetail",
            text(
                "零钱提现-至银行卡", "当前状态", "处理中", "发起提现", "提现金额", "40.00",
                "申请时间", "2026-09-27", "到账时间", "2026-09-28", "提现银行", "招商银行",
            ),
            "TRANSFER",
            "WECHAT",
        ),
        Fixture(
            "WechatChargeDetail",
            text(
                "零钱充值-来自工商银行", "当前状态", "充值完成", "充值时间", "2026-09-27",
                "支付方式", "工商银行", "充值金额", "50.00",
            ),
            "TRANSFER",
            "WECHAT",
        ),
        Fixture(
            "WeChatPaySuccess",
            text("支付成功", "￥12.00", "商户全称", "便利店"),
            "EXPENSE",
            "WECHAT",
        ),
    )

    private val alipayFixtures = listOf(
        Fixture(
            "AlipayBillDetail",
            text(
                "当前状态", "等待确认收货", "支付时间", "2026-09-27 13:00:00",
                "订单金额", "68.00", "收款方全称", "网店",
            ),
            "EXPENSE",
            "ALIPAY",
        ),
        Fixture(
            "AlipayPaySuccess",
            listOf(
                *text("支付成功", "支付成功￥9.90", "￥9.90", "支付宝余额", "付款方式", "支付宝余额", "商户名称", "水果店").toTypedArray(),
                view("完成", "android.widget.TextView"),
            ),
            "EXPENSE",
            "ALIPAY",
        ),
        Fixture(
            "AlipayTransfer",
            text("转账成功", "交易方式", "支付宝余额", "收款方", "小王", "转账金额", "100.00"),
            "EXPENSE",
            "ALIPAY",
        ),
        Fixture(
            "AlipayTransferOut",
            text("转出成功", "¥", "到账账户", "招商银行", "完成", "¥20.00", "转账金额", "20.00"),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayTransferIn",
            listOf(
                view("", "android.webkit.WebView"),
                *text("转入成功", "￥30.00", "付款方式", "银行卡").toTypedArray(),
                view("完成", "android.widget.Button"),
                view("返回", "android.widget.FrameLayout"),
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayCharge",
            text("充值成功", "付款方式", "银行卡", "订单金额", "100.00"),
            "EXPENSE",
            "ALIPAY",
        ),
        Fixture(
            "AlipayChargeDetail",
            text(
                "余额明细详情", "余额充值 ￥20.00", "支付时间", "2026-09-27 13:05:00",
                "对方账户", "工商银行", "￥20.00",
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayWithdraw",
            text("提现成功", "提现金额", "100.00", "到账银行卡", "招商银行", "¥100.00", "完成"),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayWithdrawDetail",
            text(
                "余额明细详情", "余额提现￥80.00", "支付时间", "2026-09-27 13:08:00",
                "付款方式", "支付宝余额", "对方账户", "招商银行", "￥80.00",
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipaySendRedPacket",
            text(
                "发的红包", "小王", "已领取1/1个，共1.00/1.00元", "生日快乐",
                "24小时内未领取，红包金额将被退回", "查看红包记录",
            ),
            "EXPENSE",
            "ALIPAY",
        ),
        Fixture(
            "AlipayQRCodeReceiveDetail",
            text(
                "账单详情", "当前状态", "已收款", "收款时间", "2026-09-27 13:10:00",
                "订单金额", "6.00", "付款方备注", "小王",
            ),
            "INCOME",
            "ALIPAY",
        ),
        Fixture(
            "AlipayYuLiBaoIncomeDetail",
            text("收益", "收益到账", "收益到账￥0.50", "收益发放：银行卡", "余额￥500.00", "￥0.50"),
            "INCOME",
            "ALIPAY",
        ),
        Fixture(
            "AlipayYuLiBaoTransferOutSuccess",
            listOf(
                view("快赎结果页状态", "android.widget.Image"),
                *text("转出成功", "转出成功￥50.00", "收款账号", "招商银行", "￥50.00").toTypedArray(),
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayYuLiBaoTransferOutDetail",
            listOf(
                view("转出详情", "android.webkit.WebView"),
                *text(
                    "转出到招商银行", "成功转出", "成功转出￥50.00", "从哪转出：余利宝", "收款账号：招商银行", "￥50.00",
                ).toTypedArray(),
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayYuLiBaoTransferInDetail",
            listOf(
                view("转入详情", "android.webkit.WebView"),
                *text(
                    "转入", "成功转入￥50.00", "转入到：余利宝", "付款账号：招商银行", "余额￥100.00", "￥50.00",
                ).toTypedArray(),
            ),
            "TRANSFER",
            "ALIPAY",
        ),
        Fixture(
            "AlipayYuLiBaoTransferInSuccess",
            text("转入成功￥50.00", "付款方式", "银行卡", "开始计算收益", "收益到账"),
            "TRANSFER",
            "ALIPAY",
        ),
    )

    @Test
    fun registersAllPageTypesInQianjiOrder() {
        assertEquals(
            listOf(
                "WechatPersonalRedPacketSend", "WechatGroupRedPacketDetail",
                "WechatPersonalRedPacketReceive", "WechatPersonalRedPacketReceive2",
                "WeChatTransferDetail", "WeChatTransferInDetail", "WeChatBillDetail",
                "WeChatTransferDetailWaiting", "WechatWithdrawSuccess", "WechatWithdrawDetail",
                "WechatChargeDetail", "WeChatPaySuccess",
            ),
            wechat.registeredPageTypes,
        )
        assertEquals(
            listOf(
                "AlipayBillDetail", "AlipayPaySuccess", "AlipayTransfer", "AlipayTransferOut",
                "AlipayTransferIn", "AlipayCharge", "AlipayChargeDetail", "AlipayWithdraw",
                "AlipayWithdrawDetail", "AlipaySendRedPacket", "AlipayQRCodeReceiveDetail",
                "AlipayYuLiBaoIncomeDetail", "AlipayYuLiBaoTransferOutSuccess",
                "AlipayYuLiBaoTransferOutDetail", "AlipayYuLiBaoTransferInDetail",
                "AlipayYuLiBaoTransferInSuccess",
            ),
            alipay.registeredPageTypes,
        )
        assertEquals(28, wechatFixtures.size + alipayFixtures.size)
    }

    @Test
    fun eachPageTypeMatchesItsPositiveFixtureAndBuildsExpectedCandidate() {
        (wechatFixtures.map { wechat to it } + alipayFixtures.map { alipay to it }).forEach { (parser, fixture) ->
            val result = parser.parse(fixture.nodes, observedAt = 1_800_000_000_000L)
            assertEquals("${fixture.pageType} should be the first matched rule", fixture.pageType, result.pageType)
            assertTrue("${fixture.pageType} must be a page match", result.matchedPage)
            assertNull("${fixture.pageType} should not reject its positive fixture: ${result.rejectionReason}", result.rejectionReason)
            val candidate = result.candidate
            assertNotNull("${fixture.pageType} should map to a candidate", candidate)
            assertEquals(fixture.expectedSourceApp, candidate?.sourceApp)
            assertEquals(fixture.transactionType, candidate?.transactionType)
            assertEquals("QIANJI_${fixture.pageType}", candidate?.scene?.scene)
            assertTrue("${fixture.pageType} amount must be positive", (candidate?.amountInCents ?: 0L) > 0L)
            assertTrue("${fixture.pageType} requires a non-empty merchant", !candidate?.merchantRaw.isNullOrBlank())
        }
    }

    @Test
    fun earlierRecognizerWinsWhenPagesShareCommonLabels() {
        val transferDetail = text(
            "转账-转给小王", "当前状态", "收款成功", "转账时间", "2026-09-27",
            "支付方式", "零钱", "转账金额", "20.00",
        )
        assertEquals("WeChatTransferDetail", wechat.parse(transferDetail, 1L).pageType)

        val pendingBill = text(
            "当前状态", "等待确认收货", "支付时间", "2026-09-27", "订单金额", "68.00", "收款方全称", "网店",
        )
        assertEquals("AlipayBillDetail", alipay.parse(pendingBill, 1L).pageType)
    }

    @Test
    fun similarNonPagesAndIncompleteTransactionsDoNotMatchOrCreateCandidates() {
        assertTrue(!wechat.acceptsActivity("com.tencent.mm.ui.LauncherUI"))
        val keyboard = listOf(
            ScreenNode(viewId = "com.tencent.mm:id/tenpay_keyboard_1", className = "android.widget.TextView"),
            ScreenNode(viewId = "com.tencent.mm:id/tenpay_keyboard_2", className = "android.widget.TextView"),
            ScreenNode(viewId = "com.tencent.mm:id/tenpay_keyboard_3", className = "android.widget.TextView"),
            ScreenNode(viewId = "com.tencent.mm:id/tenpay_keyboard_d", className = "android.widget.Button"),
        ) + text("完成", "密码框,共六位数字", "付款方式", "支付成功", "￥9.90")
        val passwordPage = wechat.parse(keyboard, 1L)
        assertEquals("WechatPayPassword", passwordPage.pageType)
        assertNull(passwordPage.candidate)
        assertEquals(
            QianjiPageParseResult.NoMatch,
            wechat.parse(text("小王的红包", "红包金额待确认"), 1L),
        )
        assertEquals(
            QianjiPageParseResult.NoMatch,
            alipay.parse(text("支付成功", "￥9.90"), 1L),
        )
        val matchedButMissingAmount = wechat.parse(
            text("当前状态", "已退款（￥5.00）", "支付时间", "2026-09-27", "商户全称", "咖啡店"),
            1L,
        )
        assertEquals("WeChatBillDetail", matchedButMissingAmount.pageType)
        assertNotNull(matchedButMissingAmount.rejectionReason)
        assertNull(matchedButMissingAmount.candidate)
    }

    @Test
    fun wechatPaymentSuccessUsesOnlyRecipientBetweenSuccessTitleAndAmountOnKnownLayout() {
        val realLayout = listOf(
            ScreenNode(contentDescription = "支付成功", className = "android.view.ViewGroup", depth = 0),
            view("支付成功", "android.widget.TextView"),
            view("测试收款人（**明）", "android.widget.TextView"),
            view("¥1.00", "android.widget.TextView"),
            ScreenNode(contentDescription = "完成", className = "android.widget.Button"),
            view("完成", "android.widget.TextView"),
        )

        val parsed = wechat.parse(realLayout, 1L)
        assertEquals("WeChatPaySuccess", parsed.pageType)
        assertEquals(100L, parsed.candidate?.amountInCents)
        assertEquals("测试收款人（**明）", parsed.candidate?.merchantRaw)

        val promptedLayout = realLayout.toMutableList().apply {
            add(2, view("温馨提示", "android.widget.TextView"))
        }
        val promptRejection = wechat.parse(promptedLayout, 1L)
        assertEquals("WeChatPaySuccess", promptRejection.pageType)
        assertEquals("NO_COUNTERPARTY", promptRejection.rejectionReason)
        assertNull(promptRejection.candidate)

        val missingSuccessRoot = wechat.parse(realLayout.drop(1), 1L)
        assertEquals("NO_COUNTERPARTY", missingSuccessRoot.rejectionReason)
        assertNull(missingSuccessRoot.candidate)
    }

    @Test
    fun qianjiCandidateSemanticsArePreservedForWaitingAndRefundLabels() {
        val pendingWechat = wechat.parse(
            text("待小王收款", "转账金额", "30.00", "转账时间", "2026-09-27"),
            1L,
        )
        assertEquals("WeChatTransferDetailWaiting", pendingWechat.pageType)
        assertEquals("EXPENSE", pendingWechat.candidate?.transactionType)

        val refundWechat = wechat.parse(
            text("当前状态", "已退款（￥5.00）", "支付时间", "2026-09-27", "支付金额", "5.00", "商户全称", "咖啡店"),
            1L,
        )
        assertEquals("WeChatBillDetail", refundWechat.pageType)
        assertEquals("EXPENSE", refundWechat.candidate?.transactionType)

        val incomingWechat = wechat.parse(
            text(
                "当前状态", "收款成功", "收款时间", "2026-09-27 12:35:00",
                "转账-来自小王", "收款金额", "￥3.00", "商户全称", "小王",
            ),
            1L,
        )
        assertEquals("WeChatBillDetail", incomingWechat.pageType)
        assertEquals("INCOME", incomingWechat.candidate?.transactionType)

        val pendingAlipay = alipay.parse(
            text("当前状态", "等待发货", "支付时间", "2026-09-27", "订单金额", "68.00", "收款方全称", "网店"),
            1L,
        )
        assertEquals("AlipayBillDetail", pendingAlipay.pageType)
        assertEquals("EXPENSE", pendingAlipay.candidate?.transactionType)
    }
}
