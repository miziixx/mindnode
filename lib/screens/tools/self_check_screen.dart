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
/// "선언한 Hz = 만들어진 Hz" 를 Goertzel 로 측정한다(마이크 미사용).
/// 고정 배터리 + **직접 조작 측정**(입력한 주파수를 실시간으로 분석)으로,
/// 이 검사가 실제로 동작함을 눈으로 확인할 수 있다.
class SelfCheckScreen extends StatefulWidget {
  const SelfCheckScreen({super.key});

  @override
  State<SelfCheckScreen> createState() => _SelfCheckScreenState();
}

class _SelfCheckScreenState extends State<SelfCheckScreen> {
  List<ProbeResult>? _results;
  bool _running = false;

  // 직접 조작 측정
  double _probeHz = 432;
  double _measuredHz = 432;
  double _sr = 48000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sr = context.read<PlaybackController>().sampleRate;
      _run();
      _measureProbe();
    });
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final res = runToneSelfCheck(sampleRate: _sr);
    if (!mounted) return;
    setState(() {
      _results = res;
      _running = false;
    });
  }

  /// 입력한 주파수를 실제로 생성→측정(마이크 없이). 슬라이더를 움직일 때마다 갱신.
  void _measureProbe() {
    final buf = renderTone(_probeHz, _sr, 4096);
    final m = measureDominantHz(buf, _sr,
        lo: (_probeHz - 90).clamp(20, 2000), hi: _probeHz + 90);
    setState(() => _measuredHz = m);
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

                // ── 직접 조작 측정(진짜로 동작함을 눈으로 확인) ──
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('직접 확인해 보세요',
                          style: AppTypography.label
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('아래 슬라이더로 아무 주파수나 고르면, 그 톤을 지금 만들어서 '
                          '측정한 값을 실시간으로 보여줍니다. 입력을 바꾸면 측정값도 따라옵니다.',
                          style: AppTypography.tiny),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bigStat('입력', _probeHz, AppColors.textSecondary),
                          Icon(Icons.arrow_forward_rounded,
                              color: AppColors.textMuted),
                          _bigStat('측정', _measuredHz, AppColors.accent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          '오차 ${(_measuredHz - _probeHz).abs().toStringAsFixed(2)} Hz',
                          style: AppTypography.tiny.copyWith(
                              color: (_measuredHz - _probeHz).abs() < 1.5
                                  ? AppColors.success
                                  : AppColors.warning),
                        ),
                      ),
                      Slider(
                        value: _probeHz,
                        min: 60,
                        max: 1000,
                        onChanged: (v) {
                          _probeHz = v;
                          _measureProbe();
                        },
                      ),
                      Center(
                        child: Text('원하는 값으로 드래그해 보세요 (60–1000 Hz)',
                            style: AppTypography.tiny.copyWith(fontSize: 10)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 고정 배터리 ──
                Row(
                  children: [
                    Expanded(
                      child: Text('대표 주파수 일괄 검사',
                          style: AppTypography.label
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (results != null)
                      Text(allPass ? '전체 통과' : '오류 있음',
                          style: AppTypography.tiny.copyWith(
                              color: allPass
                                  ? AppColors.success
                                  : AppColors.error)),
                  ],
                ),
                const SizedBox(height: 10),
                if (_running || results == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child:
                        Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface1.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border: Border.all(color: AppColors.softDivider),
                    ),
                    child: Column(children: [for (final r in results) _row(r)]),
                  ),
                  const SizedBox(height: 14),
                  SecondaryButton(
                      label: '다시 검사', icon: AppIcons.restore, onPressed: _run),
                ],
                const SizedBox(height: 16),
                Text(
                  '이 검사는 "생성 알고리즘"이 이 기기에서 정확함을 확인합니다(마이크 미사용). '
                  '항상 통과로 나오는 건 알고리즘이 실제로 정확하기 때문입니다 — 위 슬라이더로 '
                  '측정이 입력을 따라오는지 직접 확인해 보세요. 스피커·이어폰의 실제 출력까지 '
                  '보려면 스펙트럼 분석기 앱을 함께 쓰세요.',
                  style: AppTypography.tiny.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String label, double hz, Color color) {
    return Column(
      children: [
        Text(label, style: AppTypography.tiny.copyWith(fontSize: 10)),
        const SizedBox(height: 4),
        Text(hz.toStringAsFixed(1),
            style: AppTypography.frequencyDisplay
                .copyWith(fontSize: 34, color: color)),
        Text('Hz', style: AppTypography.smallCaps.copyWith(letterSpacing: 2)),
      ],
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
              size: 18, color: r.pass ? AppColors.success : AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(r.label,
                style:
                    AppTypography.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text('측정 ${r.measuredHz.toStringAsFixed(2)}Hz',
              style: AppTypography.tiny.copyWith(
                  color: r.pass ? AppColors.textSecondary : AppColors.error)),
        ],
      ),
    );
  }
}
