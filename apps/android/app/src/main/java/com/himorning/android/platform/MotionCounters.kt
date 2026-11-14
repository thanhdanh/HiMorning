package com.himorning.android.platform

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max

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

internal class PushUpCounter {
    private var began: Long? = null
    private var lowered: Long? = null
    private var previous: Long? = null
    private var lostSince: Long? = null
    private var completed = 0

    fun observe(elbow: Double, body: Double, incline: Double, now: Long): Int {
        if (previous?.let { now <= it || now - it > 1_500 } == true ||
            lostSince?.let { now - it > 600 } == true) interrupt()
        previous = now
        lostSince = null
        if (elbow !in 0.0..180.0 || body !in 150.0..180.0 || incline !in 0.0..35.0) {
            interrupt()
            return completed
        }

        val start = began
        val bottom = lowered
        if (start != null && now - start > 15_000) interrupt()
        else if (start == null && elbow >= 160) began = now
        else if (start != null && bottom == null && elbow <= 90) {
            if (now - start >= 150) lowered = now else interrupt()
        } else if (start != null && bottom != null && elbow >= 160) {
            if (now - start >= 750 && now - bottom >= 150) completed++
            interrupt()
        }
        return completed
    }

    fun lost(now: Long) {
        val since = lostSince ?: now
        if (now - since > 600) interrupt() else lostSince = since
        previous = now
    }

    fun interrupt() {
        began = null
        lowered = null
        previous = null
        lostSince = null
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
