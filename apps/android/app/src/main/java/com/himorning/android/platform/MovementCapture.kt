package com.himorning.android.platform

import android.Manifest
import android.content.pm.PackageManager
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.camera.core.Preview
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import com.google.mlkit.vision.pose.PoseLandmark
import com.himorning.android.core.ChallengeKind
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.hypot
import kotlin.math.max

/** Counts local pose changes from CameraX frames. It stores and uploads no images. */
@Composable
fun MovementCapture(
    kind: ChallengeKind,
    repetitions: Int,
    seated: Boolean,
    onProgress: (Int) -> Unit,
    onComplete: () -> Unit,
    onError: (CaptureError) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val latestProgress = rememberUpdatedState(onProgress)
    val latestComplete = rememberUpdatedState(onComplete)
    val latestError = rememberUpdatedState(onError)
    val executor = remember(kind, repetitions, seated, owner) { Executors.newSingleThreadExecutor() }
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FIT_CENTER } }
    DisposableEffect(kind, repetitions, seated, owner) {
        if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            onError(CaptureError.PERMISSION_REQUIRED)
            onDispose { executor.shutdown() }
        } else {
            val providerFuture = ProcessCameraProvider.getInstance(context)
            val target = when (kind) { ChallengeKind.PUSH_UPS -> repetitions.coerceIn(1, 50); ChallengeKind.JUMPING_JACKS -> 10; else -> 3 }
            val cameraProvider = AtomicReference<ProcessCameraProvider?>()
            val detector = MovementDetector(kind, target, seated, { latestProgress.value(it) }, { latestComplete.value() }, { failure ->
                ContextCompat.getMainExecutor(context).execute { cameraProvider.get()?.unbindAll(); latestError.value(failure) }
            })
            val timeoutHandler = Handler(Looper.getMainLooper())
            val timeout = Runnable { detector.timeout() }
            timeoutHandler.postDelayed(timeout, 90_000L)
            providerFuture.addListener({
                runCatching {
                    if (detector.isClosed) return@addListener
                    val provider = providerFuture.get()
                    cameraProvider.set(provider)
                    val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                    val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                    analysis.setAnalyzer(executor, detector::analyze)
                    provider.unbindAll()
                    provider.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, preview, analysis)
                }.onFailure { if (!detector.isClosed) latestError.value(CaptureError.CAMERA_UNAVAILABLE) }
            }, ContextCompat.getMainExecutor(context))
            onDispose { timeoutHandler.removeCallbacks(timeout); detector.close(); cameraProvider.get()?.unbindAll(); executor.shutdown() }
        }
    }
    Box(modifier) { AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize()) }
}

private class MovementDetector(
    private val kind: ChallengeKind,
    private val target: Int,
    private val seated: Boolean,
    private val progress: (Int) -> Unit,
    private val complete: () -> Unit,
    private val error: (CaptureError) -> Unit,
) {
    private val poseDetector = PoseDetection.getClient(AccuratePoseDetectorOptions.Builder().setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE).build())
    private val faceDetector: FaceDetector = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).build())
    private val cycle = PoseCycleCounter(when (kind) {
        ChallengeKind.NECK_ROTATION -> listOf(listOf(-1, 0, 1, 0), listOf(1, 0, -1, 0))
        else -> listOf(listOf(0, 1, 0))
    })
    private var reps = 0
    private var lastSample = 0L
    private var waves = 0
    private var lastHandX: Float? = null
    private var waveDirection = 0
    private var waveChangedAt = 0L
    private var lostSince: Long? = null
    private var closed = false
    private var completed = false
    val isClosed get() = closed

    @androidx.annotation.OptIn(markerClass = [androidx.camera.core.ExperimentalGetImage::class])
    fun analyze(proxy: ImageProxy) {
        val media = proxy.image
        if (closed || completed || media == null) { proxy.close(); return }
        val now = SystemClock.elapsedRealtime()
        if (now - lastSample < 90) { proxy.close(); return }
        lastSample = now
        val input = InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees)
        val task = if (kind == ChallengeKind.NECK_ROTATION) {
            faceDetector.process(input).addOnSuccessListener { faces ->
                val face = faces.firstOrNull()
                if (face == null || face.headEulerAngleY.isNaN()) lost(now) else observeNeck(face.headEulerAngleY, now)
            }
        } else {
            poseDetector.process(input).addOnSuccessListener { pose -> observePose(pose, now) }
        }
        task.addOnFailureListener { lost(now) }.addOnCompleteListener { proxy.close() }
    }

    fun timeout() {
        if (closed || completed) return
        closed = true
        error(CaptureError.TIMEOUT)
    }

    private fun observePose(pose: Pose, now: Long) {
        if (closed || completed) return
        val points = pose.allPoseLandmarks.associateBy { it.landmarkType }
        fun p(type: Int) = points[type]?.takeIf { it.inFrameLikelihood >= .55f }?.position
        var state: Int? = null
        when (kind) {
            ChallengeKind.WAVE_HAND -> {
                val wrist = p(PoseLandmark.RIGHT_WRIST) ?: p(PoseLandmark.LEFT_WRIST)
                if (wrist == null) { lost(now); return }
                val leftShoulder = p(PoseLandmark.LEFT_SHOULDER); val rightShoulder = p(PoseLandmark.RIGHT_SHOULDER)
                if (leftShoulder == null || rightShoulder == null) { lost(now); return }
                lostSince = null
                val prior = lastHandX; lastHandX = wrist.x
                if (prior != null && abs(wrist.x - prior) > abs(leftShoulder.x - rightShoulder.x) * .25f && now - waveChangedAt >= 120) {
                    val direction = if (wrist.x > prior) 1 else -1
                    if (waveDirection != 0 && direction != waveDirection) waves++
                    waveDirection = direction; waveChangedAt = now
                    if (waves >= 2) { waves = 0; markRep() }
                }
                return
            }
            ChallengeKind.STRETCHING -> {
                val ls = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER); val rs = p(com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER)
                val lw = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_WRIST); val rw = p(com.google.mlkit.vision.pose.PoseLandmark.RIGHT_WRIST)
                if (ls == null || rs == null || lw == null || rw == null) { lost(now); return }
                state = if (lw.y < ls.y - 24 && rw.y < rs.y - 24) 1 else if (lw.y > ls.y + 35 && rw.y > rs.y + 35) 0 else null
            }
            ChallengeKind.JUMPING_JACKS -> {
                val ls = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER); val rs = p(com.google.mlkit.vision.pose.PoseLandmark.RIGHT_SHOULDER)
                val lw = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_WRIST); val rw = p(com.google.mlkit.vision.pose.PoseLandmark.RIGHT_WRIST)
                val la = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_ANKLE); val ra = p(com.google.mlkit.vision.pose.PoseLandmark.RIGHT_ANKLE)
                if (ls == null || rs == null || lw == null || rw == null || la == null || ra == null) { lost(now); return }
                val shoulderWidth = abs(ls.x - rs.x); val feet = abs(la.x - ra.x)
                state = if (lw.y < ls.y - 20 && rw.y < rs.y - 20 && feet > shoulderWidth * 1.2) 1 else if (feet < shoulderWidth * 1.1 && lw.y > ls.y - 5 && rw.y > rs.y - 5) 0 else null
            }
            ChallengeKind.GUIDED_RHYTHM -> {
                if (seated) {
                    val ls = p(PoseLandmark.LEFT_SHOULDER); val rs = p(PoseLandmark.RIGHT_SHOULDER)
                    val lw = p(PoseLandmark.LEFT_WRIST); val rw = p(PoseLandmark.RIGHT_WRIST)
                    if (ls == null || rs == null || lw == null || rw == null) { lost(now); return }
                    state = if (lw.y < ls.y - 22 && rw.y < rs.y - 22) 1 else if (lw.y > ls.y + 30 && rw.y > rs.y + 30) 0 else null
                } else {
                    val hip = p(PoseLandmark.LEFT_HIP); val knee = p(PoseLandmark.LEFT_KNEE); val ankle = p(PoseLandmark.LEFT_ANKLE)
                    if (hip == null || knee == null || ankle == null) { lost(now); return }
                    val kneeAngle = angle(hip.x - knee.x, hip.y - knee.y, ankle.x - knee.x, ankle.y - knee.y)
                    state = if (kneeAngle >= 160) 0 else if (kneeAngle <= 120) 1 else null
                }
            }
            ChallengeKind.PUSH_UPS -> {
                val shoulder = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_SHOULDER); val elbow = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_ELBOW); val wrist = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_WRIST)
                val hip = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_HIP); val ankle = p(com.google.mlkit.vision.pose.PoseLandmark.LEFT_ANKLE)
                if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null) { lost(now); return }
                val angle = angle(shoulder.x - elbow.x, shoulder.y - elbow.y, wrist.x - elbow.x, wrist.y - elbow.y)
                val body = angle(shoulder.x - hip.x, shoulder.y - hip.y, ankle.x - hip.x, ankle.y - hip.y)
                if (body < 145) { lost(now); return }
                state = if (angle <= 90) 1 else if (angle >= 160) 0 else null
            }
            else -> return
        }
        val count = cycle.observe(state, now, if (state == 1 && kind != ChallengeKind.JUMPING_JACKS) 120 else 220)
        if (count > reps) markRep()
    }

    private fun observeNeck(yaw: Float, now: Long) {
        if (closed || completed) return
        val state = when { yaw >= 20 -> 1; yaw <= -20 -> -1; abs(yaw) <= 8 -> 0; else -> return }
        val count = cycle.observe(state, now, 120)
        if (count > reps) markRep()
    }

    private fun lost(now: Long) {
        cycle.observe(null, now)
        val lost = lostSince ?: now
        lostSince = lost
        if (now - lost > 600) { lastHandX = null; waveDirection = 0; waves = 0 }
    }
    private fun markRep() { if (closed || completed) return; reps++; progress(reps); if (reps >= target) { completed = true; complete() } }
    fun close() { closed = true; poseDetector.close(); faceDetector.close() }
    private fun angle(ax: Float, ay: Float, bx: Float, by: Float): Double {
        val dot = ax * bx + ay * by
        val magnitude = hypot(ax.toDouble(), ay.toDouble()) * hypot(bx.toDouble(), by.toDouble())
        if (magnitude == 0.0) return 0.0
        return Math.toDegrees(acos((dot / magnitude).toDouble().coerceIn(-1.0, 1.0)))
    }
}
