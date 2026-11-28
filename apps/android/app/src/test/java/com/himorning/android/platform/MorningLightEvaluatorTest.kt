package com.himorning.android.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MorningLightEvaluatorTest {
    @Test
    fun holdsBrightLightThenCompletes() {
        var evaluator = MorningLightEvaluator(brightThreshold = 0.58, dropThreshold = 0.48, holdDurationMs = 2000L)
        assertEquals(MorningLightEvaluator.State.SeekingLight, evaluator.process(0.30, 0L))
        assertEquals(MorningLightEvaluator.State.Holding(0.0), evaluator.process(0.65, 1000L))
        val mid = evaluator.process(0.60, 2000L)
        assertTrue(mid is MorningLightEvaluator.State.Holding && mid.progress in 0.49..0.51)
        assertEquals(MorningLightEvaluator.State.Completed, evaluator.process(0.62, 3000L))
    }

    @Test
    fun resetsWhenLightDropsBelowDropThreshold() {
        val evaluator = MorningLightEvaluator(brightThreshold = 0.58, dropThreshold = 0.48, holdDurationMs = 2000L)
        assertEquals(MorningLightEvaluator.State.Holding(0.0), evaluator.process(0.65, 1000L))
        assertEquals(MorningLightEvaluator.State.SeekingLight, evaluator.process(0.40, 1500L))
        assertEquals(MorningLightEvaluator.State.Holding(0.0), evaluator.process(0.65, 2000L))
    }
}
