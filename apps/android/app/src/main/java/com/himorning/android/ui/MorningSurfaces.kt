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

/** Soft surface used by cards and sheets; the thin highlight keeps edges readable without hard outlines. */
@Composable
internal fun Modifier.morningSurface(
    base: Color,
    radius: Dp = 24.dp,
    tint: Color = Color.Transparent,
    elevated: Boolean = true,
): Modifier {
    val dark = isSystemInDarkTheme()
    val shape = RoundedCornerShape(radius)
    val tintAlpha = if (dark) 0.11f else 0.075f
    // Opaque plates prevent native elevation shadows showing through child render-node bounds.
    val solidBase = base.compositeOver(MorningTheme.colors.canvas)
    val tintedBase = tint.copy(alpha = tint.alpha * tintAlpha).compositeOver(solidBase)
    val topLight = Color.White.copy(alpha = if (dark) 0.045f else 0.30f).compositeOver(tintedBase)
    val bottomShade = Color.Black.copy(alpha = if (dark) 0.025f else 0.012f).compositeOver(tintedBase)
    val edgeTop = Color.White.copy(alpha = if (dark) 0.10f else 0.66f)
    val edgeBottom = Color.White.copy(alpha = if (dark) 0.025f else 0.20f)
    val shadowDp = if (elevated) 4.dp else 0.dp

    return this
        .shadow(shadowDp, shape, clip = false,
            ambientColor = Color.Black.copy(alpha = .08f),
            spotColor = Color.Black.copy(alpha = .10f))
        .clip(shape)
        .background(Brush.verticalGradient(listOf(topLight, tintedBase, bottomShade)))
        .border(1.dp, Brush.verticalGradient(listOf(edgeTop, edgeBottom)), shape)
}

/** A static, broad warm wash behind the screen; radial gradients avoid a blur dependency. */
@Composable
internal fun Modifier.morningBackdrop(tint: Color = MorningTheme.colors.yellow): Modifier {
    val canvas = MorningTheme.colors.canvas
    val dark = isSystemInDarkTheme()
    val warmAlpha = if (dark) 0.14f else 0.18f
    val tintAlpha = if (dark) 0.08f else 0.10f
    return this.background(canvas).drawBehind {
        val radius = maxOf(size.width, size.height) * 0.76f
        drawRect(
            Brush.radialGradient(
                colors = listOf(Color(0xFFF5C842).copy(alpha = warmAlpha), Color.Transparent),
                center = Offset(size.width * 0.98f, size.height * 0.02f),
                radius = radius,
            ),
        )
        drawRect(
            Brush.radialGradient(
                colors = listOf(tint.copy(alpha = tint.alpha * tintAlpha), Color.Transparent),
                center = Offset(size.width * 0.02f, size.height * 0.92f),
                radius = radius * 0.82f,
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
    val animatePress = pressed
    val scale by animateFloatAsState(
        targetValue = if (animatePress) 0.96f else 1f,
        animationSpec = spring(dampingRatio = 0.75f, stiffness = 650f),
        label = "morningPressScale",
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
        alpha = if (animatePress) 0.89f else 1f
    }
}
