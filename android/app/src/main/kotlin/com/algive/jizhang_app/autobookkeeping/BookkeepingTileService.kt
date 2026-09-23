package com.algive.jizhang_app.autobookkeeping

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.accessibility.AutoBookkeepingAccessibilityService
import com.algive.jizhang_app.autobookkeeping.diagnostics.AutoBookkeepingDiagnostics

/**
 * Quick Settings tile: one tap scans whatever is on screen right now.
 *
 * This is the manual counterpart to event-driven detection. It matters because
 * the automatic paths can both miss a payment — the notification listener only
 * sees apps that post a results notification, and the accessibility scanner only
 * fires while a rule-matching window is in the foreground — so the user needs a
 * deliberate "record this one" gesture that does not require opening the app.
 *
 * The tile is a **trigger**, never an implicit recorder: it runs the same
 * detector and the same confirmation flow as the automatic paths, so nothing is
 * written without the user confirming category and account.
 */
class BookkeepingTileService : TileService() {

    override fun onTileAdded() {
        super.onTileAdded()
        refreshTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        val service = AutoBookkeepingAccessibilityService.instance
        if (service == null || !AutoBookkeepingSettings.enabled(this)) {
            AutoBookkeepingDiagnostics.error = "自动记账未运行，请先开启无障碍服务"
            // Nothing to scan with: take the user to the setup page instead of
            // failing silently.
            openSettings()
            return
        }
        service.triggerManualCapture()
        Toast.makeText(this, "好好记账：正在识别当前页面…", Toast.LENGTH_SHORT).show()
        refreshTile()
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val running = AutoBookkeepingAccessibilityService.instance != null &&
            AutoBookkeepingSettings.enabled(this)
        tile.state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = if (running) "点按识别当前页面" else "点击前往开启"
        }
        tile.updateTile()
    }

    private fun openSettings() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(MainActivity.OPEN_ROUTE_EXTRA, ROUTE_AUTOBOOKKEEPING)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val pending = PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                startActivityAndCollapse(pending)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }.onFailure { error ->
            AutoBookkeepingLogStore.record(
                this,
                "tile_open_failed",
                error.javaClass.simpleName,
            )
        }
    }

    private companion object {
        /** Same route the status notification opens. */
        const val ROUTE_AUTOBOOKKEEPING = "/profile/autobookkeeping"
    }
}
