package com.himorning.android.platform

import org.junit.Assert.assertEquals
import org.junit.Test

class PoseCycleCounterTest {
    @Test fun jumpingJackRequiresClosedOpenClosedAndDebouncedHolds() {
        val counter = PoseCycleCounter(listOf(listOf(0, 1, 0)))
        counter.observe(0, 0); counter.observe(0, 220)
        counter.observe(1, 300); counter.observe(1, 519)
        assertEquals(0, counter.completed)
        counter.observe(1, 520); counter.observe(0, 600); counter.observe(0, 820)
        assertEquals(1, counter.completed)
    }

    @Test fun lostTrackingResetsPartialCycleButNotCompletedCount() {
        val counter = PoseCycleCounter(listOf(listOf(0, 1, 0)))
        counter.observe(0, 0); counter.observe(0, 220)
        counter.observe(1, 300); counter.observe(1, 520)
        counter.observe(null, 600); counter.observe(null, 1_201)
        counter.observe(0, 1_300); counter.observe(0, 1_520)
        assertEquals(0, counter.completed)
    }

    @Test fun visibleMotionAcrossIntermediatePosesKeepsJumpingJackProgress() {
        val counter = PoseCycleCounter(listOf(listOf(0, 1, 0)))
        counter.observe(0, 0)
        counter.observe(0, 220)
        for (time in 300L..1_100L step 100) counter.observe(null, time, visible = true)
        counter.observe(1, 1_200)
        counter.observe(1, 1_420)
        counter.observe(0, 1_500)
        assertEquals(1, counter.observe(0, 1_720))
    }

    @Test fun guidedRhythmExpiresAnIncompleteSequence() {
        val counter = PoseCycleCounter(listOf(listOf(0, 1, 0)), maxSequenceMillis = 8_000, maxSampleGapMillis = 600)
        counter.observe(0, 0, 120)
        counter.observe(0, 130, 120)
        counter.observe(1, 300, 120)
        counter.observe(1, 430, 120)
        for (time in 600L..9_000L step 300) counter.observe(null, time, 120, visible = true)
        counter.observe(0, 9_200, 120)
        assertEquals(0, counter.observe(0, 9_400, 120))
    }

    @Test fun bothNeckTurnDirectionsCountOneFullRoundTrip() {
        val counter = PoseCycleCounter(listOf(listOf(-1, 0, 1, 0), listOf(1, 0, -1, 0)))
        var t = 0L
        for (state in listOf(-1, -1, 0, 0, 1, 1, 0, 0)) { counter.observe(state, t, 120); t += 130 }
        assertEquals(1, counter.completed)

        val reverse = PoseCycleCounter(listOf(listOf(-1, 0, 1, 0), listOf(1, 0, -1, 0)))
        t = 0
        for (state in listOf(1, 1, 0, 0, -1, -1, 0, 0)) { reverse.observe(state, t, 120); t += 130 }
        assertEquals(1, reverse.completed)
    }
}
