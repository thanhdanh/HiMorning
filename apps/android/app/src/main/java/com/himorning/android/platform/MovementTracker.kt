package com.himorning.android.platform

import android.graphics.PointF
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceContour
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseLandmark.*
import com.himorning.android.R
import com.himorning.android.core.ChallengeKind
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.atan2

internal data class MovementSample(val count: Int, val hint: Int, val marks: TrackingMarks)

internal class MovementTracker(private val kind: ChallengeKind, private val seated: Boolean) {
    private val wave = WaveCounter()
    private val reach = ReachUpCounter()
    private val neck = NeckTurnCounter()
    private val pushUp = PushUpCounter()
    private val cycle = if (kind == ChallengeKind.GUIDED_RHYTHM) {
        PoseCycleCounter(listOf(listOf(0, 1, 0)), maxSequenceMillis = 8_000, maxSampleGapMillis = 600)
    } else {
        PoseCycleCounter(listOf(listOf(0, 1, 0)))
    }
    private var side: Int? = null
    private var count = 0
    private val framingHint get() = when (kind) {
        ChallengeKind.WAVE_HAND -> R.string.tracking_show_hand
        ChallengeKind.NECK_ROTATION -> R.string.tracking_show_face
        ChallengeKind.STRETCHING -> R.string.tracking_show_elbows
        ChallengeKind.GUIDED_RHYTHM -> if (seated) R.string.tracking_show_wrists else R.string.tracking_show_body
        else -> R.string.tracking_show_body
    }

    fun body(pose: Pose, frame: CameraFrame, now: Long): MovementSample {
        val stretching = kind == ChallengeKind.STRETCHING
        val minimum = if (stretching) 0.4f else 0.55f
        val margin = if (stretching) 0.005 else 0.02
        val joints = pose.allPoseLandmarks.mapNotNull { landmark ->
            val point = landmark.position.motionPoint()
            if (landmark.inFrameLikelihood >= minimum && frame.contains(point, margin)) {
                landmark.landmarkType to point
            } else null
        }.toMap()
        val marks = bodyMarks(joints)
        val missing = if (joints.isEmpty()) R.string.tracking_waiting else framingHint
        return when (kind) {
            ChallengeKind.STRETCHING -> reach(joints, frame, now, marks, missing)
            ChallengeKind.GUIDED_RHYTHM -> rhythm(joints, frame, now, marks, missing)
            ChallengeKind.JUMPING_JACKS -> jumpingJacks(joints, frame, now, marks, missing)
            ChallengeKind.PUSH_UPS -> pushUp(joints, frame, now, marks, missing)
            else -> lost(now)
        }
    }

    fun handChanged() = wave.resetTracking()

    fun hand(palm: List<MotionPoint>, frame: CameraFrame, now: Long): MovementSample {
        val visible = palm.filter { frame.contains(it, 0.02) }
        val wrist = palm.first()
        val marks = TrackingMarks(
            paths = if (wrist in visible) palm.drop(1).filter { it in visible }.map {
                TrackingPath(listOf(wrist, it), TrackingColor.LEFT)
            } else emptyList(),
            joints = visible,
        )
        if (visible.size != palm.size) return lost(now, marks)
        val size = (wrist - palm[2]).length
        if (size < frame.shortSide * 0.025) return lost(now, marks, R.string.tracking_move_closer)
        count = wave.observe(palm.map { it.x }.average(), palm.map { it.y }.average(), size, now)
        return active(marks)
    }

    fun face(face: Face?, frame: CameraFrame, now: Long): MovementSample {
        if (face == null) return lost(now)
        val box = face.boundingBox
        val left = box.left.coerceIn(0, frame.uprightWidth).toDouble()
        val right = box.right.coerceIn(0, frame.uprightWidth).toDouble()
        val top = box.top.coerceIn(0, frame.uprightHeight).toDouble()
        val bottom = box.bottom.coerceIn(0, frame.uprightHeight).toDouble()
        if (right <= left || bottom <= top) return lost(now)
        val paths = buildList {
            add(TrackingPath(listOf(MotionPoint(left, top), MotionPoint(right, top),
                MotionPoint(right, bottom), MotionPoint(left, bottom)), TrackingColor.HEAD, closed = true))
            val oval = face.getContour(FaceContour.FACE)?.points
            val bridge = face.getContour(FaceContour.NOSE_BRIDGE)?.points
            if (oval?.size == 36 && bridge?.size == 2) {
                val midline = listOf(oval[0], bridge[0], bridge[1], oval[18]).map { it.motionPoint() }
                if (midline.all { frame.contains(it, 0.0) }) add(TrackingPath(midline, TrackingColor.LEFT))
            }
        }
        val marks = TrackingMarks(paths = paths)
        if (!face.headEulerAngleY.isFinite()) return lost(now, marks)
        count = neck.observe(face.headEulerAngleY.toDouble(), now)
        return active(marks)
    }

    fun lost(now: Long, marks: TrackingMarks = TrackingMarks(), hint: Int = framingHint): MovementSample {
        when (kind) {
            ChallengeKind.WAVE_HAND -> wave.lost(now)
            ChallengeKind.NECK_ROTATION -> neck.lost(now)
            ChallengeKind.STRETCHING -> reach.observe(null, now)
            ChallengeKind.PUSH_UPS -> pushUp.lost(now)
            else -> cycle.observe(null, now)
        }
        return MovementSample(count, hint, marks)
    }

    private fun reach(joints: Map<Int, MotionPoint>, frame: CameraFrame, now: Long, marks: TrackingMarks, missing: Int): MovementSample {
        val ls = joints[LEFT_SHOULDER] ?: return lost(now, marks, missing)
        val rs = joints[RIGHT_SHOULDER] ?: return lost(now, marks, missing)
        val le = joints[LEFT_ELBOW] ?: return lost(now, marks, missing)
        val re = joints[RIGHT_ELBOW] ?: return lost(now, marks, missing)
        if ((ls - rs).length < frame.shortSide * 0.06) return lost(now, marks, R.string.tracking_move_closer)
        count = reach.observe(reachPose(ls, rs, le, re, frame.shortSide), now)
        return active(marks)
    }

    private fun rhythm(joints: Map<Int, MotionPoint>, frame: CameraFrame, now: Long, marks: TrackingMarks, missing: Int): MovementSample {
        val state = if (seated) {
            val ls = joints[LEFT_SHOULDER] ?: return lost(now, marks, missing)
            val rs = joints[RIGHT_SHOULDER] ?: return lost(now, marks, missing)
            val lw = joints[LEFT_WRIST]
            val rw = joints[RIGHT_WRIST]
            if (lw != null && rw != null) {
                val margin = frame.uprightHeight * 0.08
                when {
                    minOf(ls.y - lw.y, rs.y - rw.y) > margin -> 1
                    minOf(lw.y - ls.y, rw.y - rs.y) > margin -> 0
                    else -> null
                }
            } else {
                val le = joints[LEFT_ELBOW] ?: return lost(now, marks, missing)
                val re = joints[RIGHT_ELBOW] ?: return lost(now, marks, missing)
                reachPose(ls, rs, le, re, frame.shortSide)
            }
        } else {
            val leg = visibleSide(joints, LEG_SIDES) ?: return lost(now, marks, missing)
            if (side != leg.first) cycle.interrupt()
            side = leg.first
            val (hip, knee, ankle) = leg.second
            when (jointAngle(hip, knee, ankle)) {
                in 155.0..180.0 -> 0
                in 0.0..125.0 -> 1
                else -> null
            }
        }
        count = cycle.observe(state, now, holdMillis = 120, visible = true)
        return active(marks)
    }

    private fun jumpingJacks(joints: Map<Int, MotionPoint>, frame: CameraFrame, now: Long, marks: TrackingMarks, missing: Int): MovementSample {
        val ls = joints[LEFT_SHOULDER] ?: return lost(now, marks, missing)
        val rs = joints[RIGHT_SHOULDER] ?: return lost(now, marks, missing)
        val lw = joints[LEFT_WRIST]
        val rw = joints[RIGHT_WRIST]
        val le = joints[LEFT_ELBOW]
        val re = joints[RIGHT_ELBOW]
        if ((lw == null && le == null) || (rw == null && re == null)) return lost(now, marks, missing)
        val la = joints[LEFT_ANKLE] ?: return lost(now, marks, R.string.tracking_show_feet)
        val ra = joints[RIGHT_ANKLE] ?: return lost(now, marks, R.string.tracking_show_feet)
        val shoulderWidth = abs(ls.x - rs.x)
        if (shoulderWidth < frame.shortSide * 0.06) return lost(now, marks, R.string.tracking_move_closer)
        val feet = abs(la.x - ra.x)
        val leftUp = lw?.let { ls.y - it.y > frame.uprightHeight * 0.06 } ?: (le != null && ls.y - le.y > -frame.uprightHeight * 0.02)
        val rightUp = rw?.let { rs.y - it.y > frame.uprightHeight * 0.06 } ?: (re != null && rs.y - re.y > -frame.uprightHeight * 0.02)
        val leftDown = lw?.let { it.y - ls.y > frame.uprightHeight * 0.05 } ?: (le != null && le.y - ls.y > frame.uprightHeight * 0.08)
        val rightDown = rw?.let { it.y - rs.y > frame.uprightHeight * 0.05 } ?: (re != null && re.y - rs.y > frame.uprightHeight * 0.08)
        val state = when {
            leftUp && rightUp && feet > shoulderWidth * 1.25 -> 1
            leftDown && rightDown && feet <= shoulderWidth * 1.15 -> 0
            else -> null
        }
        count = cycle.observe(state, now, holdMillis = 100, visible = true)
        return active(marks)
    }

    private fun pushUp(joints: Map<Int, MotionPoint>, frame: CameraFrame, now: Long, marks: TrackingMarks, missing: Int): MovementSample {
        val chain = visibleSide(joints, PUSH_UP_SIDES) ?: return lost(now, marks, missing)
        if (side != chain.first) pushUp.interrupt()
        side = chain.first
        val (shoulder, elbow, wrist, hip, ankle) = chain.second
        val stance = ankle - shoulder
        val incline = Math.toDegrees(atan2(abs(stance.y), abs(stance.x)))
        val body = jointAngle(shoulder, hip, ankle)
        val supported = shoulder.y <= wrist.y + frame.uprightHeight * 0.02 &&
            abs(wrist.y - ankle.y) <= maxOf(24.0, stance.length * 0.28)
        if (!supported) return lost(now, marks, R.string.tracking_push_up_form)
        count = pushUp.observe(jointAngle(shoulder, elbow, wrist), body, incline, now)
        return if (body >= 150 && incline <= 42) active(marks) else MovementSample(count, R.string.tracking_push_up_form, marks)
    }

    private fun visibleSide(joints: Map<Int, MotionPoint>, sides: Array<IntArray>): Pair<Int, List<MotionPoint>>? {
        // Keep the current side while visible so a transient landmark cannot switch the counter mid-rep.
        val preferred = side ?: 0
        for (index in listOf(preferred, 1 - preferred)) {
            val names = sides[index]
            if (names.all { it in joints }) return index to names.map { joints.getValue(it) }
        }
        return null
    }

    private fun active(marks: TrackingMarks) = MovementSample(count, R.string.tracking_active, marks)

    private fun bodyMarks(joints: Map<Int, MotionPoint>): TrackingMarks {
        val paths = buildList {
            for ((color, chain) in BODY_CHAINS) {
                for (i in 1 until chain.size) {
                    val a = joints[chain[i - 1]]
                    val b = joints[chain[i]]
                    if (a != null && b != null) add(TrackingPath(listOf(a, b), color))
                }
            }
            val ls = joints[LEFT_SHOULDER]; val rs = joints[RIGHT_SHOULDER]
            val lh = joints[LEFT_HIP]; val rh = joints[RIGHT_HIP]
            if (ls != null && rs != null && lh != null && rh != null) {
                add(TrackingPath(listOf(ls.midpoint(rs), lh.midpoint(rh)), TrackingColor.BODY))
            }
        }
        return TrackingMarks(paths, BODY_JOINTS.mapNotNull(joints::get))
    }

    private fun jointAngle(a: MotionPoint, pivot: MotionPoint, b: MotionPoint): Double {
        val u = a - pivot
        val v = b - pivot
        val magnitude = u.length * v.length
        if (magnitude == 0.0) return Double.NaN
        return Math.toDegrees(acos(((u.x * v.x + u.y * v.y) / magnitude).coerceIn(-1.0, 1.0)))
    }

    private companion object {
        val LEFT_LEG = intArrayOf(LEFT_HIP, LEFT_KNEE, LEFT_ANKLE)
        val RIGHT_LEG = intArrayOf(RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE)
        val LEFT_PUSH_UP = intArrayOf(LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, LEFT_HIP, LEFT_ANKLE)
        val RIGHT_PUSH_UP = intArrayOf(RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST, RIGHT_HIP, RIGHT_ANKLE)
        val LEG_SIDES = arrayOf(LEFT_LEG, RIGHT_LEG)
        val PUSH_UP_SIDES = arrayOf(LEFT_PUSH_UP, RIGHT_PUSH_UP)
        val BODY_CHAINS = listOf(
            TrackingColor.LEFT to intArrayOf(LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
            TrackingColor.RIGHT to intArrayOf(RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
            TrackingColor.BODY to intArrayOf(LEFT_SHOULDER, RIGHT_SHOULDER),
            TrackingColor.BODY to intArrayOf(LEFT_HIP, RIGHT_HIP),
            TrackingColor.BODY to intArrayOf(LEFT_SHOULDER, LEFT_HIP, LEFT_KNEE, LEFT_ANKLE),
            TrackingColor.BODY to intArrayOf(RIGHT_SHOULDER, RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE),
        )
        val BODY_JOINTS = BODY_CHAINS.flatMap { it.second.toList() }.distinct()
    }
}

private fun PointF.motionPoint() = MotionPoint(x.toDouble(), y.toDouble())
