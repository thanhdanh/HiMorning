package com.himorning.android.platform

import android.content.Context
import com.himorning.android.core.PreviewPeriod
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal class PreviewStore(
    context: Context,
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val _period = MutableStateFlow(load())
    val period: StateFlow<PreviewPeriod> = _period.asStateFlow()

    fun start() {
        val current = _period.value
        val updated = if (!current.hasStarted) current.start(nowMs()) else current.observe(nowMs())
        if (updated != current) {
            save(updated)
            _period.value = updated
        }
    }

    fun refresh() {
        val current = _period.value
        if (!current.hasStarted) return
        val updated = current.observe(nowMs())
        if (updated != current) {
            save(updated)
            _period.value = updated
        }
    }

    private fun load(): PreviewPeriod {
        val started = if (prefs.contains(KEY_STARTED_AT)) prefs.getLong(KEY_STARTED_AT, 0L) else null
        val lastSeen = if (prefs.contains(KEY_LAST_SEEN_AT)) prefs.getLong(KEY_LAST_SEEN_AT, 0L) else null
        return PreviewPeriod(startedAtMs = started, lastSeenAtMs = lastSeen)
    }

    private fun save(value: PreviewPeriod) {
        prefs.edit().apply {
            value.startedAtMs?.let { putLong(KEY_STARTED_AT, it) }
            value.lastSeenAtMs?.let { putLong(KEY_LAST_SEEN_AT, it) }
        }.apply()
    }

    companion object {
        private const val PREFS_NAME = "himorning_preview_v1"
        private const val KEY_STARTED_AT = "started_at_ms"
        private const val KEY_LAST_SEEN_AT = "last_seen_at_ms"
    }
}
