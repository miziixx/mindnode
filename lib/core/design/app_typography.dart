import 'package:flutter/widgets.dart';
import 'app_colors.dart';

/// 타이포그래피 토큰. 한국어는 Pretendard 계열을 기본으로 사용.
/// (폰트 파일은 assets/fonts 에 배치 후 pubspec 에 등록; 없으면 system fallback.)
/// 제목을 과도하게 굵게 만들지 않고, 주파수 숫자는 얇고 크게 표시한다.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Pretendard';
  static const List<String> _fallback = [
    '-apple-system',
    'Roboto',
    'Noto Sans KR',
  ];

  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.textMuted,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 28,
    height: 1.16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 20,
    height: 1.28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 14,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  /// 작은 대문자 라벨(영문). letterSpacing 확대.
  static const TextStyle smallCaps = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  /// 큰 주파수 숫자 — 얇고 크게, 고정폭 숫자.
  static const TextStyle frequencyDisplay = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 54,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  /// 남은 시간 등 중간 크기 숫자.
  static const TextStyle timeDisplay = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontSize: 31,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
    color: AppColors.textPrimary,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: _fallback,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
