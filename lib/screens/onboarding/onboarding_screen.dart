import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/state/app_state.dart';
import '../../widgets/common.dart';

/// 온보딩(최대 3단계). 강제 회원가입/권한 요청 없음.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      '주파수와 사운드를 조합합니다',
      '앱이 주파수와 드론을 실시간으로 생성하고\n자연음, 패드, 차임을 함께 재생합니다.\n효과는 상징적이며, 의료용이 아닙니다.'
    ),
    (
      '바이노럴은 이어폰을 끼세요',
      '수면·집중·이완 같은 바이노럴 세션은\n좌우 귀에 다른 주파수를 보내므로 이어폰이 필요합니다.\n차크라·기본 세션은 스피커로도 괜찮아요.'
    ),
    (
      '처음에는 낮은 음량으로 시작하세요',
      '출력 기기마다 실제 소리의 크기가 다를 수 있습니다.\n오래·크게 듣지 마시고, 두통·이명·어지럼이 생기면\n사용을 멈추세요.'
    ),
    (
      '나만의 세션을 저장하세요',
      '모든 설정과 기록은 이 기기에만 저장됩니다.\n서버도, 계정도, 광고도 없습니다.'
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 건너뛰기: 온보딩을 보지 않고 바로 시작.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: TextButton(
                  onPressed: () =>
                      context.read<AppState>().completeOnboarding(),
                  child: Text('건너뛰기',
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: AppTypography.h1
                                  .copyWith(color: AppColors.accent)),
                        ),
                        const SizedBox(height: 28),
                        Text(p.$1, style: AppTypography.h1),
                        const SizedBox(height: 14),
                        Text(p.$2, style: AppTypography.body),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppColors.accent
                          : AppColors.surface4,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: PrimaryButton(
                label: last ? '시작하기' : '다음',
                onPressed: () {
                  if (last) {
                    context.read<AppState>().completeOnboarding();
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
