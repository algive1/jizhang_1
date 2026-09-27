package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class QianjiUnionpayJdMeituanPageParserTest {
    private data class Fixture(
        val pageType: String,
        val parser: QianjiAppPageParser,
        val nodes: List<ScreenNode>,
        val expectedType: String = "EXPENSE",
    )

    private val unionpay = QianjiUnionpayPageParser()
    private val jd = QianjiJingDongPageParser()
    private val meituan = QianjiMeituanPageParser()
    private val observedAt = 1_800_000_000_000L

    private fun text(value: String) = ScreenNode(text = value, className = "android.widget.TextView")
    private fun web(value: String) = ScreenNode(text = value, className = "android.webkit.WebView")
    private fun group(value: String) = ScreenNode(text = value, className = "android.view.ViewGroup")

    private fun fixtures(): List<Fixture> = listOf(
        Fixture("UnionpayBillDetail", unionpay, listOf(
            text("账单详情"), group("客服按钮"), text("当前状态"), text("交易成功"),
            text("付款方式"), text("云闪付借记卡"), text("订单金额"), text("¥18.80"),
            text("订单时间"), text("2026-09-27 10:11:12"), text("订单描述"), text("早餐"),
        )),
        Fixture("UnionpayPaySuccess", unionpay, listOf(
            text("支付成功"), text("付款方式"), text("中国银行"), text("完成"), text("¥18.80"),
        )),
        Fixture("UnionpayTransferSuccess", unionpay, listOf(
            text("转账成功"), text("转账详情"), text("继续转账"), text("完成"),
            text("转账金额"), text("¥18.80"), text("收款人"), text("李四"),
        ), "TRANSFER"),
        Fixture("UnionpayTransferDetail", unionpay, listOf(
            text("账单详情"), group("客服按钮"), text("当前状态"), text("交易成功"),
            text("转账金额"), text("¥18.80"), text("付款方式"), text("中国银行"),
            text("转账到"), text("李四"), text("订单时间"), text("2026-09-27 10:11:12"),
            text("转账"),
        ), "TRANSFER"),
        Fixture("UnionpayMessageOrderDetail", unionpay, listOf(
            text("交易详情"), text("卡号"), text("6217000000001234"), text("交易时间"),
            text("2026-09-27 10:11:12"), text("交易类别"), text("取款"), text("分类"),
            text("商户"), text("ATM"), text("¥18.80"),
        ), "TRANSFER"),
        Fixture("JingDongWalletBillDetail", jd, listOf(
            web("账单详情"), text("付款方式"), text("京东白条"), text("创建时间"),
            text("2026-09-27 10:11:12"), text("总订单编号"), text("JD12345678"),
            text("交易成功"), text("¥18.80"), text("共1笔订单"),
        )),
        Fixture("JingDongWalletBillDetailV2", jd, listOf(
            web("账单详情"), text("支付方式：京东白条"), text("创建时间：2026-09-27 10:11:12"),
            text("总订单编号：JD12345678"), text("交易成功 ¥18.80"), text("支付立减 ¥2.00"),
        )),
        Fixture("JingDongAihuishouOrderDetail", jd, listOf(
            web("订单详情"), text("回收成功啦"), text("合计收款"), text("¥18.80"),
            text("订单编号"), text("JD12345678"), text("收款方式"), text("招商银行"),
            text("旧机信息"), text("手机"),
        ), "INCOME"),
        Fixture("JingDongOrderDetail", jd, listOf(
            text("等待收货"), text("数量 × 1"), text("实付款"), text("¥18.80"),
            text("合计"), text("¥18.80"), text("订单编号"), text("JD12345678"), text("复制"),
            text("支付时间"), text("2026-09-27 10:11:12"),
        )),
        Fixture("JingDongOrderWeb", jd, listOf(
            web("订单详情"), web("已完成"), web("订单编号：JD12345678"),
            web("下单时间：2026-09-27 10:00:00"), web("支付时间：2026-09-27 10:11:12"),
            web("商品总额 ¥20.00"), web("实付款：¥18.80"), web("¥18.80"),
        )),
        Fixture("JingDongPaySuccess", jd, listOf(
            text("支付成功"),
            text("京东白条 ¥18.80 共优惠¥2.00"),
        )),
        Fixture("MeiTuanOrderDetail", meituan, listOf(
            text("已消费"), text("咖啡"), text("实付"), text("¥18.80"), text("订单信息"),
            text("订单编号：MT12345678"), text("下单时间：2026-09-27 10:11:12"),
        )),
        Fixture("MeiTuanVoucherDetail", meituan, listOf(
            text("待到店使用"), text("咖啡券"), text("实付"), text("¥18.80"),
            text("使用须知"), text("有效日期"), text("使用时间"),
        )),
        Fixture("MeiTuanVoucherSuccessDetail", meituan, listOf(
            text("买单成功！"), text("实付款金额：¥18.80"), text("¥18.80"), text("订单编号：MT12345678"),
            text("复制"), text("消费时间：2026-09-27 10:11:12"), text("买单共省：¥2.00"),
        )),
        Fixture("MeiTuanGrouponDetail", meituan, listOf(
            text("已使用"), text("洗车"), text("实付"), text("¥18.80"), text("团购详情"),
            text("使用须知"), text("有效日期"), text("使用时间"), text("订单信息"),
        )),
        Fixture("MeiTuanMovieDetail", meituan, listOf(
            text("19:00开场"), text("展开取票码"), text("订单详情"),
            text("实付金额：¥18.80"), text("¥18.80"), text("订单号码：MT12345678"),
            text("订单时间：2026-09-27 10:11:12"),
        )),
        Fixture("MeiTuanDeliveryDetail", meituan, listOf(
            text("订单已完成"), text("预计送达 10:30"), text("商品费用"), text("¥18.00"),
            text("合计"), text("实付款"), text("¥18.80"), text("￥"),
        )),
        Fixture("MeiTuanBikeOrderDetail", meituan, listOf(
            text("已支付18.80元"), text("费用申诉"), text("车辆报修"),
            text("2026-09-27 10:11:12"), text("骑行15分12秒"),
        )),
        Fixture("MeiTuanChargeOrderDetail", meituan, listOf(
            text("订单完成"), text("充电宝已归还，感谢使用"), text("使用时长"),
            text("订单金额"), text("¥18.80"), text("元"), text("再次租借"),
        )),
        Fixture("MeiTuanPaySuccess", meituan, listOf(
            web("支付成功"), text("支付成功 ¥18.80"),
        )),
        Fixture("MeiTuanWalletBillDetail", meituan, listOf(
            web("账单详情"), text("已退款18.80元"), text("¥18.80"), text("支付方式"),
            text("美团月付"), text("下单时间"), text("2026-09-27 10:11:12"),
        )),
    )

    @Test
    fun registersTwentyOnePagesAndPreservesShadowedRuleOrder() {
        assertEquals(QianjiPageCatalog.pageTypesByPackage.getValue("com.unionpay"), unionpay.registeredPageTypes)
        assertEquals(QianjiPageCatalog.pageTypesByPackage.getValue("com.jingdong.app.mall"), jd.registeredPageTypes)
        assertEquals(QianjiPageCatalog.pageTypesByPackage.getValue("com.sankuai.meituan"), meituan.registeredPageTypes)

        val fixtures = fixtures()
        assertEquals(21, fixtures.size)
        assertEquals(21, fixtures.map(Fixture::pageType).toSet().size)
        for (fixture in fixtures) {
            val result = fixture.parser.parse(fixture.nodes, observedAt)
            // Qianji registers VoucherDetail before GrouponDetail. The latter's
            // complete gate is a subset of the former and is shadowed.
            val expectedPageType = if (fixture.pageType == "MeiTuanGrouponDetail") {
                "MeiTuanVoucherDetail"
            } else {
                fixture.pageType
            }
            assertEquals("wrong first-match page for ${fixture.pageType}", expectedPageType, result.pageType)
            assertNotNull("missing candidate for ${fixture.pageType}: ${result.rejectionReason}", result.candidate)
            assertEquals(fixture.expectedType, result.candidate?.transactionType)
            assertEquals("${fixture.pageType} amount", 1880L, result.candidate?.amountInCents)
            assertEquals("${fixture.pageType} source", expectedSource(fixture.pageType), result.candidate?.sourceApp)
            assertEquals("QIANJI_$expectedPageType", result.candidate?.scene?.scene)
        }
    }

    @Test
    fun unionPayActivityGateMatchesProfileRulesAndBlocksLegacyFallback() {
        assertTrue(unionpay.acceptsActivity(null))
        assertTrue(unionpay.acceptsActivity("com.unionpay.activity.PaySuccess"))
        assertFalse(unionpay.acceptsActivity("com.example.NotUnionPay"))
        assertFalse(unionpay.acceptsActivity("com.unionpay.activity.UPActivityMain"))

        val registry = QianjiProfilePageParserRegistry(
            listOf(
                QianjiWechatPageParser(), QianjiAlipayPageParser(), QianjiPddPageParser(),
                QianjiUnionpayPageParser(), QianjiJingDongPageParser(), QianjiMeituanPageParser(),
                QianjiDouyinPageParser(),
            ),
        )
        val result = registry.inspect(
            "com.unionpay",
            fixtures().first { it.pageType == "UnionpayPaySuccess" }.nodes,
            observedAt,
            "com.unionpay.activity.UPActivityMain",
        )
        assertNotNull(result)
        assertTrue(result!!.profileGateRejected)
        assertNull(result.candidate)
    }

    @Test
    fun qianjiStatusCandidatesKeepRefundAndPendingSemanticsVisibleForConfirmation() {
        val fixtures = fixtures().associateBy(Fixture::pageType)
        val refundPages = listOf(
            "JingDongWalletBillDetail",
            "JingDongWalletBillDetailV2",
            "MeiTuanWalletBillDetail",
        )
        for (page in refundPages) {
            val fixture = fixtures.getValue(page)
            val refundNodes = when (page) {
                "JingDongWalletBillDetail" -> fixture.nodes.map { node ->
                    if (node.label == "交易成功") node.copy(text = "已退款(￥18.80)") else node
                }
                "JingDongWalletBillDetailV2" -> fixture.nodes.map { node ->
                    if (node.label.startsWith("交易成功")) node.copy(text = "已退款(￥18.80)") else node
                }
                else -> fixture.nodes
            }
            val result = fixture.parser.parse(refundNodes, observedAt)
            assertNotNull("Qianji creates a default-direction candidate for $page", result.candidate)
            assertEquals("EXPENSE", result.candidate?.transactionType)
            assertTrue(result.candidate?.note.orEmpty().contains("退款"))
        }

        val waitingOrder = fixtures.getValue("JingDongOrderDetail")
        val waitingResult = waitingOrder.parser.parse(waitingOrder.nodes, observedAt)
        assertNotNull(waitingResult.candidate)
        assertTrue(waitingResult.candidate?.note.orEmpty().contains("等待收货"))

        val expectedDelivery = fixtures.getValue("MeiTuanDeliveryDetail")
        assertNotNull(expectedDelivery.parser.parse(expectedDelivery.nodes, observedAt).candidate)

        val noMatch = unionpay.parse(listOf(text("普通云闪付首页")), observedAt)
        assertFalse(noMatch.blocksLegacyFallback)
        assertNull(noMatch.pageType)
    }

    private fun expectedSource(pageType: String): String = when {
        pageType.startsWith("Unionpay") -> "UNIONPAY"
        pageType.startsWith("JingDong") -> "JD"
        else -> "MEITUAN"
    }
}
