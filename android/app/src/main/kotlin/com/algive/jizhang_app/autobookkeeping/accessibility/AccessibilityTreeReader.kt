package com.algive.jizhang_app.autobookkeeping.accessibility

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode

class AccessibilityTreeReader {
    @Suppress("DEPRECATION")
    fun read(root: AccessibilityNodeInfo): List<ScreenNode> {
        val output = mutableListOf<ScreenNode>()
        var visited = 0
        fun visit(node: AccessibilityNodeInfo, depth: Int) {
            if (++visited > 240 || depth > 18) return
            if (node.isVisibleToUser && !node.isPassword) {
                val bounds = Rect(); node.getBoundsInScreen(bounds)
                output.add(ScreenNode(node.text?.take(160)?.toString().orEmpty(), node.contentDescription?.take(160)?.toString().orEmpty(), node.viewIdResourceName.orEmpty(), node.className?.toString().orEmpty(), listOf(bounds.left, bounds.top, bounds.right, bounds.bottom), depth))
            }
            for (i in 0 until node.childCount.coerceAtMost(80)) {
                if (visited >= 240) break
                val child = node.getChild(i) ?: continue
                try { visit(child, depth + 1) } finally { child.recycle() }
            }
        }
        visit(root, 0)
        return output
    }
}
