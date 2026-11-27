package com.himorning.android.core

import kotlin.math.ceil

enum class MorningAccess {
    FREE,
    PREVIEW,
    PRO;

    val hasFullAccess: Boolean
        get() = this == PREVIEW || this == PRO
}

data class PreviewPeriod(
    val startedAtMs: Long? = null,
    val lastSeenAtMs: Long? = null,
) {
    val hasStarted: Boolean get() = startedAtMs != null

    fun start(nowMs: Long): PreviewPeriod {
        if (startedAtMs != null) return this
        return copy(startedAtMs = nowMs, lastSeenAtMs = nowMs)
    }

    fun observe(nowMs: Long): PreviewPeriod {
        if (startedAtMs == null) return this
        val monotonic = maxOf(lastSeenAtMs ?: nowMs, nowMs)
        return if (monotonic == lastSeenAtMs) this else copy(lastSeenAtMs = monotonic)
    }

    fun expiresAtMs(): Long? = startedAtMs?.let { it + DURATION_MS }

    fun remainingDays(nowMs: Long): Int {
        val end = expiresAtMs() ?: return DURATION_DAYS
        val effectiveNow = maxOf(nowMs, lastSeenAtMs ?: nowMs)
        val remainingMs = (end - effectiveNow).coerceAtLeast(0L)
        if (remainingMs == 0L) return 0
        return ceil(remainingMs.toDouble() / DAY_MS.toDouble()).toInt().coerceIn(1, DURATION_DAYS)
    }

    fun access(nowMs: Long): MorningAccess {
        val end = expiresAtMs() ?: return MorningAccess.PREVIEW
        val effectiveNow = maxOf(nowMs, lastSeenAtMs ?: nowMs)
        return if (effectiveNow < end) MorningAccess.PREVIEW else MorningAccess.FREE
    }

    companion object {
        const val DURATION_DAYS = 30
        const val DAY_MS = 24L * 60L * 60L * 1000L
        const val DURATION_MS = DURATION_DAYS * DAY_MS
    }
}

fun effectiveAccess(isPro: Boolean, preview: PreviewPeriod, nowMs: Long): MorningAccess =
    if (isPro) MorningAccess.PRO else preview.access(nowMs)

fun annualSavingsPercent(
    monthlyPriceMicros: Long,
    annualPriceMicros: Long,
    sameCurrency: Boolean,
): Int? {
    if (!sameCurrency || monthlyPriceMicros <= 0L || annualPriceMicros <= 0L) return null
    val monthlyYearMicros = monthlyPriceMicros * 12L
    if (monthlyYearMicros <= annualPriceMicros) return null
    val percent = ((monthlyYearMicros - annualPriceMicros) * 100L / monthlyYearMicros).toInt()
    return percent.takeIf { it >= 1 }
}
