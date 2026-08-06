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
      '앱이 주파수와 드론을 실시간으로 생성하고\n자연음, 패드, 차임을 함께 재생합니다.'
    ),
    (
      '처음에는 낮은 음량으로 시작하세요',
      '출력 기기마다 실제 소리의 크기가 다를 수 있습니다.\n두통·이명·어지럼이 생기면 사용을 멈추세요.'
    ),
    (
      '나만의 세션을 저장하세요',
      '모든 설정과 기록은 이 기기에만 저장됩니다.\n서버도 계정도 없습니다.'
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
