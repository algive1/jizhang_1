package com.algive.jizhang_app.autobookkeeping.merchant

object MerchantNormalizer {
    val brands = linkedMapOf("麦当劳" to listOf("麦当劳", "mcdonald"), "肯德基" to listOf("肯德基", "kfc"), "瑞幸咖啡" to listOf("瑞幸", "luckin"), "星巴克" to listOf("星巴克", "starbucks"), "美团" to listOf("美团"), "滴滴" to listOf("滴滴"))
    fun normalize(raw: String): String {
        val value = raw.trim().lowercase()
        return brands.entries.firstOrNull { (_, aliases) -> aliases.any { value.contains(it) } }?.key
            ?: raw.replace(Regex("[（(][^()（）]*[)）]"), "").trim().take(80)
    }
}
