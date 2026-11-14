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
