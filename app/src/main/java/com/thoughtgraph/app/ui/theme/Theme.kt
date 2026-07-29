package com.thoughtgraph.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.thoughtgraph.app.R

// Warm ivory + coral palette taken directly from the prototype.
val Bg = Color(0xFFF5F1E9)
val Panel = Color(0xFFFFFDF8)
val Panel2 = Color(0xFFFAF6EE)
val Line = Color(0xFFE5DDD1)
val TextMain = Color(0xFF26241F)
val Muted = Color(0xFF888177)
val Accent = Color(0xFFEF7657)
val AccentDark = Color(0xFFC75437)
val AccentSoft = Color(0xFFFFF0EA)
val Green = Color(0xFF628F76)
val GreenSoft = Color(0xFFEDF5EF)
val Purple = Color(0xFF8175BA)
val PurpleSoft = Color(0xFFF2EFFA)
val Yellow = Color(0xFFD6A94F)
val YellowSoft = Color(0xFFFFF7DF)
val Danger = Color(0xFFC85151)
val DangerSoft = Color(0xFFFFF0F0)

// High contrast overrides.
val LineHc = Color(0xFFC8BFB3)
val TextHc = Color(0xFF11100E)

/**
 * Central theme values so the point colour can later be re-skinned without
 * touching individual screens.
 */
data class TgColors(
    val bg: Color,
    val panel: Color,
    val panel2: Color,
    val line: Color,
    val text: Color,
    val muted: Color,
    val accent: Color,
    val accentDark: Color,
    val accentSoft: Color,
    val highContrast: Boolean
)

fun tgColors(highContrast: Boolean): TgColors = TgColors(
    bg = Bg,
    panel = Panel,
    panel2 = Panel2,
    line = if (highContrast) LineHc else Line,
    text = if (highContrast) TextHc else TextMain,
    muted = if (highContrast) Color(0xFF5C554C) else Muted,
    accent = Accent,
    accentDark = AccentDark,
    accentSoft = AccentSoft,
    highContrast = highContrast
)

// Pretendard, matching the prototype's font stack.
val Pretendard = FontFamily(
    Font(R.font.pretendard_regular, FontWeight.Normal),
    Font(R.font.pretendard_medium, FontWeight.Medium),
    Font(R.font.pretendard_medium, FontWeight.SemiBold),
    Font(R.font.pretendard_bold, FontWeight.Bold),
    Font(R.font.pretendard_black, FontWeight.Black)
)

private fun Typography.withFont(f: FontFamily) = Typography(
    displayLarge = displayLarge.copy(fontFamily = f),
    displayMedium = displayMedium.copy(fontFamily = f),
    displaySmall = displaySmall.copy(fontFamily = f),
    headlineLarge = headlineLarge.copy(fontFamily = f),
    headlineMedium = headlineMedium.copy(fontFamily = f),
    headlineSmall = headlineSmall.copy(fontFamily = f),
    titleLarge = titleLarge.copy(fontFamily = f),
    titleMedium = titleMedium.copy(fontFamily = f),
    titleSmall = titleSmall.copy(fontFamily = f),
    bodyLarge = bodyLarge.copy(fontFamily = f),
    bodyMedium = bodyMedium.copy(fontFamily = f),
    bodySmall = bodySmall.copy(fontFamily = f),
    labelLarge = labelLarge.copy(fontFamily = f),
    labelMedium = labelMedium.copy(fontFamily = f),
    labelSmall = labelSmall.copy(fontFamily = f)
)

@Composable
fun ThoughtGraphTheme(
    @Suppress("UNUSED_PARAMETER") darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    // Dark mode is intentionally out of scope for this iteration; we keep the
    // warm light scheme regardless of system setting.
    val scheme = lightColorScheme(
        primary = Accent,
        onPrimary = Color.White,
        background = Bg,
        surface = Panel,
        onSurface = TextMain,
        error = Danger
    )
    MaterialTheme(
        colorScheme = scheme,
        typography = Typography().withFont(Pretendard)
    ) {
        // Ensure raw Text() calls (which start from LocalTextStyle) also use Pretendard.
        CompositionLocalProvider(
            LocalTextStyle provides LocalTextStyle.current.copy(fontFamily = Pretendard),
            content = content
        )
    }
}
