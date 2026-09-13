package com.algive.jizhang_app.autobookkeeping.repository
import com.algive.jizhang_app.autobookkeeping.category.CatalogItem

object PaymentAccountResolver {
    fun resolve(method: String, accounts: List<CatalogItem>, mappedId: String?): CatalogItem? {
        accounts.singleOrNull { it.id == mappedId }?.let { return it }
        if (method == "UNKNOWN") return null
        accounts.singleOrNull { it.name == method }?.let { return it }
        // No card number field exists in this project. Only an unambiguous suffix in a user-named account is usable.
        val suffix = Regex("(?:尾号|[（(])\\s*(\\d{4})").find(method)?.groupValues?.get(1)
        if (suffix != null) return accounts.singleOrNull { it.type in setOf("debitCard", "creditCard") && it.name.contains(suffix) }
        if (method in setOf("零钱", "微信零钱")) return accounts.singleOrNull { it.type == "wechat" && it.name in setOf("微信", "微信零钱", "零钱") }
        return null
    }
}
