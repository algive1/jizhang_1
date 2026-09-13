package com.algive.jizhang_app.autobookkeeping.category

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate

data class CatalogItem(val id: String, val name: String, val bookId: String, val type: String = "", val assetBookId: String = bookId)
data class MerchantPreference(val merchantKey: String, val categoryId: String, val accountId: String, val bookId: String, val tags: List<String>, val useCount: Int, val lastUsedAt: Long)
enum class CategorySource { USER_HISTORY, MERCHANT_DICTIONARY, KEYWORD, LOCAL_MODEL, AI }
data class CategoryResolution(val categoryId: String?, val categoryName: String?, val confidence: Double, val source: CategorySource)
interface AiCategoryProvider { fun resolve(candidate: PaymentCandidate): CategoryResolution? }
class CategoryResolver {
    fun resolve(c: PaymentCandidate, categories: List<CatalogItem>, history: MerchantPreference?): CategoryResolution {
        categories.firstOrNull { it.id == history?.categoryId }?.let { return CategoryResolution(it.id, it.name, .99, CategorySource.USER_HISTORY) }
        val brand = when(c.merchantNormalized) { "麦当劳", "肯德基", "瑞幸咖啡", "星巴克" -> "餐饮"; "滴滴" -> "交通"; else -> null }
        val keyword = listOf("餐", "饭", "咖啡", "奶茶").any { c.merchantNormalized.contains(it) }
        val target = brand ?: if (keyword) "餐饮" else null
        val category = categories.firstOrNull { target != null && it.name.contains(target) }
        return CategoryResolution(category?.id, category?.name, if (category == null) 0.0 else if (brand != null) .9 else .78, if (brand != null) CategorySource.MERCHANT_DICTIONARY else CategorySource.KEYWORD)
    }
}
