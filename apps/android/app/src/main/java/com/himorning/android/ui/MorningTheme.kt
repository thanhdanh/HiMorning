package com.himorning.android.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.unit.sp
import com.himorning.android.R
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.Typography

internal data class MorningColors(
    val canvas: Color,
    val surface: Color,
    val soft: Color,
    val ink: Color,
    val muted: Color,
    val line: Color,
    val yellow: Color,
    val alarmCard: Color,
    val hero: Color,
    val onYellow: Color,
    val accent: Color,
    val success: Color,
    val correctWord: Color,
)

private val lightMorningColors = MorningColors(
    canvas = Color(0xFFFFFCF6), surface = Color.White, soft = Color(0xFFF4F1E9),
    ink = Color(0xFF29251D), muted = Color(0xFF756F63), line = Color(0xFFE9E5DC),
    yellow = Color(0xFFF5C842), alarmCard = Color(0xFFF9E07D), hero = Color(0xFFF8D960),
    onYellow = Color(0xFF29251D), accent = Color(0xFF967211), success = Color(0xFF44634A),
    correctWord = Color(0xFF126B36),
)
private val darkMorningColors = MorningColors(
    canvas = Color(0xFF201F1A), surface = Color(0xFF2C2A24), soft = Color(0xFF353229),
    ink = Color(0xFFF8F4EA), muted = Color(0xFFC2BBAE), line = Color(0xFF49463D),
    yellow = Color(0xFFF5C842), alarmCard = Color(0xFFF9E07D), hero = Color(0xFFF8D960),
    onYellow = Color(0xFF29251D), accent = Color(0xFFF5C842), success = Color(0xFFBDD6BF),
    correctWord = Color(0xFF7FE5A2),
)

// Nunito ships under the bundled OFL; explicit axes avoid its default 200 weight.
@OptIn(ExperimentalTextApi::class)
private val roundedMorningFont = FontFamily(
    listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold, FontWeight.Bold).map { weight ->
        Font(R.font.nunito, weight = weight, variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)))
    },
)

private val LocalMorningColors = compositionLocalOf { lightMorningColors }

internal object MorningTheme {
    val colors: MorningColors @Composable get() = LocalMorningColors.current
}

@Composable
internal fun HiMorningTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val palette = if (dark) darkMorningColors else lightMorningColors
    val error = if (dark) Color(0xFFFFB4AB) else Color(0xFFBA453E)
    val scheme = if (dark) darkColorScheme(
        primary = palette.accent, onPrimary = if (dark) palette.onYellow else Color.White,
        primaryContainer = palette.soft, onPrimaryContainer = palette.ink,
        inversePrimary = lightMorningColors.accent,
        secondary = palette.success, onSecondary = palette.canvas,
        secondaryContainer = palette.soft, onSecondaryContainer = palette.ink,
        tertiary = palette.accent, onTertiary = palette.onYellow,
        tertiaryContainer = palette.soft, onTertiaryContainer = palette.ink,
        background = palette.canvas, onBackground = palette.ink, surface = palette.surface,
        onSurface = palette.ink, surfaceVariant = palette.soft, onSurfaceVariant = palette.muted,
        surfaceTint = palette.accent,
        inverseSurface = lightMorningColors.ink, inverseOnSurface = lightMorningColors.surface,
        surfaceDim = palette.canvas, surfaceBright = palette.surface,
        surfaceContainerLowest = palette.canvas, surfaceContainerLow = palette.canvas,
        surfaceContainer = palette.surface, surfaceContainerHigh = palette.soft,
        surfaceContainerHighest = palette.soft,
        outline = palette.line, outlineVariant = palette.line,
        error = error, onError = Color.White, errorContainer = palette.soft, onErrorContainer = error,
    ) else lightColorScheme(
        primary = palette.accent, onPrimary = Color.White,
        primaryContainer = palette.soft, onPrimaryContainer = palette.ink,
        inversePrimary = darkMorningColors.accent,
        secondary = palette.success, onSecondary = Color.White,
        secondaryContainer = palette.soft, onSecondaryContainer = palette.ink,
        tertiary = palette.accent, onTertiary = Color.White,
        tertiaryContainer = palette.soft, onTertiaryContainer = palette.ink,
        background = palette.canvas, onBackground = palette.ink, surface = palette.surface,
        onSurface = palette.ink, surfaceVariant = palette.soft, onSurfaceVariant = palette.muted,
        surfaceTint = palette.accent,
        inverseSurface = darkMorningColors.ink, inverseOnSurface = darkMorningColors.surface,
        surfaceDim = Color(0xFFE7E1D7), surfaceBright = Color.White,
        surfaceContainerLowest = Color.White, surfaceContainerLow = palette.canvas,
        surfaceContainer = palette.surface, surfaceContainerHigh = palette.soft,
        surfaceContainerHighest = palette.soft,
        outline = palette.line, outlineVariant = palette.line,
        error = error, onError = Color.White, errorContainer = Color(0xFFFFDAD5), onErrorContainer = error,
    )
    val typography = Typography().let { base ->
        base.copy(
            displayLarge = base.displayLarge.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-1).sp),
            displayMedium = base.displayMedium.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-.8).sp),
            displaySmall = base.displaySmall.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-.6).sp),
            headlineLarge = base.headlineLarge.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-.4).sp),
            headlineMedium = base.headlineMedium.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-.4).sp),
            headlineSmall = base.headlineSmall.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold, letterSpacing = (-.4).sp),
            titleLarge = base.titleLarge.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold),
            titleMedium = base.titleMedium.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.Medium),
            titleSmall = base.titleSmall.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.Medium),
            bodyLarge = base.bodyLarge.copy(fontFamily = FontFamily.SansSerif),
            bodyMedium = base.bodyMedium.copy(fontFamily = FontFamily.SansSerif),
            bodySmall = base.bodySmall.copy(fontFamily = FontFamily.SansSerif),
            labelLarge = base.labelLarge.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.SemiBold),
            labelMedium = base.labelMedium.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.Medium),
            labelSmall = base.labelSmall.copy(fontFamily = roundedMorningFont, fontWeight = FontWeight.Medium),
        )
    }
    CompositionLocalProvider(LocalMorningColors provides palette) {
        MaterialTheme(colorScheme = scheme, typography = typography, content = content)
    }
}
