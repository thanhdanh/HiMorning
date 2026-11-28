package com.himorning.android.platform

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
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
import com.himorning.android.core.PushUpVariant
import kotlinx.coroutines.delay
import java.util.concurrent.Executors

internal fun movementTarget(kind: ChallengeKind, repetitions: Int) = when (kind) {
    ChallengeKind.PUSH_UPS -> repetitions.coerceIn(1, 50)
    ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS -> 10
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
    pushUpVariant: PushUpVariant = PushUpVariant.STANDARD,
) = key(kind, repetitions, seated, pushUpVariant) {
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
    var romProgress by remember { mutableFloatStateOf(0f) }
    var isLowLight by remember { mutableStateOf(false) }
    var fillLightOn by remember { mutableStateOf(false) }

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
            val detector = MovementDetector(context.applicationContext, kind, seated, pushUpVariant, onError = { error ->
                main.post { if (!disposed) latestError(error) }
            }) { frame, sample, timestamp ->
                main.post {
                    if (!disposed && lastProgress < target) {
                        if (SystemClock.elapsedRealtime() - timestamp < 500) {
                            overlay.update(frame, sample.marks, timestamp)
                            hint = sample.hint
                            romProgress = sample.romProgress.toFloat().coerceIn(0f, 1f)
                            isLowLight = sample.isLowLight
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
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
            val gravityListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    if (event.values.size >= 2) {
                        detector.updateRollDegrees(
                            CameraConditionMath.androidRollDegrees(event.values[0].toDouble(), event.values[1].toDouble()),
                        )
                    }
                }
                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
            }
            if (gravitySensor != null) {
                runCatching { sensorManager.registerListener(gravityListener, gravitySensor, SensorManager.SENSOR_DELAY_UI) }
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
                runCatching { sensorManager?.unregisterListener(gravityListener) }
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

    val shape = RoundedCornerShape(24.dp)
    Box(
        modifier
            .clip(shape)
            .background(Color.Black)
            .then(if (fillLightOn) Modifier.border(14.dp, Color(0xFFFFE4B5), shape) else Modifier),
    ) {
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
        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(10.dp)
                .clip(badge)
                .background(if (fillLightOn) Color(0xFFFFE4B5) else Color.Black.copy(alpha = 0.72f))
                .clickable { fillLightOn = !fillLightOn }
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Icon(
                Icons.Outlined.WbSunny,
                contentDescription = null,
                tint = if (fillLightOn) Color(0xFF1F1608) else if (isLowLight) Color(0xFFFFDD55) else Color.White,
                modifier = Modifier.size(16.dp),
            )
            Text(
                text = stringResource(if (fillLightOn) R.string.fill_light_on else R.string.fill_light_off),
                color = if (fillLightOn) Color(0xFF1F1608) else if (isLowLight) Color(0xFFFFDD55) else Color.White,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
            )
        }
        Text(
            text = stringResource(R.string.movement_progress, progress, target),
            modifier = Modifier.align(Alignment.TopEnd).padding(10.dp)
                .background(Color.Black.copy(alpha = 0.72f), badge).padding(horizontal = 12.dp, vertical = 5.dp),
            style = if (kind == ChallengeKind.JUMPING_JACKS || kind == ChallengeKind.SQUATS || (kind == ChallengeKind.GUIDED_RHYTHM && !seated))
                MaterialTheme.typography.headlineLarge else MaterialTheme.typography.headlineSmall,
            color = Color.White,
            fontWeight = FontWeight.Bold,
        )
        Column(
            modifier = Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (isLowLight && !fillLightOn) {
                Text(
                    text = stringResource(R.string.tracking_low_light),
                    modifier = Modifier.background(Color.Black.copy(alpha = 0.72f), badge).padding(horizontal = 10.dp, vertical = 4.dp),
                    color = Color(0xFFFFDD55),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            Text(
                text = stringResource(hint),
                modifier = Modifier.background(Color.Black.copy(alpha = 0.72f), badge).padding(horizontal = 10.dp, vertical = 5.dp),
                color = if (hint == R.string.tracking_active) Color(0xFF64DCC4) else Color(0xFFFFDD55),
                style = MaterialTheme.typography.labelMedium,
            )
            if (kind == ChallengeKind.PUSH_UPS || kind == ChallengeKind.SQUATS) {
                LinearProgressIndicator(
                    progress = { romProgress },
                    modifier = Modifier.fillMaxWidth().height(7.dp).clip(RoundedCornerShape(999.dp)),
                    color = if (romProgress >= 0.85f) Color(0xFF34D399) else Color(0xFF64DCC4),
                    trackColor = Color.White.copy(alpha = 0.24f),
                )
            }
        }
    }
}

private class MovementDetector(
    private val context: Context,
    private val kind: ChallengeKind,
    seated: Boolean,
    pushUpVariant: PushUpVariant,
    private val onError: (CaptureError) -> Unit,
    private val onSample: (CameraFrame, MovementSample, Long) -> Unit,
) {
    private val tracker = MovementTracker(kind, seated, pushUpVariant)
    private var hand: HandLandmarker? = null
    private var pose: com.google.mlkit.vision.pose.PoseDetector? = null
    private var face: com.google.mlkit.vision.face.FaceDetector? = null
    private var lastHandedness: String? = null
    private val handRotation = Matrix()
    private var lastTime = -1L
    private var frameCounter = 0
    @Volatile private var rollDegrees = 0.0
    @Volatile private var lowLight = false
    private var consecutiveAnalysisErrors = 0
    @Volatile private var stopped = false

    fun updateRollDegrees(degrees: Double) {
        rollDegrees = degrees
    }

    @androidx.annotation.OptIn(markerClass = [androidx.camera.core.ExperimentalGetImage::class])
    fun analyze(proxy: ImageProxy) {
        val timestamp = SystemClock.elapsedRealtime()
        try {
            if (stopped || timestamp <= lastTime) return
            lastTime = timestamp
            if (frameCounter++ % 8 == 0) {
                sampleMeanLuma(proxy)?.let { meanLuma ->
                    lowLight = CameraConditionMath.classifyLuma(meanLuma) == CameraLightingStatus.LOW_LIGHT
                }
            }
            if (kind == ChallengeKind.WAVE_HAND && hand == null) {
                try {
                    hand = createHandDetector()
                } catch (failure: Exception) {
                    stop()
                    Log.w("MovementCapture", "Could not start the hand detector", failure)
                    onError(CaptureError.AI_SCANNER_UNAVAILABLE)
                    return
                } catch (failure: LinkageError) {
                    stop()
                    Log.w("MovementCapture", "Hand detector is unavailable on this device", failure)
                    onError(CaptureError.AI_SCANNER_UNAVAILABLE)
                    return
                }
            }
            val frame = CameraFrame(proxy)
            val currentLowLight = lowLight
            val currentRoll = rollDegrees
            val sample = try {
                val result = if (kind == ChallengeKind.WAVE_HAND) {
                    analyzeHand(proxy, frame, timestamp).copy(isLowLight = currentLowLight)
                } else {
                    val media = proxy.image ?: return
                    val input = InputImage.fromMediaImage(media, frame.rotation)
                    if (kind == ChallengeKind.NECK_ROTATION) {
                        val detector = face ?: FaceDetection.getClient(FaceDetectorOptions.Builder()
                            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL).build()).also { face = it }
                        val faces = Tasks.await(detector.process(input))
                        tracker.face(faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }, frame, timestamp).copy(isLowLight = currentLowLight)
                    } else {
                        val detector = pose ?: PoseDetection.getClient(PoseDetectorOptions.Builder()
                            .setDetectorMode(PoseDetectorOptions.STREAM_MODE).build()).also { pose = it }
                        tracker.body(Tasks.await(detector.process(input)), frame, timestamp, rollDegrees = currentRoll, isLowLight = currentLowLight)
                    }
                }
                consecutiveAnalysisErrors = 0
                result
            } catch (failure: Exception) {
                consecutiveAnalysisErrors++
                if (!stopped) Log.w("MovementCapture", "Could not analyze camera frame", failure)
                if (consecutiveAnalysisErrors >= 10) {
                    stop()
                    onError(CaptureError.AI_SCANNER_UNAVAILABLE)
                    return
                }
                tracker.lost(timestamp, hint = R.string.tracking_ai_unclear, isLowLight = currentLowLight)
            }
            if (!stopped) onSample(frame, sample, timestamp)
        } finally {
            proxy.close()
        }
    }

    private fun sampleMeanLuma(proxy: ImageProxy): Double? {
        if (proxy.format != ImageFormat.YUV_420_888) return null
        val plane = proxy.planes.firstOrNull() ?: return null
        val buffer = plane.buffer
        val width = proxy.width
        val height = proxy.height
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        var sum = 0L
        var count = 0L
        var y = 0
        while (y < height) {
            var x = 0
            val rowOffset = y * rowStride
            while (x < width) {
                val idx = rowOffset + x * pixelStride
                if (idx < buffer.limit()) {
                    sum += (buffer.get(idx).toInt() and 0xFF)
                    count++
                }
                x += 8
            }
            y += 8
        }
        if (count <= 0L) return null
        return sum.toDouble() / (count.toDouble() * 255.0)
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
