package com.himorning.android.ui

import android.animation.ValueAnimator
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Flat surface matching iOS MorningTheme cards and sheets. */
@Composable
internal fun Modifier.morningSurface(
    base: Color,
    radius: Dp = 24.dp,
    tint: Color = Color.Transparent,
    elevated: Boolean = true,
    borderColor: Color? = MorningTheme.colors.line,
): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .clip(shape)
        .background(base)
        .then(
            if (borderColor != null) Modifier.border(1.dp, borderColor, shape)
            else Modifier,
        )
}

/** Single top-right warm radial wash matching iOS MorningBackdrop. */
@Composable
internal fun Modifier.morningBackdrop(tint: Color = MorningTheme.colors.yellow): Modifier {
    val canvas = MorningTheme.colors.canvas
    val dark = isSystemInDarkTheme()
    val warmAlpha = if (dark) 0.12f else 0.16f
    return this.background(canvas).drawBehind {
        val radius = maxOf(size.width, size.height) * 0.72f
        drawRect(
            Brush.radialGradient(
                colors = listOf(tint.copy(alpha = warmAlpha), Color.Transparent),
                center = Offset(size.width * 0.96f, size.height * 0.04f),
                radius = radius,
            ),
        )
    }
}

/** Applies a small press response only when motion is enabled and the control can act. */
@Composable
internal fun Modifier.morningPress(
    interactions: MutableInteractionSource,
    enabled: Boolean = true,
): Modifier {
    if (!enabled || !ValueAnimator.areAnimatorsEnabled()) {
        return this.graphicsLayer {
            scaleX = 1f
            scaleY = 1f
            alpha = 1f
        }
    }
    val pressed by interactions.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.985f else 1f,
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 650f),
        label = "morningPressScale",
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
        alpha = if (pressed) 0.88f else 1f
    }
}
