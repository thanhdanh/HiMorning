package com.himorning.android.platform

import android.content.Context
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.os.SystemClock
import android.view.View
import androidx.camera.core.ImageProxy
import androidx.camera.view.PreviewView

internal class CameraFrame(proxy: ImageProxy) {
    private val width = proxy.width
    private val height = proxy.height
    val rotation = proxy.imageInfo.rotationDegrees
    private val sideways = rotation == 90 || rotation == 270
    val uprightWidth = if (sideways) height else width
    val uprightHeight = if (sideways) width else height
    val shortSide = minOf(width, height)
    private val sensorToBuffer = Matrix(proxy.imageInfo.sensorToBufferTransformMatrix)

    fun contains(point: MotionPoint, margin: Double) =
        point.x > uprightWidth * margin && point.x < uprightWidth * (1 - margin) &&
            point.y > uprightHeight * margin && point.y < uprightHeight * (1 - margin)

    fun projection(preview: PreviewView): Matrix? {
        val sensorToView = preview.sensorToViewTransform ?: return null
        val bufferToSensor = Matrix()
        if (!sensorToBuffer.invert(bufferToSensor)) return null
        return Matrix().apply { setConcat(sensorToView, bufferToSensor) }
    }

    fun rawPoint(point: MotionPoint) = rawCameraPoint(point, width, height, rotation)
}

internal enum class TrackingColor(val argb: Int) {
    LEFT(0xFF64DCC4.toInt()), RIGHT(0xFF46D9F4.toInt()),
    BODY(0xFFFFDD55.toInt()), HEAD(0xFFFFA44A.toInt())
}

internal data class TrackingPath(val points: List<MotionPoint>, val color: TrackingColor, val closed: Boolean = false)
internal data class TrackingMarks(
    val paths: List<TrackingPath> = emptyList(),
    val joints: Collection<MotionPoint> = emptyList(),
)

internal class TrackingOverlay(context: Context, private val preview: PreviewView) : View(context) {
    private data class Sample(val frame: CameraFrame, val marks: TrackingMarks, val time: Long)

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val density = resources.displayMetrics.density
    private val path = Path()
    private val coords = FloatArray(2)
    private var sample: Sample? = null
    private val expire = Runnable { invalidate() }

    init { importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO }

    fun update(frame: CameraFrame, marks: TrackingMarks, time: Long) {
        removeCallbacks(expire)
        sample = Sample(frame, marks, time)
        invalidate()
        postDelayed(expire, (500 - (SystemClock.elapsedRealtime() - time)).coerceAtLeast(0))
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(expire)
        sample = null
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        val (frame, marks, time) = sample ?: return
        if (SystemClock.elapsedRealtime() - time >= 500) return
        val projection = frame.projection(preview) ?: return

        fun project(point: MotionPoint) {
            val raw = frame.rawPoint(point)
            coords[0] = raw.x.toFloat()
            coords[1] = raw.y.toFloat()
            projection.mapPoints(coords)
        }

        for (line in marks.paths) {
            path.rewind()
            project(line.points.first())
            path.moveTo(coords[0], coords[1])
            for (point in line.points.drop(1)) {
                project(point)
                path.lineTo(coords[0], coords[1])
            }
            if (line.closed) path.close()
            paint.style = Paint.Style.STROKE
            paint.color = 0xB3000000.toInt()
            paint.strokeWidth = 5f * density
            canvas.drawPath(path, paint)
            paint.color = line.color.argb
            paint.strokeWidth = 2.5f * density
            canvas.drawPath(path, paint)
        }
        paint.style = Paint.Style.FILL
        for (joint in marks.joints) {
            project(joint)
            paint.color = 0xB3000000.toInt()
            canvas.drawCircle(coords[0], coords[1], 3.5f * density, paint)
            paint.color = 0xFFFFFFFF.toInt()
            canvas.drawCircle(coords[0], coords[1], 2.75f * density, paint)
        }
    }
}
