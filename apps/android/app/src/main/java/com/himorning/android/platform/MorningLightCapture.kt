package com.himorning.android.platform

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.himorning.android.ui.MorningTheme
import java.util.concurrent.Executors

internal class MorningLightEvaluator(
    private val brightThreshold: Double = DEFAULT_BRIGHT_THRESHOLD,
    private val dropThreshold: Double = DEFAULT_DROP_THRESHOLD,
    private val holdDurationMs: Long = DEFAULT_HOLD_DURATION_MS,
) {
    sealed interface State {
        data object SeekingLight : State
        data class Holding(val progress: Double) : State
        data object Completed : State
    }

    private var holdStartMs: Long? = null
    var state: State = State.SeekingLight
        private set

    fun process(luminance: Double, timestampMs: Long): State {
        if (state == State.Completed) return State.Completed
        val start = holdStartMs
        if (start == null) {
            if (luminance >= brightThreshold) {
                holdStartMs = timestampMs
                state = State.Holding(0.0)
            } else {
                state = State.SeekingLight
            }
            return state
        }
        if (luminance < dropThreshold) {
            holdStartMs = null
            state = State.SeekingLight
            return state
        }
        val elapsed = (timestampMs - start).coerceAtLeast(0L)
        val progress = (elapsed.toDouble() / holdDurationMs.coerceAtLeast(200L)).coerceIn(0.0, 1.0)
        state = if (elapsed >= holdDurationMs) State.Completed else State.Holding(progress)
        return state
    }

    companion object {
        const val DEFAULT_BRIGHT_THRESHOLD = 0.58
        const val DEFAULT_DROP_THRESHOLD = 0.48
        const val DEFAULT_HOLD_DURATION_MS = 2000L
    }
}

@Composable
fun MorningLightCapture(
    progress: Float,
    onProgress: (Float) -> Unit,
    onHoldingChanged: (Boolean) -> Unit,
    onComplete: () -> Unit,
    onError: (CaptureError) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val latestProgress by rememberUpdatedState(onProgress)
    val latestHolding by rememberUpdatedState(onHoldingChanged)
    val latestComplete by rememberUpdatedState(onComplete)
    val latestError by rememberUpdatedState(onError)
    val preview = remember(context) {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
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
                .setResolutionSelector(
                    ResolutionSelector.Builder()
                        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                        .build(),
                )
                .build().also { it.setSurfaceProvider(preview.surfaceProvider) }
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
            val evaluator = MorningLightEvaluator()
            var provider: ProcessCameraProvider? = null
            var disposed = false
            var completed = false

            val timeout = Runnable {
                if (!disposed && !completed) latestError(CaptureError.TIMEOUT)
            }
            main.postDelayed(timeout, 90_000)

            analysis.setAnalyzer(executor) { proxy: ImageProxy ->
                try {
                    if (disposed || completed) return@setAnalyzer
                    val plane = proxy.planes.firstOrNull() ?: return@setAnalyzer
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
                            x += 4
                        }
                        y += 4
                    }
                    if (count <= 0L) return@setAnalyzer
                    val luminance = sum.toDouble() / (count.toDouble() * 255.0)
                    val state = evaluator.process(luminance, SystemClock.elapsedRealtime())
                    main.post {
                        if (disposed || completed) return@post
                        when (state) {
                            is MorningLightEvaluator.State.SeekingLight -> {
                                latestHolding(false)
                                latestProgress(0f)
                            }
                            is MorningLightEvaluator.State.Holding -> {
                                latestHolding(true)
                                latestProgress(state.progress.toFloat())
                            }
                            is MorningLightEvaluator.State.Completed -> {
                                completed = true
                                latestHolding(true)
                                latestProgress(1f)
                                latestComplete()
                            }
                        }
                    }
                } finally {
                    proxy.close()
                }
            }

            providerFuture.addListener({
                if (!disposed) {
                    runCatching {
                        val cameraProvider = providerFuture.get()
                        provider = cameraProvider
                        val selector = if (cameraProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)) {
                            CameraSelector.DEFAULT_BACK_CAMERA
                        } else {
                            CameraSelector.DEFAULT_FRONT_CAMERA
                        }
                        cameraProvider.bindToLifecycle(owner, selector, cameraPreview, analysis)
                    }.onFailure {
                        Log.w("MorningLightCapture", "Could not bind camera", it)
                        latestError(CaptureError.CAMERA_UNAVAILABLE)
                    }
                }
            }, ContextCompat.getMainExecutor(context))

            onDispose {
                disposed = true
                main.removeCallbacks(timeout)
                analysis.clearAnalyzer()
                provider?.unbind(cameraPreview, analysis)
                executor.shutdown()
            }
        }
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .widthIn(max = 260.dp)
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(RoundedCornerShape(20.dp))
                .background(Color.Black),
        ) {
            AndroidView(
                factory = { ctx ->
                    FrameLayout(ctx).apply {
                        addView(preview, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
                    }
                },
                modifier = Modifier.fillMaxSize(),
            )
        }
        LinearProgressIndicator(
            progress = { progress.coerceIn(0f, 1f) },
            modifier = Modifier.widthIn(max = 240.dp).fillMaxWidth().clip(RoundedCornerShape(999.dp)),
            color = MorningTheme.colors.yellow,
            trackColor = MorningTheme.colors.soft,
        )
    }
}
