import 'package:flutter/material.dart';

/// 중앙 관리 색상 토큰. 코드 곳곳에 색을 흩어놓지 않는다.
/// 완전한 검정을 배경으로 쓰지 않고, 청/회색이 섞인 깊은 차콜을 사용한다.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = Color(0xFF0B0D12);
  static const Color surface1 = Color(0xFF12161E); // primary surface
  static const Color surface2 = Color(0xFF181D27); // secondary surface
  static const Color surface3 = Color(0xFF202631); // elevated surface
  static const Color surface4 = Color(0xFF272E3A);
  static const Color deep = Color(0xFF080A0E); // deep surface

  // Text
  static const Color textPrimary = Color(0xFFF1F0EB);
  static const Color textSecondary = Color(0xFFB4B8C1);
  static const Color textMuted = Color(0xFF7C828E);
  static const Color textDisabled = Color(0xFF545A65);

  // Dividers / pressed
  static const Color divider = Color(0xFF272D38);
  static Color softDivider = Colors.white.withOpacity(0.06);
  static Color pressed = Colors.white.withOpacity(0.08);

  // Status
  static const Color success = Color(0xFF7EA990);
  static const Color warning = Color(0xFFC8A76E);
  static const Color error = Color(0xFFBD7373);
  static const Color info = Color(0xFF7896B9);

  // Neutral accent (지배적이지 않은 은은한 포인트)
  static const Color accent = Color(0xFF7896B9);
}

/// 차크라 포인트 색상 — 낮은 채도, 깊은 명도. 화면 전체를 채우지 않는다.
class ChakraColors {
  ChakraColors._();

  static const Color root = Color(0xFF8D4A52); // 1 딥 버건디
  static const Color sacral = Color(0xFFB06A45); // 2 번트 오렌지
  static const Color solar = Color(0xFFC39A4B); // 3 앰버 골드
  static const Color heart = Color(0xFF6F987D); // 4 세이지 그린
  static const Color throat = Color(0xFF668BA5); // 5 스모키 블루
  static const Color thirdEye = Color(0xFF626793); // 6 딥 인디고
  static const Color crown = Color(0xFF8A739D); // 7 뮤트 바이올렛

  /// 차크라 인덱스(1..7) → 색상.
  static Color byIndex(int oneBased) {
    switch (oneBased) {
      case 1:
        return root;
      case 2:
        return sacral;
      case 3:
        return solar;
      case 4:
        return heart;
      case 5:
        return throat;
      case 6:
        return thirdEye;
      case 7:
        return crown;
      default:
        return AppColors.accent;
    }
  }

  static const List<Color> ordered = [
    root,
    sacral,
    solar,
    heart,
    throat,
    thirdEye,
    crown,
  ];
}
