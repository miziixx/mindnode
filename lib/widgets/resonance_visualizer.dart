import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 추상 공명 시각화. **재생 파라미터 기반**이며 실제 FFT 분석이 아니다.
/// 느린 링 호흡 + 드론 배경광 + 펄스 확대/축소 + 차임 파동.
/// reduceMotion / 백그라운드일 때 애니메이션을 멈춘다.
class ResonanceVisualizer extends StatefulWidget {
  const ResonanceVisualizer({
    super.key,
    required this.accent,
    required this.active,
    this.reduceMotion = false,
    this.pulseActive = false,
    this.pulseRateHz = 0,
    this.binauralActive = false,
    this.size = 300,
  });

  final Color accent;
  final bool active; // 재생 중 여부(멈추면 정적)
  final bool reduceMotion;
  final bool pulseActive;
  final double pulseRateHz;
  final bool binauralActive;
  final double size;

  @override
  State<ResonanceVisualizer> createState() => _ResonanceVisualizerState();
}

class _ResonanceVisualizerState extends State<ResonanceVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // 매우 느린 주기(전체 위상 진행용). 실제 프레임 갱신은 초당 소수.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _maybeAnimate();
  }

  void _maybeAnimate() {
    if (widget.active && !widget.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant ResonanceVisualizer old) {
    super.didUpdateWidget(old);
    _maybeAnimate();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _ResonancePainter(
              t: _c.value,
              accent: widget.accent,
              active: widget.active && !widget.reduceMotion,
              pulseActive: widget.pulseActive,
              pulseRateHz: widget.pulseRateHz,
              binauralActive: widget.binauralActive,
            ),
          );
        },
      ),
    );
  }
}

class _ResonancePainter extends CustomPainter {
  _ResonancePainter({
    required this.t,
    required this.accent,
    required this.active,
    required this.pulseActive,
    required this.pulseRateHz,
    required this.binauralActive,
  });

  final double t; // 0..1 phase
  final Color accent;
  final bool active;
  final bool pulseActive;
  final double pulseRateHz;
  final bool binauralActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 드론 배경광(매우 느림)
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        accent.withOpacity(0.12),
        accent.withOpacity(0.02),
        Colors.transparent,
      ], stops: const [
        0.0,
        0.55,
        0.75,
      ]).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, glow);

    // 펄스: 링의 느린 확대/축소
    double pulseScale = 1.0;
    if (pulseActive && active) {
      // 표시용 저속 변조(실제 오디오 속도와 무관, 시각적 은유)
      pulseScale = 1.0 + 0.03 * math.sin(t * 2 * math.pi * 2);
    }

    final ringSpecs = [0.34, 0.55, 0.76, 0.96];
    for (var i = 0; i < ringSpecs.length; i++) {
      final breath = active
          ? 1.0 + 0.03 * math.sin((t + i * 0.22) * 2 * math.pi)
          : 1.0;
      final r = maxR * ringSpecs[i] * breath * (i == 0 ? pulseScale : 1.0);
      final opacity = [0.35, 0.22, 0.14, 0.08][i];
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accent.withOpacity(opacity);
      canvas.drawCircle(center, r, paint);
    }

    // 바이노럴: 좌우 분리된 두 얇은 파동
    if (binauralActive) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accent.withOpacity(0.28);
      final rr = maxR * 0.62;
      final off = maxR * 0.05;
      canvas.drawArc(
          Rect.fromCircle(center: center.translate(-off, 0), radius: rr),
          math.pi * 0.6, math.pi * 0.8, false, p);
      canvas.drawArc(
          Rect.fromCircle(center: center.translate(off, 0), radius: rr),
          -math.pi * 0.2, math.pi * 0.8, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ResonancePainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.active != active ||
      old.pulseActive != pulseActive ||
      old.binauralActive != binauralActive;
}
