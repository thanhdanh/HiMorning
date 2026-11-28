package com.himorning.android.platform

import com.himorning.android.core.PushUpVariant
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

internal enum class MovementFormCue {
    NONE,
    LOWER_CHEST,
    STRAIGHTEN_BODY,
    BEND_KNEES_DEEPER,
    STAND_TALL,
}

internal enum class CameraLightingStatus { LOW_LIGHT, OK, OVEREXPOSED }

internal object CameraConditionMath {
    const val LOW_LIGHT_MEAN_LUMA = 0.2
    const val OVEREXPOSED_MEAN_LUMA = 0.9
    const val ROLL_DEADZONE_DEG = 0.5
    const val MAX_COMPENSATED_ROLL_DEG = 35.0

    fun classifyLuma(meanLuma: Double): CameraLightingStatus = when {
        meanLuma < LOW_LIGHT_MEAN_LUMA -> CameraLightingStatus.LOW_LIGHT
        meanLuma > OVEREXPOSED_MEAN_LUMA -> CameraLightingStatus.OVEREXPOSED
        else -> CameraLightingStatus.OK
    }

    /** Gravity vector (m/s^2) roll in portrait orientation: upright phone has gx ~ 0, gy ~ +9.81. */
    fun androidRollDegrees(gx: Double, gy: Double): Double {
        if (!gx.isFinite() || !gy.isFinite()) return 0.0
        val deg = Math.toDegrees(atan2(gx, gy))
        if (abs(deg) < ROLL_DEADZONE_DEG) return 0.0
        return deg.coerceIn(-MAX_COMPENSATED_ROLL_DEG, MAX_COMPENSATED_ROLL_DEG)
    }

    fun derotatePoint(point: MotionPoint, width: Double, height: Double, rollDegrees: Double): MotionPoint {
        if (abs(rollDegrees) < ROLL_DEADZONE_DEG) return point
        val rad = Math.toRadians(-rollDegrees)
        val c = cos(rad)
        val s = sin(rad)
        val cx = width / 2.0
        val cy = height / 2.0
        val dx = point.x - cx
        val dy = point.y - cy
        return MotionPoint(
            x = cx + dx * c - dy * s,
            y = cy + dx * s + dy * c,
        )
    }
}

internal class OneEuroFilter(private val minCutoff: Double, private val beta: Double) {
    private var smoothed = 0.0
    private var previous = 0.0
    private var derivative = 0.0
    private var lastTime: Long? = null

    fun filter(sample: Double, now: Long): Double {
        val last = lastTime
        if (last == null) {
            smoothed = sample
        } else {
            if (now <= last) return smoothed
            val seconds = (now - last) / 1_000.0
            derivative += alpha(1.0, seconds) * ((sample - previous) / seconds - derivative)
            smoothed += alpha(minCutoff + beta * abs(derivative), seconds) * (sample - smoothed)
        }
        previous = sample
        lastTime = now
        return smoothed
    }

    fun reset() {
        lastTime = null
        derivative = 0.0
    }

    private fun alpha(cutoff: Double, seconds: Double) = 1 / (1 + 1 / (2 * PI * cutoff * seconds))
}

/** Measures complete lateral swings in palm lengths, using the same thresholds as iOS Vision. */
internal class WaveCounter {
    private data class Position(val x: Double, val y: Double, val time: Long)

    private val xFilter = OneEuroFilter(3.0, 0.3)
    private val yFilter = OneEuroFilter(3.0, 0.3)
    private val sizeFilter = OneEuroFilter(0.3, 0.0)
    private var previous: Position? = null
    private var acquiredAt: Long? = null
    private var lostSince: Long? = null
    private var travelX = 0.0
    private var travelY = 0.0
    private var extreme = Position(0.0, 0.0, 0)
    private var low = extreme
    private var high = extreme
    private var direction = 0
    private var pendingSwing: Long? = null
    var completed = 0
        private set

    fun observe(x: Double, y: Double, palmSize: Double, now: Long): Int {
        if (!x.isFinite() || !y.isFinite() || !palmSize.isFinite() || palmSize <= 0) {
            lost(now)
            return completed
        }
        if (previous?.let { now <= it.time || now - it.time > 600 } == true ||
            lostSince?.let { now - it > 600 } == true) resetTracking()
        lostSince = null
        val scale = sizeFilter.filter(palmSize, now)
        previous?.let {
            travelX += (x - it.x) / scale
            travelY += (y - it.y) / scale
        }
        previous = Position(x, y, now)
        val point = Position(xFilter.filter(travelX, now), yFilter.filter(travelY, now), now)
        val start = acquiredAt ?: now.also { acquiredAt = it }
        if (now - start < 150) {
            anchor(point)
            return completed
        }

        if (direction == 0) {
            if (point.x < low.x) low = point
            if (point.x > high.x) high = point
            extreme = when {
                high.x - point.x >= 0.62 -> high
                point.x - low.x >= 0.62 -> low
                else -> extreme
            }
        }
        if ((direction > 0 && point.x > extreme.x) || (direction < 0 && point.x < extreme.x)) extreme = point
        val dx = point.x - extreme.x
        val dy = abs(point.y - extreme.y)
        if (dy > 0.35 && dy * 1.4 > abs(dx)) {
            anchor(point)
            return completed
        }
        val reversing = direction == 0 || (direction > 0 && dx < 0) || (direction < 0 && dx > 0)
        if (reversing && abs(dx) >= 0.62 && abs(dx) >= dy * 1.4 && now - extreme.time >= 80) {
            extreme = point
            direction = if (dx > 0) 1 else -1
            val pending = pendingSwing
            if (pending != null && now - pending <= 2_000) {
                completed++
                pendingSwing = null
            } else {
                pendingSwing = now
            }
        }
        return completed
    }

    fun lost(now: Long) {
        val since = lostSince ?: previous?.time ?: now
        if (now - since > 600) resetTracking()
        lostSince = since
    }

    fun resetTracking() {
        xFilter.reset()
        yFilter.reset()
        sizeFilter.reset()
        previous = null
        acquiredAt = null
        lostSince = null
        travelX = 0.0
        travelY = 0.0
        anchor(Position(0.0, 0.0, 0))
    }

    private fun anchor(point: Position) {
        extreme = point
        low = point
        high = point
        direction = 0
        pendingSwing = null
    }
}

internal class ReachUpCounter {
    private var lastTime: Long? = null
    private var candidate: Int? = null
    private var candidateSince = 0L
    private var needsLowering = false
    private var completed = 0

    fun observe(pose: Int?, now: Long): Int {
        val last = lastTime
        lastTime = now
        if (last != null && (now <= last || now - last > 600)) candidate = null
        if (pose != candidate) {
            candidate = pose
            candidateSince = now
        }
        if (pose == 0 && now - candidateSince >= 220) needsLowering = false
        if (pose == 1 && now - candidateSince >= 120 && !needsLowering) {
            completed++
            needsLowering = true
        }
        return completed
    }
}

internal class NeckTurnCounter {
    private enum class Zone { LEFT, RIGHT, CENTER }

    private val filter = OneEuroFilter(1.0, 0.05)
    private var previous: Long? = null
    private var loss: Long? = null
    private var candidate: Zone? = null
    private var candidateSince = 0L
    private var committed: Zone? = null
    private var lastAbsYaw = 0.0
    private var visitedLeft = false
    private var visitedRight = false
    private var completed = 0
    private val lossLimit get() = if (committed == Zone.LEFT || committed == Zone.RIGHT) {
        if (lastAbsYaw >= 15) 1_500L else 600L
    } else 600L

    fun observe(yaw: Double, now: Long): Int {
        if (!yaw.isFinite()) {
            lost(now)
            return completed
        }
        if (previous?.let { now <= it || now - it > lossLimit } == true ||
            loss?.let { now - it > lossLimit } == true) resetTracking()
        previous = now
        loss = null
        val angle = filter.filter(yaw, now)
        lastAbsYaw = abs(angle)
        val zone = when {
            angle >= 20 -> Zone.RIGHT
            angle <= -20 -> Zone.LEFT
            lastAbsYaw <= 8 -> Zone.CENTER
            else -> null
        }
        if (zone != candidate) {
            candidate = zone
            candidateSince = now
        }
        if (zone != null && zone != committed && now - candidateSince >= 120) {
            if (zone == Zone.CENTER) {
                visitedLeft = visitedLeft || committed == Zone.LEFT
                visitedRight = visitedRight || committed == Zone.RIGHT
            }
            committed = zone
            if (visitedLeft && visitedRight) {
                completed++
                visitedLeft = false
                visitedRight = false
            }
        }
        return completed
    }

    fun lost(now: Long) {
        val since = loss ?: previous ?: now
        if (now - since > lossLimit) resetTracking()
        loss = since
    }

    private fun resetTracking() {
        filter.reset()
        previous = null
        loss = null
        candidate = null
        committed = null
        lastAbsYaw = 0.0
        visitedLeft = false
        visitedRight = false
    }
}

internal class PushUpCounter(private val variant: PushUpVariant = PushUpVariant.STANDARD) {
    private val elbowFilter = OneEuroFilter(2.2, 0.18)
    private var began: Long? = null
    private var lowered: Long? = null
    private var previous: Long? = null
    private var lostSince: Long? = null
    private var formLostSince: Long? = null
    private var completed = 0
    var romProgress: Double = 0.0
        private set
    var formCue: MovementFormCue = MovementFormCue.NONE
        private set

    private val elbowDownMax get() = if (variant == PushUpVariant.INCLINE_OR_KNEE) 108.0 else 98.0
    private val elbowUpMin get() = if (variant == PushUpVariant.INCLINE_OR_KNEE) 146.0 else 150.0
    private val bodyAngleMin get() = if (variant == PushUpVariant.INCLINE_OR_KNEE) 138.0 else 150.0
    private val inclineMax get() = if (variant == PushUpVariant.INCLINE_OR_KNEE) 68.0 else 42.0

    fun observe(elbow: Double, body: Double, incline: Double, now: Long): Int {
        if (previous?.let { now <= it || now - it > 1_500 } == true ||
            lostSince?.let { now - it > 600 } == true) interrupt()
        previous = now
        lostSince = null
        if (!elbow.isFinite() || !body.isFinite() || !incline.isFinite() || elbow !in 0.0..180.0) {
            interrupt()
            return completed
        }
        val smoothedElbow = elbowFilter.filter(elbow, now).coerceIn(0.0, 180.0)
        romProgress = ((elbowUpMin - smoothedElbow) / (elbowUpMin - elbowDownMax)).coerceIn(0.0, 1.0)
        if (body !in bodyAngleMin..180.0 || incline !in 0.0..inclineMax) {
            formCue = MovementFormCue.STRAIGHTEN_BODY
            val since = formLostSince ?: now
            if (now - since > 450) interrupt() else formLostSince = since
            return completed
        }
        if (formLostSince?.let { now - it > 450 } == true) {
            interrupt()
            return completed
        }
        formLostSince = null

        val start = began
        val bottom = lowered
        formCue = MovementFormCue.NONE
        if (start != null && now - start > 15_000) interrupt()
        else if (start == null && smoothedElbow >= elbowUpMin) began = now
        else if (start != null && bottom == null && smoothedElbow <= elbowDownMax) {
            if (now - start >= 150) lowered = now else interrupt()
        } else if (start != null && bottom != null && smoothedElbow >= elbowUpMin) {
            if (now - start >= 750 && now - bottom >= 150) completed++
            interrupt()
        } else if (start != null && bottom == null && smoothedElbow in (elbowDownMax + 0.01)..(elbowUpMin - 8.0) && now - start >= 900) {
            formCue = MovementFormCue.LOWER_CHEST
        }
        return completed
    }

    fun lost(now: Long) {
        val since = lostSince ?: now
        if (now - since > 600) interrupt() else lostSince = since
        previous = now
    }

    fun interrupt() {
        elbowFilter.reset()
        began = null
        lowered = null
        previous = null
        lostSince = null
        formLostSince = null
        romProgress = 0.0
        formCue = MovementFormCue.NONE
    }
}

/** Morning Squat counter using thresholds from shared/contracts/v1/movement-rules.json. */
internal class SquatCounter {
    private val kneeFilter = OneEuroFilter(2.2, 0.18)
    private var began: Long? = null
    private var bottomAt: Long? = null
    private var previous: Long? = null
    private var lostSince: Long? = null
    var completed = 0
        private set
    var romProgress: Double = 0.0
        private set
    var formCue: MovementFormCue = MovementFormCue.NONE
        private set

    fun observe(kneeAngle: Double, now: Long): Int {
        if (previous?.let { now <= it || now - it > 1_500 } == true ||
            lostSince?.let { now - it > 600 } == true) interrupt()
        previous = now
        lostSince = null
        if (!kneeAngle.isFinite() || kneeAngle !in 0.0..180.0) {
            interrupt()
            return completed
        }
        val smoothed = kneeFilter.filter(kneeAngle, now).coerceIn(0.0, 180.0)
        romProgress = ((STANDING_KNEE_MIN - smoothed) / (STANDING_KNEE_MIN - BOTTOM_KNEE_MAX)).coerceIn(0.0, 1.0)
        val start = began
        val bottom = bottomAt
        formCue = MovementFormCue.NONE
        if (start != null && now - start > 15_000) interrupt()
        else if (start == null && smoothed >= STANDING_KNEE_MIN) began = now
        else if (start != null && bottom == null && smoothed <= BOTTOM_KNEE_MAX) {
            if (now - start >= 140) bottomAt = now else interrupt()
        } else if (start != null && bottom != null && smoothed >= STANDING_KNEE_MIN) {
            if (now - start >= 650 && now - bottom >= 140) completed++
            interrupt()
        } else if (start != null && bottom == null && smoothed in (BOTTOM_KNEE_MAX + 0.01)..(STANDING_KNEE_MIN - 10.0) && now - start >= 900) {
            formCue = MovementFormCue.BEND_KNEES_DEEPER
        } else if (start != null && bottom != null && smoothed < STANDING_KNEE_MIN && now - bottom >= 900) {
            formCue = MovementFormCue.STAND_TALL
        }
        return completed
    }

    fun lost(now: Long) {
        val since = lostSince ?: now
        if (now - since > 600) interrupt() else lostSince = since
        previous = now
    }

    fun interrupt() {
        kneeFilter.reset()
        began = null
        bottomAt = null
        previous = null
        lostSince = null
        romProgress = 0.0
        formCue = MovementFormCue.NONE
    }

    private companion object {
        const val STANDING_KNEE_MIN = 155.0
        const val BOTTOM_KNEE_MAX = 115.0
    }
}

internal fun reachPose(
    leftShoulder: MotionPoint,
    rightShoulder: MotionPoint,
    leftElbow: MotionPoint,
    rightElbow: MotionPoint,
    frameShortSide: Int,
): Int? {
    val axis = rightShoulder - leftShoulder
    val width = axis.length
    if (width < frameShortSide * 0.06) return null
    val up = if (axis.x >= 0) MotionPoint(axis.y, -axis.x) else MotionPoint(-axis.y, axis.x)
    val leftArm = leftElbow - leftShoulder
    val rightArm = rightElbow - rightShoulder
    if (minOf(leftArm.length, rightArm.length) < width * 0.12) return null
    val left = (leftArm.x * up.x + leftArm.y * up.y) / width
    val right = (rightArm.x * up.x + rightArm.y * up.y) / width
    return when {
        minOf(left, right) >= -max(4.0, width * 0.13) -> 1
        maxOf(left, right) <= -max(8.0, width * 0.4) -> 0
        else -> null
    }
}
