import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/design/app_colors.dart';
import 'core/design/app_tokens.dart';
import 'core/state/app_state.dart';
import 'core/state/playback_controller.dart';
import 'screens/home/home_screen.dart';
import 'screens/chakra/chakra_screen.dart';
import 'screens/studio/studio_screen.dart';
import 'screens/records/records_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/dreamy_background.dart';
import 'widgets/mini_player.dart';

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
    StudioScreen(),
    RecordsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final playback = context.watch<PlaybackController>();
    final showMini = playback.isActive && playback.session != null;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 모든 탭 화면 공통의 은은한 몽환 배경(단일 애니메이션).
          Positioned.fill(
            child: DreamyBackground(
              accent: AppColors.accent,
              reduceMotion: app.settings.reduceMotion,
              particleCount: 30,
            ),
          ),
          Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
          child: Stack(
            children: [
              // 하단바/미니플레이어 높이만큼 하단 여백 확보(콘텐츠 안 가려짐).
              Positioned.fill(
                child: IndexedStack(
                  index: app.navIndex,
                  children: _pages,
                ),
              ),
              // 미니 플레이어(하단바 바로 위)
              Positioned(
                left: 10,
                right: 10,
                bottom: AppMetrics.navHeight + bottomInset + 8,
                child: MiniPlayer(visible: showMini),
              ),
              // 하단 내비게이션(모든 주요 화면 공통)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}
