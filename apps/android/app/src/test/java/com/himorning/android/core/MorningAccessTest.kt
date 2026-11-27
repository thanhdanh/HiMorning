package com.himorning.android.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MorningAccessTest {
    @Test
    fun previewPeriodStartsWithThirtyDaysAndExpiresMonotonically() {
        val t0 = 1_700_000_000_000L
        var period = PreviewPeriod()
        assertFalse(period.hasStarted)
        assertEquals(30, period.remainingDays(t0))
        assertEquals(MorningAccess.PREVIEW, period.access(t0))

        period = period.start(t0)
        assertTrue(period.hasStarted)
        assertEquals(30, period.remainingDays(t0))
        assertEquals(MorningAccess.PREVIEW, period.access(t0 + 29L * PreviewPeriod.DAY_MS))
        assertEquals(1, period.remainingDays(t0 + 29L * PreviewPeriod.DAY_MS))

        // Clock rollback cannot restore an expired preview.
        val afterExpiry = t0 + 31L * PreviewPeriod.DAY_MS
        period = period.observe(afterExpiry)
        assertEquals(MorningAccess.FREE, period.access(t0 + PreviewPeriod.DAY_MS))
        assertEquals(0, period.remainingDays(t0 + PreviewPeriod.DAY_MS))
    }

    @Test
    fun proOverridesExpiredPreview() {
        val t0 = 1_700_000_000_000L
        val expired = PreviewPeriod(startedAtMs = t0, lastSeenAtMs = t0 + 35L * PreviewPeriod.DAY_MS)
        assertEquals(MorningAccess.FREE, effectiveAccess(isPro = false, preview = expired, nowMs = t0 + 35L * PreviewPeriod.DAY_MS))
        assertEquals(MorningAccess.PRO, effectiveAccess(isPro = true, preview = expired, nowMs = t0 + 35L * PreviewPeriod.DAY_MS))
    }

    @Test
    fun annualSavingsComputesPercentOnlyWhenCheaperInSameCurrency() {
        assertEquals(29, annualSavingsPercent(19_000_000_000L, 160_000_000_000L, sameCurrency = true))
        assertNull(annualSavingsPercent(19_000_000_000L, 160_000_000_000L, sameCurrency = false))
        assertNull(annualSavingsPercent(10_000_000_000L, 120_000_000_000L, sameCurrency = true))
    }
}
