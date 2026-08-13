import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/design/app_colors.dart';
import 'core/design/app_tokens.dart';
import 'core/state/app_state.dart';
import 'core/state/playback_controller.dart';
import 'screens/home/home_screen.dart';
import 'screens/chakra/chakra_screen.dart';
import 'screens/studio/studio_workspace.dart';
import 'screens/records/records_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/dreamy_background.dart';
import 'widgets/mini_player.dart';
import 'widgets/side_nav.dart';

/// 앱 루트: 온보딩 게이트 + 탭 셸(하단바 + 미니플레이어 상시 유지).
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!app.settings.onboardingDone) {
      return const OnboardingScreen();
    }
    return const _TabShell();
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell();

  static const _pages = [
    HomeScreen(),
    ChakraScreen(),
    StudioTab(),
    RecordsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final playback = context.watch<PlaybackController>();
    final showMini = playback.isActive && playback.session != null;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // 넓은 화면(태블릿 가로·데스크톱): 좌측 사이드바 + 넓은 콘텐츠 + 상시 플레이어.
    // 좁은 화면(모바일): 기존 하단 탭바 구조 유지.
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 모든 화면 공통의 은은한 몽환 배경(단일 애니메이션).
          Positioned.fill(
            child: DreamyBackground(
              accent: AppColors.accent,
              reduceMotion: app.settings.reduceMotion,
              particleCount: wide ? 44 : 30,
            ),
          ),
          if (wide)
            _wideShell(app, showMini, bottomInset)
          else
            _narrowShell(app, showMini, bottomInset),
        ],
      ),
    );
  }

  // ── 모바일: 하단 탭바 셸 ──
  Widget _narrowShell(AppState app, bool showMini, double bottomInset) {
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: app.navIndex, children: _pages),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: AppMetrics.navHeight + bottomInset + 8,
              child: MiniPlayer(visible: showMini),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  // ── 태블릿/데스크톱: 좌측 사이드바 + 콘텐츠 + 하단 상시 플레이어 ──
  Widget _wideShell(AppState app, bool showMini, double bottomInset) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SideNav(),
        Expanded(
          child: Stack(
            children: [
              // 콘텐츠는 과도하게 늘어나지 않게 중앙 정렬 + 최대 폭 제한.
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: IndexedStack(index: app.navIndex, children: _pages),
                  ),
                ),
              ),
              // 상시 플레이어 바(콘텐츠 폭에 맞춰 하단 고정).
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomInset + 14,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: MiniPlayer(visible: showMini),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
