package com.algive.jizhang_app.autobookkeeping.rules

import android.content.Context
import com.algive.jizhang_app.autobookkeeping.AutoBookkeepingCustomApps
import org.json.JSONArray
import org.json.JSONObject

enum class PaymentParserKind {
    WECHAT,
    MEITUAN,
    GENERIC,
}

enum class SuccessMatchMode {
    EXACT,
    PREFIX,
}

data class AppPaymentRule(
    val packageNames: Set<String>,
    val sourceApp: String,
    val scene: String,
    val version: Int,
    val parserKind: PaymentParserKind,
    val successMatchMode: SuccessMatchMode,
    val successMarkers: Set<String>,
    val rejectMarkers: Set<String>,
    val merchantKeys: Set<String>,
    val amountKeys: Set<String>,
    val methodKeys: Set<String>,
    val excludedAmountLabels: Set<String>,
    val fallbackMerchantBlockedLabels: Set<String> = emptySet(),
    val fallbackMerchantBlockedFragments: Set<String> = emptySet(),
    val activityHints: Set<String> = emptySet(),
) {
    fun isSuccessLabel(label: String): Boolean =
        successMarkers.any { marker ->
            when (successMatchMode) {
                SuccessMatchMode.EXACT -> label == marker
                SuccessMatchMode.PREFIX -> label == marker || label.startsWith(marker)
            }
        }

    fun hasRejectedStatus(labels: List<String>): Boolean =
        rejectMarkers.isNotEmpty() &&
            labels.any { label -> rejectMarkers.any(label::contains) }
}

/**
 * Versioned, local-only payment-page rules.
 *
 * The JSON asset can change labels and package mappings, but cannot inject
 * executable code or regexes. Any malformed/unsupported asset falls back to
 * the built-in conservative rules so automatic bookkeeping keeps working.
 */
class AutoBookkeepingRuleRegistry private constructor(
    val schemaVersion: Int,
    private val rules: List<AppPaymentRule>,
    val loadedFromAsset: Boolean,
    /**
     * Package names the user added themselves. They are not part of [rules]; they
     * resolve to the generic template instead, which is how an app the packaged
     * rule set does not know about can still be recognised.
     */
    val customPackages: Set<String> = emptySet(),
) {
    private val byPackage: Map<String, AppPaymentRule> = buildMap {
        rules.forEach { rule ->
            rule.packageNames.forEach { packageName -> put(packageName, rule) }
        }
    }

    val supportedPackages: Set<String> get() = byPackage.keys + customPackages

    fun ruleFor(packageName: String): AppPaymentRule? =
        byPackage[packageName] ?: customRuleFor(packageName)

    /** True when the package is user-added rather than covered by a shipped rule. */
    fun isCustom(packageName: String): Boolean =
        packageName !in byPackage && packageName in customPackages

    /**
     * The generic template, re-stamped with the user's package. Reusing a shipped
     * GENERIC rule verbatim means custom apps inherit the same success/reject
     * markers, amount labels and exclusion list that the audited rules use —
     * there is no second, weaker rule dialect to keep correct.
     */
    private fun customRuleFor(packageName: String): AppPaymentRule? {
        if (packageName !in customPackages) return null
        val template = rules.firstOrNull { it.parserKind == PaymentParserKind.GENERIC }
            ?: return null
        return template.copy(
            packageNames = setOf(packageName),
            sourceApp = CUSTOM_SOURCE,
            scene = CUSTOM_SCENE,
        )
    }

    /** The same rule set with a different user-added package list. */
    fun withCustomPackages(packages: Set<String>): AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry(
            schemaVersion = schemaVersion,
            rules = rules,
            loadedFromAsset = loadedFromAsset,
            customPackages = packages,
        )

    fun ruleForKind(kind: PaymentParserKind): AppPaymentRule? =
        rules.firstOrNull { it.parserKind == kind }

    fun versionsSummary(): String =
        rules.joinToString(",") { "${it.sourceApp}:v${it.version}" } +
            if (customPackages.isEmpty()) "" else ",custom:${customPackages.size}"

    companion object {
        private const val ASSET_PATH = "autobookkeeping_rules_v1.json"
        private const val SUPPORTED_SCHEMA = 1

        /** Reported for user-added packages so diagnostics never claim a real app. */
        const val CUSTOM_SOURCE = "CUSTOM"
        private const val CUSTOM_SCENE = "CUSTOM_PAYMENT_SUCCESS"

        private val ALLOWED_PACKAGES = setOf(
            "com.tencent.mm",
            "com.eg.android.AlipayGphone",
            "com.unionpay",
            "com.sankuai.meituan",
            "com.sankuai.meituan.takeout",
            "com.jingdong.app.mall",
            "com.xunmeng.pinduoduo",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.mobile",
            // 抖音极速版 — a separate app with its own package id.
            "com.ss.android.ugc.aweme.lite",
            "com.taobao.taobao",
            // 1号会员店
            "com.thestore.main",
        )

        private val ALLOWED_SOURCES = setOf(
            "WECHAT",
            "ALIPAY",
            "UNIONPAY",
            "MEITUAN",
            "JD",
            "PINDUODUO",
            "DOUYIN",
            "TAOBAO",
            "ONESTORE",
        )

        fun load(context: Context): AutoBookkeepingRuleRegistry =
            runCatching {
                val raw = context.assets.open(ASSET_PATH)
                    .bufferedReader()
                    .use { it.readText() }
                parse(raw, AutoBookkeepingCustomApps.all(context))
            }.getOrElse {
                builtIn(AutoBookkeepingCustomApps.all(context))
            }

        fun builtIn(
            customPackages: Set<String> = emptySet(),
        ): AutoBookkeepingRuleRegistry =
            AutoBookkeepingRuleRegistry(
                schemaVersion = SUPPORTED_SCHEMA,
                rules = builtInRules(),
                loadedFromAsset = false,
                customPackages = customPackages,
            )

        private fun parse(
            raw: String,
            customPackages: Set<String>,
        ): AutoBookkeepingRuleRegistry {
            val root = JSONObject(raw)
            val schemaVersion = root.optInt("schemaVersion", -1)
            require(schemaVersion == SUPPORTED_SCHEMA) {
                "Unsupported auto-bookkeeping rule schema"
            }
            val array = root.optJSONArray("rules")
                ?: error("Missing auto-bookkeeping rules")
            require(array.length() in 1..32) { "Invalid rule count" }

            val parsedRules = buildList {
                for (index in 0 until array.length()) {
                    add(parseRule(array.getJSONObject(index)))
                }
            }
            validateRuleSet(parsedRules)
            return AutoBookkeepingRuleRegistry(
                schemaVersion = schemaVersion,
                rules = parsedRules,
                loadedFromAsset = true,
                customPackages = customPackages,
            )
        }

        private fun parseRule(json: JSONObject): AppPaymentRule {
            val packages = json.stringSet("packages")
            val sourceApp = json.getString("sourceApp").trim()
            val scene = json.getString("scene").trim()
            val version = json.getInt("version")
            val parserKind = PaymentParserKind.valueOf(
                json.getString("parserKind").trim().uppercase(),
            )
            val successMatchMode = SuccessMatchMode.valueOf(
                json.optString("successMatchMode", "PREFIX")
                    .trim()
                    .uppercase(),
            )
            return AppPaymentRule(
                packageNames = packages,
                sourceApp = sourceApp,
                scene = scene,
                version = version,
                parserKind = parserKind,
                successMatchMode = successMatchMode,
                successMarkers = json.stringSet("successMarkers"),
                rejectMarkers = json.stringSet("rejectMarkers", required = false),
                merchantKeys = json.stringSet("merchantKeys"),
                amountKeys = json.stringSet("amountKeys"),
                methodKeys = json.stringSet("methodKeys"),
                excludedAmountLabels =
                    json.stringSet("excludedAmountLabels", required = false),
                fallbackMerchantBlockedLabels =
                    json.stringSet("fallbackMerchantBlockedLabels", required = false),
                fallbackMerchantBlockedFragments =
                    json.stringSet("fallbackMerchantBlockedFragments", required = false),
                activityHints =
                    json.stringSet("activityHints", required = false),
            ).also(::validateRule)
        }

        private fun JSONObject.stringSet(
            key: String,
            required: Boolean = true,
        ): Set<String> {
            val array = optJSONArray(key)
            if (array == null) {
                require(!required) { "Missing $key" }
                return emptySet()
            }
            require(array.length() <= 64) { "Too many $key entries" }
            return array.asStrings().toSet()
        }

        private fun JSONArray.asStrings(): List<String> = buildList {
            for (index in 0 until length()) {
                val value = getString(index).trim()
                require(value.length in 1..100) { "Invalid rule text length" }
                add(value)
            }
        }

        private fun validateRule(rule: AppPaymentRule) {
            require(rule.packageNames.isNotEmpty())
            require(rule.packageNames.all { it in ALLOWED_PACKAGES })
            require(rule.sourceApp in ALLOWED_SOURCES)
            require(rule.scene.length in 1..80)
            require(rule.version in 1..999)
            require(rule.successMarkers.isNotEmpty())
            require(rule.merchantKeys.isNotEmpty())
            require(rule.amountKeys.isNotEmpty())
            require(rule.methodKeys.isNotEmpty())
            require(rule.activityHints.size <= 20)
        }

        private fun validateRuleSet(rules: List<AppPaymentRule>) {
            val packages = rules.flatMap { it.packageNames }
            require(packages.size == packages.toSet().size) {
                "Duplicate package rules"
            }
            // A bundled rules file must never silently drop a supported app.
            require(packages.toSet() == ALLOWED_PACKAGES) {
                "Rule package set does not match supported apps"
            }
            require(rules.count { it.parserKind == PaymentParserKind.WECHAT } == 1)
            require(rules.count { it.parserKind == PaymentParserKind.MEITUAN } == 1)
        }

        private fun builtInRules(): List<AppPaymentRule> {
            val amountKeys = setOf(
                "实付",
                "实付金额",
                "付款金额",
                "支付金额",
                "实际支付",
                "消费金额",
                "扣款金额",
            )
            val methodKeys = setOf("支付方式", "付款方式", "支付渠道")
            val excluded = setOf(
                "优惠",
                "余额",
                "订单",
                "时间",
                "积分",
                "原价",
                "商品金额",
                "合计",
                "立减",
                "红包",
            )
            val genericSuccess = setOf(
                "支付成功",
                "付款成功",
                "交易成功",
                "已支付",
                "支付完成",
                "付款完成",
                "订单支付成功",
            )
            val genericMerchant = setOf(
                "收款方",
                "商户",
                "商户名称",
                "商家",
                "店铺",
                "门店",
            )
            val genericRules = listOf(
                Triple(setOf("com.eg.android.AlipayGphone"), "ALIPAY", "ALIPAY_PAYMENT_SUCCESS"),
                Triple(setOf("com.unionpay"), "UNIONPAY", "UNIONPAY_PAYMENT_SUCCESS"),
                Triple(setOf("com.jingdong.app.mall"), "JD", "JD_PAYMENT_SUCCESS"),
                Triple(setOf("com.xunmeng.pinduoduo"), "PINDUODUO", "PINDUODUO_PAYMENT_SUCCESS"),
                Triple(
                    setOf(
                        "com.ss.android.ugc.aweme",
                        "com.ss.android.ugc.aweme.mobile",
                    ),
                    "DOUYIN",
                    "DOUYIN_PAYMENT_SUCCESS",
                ),
            ).map { (packages, source, scene) ->
                AppPaymentRule(
                    packageNames = packages,
                    sourceApp = source,
                    scene = scene,
                    version = 1,
                    parserKind = PaymentParserKind.GENERIC,
                    successMatchMode = SuccessMatchMode.PREFIX,
                    successMarkers = genericSuccess,
                    rejectMarkers = emptySet(),
                    merchantKeys = genericMerchant,
                    amountKeys = amountKeys,
                    methodKeys = methodKeys,
                    excludedAmountLabels = excluded,
                )
            }

            return listOf(
                AppPaymentRule(
                    packageNames = setOf("com.tencent.mm"),
                    sourceApp = "WECHAT",
                    scene = "WECHAT_PAYMENT_SUCCESS",
                    version = 1,
                    parserKind = PaymentParserKind.WECHAT,
                    successMatchMode = SuccessMatchMode.EXACT,
                    successMarkers = setOf(
                        "支付成功",
                        "付款成功",
                        "已支付",
                        "支付完成",
                    ),
                    rejectMarkers = setOf(
                        "支付失败",
                        "付款失败",
                        "交易失败",
                    ),
                    merchantKeys = setOf(
                        "收款方",
                        "商户",
                        "商户名称",
                        "收款商户",
                        "收款单位",
                    ),
                    amountKeys = setOf(
                        "实付",
                        "实付金额",
                        "付款金额",
                        "支付金额",
                        "实际支付",
                    ),
                    methodKeys = setOf("支付方式", "付款方式"),
                    excludedAmountLabels = excluded,
                    fallbackMerchantBlockedLabels = setOf(
                        "微信",
                        "微信支付",
                        "转账",
                        "红包",
                        "扫一扫",
                        "完成",
                        "返回",
                        "更多",
                        "查看账单",
                        "账单详情",
                    ),
                    activityHints = setOf(
                        "WalletPayUI",
                        "WalletOrderInfo",
                        "WalletOfflineCoinPurseUI",
                        "WalletOrderInfoNewUI",
                        "UIPageFragmentActivity",
                    ),
                ),
                AppPaymentRule(
                    packageNames = setOf(
                        "com.sankuai.meituan",
                        "com.sankuai.meituan.takeout",
                    ),
                    sourceApp = "MEITUAN",
                    scene = "MEITUAN_PAYMENT_SUCCESS",
                    version = 1,
                    parserKind = PaymentParserKind.MEITUAN,
                    successMatchMode = SuccessMatchMode.PREFIX,
                    successMarkers = setOf(
                        "支付成功",
                        "付款成功",
                        "交易成功",
                        "订单支付成功",
                        "订单已支付",
                        "订单支付完成",
                        "支付完成",
                        "付款完成",
                        "支付已完成",
                        "付款已完成",
                        "交易已完成",
                        "已支付",
                        "已付款",
                    ),
                    rejectMarkers = setOf(
                        "待支付",
                        "待付款",
                        "去支付",
                        "去付款",
                        "未支付",
                        "未付款",
                        "支付失败",
                        "付款失败",
                        "交易失败",
                        "支付取消",
                        "付款取消",
                        "取消支付",
                        "重新支付",
                        "支付提醒",
                    ),
                    merchantKeys = setOf(
                        "商户",
                        "商户名称",
                        "商家",
                        "商家名称",
                        "订单商家",
                        "店铺",
                        "店铺名称",
                        "门店",
                        "收款方",
                    ),
                    amountKeys = amountKeys + "订单实付",
                    methodKeys = methodKeys,
                    excludedAmountLabels = setOf(
                        "优惠",
                        "红包",
                        "立减",
                        "原价",
                        "商品金额",
                        "配送费",
                        "打包费",
                        "会员",
                        "积分",
                        "应付",
                    ),
                    fallbackMerchantBlockedLabels = setOf(
                        "美团",
                        "美团外卖",
                        "订单详情",
                        "支付详情",
                        "查看订单",
                        "完成",
                        "返回",
                        "支付方式",
                        "付款方式",
                        "支付渠道",
                    ),
                    fallbackMerchantBlockedFragments = setOf(
                        "订单",
                        "支付",
                        "付款",
                        "金额",
                        "优惠",
                        "完成",
                        "详情",
                        "返回",
                        "时间",
                        "方式",
                        "渠道",
                        "美团",
                    ),
                ),
            ) + genericRules
        }
    }
}
