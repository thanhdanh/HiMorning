package com.himorning.android.ui

import android.animation.ValueAnimator
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.himorning.android.R
import com.himorning.android.core.ChallengeKind
import kotlin.math.roundToInt

private enum class MovementAnimation(val drawable: Int, val frames: Int) {
    WAVE(R.drawable.motion_wave, 26),
    PUSH_UPS(R.drawable.motion_push_ups, 62),
    JUMPING_JACKS(R.drawable.motion_jumping_jacks, 34),
    REACH(R.drawable.motion_reach, 67),
    NECK(R.drawable.motion_neck, 86),
    STANDING(R.drawable.motion_rhythm_standing, 67),
    SEATED(R.drawable.motion_rhythm_seated, 62),
}

@Composable
internal fun MovementChallengeIcon(
    kind: ChallengeKind,
    seated: Boolean = false,
    tint: Color,
    size: Dp,
    animated: Boolean = true,
) {
    val animation = when (kind) {
        ChallengeKind.WAVE_HAND -> MovementAnimation.WAVE
        ChallengeKind.PUSH_UPS -> MovementAnimation.PUSH_UPS
        ChallengeKind.SQUATS -> MovementAnimation.STANDING
        ChallengeKind.JUMPING_JACKS -> MovementAnimation.JUMPING_JACKS
        ChallengeKind.STRETCHING -> MovementAnimation.REACH
        ChallengeKind.NECK_ROTATION -> MovementAnimation.NECK
        ChallengeKind.GUIDED_RHYTHM -> if (seated) MovementAnimation.SEATED else MovementAnimation.STANDING
        else -> null
    }
    if (animation == null || !animated || !ValueAnimator.areAnimatorsEnabled()) {
        Icon(challengeIcon(kind, seated), contentDescription = null, tint = tint, modifier = Modifier.size(size))
        return
    }

    // Each atlas has eight columns of 96px poses sampled from the iOS movement illustration.
    val atlas = ImageBitmap.imageResource(animation.drawable)
    val frame = remember(animation) { mutableIntStateOf(animation.frames / 4) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val colorFilter = remember(tint) { ColorFilter.tint(tint) }
    LaunchedEffect(animation, lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) {
            val start = withFrameNanos { it }
            while (true) {
                withFrameNanos { time ->
                    if (ValueAnimator.areAnimatorsEnabled()) {
                        frame.intValue = (((time - start) * 24 / 1_000_000_000) % animation.frames).toInt()
                    } else {
                        frame.intValue = animation.frames / 4
                    }
                }
            }
        }
    }
    Canvas(Modifier.size(size)) {
        val step = frame.intValue
        val frameSize = atlas.width / 8
        drawImage(
            image = atlas,
            srcOffset = IntOffset(step % 8 * frameSize, step / 8 * frameSize),
            srcSize = IntSize(frameSize, frameSize),
            dstSize = IntSize(this.size.width.roundToInt(), this.size.height.roundToInt()),
            colorFilter = colorFilter,
            filterQuality = FilterQuality.Medium,
        )
    }
}
