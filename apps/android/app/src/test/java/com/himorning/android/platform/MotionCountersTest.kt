package com.himorning.android.platform

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

class MotionCountersTest {
    @Test fun slowWaveAccumulatesMotionWithoutAShoulderReference() {
        for (period in listOf(35L, 110L)) {
            val wave = WaveCounter()
            for (time in 0L..4_000L step period) {
                wave.observe(180 + 35 * sin(2 * PI * time / 1_000), 160.0, 35.0, time)
            }
            assertTrue("Wave at a ${period}ms frame interval", wave.completed >= 3)
        }
    }

    @Test fun liftFidgetAndChangingPalmSizeDoNotCount() {
        val wave = WaveCounter()
        for (time in 0L..4_000L step 35) {
            val oscillation = sin(2 * PI * time / 850)
            wave.observe(200 + 4 * oscillation, 130 + 50 * oscillation, 40 + 10 * oscillation, time)
        }
        assertEquals(0, wave.completed)
    }

    @Test fun waveDoesNotJoinSwingsAcrossMissingHand() {
        val wave = WaveCounter()
        for (i in 0..20) wave.observe(100.0 + 3 * i, 140.0, 40.0, 35L * i)
        wave.lost(1_400)
        for (i in 0..20) wave.observe(160.0 - 3 * i, 140.0, 40.0, 1_435 + 35L * i)
        assertEquals(0, wave.completed)
    }

    @Test fun reachCanStartRaisedAndCannotRecountUntilLowered() {
        val reach = ReachUpCounter()
        assertEquals(0, reach.observe(1, 0))
        assertEquals(1, reach.observe(1, 120))
        reach.observe(null, 160)
        reach.observe(1, 1_000)
        assertEquals(1, reach.observe(1, 1_150))
        reach.observe(0, 1_300)
        reach.observe(0, 1_520)
        reach.observe(1, 1_600)
        assertEquals(2, reach.observe(1, 1_720))
    }

    @Test fun reachGeometryUsesElbowsAndFollowsTiltedShoulderAxis() {
        val ls = MotionPoint(100.0, 150.0)
        val rs = MotionPoint(200.0, 180.0)
        assertEquals(1, reachPose(ls, rs, MotionPoint(60.0, 138.0), MotionPoint(240.0, 192.0), 480))
        assertEquals(0, reachPose(ls, rs, MotionPoint(75.0, 215.0), MotionPoint(210.0, 245.0), 480))
        assertNull(reachPose(ls, rs, ls, rs, 480))
    }

    @Test fun neckRequiresReturningToCenterAfterEachSide() {
        val neck = NeckTurnCounter()
        var time = 0L
        fun hold(angle: Double): Int {
            var count = 0
            repeat(16) {
                count = neck.observe(angle, time)
                time += 35
            }
            return count
        }
        assertEquals(0, hold(-35.0))
        assertEquals(0, hold(35.0))
        assertEquals(0, hold(0.0))
        assertEquals(0, hold(-35.0))
        assertEquals(1, hold(0.0))
    }

    @Test fun pushUpRejectsShallowOrTooFastMotion() {
        val counter = PushUpCounter()
        counter.observe(165.0, 170.0, 10.0, 0)
        counter.observe(85.0, 145.0, 10.0, 250)
        assertEquals(0, counter.observe(165.0, 170.0, 10.0, 400))
        counter.observe(85.0, 170.0, 10.0, 500)
        assertEquals(0, counter.observe(165.0, 170.0, 10.0, 600))
        counter.observe(165.0, 170.0, 10.0, 700)
        counter.observe(85.0, 170.0, 10.0, 1_100)
        assertEquals(1, counter.observe(165.0, 170.0, 10.0, 1_500))
    }

    @Test fun cameraProjectionUndoesRotationBeforeCameraXMapsToView() {
        val upright = MotionPoint(100.0, 150.0)
        assertEquals(MotionPoint(150.0, 380.0), rawCameraPoint(upright, 640, 480, 90))
        assertEquals(MotionPoint(540.0, 330.0), rawCameraPoint(upright, 640, 480, 180))
        assertEquals(MotionPoint(490.0, 100.0), rawCameraPoint(upright, 640, 480, 270))
        assertEquals(upright, rawCameraPoint(upright, 640, 480, 0))
    }
}
