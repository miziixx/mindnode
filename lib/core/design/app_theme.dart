import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// 다크 테마. 완전한 검정 대신 깊은 차콜. 밤에 오래 보아도 눈이 편하게.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: AppColors.surface1,
      primary: AppColors.accent,
      secondary: AppColors.accent,
      error: AppColors.error,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      splashFactory: InkRipple.splashFactory,
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surface3,
        thumbColor: AppColors.textPrimary,
        trackHeight: 3,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTypography.h1,
        titleLarge: AppTypography.h2,
        titleMedium: AppTypography.h3,
        bodyMedium: AppTypography.body,
        labelSmall: AppTypography.tiny,
      ),
    );
  }
}
