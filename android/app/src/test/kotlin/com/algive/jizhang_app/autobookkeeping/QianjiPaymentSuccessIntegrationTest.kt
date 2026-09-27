package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class QianjiPaymentSuccessIntegrationTest {
    private val detector = PaymentSceneDetector()

    @Test
    fun sevenSupportedAppsReachCandidateFromPaymentOrBillSuccessPage() {
        val cases = listOf(
            Case(
                "com.tencent.mm",
                "WeChatPaySuccess",
                listOf(
                    node(desc = "支付成功", clazz = "android.view.ViewGroup"),
                    node("支付成功"), node("测试收款人（**明）"), node("¥1.00"),
                    node(desc = "完成", clazz = "android.widget.Button"), node("完成"),
                ),
                "com.tencent.mm.framework.app.UIPageFragmentActivity",
            ),
            Case(
                "com.eg.android.AlipayGphone",
                "AlipayPaySuccess",
                listOf(node("支付成功"), node("支付成功￥9.90"), node("￥9.90"), node("完成")),
            ),
            Case(
                "com.xunmeng.pinduoduo",
                "PddWalletBillDetail",
                labels(
                    "账单详情", "当前状态", "支付成功", "商品详情", "抹茶拿铁",
                    "支付时间", "2026-09-05 10:11:12", "支付方式", "微信支付",
                    "交易单号", "PDD12345", "商户单号", "MERCHANT123", "茶饮店", "¥12.80",
                ),
            ),
            Case(
                "com.unionpay",
                "UnionpayPaySuccess",
                labels("支付成功", "付款方式", "中国银行", "完成", "¥18.80"),
                "com.unionpay.activity.PaySuccess",
            ),
            Case(
                "com.jingdong.app.mall",
                "JingDongPaySuccess",
                listOf(node("支付成功"), node("京东白条 ¥18.80 共优惠¥2.00")),
            ),
            Case(
                "com.sankuai.meituan",
                "MeiTuanPaySuccess",
                listOf(
                    node("支付成功", clazz = "android.webkit.WebView"),
                    node("支付成功 ¥18.80"),
                ),
            ),
            Case(
                "com.ss.android.ugc.aweme",
                "DouyingPaySuccess",
                listOf(
                    node("支付成功", clazz = FLATTEN), node("¥9.99", clazz = FLATTEN),
                    node("支付方式", clazz = FLATTEN), node("抖音支付（支付宝）", clazz = FLATTEN),
                    node("支付时间", clazz = FLATTEN), node("2026-09-10 15:16:17", clazz = FLATTEN),
                    node("完成", clazz = FLATTEN),
                ),
            ),
        )

        cases.forEach { case ->
            val result = detector.inspect(
                packageName = case.packageName,
                nodes = case.nodes,
                timestamp = 1_800_000_000_000L,
                activityClassName = case.activityClassName,
            )
            assertNotNull("${case.pageType}: ${result.rejectionReason}", result.candidate)
            assertEquals("QIANJI_${case.pageType}", result.candidate?.scene?.scene)
        }
    }

    private data class Case(
        val packageName: String,
        val pageType: String,
        val nodes: List<ScreenNode>,
        val activityClassName: String? = null,
    )

    private fun labels(vararg labels: String) = labels.map(::node)

    private fun node(
        text: String = "",
        desc: String = "",
        clazz: String = "android.widget.TextView",
    ) = ScreenNode(text = text, contentDescription = desc, className = clazz)

    private companion object {
        const val FLATTEN = "com.lynx.tasm.behavior.ui.text.FlattenUIText"
    }
}
