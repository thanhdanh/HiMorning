package com.himorning.android.platform

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import android.widget.FrameLayout
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import com.himorning.android.R
import com.himorning.android.core.ChallengeKind
import kotlinx.coroutines.delay
import java.util.concurrent.Executors

internal fun movementTarget(kind: ChallengeKind, repetitions: Int) = when (kind) {
    ChallengeKind.PUSH_UPS -> repetitions.coerceIn(1, 50)
    ChallengeKind.JUMPING_JACKS -> 10
    else -> 3
}

@Composable
fun MovementCapture(
    kind: ChallengeKind,
    repetitions: Int,
    seated: Boolean,
    progress: Int,
    onProgress: (Int) -> Unit,
    onComplete: () -> Unit,
    onError: (CaptureError) -> Unit,
    modifier: Modifier = Modifier,
) = key(kind, repetitions, seated) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val latestProgress by rememberUpdatedState(onProgress)
    val latestComplete by rememberUpdatedState(onComplete)
    val latestError by rememberUpdatedState(onError)
    val preview = remember(context) {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FIT_CENTER
        }
    }
    val overlay = remember(preview) { TrackingOverlay(context, preview) }
    val target = movementTarget(kind, repetitions)
    var hint by remember { mutableIntStateOf(R.string.tracking_waiting) }
    var freshness by remember { mutableLongStateOf(0) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(150)
            if (SystemClock.elapsedRealtime() - freshness >= 500) hint = R.string.tracking_waiting
        }
    }
    DisposableEffect(context, owner, preview) {
        if (context.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            latestError(CaptureError.PERMISSION_REQUIRED)
            onDispose {}
        } else {
            val executor = Executors.newSingleThreadExecutor()
            val main = Handler(Looper.getMainLooper())
            val providerFuture = ProcessCameraProvider.getInstance(context)
            val cameraPreview = Preview.Builder()
                .setResolutionSelector(ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY).build())
                .build().also { it.setSurfaceProvider(preview.surfaceProvider) }
            val analysisBuilder = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setResolutionSelector(ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(ResolutionStrategy(Size(640, 480), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER))
                    .build())
            if (kind == ChallengeKind.WAVE_HAND) analysisBuilder.setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            val analysis = analysisBuilder.build()
            var provider: ProcessCameraProvider? = null
            var lastProgress = 0
            var disposed = false
            val detector = MovementDetector(context.applicationContext, kind, seated, onError = {
                main.post { if (!disposed) latestError(CaptureError.CAMERA_UNAVAILABLE) }
            }) { frame, sample, timestamp ->
                main.post {
                    if (!disposed && lastProgress < target) {
                        if (SystemClock.elapsedRealtime() - timestamp < 500) {
                            overlay.update(frame, sample.marks, timestamp)
                            hint = sample.hint
                            freshness = timestamp
                        }
                        if (sample.count != lastProgress) {
                            lastProgress = sample.count
                            latestProgress(lastProgress)
                            if (lastProgress >= target) latestComplete()
                        }
                    }
                }
            }
            val timeout = Runnable { if (!disposed && lastProgress < target) latestError(CaptureError.TIMEOUT) }
            main.postDelayed(timeout, 90_000)
            analysis.setAnalyzer(executor, detector::analyze)
            providerFuture.addListener({
                if (!disposed) {
                    runCatching {
                        val cameraProvider = providerFuture.get()
                        provider = cameraProvider
                        cameraProvider.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, cameraPreview, analysis)
                    }.onFailure {
                        Log.w("MovementCapture", "Could not bind front camera", it)
                        latestError(CaptureError.CAMERA_UNAVAILABLE)
                    }
                }
            }, ContextCompat.getMainExecutor(context))

            onDispose {
                disposed = true
                detector.stop()
                main.removeCallbacks(timeout)
                analysis.clearAnalyzer()
                val boundProvider = provider
                executor.execute {
                    try { detector.close() } finally {
                        main.post { boundProvider?.unbind(cameraPreview, analysis) }
                    }
                }
                executor.shutdown()
            }
        }
    }

    Box(modifier.clip(RoundedCornerShape(24.dp)).background(Color.Black)) {
        AndroidView(
            factory = { viewContext ->
                FrameLayout(viewContext).apply {
                    addView(preview, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
                    addView(overlay, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
                }
            },
            modifier = Modifier.fillMaxSize(),
        )
        val badge = RoundedCornerShape(24.dp)
        Text(
            text = stringResource(R.string.movement_progress, progress, target),
            modifier = Modifier.align(Alignment.TopEnd).padding(10.dp)
                .background(Color.Black.copy(alpha = 0.72f), badge).padding(horizontal = 12.dp, vertical = 5.dp),
            style = if (kind == ChallengeKind.JUMPING_JACKS || (kind == ChallengeKind.GUIDED_RHYTHM && !seated))
                MaterialTheme.typography.headlineLarge else MaterialTheme.typography.headlineSmall,
            color = Color.White,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = stringResource(hint),
            modifier = Modifier.align(Alignment.BottomStart).padding(10.dp)
                .background(Color.Black.copy(alpha = 0.72f), badge).padding(horizontal = 10.dp, vertical = 5.dp),
            color = if (hint == R.string.tracking_active) Color(0xFF64DCC4) else Color(0xFFFFDD55),
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

private class MovementDetector(
    private val context: Context,
    private val kind: ChallengeKind,
    seated: Boolean,
    private val onError: () -> Unit,
    private val onSample: (CameraFrame, MovementSample, Long) -> Unit,
) {
    private val tracker = MovementTracker(kind, seated)
    private var hand: HandLandmarker? = null
    private var pose: com.google.mlkit.vision.pose.PoseDetector? = null
    private var face: com.google.mlkit.vision.face.FaceDetector? = null
    private var lastHandedness: String? = null
    private val handRotation = Matrix()
    private var lastTime = -1L
    @Volatile private var stopped = false

    @androidx.annotation.OptIn(markerClass = [androidx.camera.core.ExperimentalGetImage::class])
    fun analyze(proxy: ImageProxy) {
        val timestamp = SystemClock.elapsedRealtime()
        try {
            if (stopped || timestamp <= lastTime) return
            lastTime = timestamp
            if (kind == ChallengeKind.WAVE_HAND && hand == null) {
                try {
                    hand = createHandDetector()
                } catch (failure: Exception) {
                    stop()
                    Log.w("MovementCapture", "Could not start the hand detector", failure)
                    onError()
                    return
                } catch (failure: LinkageError) {
                    stop()
                    Log.w("MovementCapture", "Hand detector is unavailable on this device", failure)
                    onError()
                    return
                }
            }
            val frame = CameraFrame(proxy)
            val sample = try {
                if (kind == ChallengeKind.WAVE_HAND) {
                    analyzeHand(proxy, frame, timestamp)
                } else {
                    val media = proxy.image ?: return
                    val input = InputImage.fromMediaImage(media, frame.rotation)
                    if (kind == ChallengeKind.NECK_ROTATION) {
                        val detector = face ?: FaceDetection.getClient(FaceDetectorOptions.Builder()
                            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL).build()).also { face = it }
                        val faces = Tasks.await(detector.process(input))
                        tracker.face(faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }, frame, timestamp)
                    } else {
                        val detector = pose ?: PoseDetection.getClient(PoseDetectorOptions.Builder()
                            .setDetectorMode(PoseDetectorOptions.STREAM_MODE).build()).also { pose = it }
                        tracker.body(Tasks.await(detector.process(input)), frame, timestamp)
                    }
                }
            } catch (failure: Exception) {
                if (!stopped) Log.w("MovementCapture", "Could not analyze camera frame", failure)
                tracker.lost(timestamp)
            }
            if (!stopped) onSample(frame, sample, timestamp)
        } finally {
            proxy.close()
        }
    }

    private fun createHandDetector(): HandLandmarker = HandLandmarker.createFromOptions(
        context,
        HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("hand_landmarker.task").build())
            .setRunningMode(RunningMode.VIDEO)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.6f)
            .setMinHandPresenceConfidence(0.6f)
            .setMinTrackingConfidence(0.5f)
            .build(),
    )

    private fun analyzeHand(proxy: ImageProxy, frame: CameraFrame, time: Long): MovementSample {
        val detector = checkNotNull(hand)
        val raw = proxy.toBitmap()
        try {
            // MediaPipe owns the backing bitmap after wrapping it in MPImage.
            handRotation.setRotate(frame.rotation.toFloat())
            val bitmap = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, handRotation, false)
            val image = BitmapImageBuilder(bitmap).build()
            try {
                val result = detector.detectForVideo(image, time)
                val points = result.landmarks().firstOrNull() ?: return tracker.lost(time)
                if (points.size < 18) return tracker.lost(time)
                val handedness = result.handedness().firstOrNull()?.firstOrNull()
                val side = handedness?.takeIf { it.score() >= 0.8f }?.categoryName()
                if (side != null) {
                    if (lastHandedness != null && lastHandedness != side) tracker.handChanged()
                    lastHandedness = side
                }
                val palm = PALM_JOINTS.map { index ->
                    val point = points[index]
                    MotionPoint(point.x().toDouble() * frame.uprightWidth, point.y().toDouble() * frame.uprightHeight)
                }
                return tracker.hand(palm, frame, time)
            } finally {
                image.close()
            }
        } finally {
            if (!raw.isRecycled) raw.recycle()
        }
    }

    fun stop() { stopped = true }

    fun close() {
        hand?.close()
        pose?.close()
        face?.close()
    }

    private companion object {
        val PALM_JOINTS = intArrayOf(0, 5, 9, 13, 17)
    }
}
