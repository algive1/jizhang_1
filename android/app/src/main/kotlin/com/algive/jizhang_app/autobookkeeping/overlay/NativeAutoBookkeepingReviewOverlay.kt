package com.algive.jizhang_app.autobookkeeping.overlay

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.InputType
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.PopupMenu
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToLong

/**
 * Immediate native confirmation surface shown by [AutoBillOverlayService].
 *
 * The view deliberately owns presentation and lightweight selection state only.
 * Books/accounts/categories and the final save are still resolved by Flutter,
 * which keeps the existing bookkeeping, learning, attachment and dedup logic as
 * the single source of truth.
 */
class NativeAutoBookkeepingReviewOverlay(
    private val context: Context,
    private val candidate: PaymentCandidate,
    private val onCancel: () -> Unit,
    private val onSubmit: (Map<String, Any?>) -> Unit,
    private val onAdvanced: () -> Unit,
) {
    data class Option(
        val id: String,
        val label: String,
        val type: String? = null,
        val parentId: String? = null,
        val sortOrder: Int = 0,
    )

    private val orange = Color.rgb(232, 139, 48)
    private val orangeSoft = Color.rgb(255, 239, 218)
    private val cardColor = Color.rgb(255, 249, 241)
    private val surfaceColor = Color.rgb(255, 252, 247)
    private val dividerColor = Color.rgb(231, 216, 199)
    private val primaryText = Color.rgb(48, 39, 32)
    private val secondaryText = Color.rgb(119, 105, 92)

    val root = FrameLayout(context).apply {
        isClickable = true
        isFocusableInTouchMode = true
        setBackgroundColor(Color.argb(82, 0, 0, 0))
        setOnKeyListener { _, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                onCancel()
                true
            } else {
                false
            }
        }
    }

    private val card = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(12), dp(6), dp(12), dp(10))
        background = rounded(cardColor, 28f)
        elevation = dp(14).toFloat()
    }

    private val categoriesGrid = GridLayout(context).apply {
        columnCount = 5
        rowCount = 3
        alignmentMode = GridLayout.ALIGN_BOUNDS
        useDefaultMargins = false
        setPadding(dp(2), dp(2), dp(2), dp(2))
        background = rounded(surfaceColor, 22f, dividerColor, 1)
    }

    private val noteField = EditText(context).apply {
        setSingleLine(true)
        setText(candidate.merchantNormalized)
        setTextColor(primaryText)
        setHintTextColor(secondaryText)
        hint = "添加备注..."
        textSize = 15f
        setPadding(dp(8), 0, dp(4), 0)
        background = null
    }

    private val amountField = EditText(context).apply {
        setSingleLine(true)
        inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
        setText("%.2f".format(Locale.US, candidate.amountInCents / 100.0))
        setTextColor(primaryText)
        textSize = 34f
        typeface = Typeface.DEFAULT_BOLD
        gravity = Gravity.CENTER_VERTICAL
        setSelectAllOnFocus(true)
        setPadding(dp(12), 0, dp(8), 0)
        background = null
    }

    private val amountMirror = TextView(context).apply {
        text = "= ¥${"%.2f".format(Locale.US, candidate.amountInCents / 100.0)}"
        setTextColor(orange)
        textSize = 24f
        typeface = Typeface.DEFAULT_BOLD
        gravity = Gravity.CENTER_VERTICAL or Gravity.END
        setPadding(dp(4), 0, dp(12), 0)
    }

    @Suppress("DEPRECATION")
    private val screenshotSwitch = Switch(context).apply {
        isChecked = true
    }

    private lateinit var accountChip: TextView
    private lateinit var reimbursementChip: TextView
    private lateinit var bookChip: TextView
    private lateinit var destinationChip: TextView
    private lateinit var dateChip: TextView

    private val statusText = TextView(context).apply {
        setTextColor(orange)
        textSize = 12f
        gravity = Gravity.CENTER
        visibility = View.GONE
        setPadding(dp(4), dp(2), dp(4), dp(2))
    }

    private val completeButton = actionButton("✓  完成", filled = true) {
        hideKeyboard()
        onSubmit(buildDraft())
    }

    private val typeTabs = linkedMapOf<String, TextView>()

    private var bookOptions: List<Option> = emptyList()
    private var accountOptions: List<Option> = emptyList()
    private var categoryOptions: List<Option> = emptyList()
    private var selectedBookId: String? = null
    private var selectedAccountId: String? = null
    private var selectedDestinationAccountId: String? = null
    private var selectedCategoryId: String? = null
    private var selectedSubcategoryId: String? = null
    private var selectedCategoryName: String? = null
    private var transactionType: String = initialType()
    private var reimbursementStatus: String = "none"
    private var occurredAtMillis: Long = candidate.timestamp
    private var userSelectedCategory = false
    private var userSelectedType = false
    private var flutterReady = false

    init {
        accountChip = selectorChip(initialAccountLabel()) {
            showOptions(accountChip, accountOptions, selectedAccountId) {
                selectedAccountId = it.id
                accountChip.text = it.label
            }
        }
        reimbursementChip = selectorChip("不报销") {
            val options = listOf(
                Option("none", "不报销"),
                Option("pending", "待报销"),
                Option("reimbursed", "已报销"),
                Option("partial", "部分报销"),
            )
            showOptions(reimbursementChip, options, reimbursementStatus) {
                reimbursementStatus = it.id
                reimbursementChip.text = it.label
            }
        }
        bookChip = selectorChip("个人账本") {
            showOptions(bookChip, bookOptions, selectedBookId) {
                selectedBookId = it.id
                bookChip.text = it.label
            }
        }
        destinationChip = selectorChip("转入账户") {
            showOptions(destinationChip, accountOptions, selectedDestinationAccountId) {
                selectedDestinationAccountId = it.id
                destinationChip.text = "转入 ${it.label}"
            }
        }.apply {
            visibility = View.GONE
        }
        dateChip = selectorChip(dateLabel(occurredAtMillis)) {
            val now = System.currentTimeMillis()
            val day = 24L * 60L * 60L * 1000L
            val options = listOf(
                Option(now.toString(), "今天"),
                Option((now - day).toString(), "昨天"),
                Option((now - 2 * day).toString(), "前天"),
                Option("advanced", "更多日期…"),
            )
            showOptions(dateChip, options, occurredAtMillis.toString()) { selected ->
                if (selected.id == "advanced") {
                    onAdvanced()
                } else {
                    occurredAtMillis = selected.id.toLongOrNull() ?: occurredAtMillis
                    dateChip.text = selected.label
                }
            }
        }

        build()
        renderTypeTabs()
        renderCategories()
        updateTransferState()
        amountField.setOnFocusChangeListener { _, hasFocus ->
            if (!hasFocus) refreshAmountMirror()
        }
    }

    fun setBottomInset(bottomInset: Int) {
        val params = card.layoutParams as? FrameLayout.LayoutParams ?: return
        val target = maxOf(bottomInset, dp(4))
        if (params.bottomMargin != target) {
            params.bottomMargin = target
            card.layoutParams = params
        }
    }

    fun setFlutterReady(ready: Boolean) {
        flutterReady = ready
        if (ready && statusText.text == "正在准备保存引擎…") {
            showMessage(null)
        }
    }

    fun syncFromFlutter(payload: Map<*, *>) {
        val previousCategoryName = selectedCategoryName
        val previousType = transactionType

        bookOptions = parseOptions(payload["books"])
        accountOptions = parseOptions(payload["accounts"])
        categoryOptions = parseOptions(payload["categories"])

        if (selectedBookId == null || bookOptions.none { it.id == selectedBookId }) {
            selectedBookId = payload["selectedBookId"]?.toString()
                ?.takeIf { id -> bookOptions.any { it.id == id } }
                ?: bookOptions.firstOrNull()?.id
        }
        bookChip.text = bookOptions.firstOrNull { it.id == selectedBookId }?.label ?: "个人账本"

        if (selectedAccountId == null || accountOptions.none { it.id == selectedAccountId }) {
            selectedAccountId = payload["selectedAccountId"]?.toString()
                ?.takeIf { id -> accountOptions.any { it.id == id } }
                ?: accountOptions.firstOrNull()?.id
        }
        accountChip.text = accountOptions.firstOrNull { it.id == selectedAccountId }?.label
            ?: initialAccountLabel()

        if (selectedDestinationAccountId == null ||
            accountOptions.none { it.id == selectedDestinationAccountId }
        ) {
            selectedDestinationAccountId = payload["selectedDestinationAccountId"]?.toString()
                ?.takeIf { id -> accountOptions.any { it.id == id } }
        }
        destinationChip.text = selectedDestinationAccountId?.let { id ->
            accountOptions.firstOrNull { it.id == id }?.let { "转入 ${it.label}" }
        } ?: "转入账户"

        if (!userSelectedType) {
            transactionType = payload["transactionType"]?.toString()
                ?.takeIf { it in setOf("expense", "income", "transfer") }
                ?: previousType
        }

        selectedCategoryId = if (userSelectedCategory && previousCategoryName != null) {
            categoryOptions.firstOrNull {
                it.parentId == null &&
                    it.type == categoryTypeFor(transactionType) &&
                    it.label == previousCategoryName
            }?.id
        } else {
            payload["selectedCategoryId"]?.toString()
                ?.takeIf { id -> categoryOptions.any { it.id == id } }
        }
        selectedSubcategoryId = payload["selectedSubcategoryId"]?.toString()
            ?.takeIf { id -> categoryOptions.any { it.id == id } }
        selectedCategoryName = categoryOptions.firstOrNull { it.id == selectedCategoryId }?.label
            ?: previousCategoryName

        val occurredAt = (payload["occurredAt"] as? Number)?.toLong()
        if (occurredAt != null && occurredAt > 0L) {
            occurredAtMillis = occurredAt
            dateChip.text = dateLabel(occurredAtMillis)
        }
        if (payload["screenshotEnabled"] is Boolean) {
            screenshotSwitch.isChecked = payload["screenshotEnabled"] == true
        }

        flutterReady = true
        renderTypeTabs()
        renderCategories()
        updateTransferState()
    }

    fun showMessage(message: String?) {
        if (message.isNullOrBlank()) {
            statusText.text = ""
            statusText.visibility = View.GONE
        } else {
            statusText.text = message
            statusText.visibility = View.VISIBLE
        }
    }

    fun setSaving(saving: Boolean) {
        completeButton.isEnabled = !saving
        completeButton.alpha = if (saving) .6f else 1f
        completeButton.text = if (saving) "保存中…" else "✓  完成"
    }

    fun currentDraft(): Map<String, Any?> = buildDraft()

    private fun build() {
        val cardHeight = (context.resources.displayMetrics.heightPixels * .61f).toInt()
        root.addView(
            card,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                cardHeight,
                Gravity.BOTTOM,
            ).apply {
                leftMargin = dp(12)
                rightMargin = dp(12)
                bottomMargin = dp(6)
            },
        )

        card.addView(
            View(context).apply { background = rounded(Color.rgb(207, 196, 184), 999f) },
            LinearLayout.LayoutParams(dp(44), dp(5)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(4)
            },
        )

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(
            TextView(context).apply {
                text = "←"
                textSize = 34f
                setTextColor(primaryText)
                gravity = Gravity.CENTER
                setOnClickListener { onCancel() }
            },
            LinearLayout.LayoutParams(dp(44), dp(48)),
        )
        val tabHost = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            background = rounded(surfaceColor, 23f, dividerColor, 1)
            setPadding(dp(2), dp(2), dp(2), dp(2))
        }
        listOf(
            "expense" to "支出",
            "income" to "收入",
            "transfer" to "转账",
            "debt" to "债务",
        ).forEach { (key, label) ->
            val tab = TextView(context).apply {
                text = label
                textSize = 15f
                gravity = Gravity.CENTER
                setTextColor(primaryText)
                setOnClickListener {
                    if (key == "debt") {
                        onAdvanced()
                    } else {
                        userSelectedType = true
                        transactionType = key
                        selectedCategoryId = null
                        selectedSubcategoryId = null
                        selectedCategoryName = null
                        renderTypeTabs()
                        renderCategories()
                        updateTransferState()
                    }
                }
            }
            typeTabs[key] = tab
            tabHost.addView(tab, LinearLayout.LayoutParams(0, dp(42), 1f))
        }
        header.addView(tabHost, LinearLayout.LayoutParams(0, dp(46), 1f))
        header.addView(
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL or Gravity.END
                addView(TextView(context).apply {
                    text = "自动截图"
                    textSize = 11f
                    setTextColor(secondaryText)
                    gravity = Gravity.CENTER_VERTICAL
                })
                addView(screenshotSwitch, LinearLayout.LayoutParams(dp(48), dp(44)))
            },
            LinearLayout.LayoutParams(dp(106), dp(48)),
        )
        card.addView(header, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(50)))

        card.addView(categoriesGrid, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(184),
        ).apply {
            topMargin = dp(4)
        })

        val detail = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(6))
            background = rounded(surfaceColor, 20f, dividerColor, 1)
        }
        val noteRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(TextView(context).apply {
                text = "✎"
                textSize = 22f
                setTextColor(secondaryText)
                gravity = Gravity.CENTER
            }, LinearLayout.LayoutParams(dp(34), dp(42)))
            addView(noteField, LinearLayout.LayoutParams(0, dp(42), 1f))
            addView(chip("✨ AI帮我记", true) { onAdvanced() },
                LinearLayout.LayoutParams(dp(104), dp(38)).apply { rightMargin = dp(4) })
            addView(chip("🎙", false) { onAdvanced() }, LinearLayout.LayoutParams(dp(42), dp(38)))
        }
        detail.addView(noteRow)

        val amountRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            background = rounded(Color.rgb(250, 239, 225), 20f)
            addView(amountField, LinearLayout.LayoutParams(0, dp(62), 1f))
            addView(amountMirror, LinearLayout.LayoutParams(dp(146), dp(62)))
        }
        detail.addView(amountRow, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(62),
        ).apply { topMargin = dp(2) })

        val primaryChips = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(accountChip, LinearLayout.LayoutParams(0, dp(40), 1f))
            addView(reimbursementChip, LinearLayout.LayoutParams(0, dp(40), 1f).apply {
                leftMargin = dp(6)
            })
            addView(bookChip, LinearLayout.LayoutParams(0, dp(40), 1f).apply {
                leftMargin = dp(6)
            })
        }
        detail.addView(primaryChips, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(40),
        ).apply { topMargin = dp(6) })

        detail.addView(destinationChip, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(40),
        ).apply { topMargin = dp(5) })

        val utilityChips = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(chip("📎 附件", false) { onAdvanced() }, LinearLayout.LayoutParams(0, dp(38), 1f))
            addView(chip("▣ 图片", false) { onAdvanced() }, LinearLayout.LayoutParams(0, dp(38), 1f).apply {
                leftMargin = dp(5)
            })
            addView(dateChip, LinearLayout.LayoutParams(0, dp(38), 1f).apply {
                leftMargin = dp(5)
            })
            addView(chip("◷ 定期付", false) { onAdvanced() }, LinearLayout.LayoutParams(0, dp(38), 1f).apply {
                leftMargin = dp(5)
            })
        }
        detail.addView(utilityChips, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(38),
        ).apply { topMargin = dp(5) })

        card.addView(
            ScrollView(context).apply {
                isFillViewport = true
                addView(detail)
            },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply {
                topMargin = dp(6)
            },
        )

        card.addView(statusText, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        val actions = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(actionButton("取消", false) { onCancel() }, LinearLayout.LayoutParams(0, dp(48), 1f))
            addView(completeButton, LinearLayout.LayoutParams(0, dp(48), 1f).apply {
                leftMargin = dp(10)
            })
        }
        card.addView(actions, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(48),
        ).apply {
            topMargin = dp(4)
        })
    }

    private fun renderTypeTabs() {
        typeTabs.forEach { (key, view) ->
            val selected = key == transactionType
            view.background = if (selected) rounded(orange, 20f) else null
            view.setTextColor(if (selected) Color.WHITE else primaryText)
            view.typeface = if (selected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
    }

    private fun renderCategories() {
        categoriesGrid.removeAllViews()
        val roots = if (categoryOptions.isNotEmpty()) {
            categoryOptions.filter {
                it.parentId == null && it.type == categoryTypeFor(transactionType)
            }.take(15)
        } else {
            fallbackCategories(transactionType)
        }
        for (option in roots) {
            val selected = option.id == selectedCategoryId ||
                (selectedCategoryId == null && option.label == selectedCategoryName)
            val tile = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(2), dp(2), dp(2), dp(2))
                background = if (selected) rounded(orangeSoft, 18f) else null
                addView(TextView(context).apply {
                    text = categoryGlyph(option.label)
                    textSize = 20f
                    gravity = Gravity.CENTER
                    setTextColor(orange)
                }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(28)))
                addView(TextView(context).apply {
                    text = option.label
                    textSize = 11.5f
                    gravity = Gravity.CENTER
                    maxLines = 1
                    setTextColor(if (selected) orange else primaryText)
                    typeface = if (selected) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(26)))
                setOnClickListener { anchor ->
                    userSelectedCategory = true
                    selectedCategoryId = option.id.takeIf { it.isNotBlank() }
                    selectedSubcategoryId = null
                    selectedCategoryName = option.label
                    renderCategories()
                    showSubcategoriesIfAny(anchor, option)
                }
            }
            categoriesGrid.addView(
                tile,
                GridLayout.LayoutParams().apply {
                    width = 0
                    height = dp(58)
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                },
            )
        }
        while (categoriesGrid.childCount < 15) {
            categoriesGrid.addView(
                View(context),
                GridLayout.LayoutParams().apply {
                    width = 0
                    height = dp(58)
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                },
            )
        }
    }

    private fun showSubcategoriesIfAny(anchor: View, rootOption: Option) {
        if (categoryOptions.isEmpty()) return
        val children = categoryOptions.filter { it.parentId == rootOption.id }
        if (children.isEmpty()) return
        val popup = PopupMenu(context, anchor)
        popup.menu.add(0, 0, 0, "仅使用${rootOption.label}")
        children.forEachIndexed { index, child ->
            popup.menu.add(0, index + 1, index + 1, child.label)
        }
        popup.setOnMenuItemClickListener { item ->
            selectedSubcategoryId = if (item.itemId == 0) null else children[item.itemId - 1].id
            true
        }
        popup.show()
    }

    private fun updateTransferState() {
        destinationChip.visibility = if (transactionType == "transfer") View.VISIBLE else View.GONE
        categoriesGrid.alpha = if (transactionType == "transfer") .45f else 1f
    }

    private fun buildDraft(): Map<String, Any?> {
        refreshAmountMirror()
        val amount = amountField.text.toString().trim().replace(",", "").toDoubleOrNull()
        val amountInCents = ((amount ?: 0.0) * 100.0).roundToLong()
        return linkedMapOf(
            "bookId" to selectedBookId,
            "type" to transactionType,
            "amountInCents" to amountInCents,
            "note" to noteField.text.toString().trim(),
            "occurredAt" to occurredAtMillis,
            "categoryId" to selectedCategoryId,
            "subcategoryId" to selectedSubcategoryId,
            "accountId" to selectedAccountId,
            "destinationAccountId" to selectedDestinationAccountId,
            "reimbursementStatus" to reimbursementStatus,
            "screenshotEnabled" to screenshotSwitch.isChecked,
            "flutterReady" to flutterReady,
        )
    }

    private fun refreshAmountMirror() {
        val amount = amountField.text.toString().trim().replace(",", "").toDoubleOrNull() ?: 0.0
        amountMirror.text = "= ¥${"%.2f".format(Locale.US, amount)}"
    }

    private fun showOptions(
        anchor: View,
        options: List<Option>,
        selectedId: String?,
        onSelected: (Option) -> Unit,
    ) {
        if (options.isEmpty()) {
            showMessage("选项正在加载，可先修改金额和分类")
            return
        }
        val popup = PopupMenu(context, anchor)
        options.forEachIndexed { index, option ->
            popup.menu.add(0, index, index, if (option.id == selectedId) "✓ ${option.label}" else option.label)
        }
        popup.setOnMenuItemClickListener { item ->
            options.getOrNull(item.itemId)?.let(onSelected)
            true
        }
        popup.show()
    }

    private fun parseOptions(raw: Any?): List<Option> =
        (raw as? List<*>)
            .orEmpty()
            .mapNotNull { item ->
                val map = item as? Map<*, *> ?: return@mapNotNull null
                val id = map["id"]?.toString()?.takeIf { it.isNotBlank() } ?: return@mapNotNull null
                val label = map["label"]?.toString()?.takeIf { it.isNotBlank() } ?: id
                Option(
                    id = id,
                    label = label,
                    type = map["type"]?.toString(),
                    parentId = map["parentId"]?.toString()?.takeIf { it.isNotBlank() },
                    sortOrder = (map["sortOrder"] as? Number)?.toInt() ?: 0,
                )
            }

    private fun selectorChip(label: String, onClick: () -> Unit): TextView =
        chip(label, true, onClick)

    private fun chip(label: String, selected: Boolean, onClick: () -> Unit): TextView =
        TextView(context).apply {
            text = label
            maxLines = 1
            textSize = 12f
            gravity = Gravity.CENTER
            setTextColor(if (selected) orange else primaryText)
            background = rounded(
                if (selected) orangeSoft else surfaceColor,
                18f,
                if (selected) orange else dividerColor,
                1,
            )
            setPadding(dp(6), 0, dp(6), 0)
            setOnClickListener { onClick() }
        }

    private fun actionButton(label: String, filled: Boolean, onClick: () -> Unit): TextView =
        TextView(context).apply {
            text = label
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(if (filled) Color.WHITE else orange)
            background = rounded(
                if (filled) orange else Color.TRANSPARENT,
                24f,
                if (filled) orange else secondaryText,
                1,
            )
            setOnClickListener { onClick() }
        }

    private fun rounded(
        color: Int,
        radiusDp: Float,
        strokeColor: Int? = null,
        strokeDp: Int = 0,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
        if (strokeColor != null && strokeDp > 0) {
            setStroke(dp(strokeDp), strokeColor)
        }
    }

    private fun fallbackCategories(type: String): List<Option> {
        val labels = if (type == "income") {
            listOf("工资", "奖金", "兼职", "投资收益", "退款", "其他收入")
        } else {
            listOf(
                "其他", "汽车", "数码", "宠物", "人情",
                "旅行", "教育培训", "医疗", "生活缴费", "住房",
                "娱乐", "烟酒茶", "家居日用", "购物", "交通",
            )
        }
        return labels.map { Option("", it, categoryTypeFor(type)) }
    }

    private fun categoryGlyph(label: String): String = when (label) {
        "汽车", "交通" -> "▣"
        "数码" -> "▤"
        "宠物" -> "●"
        "人情" -> "♥"
        "旅行" -> "✈"
        "教育培训" -> "◆"
        "医疗" -> "✚"
        "生活缴费" -> "▧"
        "住房" -> "⌂"
        "娱乐" -> "◉"
        "烟酒茶" -> "▽"
        "家居日用" -> "▥"
        "购物" -> "▰"
        "工资" -> "¥"
        "奖金" -> "★"
        "兼职" -> "◷"
        "投资收益" -> "↗"
        "退款" -> "↶"
        else -> "•••"
    }

    private fun initialAccountLabel(): String {
        val suffix = candidate.identifierSuffix?.let { "-$it" }.orEmpty()
        return when (candidate.sourceApp) {
            "WECHAT" -> "微信$suffix"
            "ALIPAY" -> "支付宝$suffix"
            "UNIONPAY" -> "银行卡$suffix"
            else -> candidate.paymentMethod.ifBlank { "支付账户" }
        }
    }

    private fun initialType(): String = when (candidate.transactionType) {
        "INCOME" -> "income"
        "TRANSFER" -> "transfer"
        else -> "expense"
    }

    private fun categoryTypeFor(type: String): String =
        if (type == "income") "income" else "expense"

    private fun dateLabel(timestamp: Long): String {
        val now = Date()
        val date = Date(timestamp)
        val formatter = SimpleDateFormat("yyyyMMdd", Locale.CHINA)
        val today = formatter.format(now)
        val target = formatter.format(date)
        val day = 24L * 60L * 60L * 1000L
        return when {
            target == today -> "今天"
            formatter.format(Date(now.time - day)) == target -> "昨天"
            else -> SimpleDateFormat("M月d日", Locale.CHINA).format(date)
        }
    }

    private fun hideKeyboard() {
        (context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager)
            ?.hideSoftInputFromWindow(root.windowToken, 0)
        root.requestFocus()
    }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt()
    private fun dp(value: Float): Int = (value * context.resources.displayMetrics.density).toInt()
}
