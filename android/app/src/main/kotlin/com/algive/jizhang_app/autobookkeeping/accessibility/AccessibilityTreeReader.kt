package com.algive.jizhang_app.autobookkeeping.accessibility

import android.graphics.Rect
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode

data class AccessibilityTreeSnapshot(
    val nodes: List<ScreenNode>,
    val visited: Int,
    val maxDepth: Int,
    val truncated: Boolean,
    val elapsedMs: Long = 0,
    val truncationReason: String? = null,
)

class AccessibilityTreeReader {
    @Suppress("DEPRECATION")
    fun read(root: AccessibilityNodeInfo): List<ScreenNode> = readSnapshot(root).nodes

    @Suppress("DEPRECATION")
    fun readSnapshot(root: AccessibilityNodeInfo): AccessibilityTreeSnapshot {
        val output = mutableListOf<ScreenNode>()
        var visited = 0
        var maxDepth = 0
        var truncated = false
        var truncationReason: String? = null
        val startedAt = SystemClock.elapsedRealtime()
        val deadline = startedAt + 250

        fun visit(node: AccessibilityNodeInfo, depth: Int) {
            if (visited >= MAX_NODES || depth > MAX_DEPTH || SystemClock.elapsedRealtime() >= deadline) {
                truncated = true
                truncationReason = when {
                    visited >= MAX_NODES -> "NODE_LIMIT"
                    depth > MAX_DEPTH -> "DEPTH_LIMIT"
                    else -> "TIME_LIMIT"
                }
                return
            }
            visited += 1
            maxDepth = maxOf(maxDepth, depth)

            if (node.isVisibleToUser && !node.isPassword) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                output.add(
                    ScreenNode(
                        node.text?.take(160)?.toString().orEmpty(),
                        node.contentDescription?.take(160)?.toString().orEmpty(),
                        node.viewIdResourceName.orEmpty(),
                        node.className?.toString().orEmpty(),
                        listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
                        depth,
                    ),
                )
            }

            val childLimit = node.childCount.coerceAtMost(MAX_CHILDREN_PER_NODE)
            if (node.childCount > childLimit) { truncated = true; truncationReason = "CHILD_LIMIT" }
            for (i in 0 until childLimit) {
                if (visited >= MAX_NODES || SystemClock.elapsedRealtime() >= deadline) {
                    truncated = true
                    truncationReason = if (visited >= MAX_NODES) "NODE_LIMIT" else "TIME_LIMIT"
                    break
                }
                val child = node.getChild(i) ?: continue
                try {
                    visit(child, depth + 1)
                } finally {
                    child.recycle()
                }
            }
        }

        visit(root, 0)
        return AccessibilityTreeSnapshot(
            nodes = output,
            visited = visited,
            maxDepth = maxDepth,
            truncated = truncated,
            elapsedMs = SystemClock.elapsedRealtime() - startedAt,
            truncationReason = truncationReason,
        )
    }

    private companion object {
        const val MAX_NODES = 480
        const val MAX_DEPTH = 48
        const val MAX_CHILDREN_PER_NODE = 120
    }
}
