import 'package:flutter/material.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_typography.dart';

/// 호흡 가이드. 들숨 4초 · 멈춤 2초 · 날숨 6초 · 멈춤 2초(총 14초) 리듬으로
/// 원이 커졌다 작아지고 안내 문구가 바뀐다. reduceMotion 이면 정적 안내만.
class BreathingGuide extends StatefulWidget {
  const BreathingGuide({
    super.key,
    required this.accent,
    this.active = true,
    this.reduceMotion = false,
  });

  final Color accent;
  final bool active;
  final bool reduceMotion;

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // (문구, 시작 비율, 끝 비율, 목표 스케일 시작, 목표 스케일 끝)
  static const _inhale = 4.0, _hold1 = 2.0, _exhale = 6.0, _hold2 = 2.0;
  static const _total = _inhale + _hold1 + _exhale + _hold2;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 14000));
    _maybe();
  }

  void _maybe() {
    if (widget.active && !widget.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant BreathingGuide old) {
    super.didUpdateWidget(old);
    _maybe();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 현재 위상 → (문구, 스케일 0..1)
  (String, double) _phase(double t) {
    final sec = t * _total;
    if (sec < _inhale) {
      return ('들이쉬기', sec / _inhale); // 0→1
    } else if (sec < _inhale + _hold1) {
      return ('잠시 멈춤', 1.0);
    } else if (sec < _inhale + _hold1 + _exhale) {
      final e = (sec - _inhale - _hold1) / _exhale;
      return ('내쉬기', 1.0 - e); // 1→0
    } else {
      return ('잠시 멈춤', 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion || !widget.active) {
      return Text('호흡: 4초 들이쉬고 · 6초 내쉬기',
          style: AppTypography.tiny, textAlign: TextAlign.center);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final (label, s) = _phase(_c.value);
        final scale = 0.55 + 0.45 * Curves.easeInOut.transform(s);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Center(
                child: Container(
                  width: 84 * scale,
                  height: 84 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      widget.accent.withOpacity(0.42),
                      widget.accent.withOpacity(0.10),
                    ]),
                    border: Border.all(
                        color: widget.accent.withOpacity(0.55), width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: AppTypography.label
                    .copyWith(color: AppColors.textSecondary)),
          ],
        );
      },
    );
  }
}
