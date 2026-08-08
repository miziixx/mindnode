import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/tone_probe.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_tokens.dart';
import '../../core/design/app_typography.dart';
import '../../core/state/app_state.dart';
import '../../core/state/playback_controller.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import '../../widgets/dreamy_background.dart';

/// 주파수 자가 진단. 기기 CPU에서 생성 알고리즘을 직접 돌려
/// "선언한 Hz = 만들어진 Hz" 를 Goertzel 로 측정해 보여준다(마이크 미사용).
class SelfCheckScreen extends StatefulWidget {
  const SelfCheckScreen({super.key});

  @override
  State<SelfCheckScreen> createState() => _SelfCheckScreenState();
}

class _SelfCheckScreenState extends State<SelfCheckScreen> {
  List<ProbeResult>? _results;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = null;
    });
    final sr = context.read<PlaybackController>().sampleRate;
    // 무거운 계산을 프레임 뒤로 미뤄 첫 페인트를 막지 않는다.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final res = runToneSelfCheck(sampleRate: sr);
    if (!mounted) return;
    setState(() {
      _results = res;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final results = _results;
    final allPass = results != null && results.every((r) => r.pass);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DreamyBackground(
              accent: AppColors.accent,
              reduceMotion: context.watch<AppState>().settings.reduceMotion,
              particleCount: 24,
            ),
          ),
          SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconChipButton(
                    icon: AppIcons.back,
                    tooltip: '뒤로',
                    onTap: () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Text('주파수 자가 진단', style: AppTypography.h3),
              ],
            ),
            const SizedBox(height: 18),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이 기기에서 직접 검증',
                      style: AppTypography.label
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '앱의 톤 생성 알고리즘을 지금 이 폰의 CPU에서 실행해, '
                    '"만들어진 소리가 선언한 주파수와 같은지"를 Goertzel 분석으로 측정합니다. '
                    '마이크는 쓰지 않습니다.',
                    style: AppTypography.tiny,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_running || results == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: (allPass ? AppColors.success : AppColors.error)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                      color: (allPass ? AppColors.success : AppColors.error)
                          .withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(allPass ? AppIcons.check : Icons.error_outline_rounded,
                        color: allPass ? AppColors.success : AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allPass
                            ? '통과 — 모든 주파수가 정확히 생성됩니다.'
                            : '일부 항목이 허용 오차를 벗어났습니다.',
                        style: AppTypography.label,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.softDivider),
                ),
                child: Column(
                  children: [
                    for (final r in results) _row(r),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SecondaryButton(
                label: '다시 검사',
                icon: AppIcons.restore,
                onPressed: _run,
              ),
              const SizedBox(height: 16),
              Text(
                '참고: 이 검사는 "생성 알고리즘"이 정확함을 기기에서 확인합니다. '
                '스피커·이어폰에서 실제로 나오는 소리까지 확인하려면, '
                '스펙트럼 분석기 앱을 켜고 프리셋을 재생해 해당 Hz가 표시되는지 보세요.',
                style: AppTypography.tiny.copyWith(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _row(ProbeResult r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(r.pass ? AppIcons.check : Icons.close_rounded,
              size: 18,
              color: r.pass ? AppColors.success : AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(r.label,
                style: AppTypography.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text('측정 ${r.measuredHz.toStringAsFixed(2)}Hz',
              style: AppTypography.tiny.copyWith(
                  color: r.pass ? AppColors.textSecondary : AppColors.error)),
        ],
      ),
    );
  }
}
