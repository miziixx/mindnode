import 'package:flutter/widgets.dart';

/// 간격 토큰. 좌우 기본 여백 20, 카드 간격 12, 섹션 간격 28~36.
class AppSpacing {
  AppSpacing._();
  static const double screenH = 20; // 좌우 화면 여백
  static const double cardGap = 12;
  static const double sectionGap = 30;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// 모서리 토큰. 모든 카드를 같은 라운드로 만들지 않는다(용도별 구분).
class AppRadius {
  AppRadius._();
  static const double small = 8;
  static const double medium = 14;
  static const double large = 20;
  static const double pill = 999;
}

/// 아이콘 크기.
class AppIconSize {
  AppIconSize._();
  static const double sm = 18;
  static const double md = 20;
  static const double lg = 24;
}

/// 최소 터치 영역(접근성). 44x44 이상.
class AppTouchTarget {
  AppTouchTarget._();
  static const double min = 44;
  static const double primaryButtonHeight = 52;
}

/// 그림자는 최소화하고 표면 밝기 차이로 깊이를 만든다.
class AppElevation {
  AppElevation._();
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x59000000), blurRadius: 60, offset: Offset(0, -18)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x47000000), blurRadius: 50, offset: Offset(0, 18)),
  ];
}

/// 애니메이션 토큰. 매우 느리고 제한적으로 사용.
class AppAnimation {
  AppAnimation._();
  static const Duration pageTransition = Duration(milliseconds: 220);
  static const Duration cardSelect = Duration(milliseconds: 120);
  static const Duration bottomSheet = Duration(milliseconds: 280);
  static const Duration miniPlayer = Duration(milliseconds: 220);
  static const Duration resonanceRing = Duration(seconds: 8); // 4~12s
  static const Duration droneGlow = Duration(seconds: 18); // 10~30s
  static const Duration chimeRipple = Duration(milliseconds: 1400); // <1.5s
}

/// 플레이어 시각화 토큰(재생 파라미터 기반, 실제 FFT 아님).
class PlayerVisualizationTokens {
  PlayerVisualizationTokens._();
  static const double ringMaxScale = 1.04;
  static const double droneGlowOpacity = 0.10;
  static const int natureParticleCount = 6;
}

/// 하단바/미니플레이어 높이(하단 안전 여백 계산에 사용).
class AppMetrics {
  AppMetrics._();
  static const double navHeight = 74;
  static const double miniPlayerHeight = 72;
  static const double contentMaxWidth = 520; // 태블릿 폭 제한
}
