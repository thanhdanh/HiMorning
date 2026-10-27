package com.himorning.android.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.AccessibilityNew
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.PlayCircleOutline
import androidx.compose.material.icons.outlined.SelfImprovement
import androidx.compose.material.icons.outlined.Spa
import androidx.compose.material.icons.outlined.WavingHand
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.himorning.android.core.Alarm
import com.himorning.android.core.ChallengeKind
import com.himorning.android.core.WakeMode

@Composable
internal fun MorningButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    primary: Boolean = true,
    enabled: Boolean = true,
    leadingIcon: androidx.compose.ui.graphics.vector.ImageVector? = null,
) {
    val colors = MorningTheme.colors
    val interactions = remember { MutableInteractionSource() }
    val buttonSurface = if (primary) colors.yellow else colors.surface
    Button(
        onClick = onClick,
        enabled = enabled,
        interactionSource = interactions,
        modifier = modifier.fillMaxWidth().defaultMinSize(minHeight = 48.dp)
            .morningPress(interactions, enabled)
            .morningSurface(buttonSurface, radius = 16.dp, tint = colors.yellow, elevated = primary),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            contentColor = if (primary) colors.onYellow else colors.ink,
            disabledContainerColor = Color.Transparent,
            disabledContentColor = colors.muted,
        ),
        border = if (primary) null else BorderStroke(1.dp, colors.line),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp, pressedElevation = 0.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leadingIcon != null) Icon(leadingIcon, contentDescription = null, modifier = Modifier.padding(end = 8.dp))
            Text(text, style = MaterialTheme.typography.labelLarge, lineHeight = 20.sp)
        }
    }
}

@Composable
internal fun MorningIconButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = MorningTheme.colors
    val interactions = remember { MutableInteractionSource() }
    IconButton(
        onClick = onClick,
        enabled = enabled,
        interactionSource = interactions,
        modifier = modifier.size(48.dp).morningPress(interactions, enabled)
            .morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)
            .semantics { contentDescription = label; role = Role.Button },
    ) { Icon(icon, contentDescription = null, tint = if (enabled) colors.ink else colors.muted.copy(alpha = .45f)) }
}

@Composable
internal fun MorningSunrise(size: Dp = 28.dp, modifier: Modifier = Modifier) {
    val ink = MorningTheme.colors.ink
    Canvas(modifier.size(size)) {
        val u = this.size.minDimension / 24f
        fun point(x: Float, y: Float) = Offset(x * u, y * u)
        fun line(x1: Float, y1: Float, x2: Float, y2: Float) = drawLine(ink, point(x1, y1), point(x2, y2), 1.8f * u, StrokeCap.Round)
        line(2f, 19f, 22f, 19f)
        line(1f, 22f, 23f, 22f)
        drawArc(ink, 180f, 180f, false, point(7f, 11f), androidx.compose.ui.geometry.Size(10f * u, 10f * u), style = Stroke(1.8f * u, cap = StrokeCap.Round))
        line(12f, 1f, 12f, 8f)
        line(8.8f, 4.2f, 12f, 1f)
        line(15.2f, 4.2f, 12f, 1f)
        line(3f, 8f, 5f, 10f)
        line(19f, 10f, 21f, 8f)
        line(1f, 15f, 4f, 15f)
        line(20f, 15f, 23f, 15f)
    }
}

@Composable
internal fun MorningSun(size: Dp = 68.dp, modifier: Modifier = Modifier) {
    val palette = MorningTheme.colors
    Canvas(modifier.size(size)) {
        val center = Offset(this.size.width / 2, this.size.height / 2)
        val unit = this.size.minDimension / 140f
        val rayColor = palette.accent
        repeat(12) { index ->
            val angle = Math.toRadians(index * 30.0)
            val inner = 51f * unit
            val outer = 63f * unit
            drawLine(
                rayColor,
                Offset(center.x + kotlin.math.cos(angle).toFloat() * inner, center.y + kotlin.math.sin(angle).toFloat() * inner),
                Offset(center.x + kotlin.math.cos(angle).toFloat() * outer, center.y + kotlin.math.sin(angle).toFloat() * outer),
                strokeWidth = 2f * unit,
                cap = StrokeCap.Round,
            )
        }
        drawCircle(palette.yellow, radius = 45f * unit, center = center)
        val eyeY = center.y - 4f * unit
        val eyeGap = 12f * unit
        drawCircle(palette.onYellow, radius = 2.2f * unit, center = Offset(center.x - eyeGap, eyeY))
        drawCircle(palette.onYellow, radius = 2.2f * unit, center = Offset(center.x + eyeGap, eyeY))
        val smile = Path().apply {
            moveTo(center.x - 10f * unit, center.y + 7f * unit)
            quadraticTo(center.x, center.y + 17f * unit, center.x + 10f * unit, center.y + 7f * unit)
        }
        drawPath(smile, palette.onYellow, style = Stroke(width = 2.4f * unit, cap = StrokeCap.Round))
    }
}

internal fun challengeIcon(kind: ChallengeKind) = when (kind) {
    ChallengeKind.NONE -> Icons.Outlined.WbSunny
    ChallengeKind.PUSH_UPS -> Icons.Outlined.FitnessCenter
    ChallengeKind.READ_AND_CHOOSE -> Icons.Outlined.Book
    ChallengeKind.GUIDED_RHYTHM -> Icons.Outlined.SelfImprovement
    ChallengeKind.READ_ALOUD -> Icons.Outlined.Mic
    ChallengeKind.WAVE_HAND -> Icons.Outlined.WavingHand
    ChallengeKind.NECK_ROTATION -> Icons.Outlined.AccessibilityNew
    ChallengeKind.RIDDLE -> Icons.Outlined.Lightbulb
    ChallengeKind.JUMPING_JACKS -> Icons.Outlined.DirectionsRun
    ChallengeKind.STRETCHING -> Icons.Outlined.Spa
}

internal fun modeIcon(mode: WakeMode) = when (mode) {
    WakeMode.GENTLE -> Icons.Outlined.Spa
    WakeMode.BALANCED -> Icons.Outlined.WbSunny
    WakeMode.FOCUSED -> Icons.Outlined.Bolt
}

@Composable
internal fun challengeColor(kind: ChallengeKind, onYellow: Boolean = false): Color {
    val dark = isSystemInDarkTheme() && !onYellow
    return when (kind) {
        ChallengeKind.NONE -> if (onYellow) Color(0xFF967211) else MorningTheme.colors.accent
        ChallengeKind.PUSH_UPS, ChallengeKind.JUMPING_JACKS -> if (dark) Color(0xFFFF9166) else Color(0xFFBF472E)
        ChallengeKind.READ_ALOUD, ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE -> if (dark) Color(0xFFBDA6FF) else Color(0xFF6652AD)
        ChallengeKind.GUIDED_RHYTHM, ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION, ChallengeKind.STRETCHING -> if (dark) Color(0xFF66D4BA) else Color(0xFF1F7A70)
    }
}
