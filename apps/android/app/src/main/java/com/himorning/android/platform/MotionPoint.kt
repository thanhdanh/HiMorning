package com.himorning.android.platform

import kotlin.math.hypot

internal data class MotionPoint(val x: Double, val y: Double) {
    val length get() = hypot(x, y)
    operator fun minus(other: MotionPoint) = MotionPoint(x - other.x, y - other.y)
    fun midpoint(other: MotionPoint) = MotionPoint((x + other.x) / 2, (y + other.y) / 2)
}

internal fun rawCameraPoint(point: MotionPoint, width: Int, height: Int, rotation: Int): MotionPoint =
    when (rotation) {
        90 -> MotionPoint(point.y, height - point.x)
        180 -> MotionPoint(width - point.x, height - point.y)
        270 -> MotionPoint(width - point.y, point.x)
        else -> point
    }
