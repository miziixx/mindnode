import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 몽환적 배경 — 바람에 흐르는 별빛(드리프트 파티클) + 연기 같은 성운(느린 그라데이션).
/// 매우 느리고 은은하게, 초당 프레임을 남발하지 않으며 seamless 하게 반복.
/// reduceMotion 이면 정지된 한 프레임만 그린다. 백그라운드에서는 Ticker 가 자동 정지.
class DreamyBackground extends StatefulWidget {
  const DreamyBackground({
    super.key,
    required this.accent,
    this.reduceMotion = false,
    this.enabled = true,
    this.particleCount = 42,
  });

  final Color accent;
  final bool reduceMotion;
  final bool enabled;
  final int particleCount;

  @override
  State<DreamyBackground> createState() => _DreamyBackgroundState();
}

class _Particle {
  final double x0, size, swayAmp, phase, twPhase;
  final int driftCycles, swayCycles, twCycles;
  final double base; // 기준 밝기
  final bool white; // 별빛(흰색) 여부
  _Particle(this.x0, this.size, this.swayAmp, this.phase, this.twPhase,
      this.driftCycles, this.swayCycles, this.twCycles, this.base, this.white);
}

class _Nebula {
  final double x, y, r, phx, phy, ampx, ampy, opacity;
  final bool useAccent;
  _Nebula(this.x, this.y, this.r, this.phx, this.phy, this.ampx, this.ampy,
      this.opacity, this.useAccent);
}

class _DreamyBackgroundState extends State<DreamyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;
  late final List<_Nebula> _nebulae;

  @override
  void initState() {
    super.initState();
    // 120초 주기. 모든 파티클 주파수를 정수 사이클로 두어 경계에서 seamless.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 120));
    final rnd = math.Random(11);
    _particles = List.generate(widget.particleCount, (i) {
      return _Particle(
        rnd.nextDouble(),
        rnd.nextDouble() * 1.6 + 0.6, // 0.6~2.2 px
        rnd.nextDouble() * 0.06 + 0.02, // 좌우 흔들림
        rnd.nextDouble(),
        rnd.nextDouble(),
        1 + rnd.nextInt(2), // 위로 1~2회 이동/주기
        1 + rnd.nextInt(3), // 흔들림 사이클
        2 + rnd.nextInt(4), // 반짝임 사이클
        rnd.nextDouble() * 0.5 + 0.2,
        rnd.nextDouble() < 0.35, // 일부는 흰 별빛
      );
    });
    _nebulae = List.generate(4, (i) {
      return _Nebula(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.7,
        rnd.nextDouble() * 0.25 + 0.28, // 반경(화면 비율)
        rnd.nextDouble(),
        rnd.nextDouble(),
        rnd.nextDouble() * 0.06 + 0.03,
        rnd.nextDouble() * 0.05 + 0.02,
        rnd.nextDouble() * 0.05 + 0.04,
        rnd.nextBool(),
      );
    });
    _apply();
  }

  void _apply() {
    if (widget.enabled && !widget.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didUpdateWidget(covariant DreamyBackground old) {
    super.didUpdateWidget(old);
    _apply();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _DreamyPainter(
            p: _c.value,
            accent: widget.accent,
            particles: _particles,
            nebulae: _nebulae,
            still: widget.reduceMotion || !widget.enabled,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DreamyPainter extends CustomPainter {
  _DreamyPainter({
    required this.p,
    required this.accent,
    required this.particles,
    required this.nebulae,
    required this.still,
  });

  final double p;
  final Color accent;
  final List<_Particle> particles;
  final List<_Nebula> nebulae;
  final bool still;

  static const double _tau = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 연기 같은 성운(느리게 떠다니는 부드러운 광).
    for (final n in nebulae) {
      final cx = (n.x + n.ampx * math.sin(_tau * (p + n.phx))) * w;
      final cy = (n.y + n.ampy * math.sin(_tau * (p + n.phy))) * h;
      final r = n.r * w;
      final color = n.useAccent ? accent : const Color(0xFF8A73C0);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(n.opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // 바람에 흐르는 별빛 파티클.
    for (final pt in particles) {
      final y = _mod1(0.5 + pt.phase - pt.driftCycles * p); // 위로 흐름
      final x = (pt.x0 + pt.swayAmp * math.sin(_tau * (pt.swayCycles * p + pt.phase)));
      final tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(_tau * (pt.twCycles * p + pt.twPhase)));
      final opacity = (pt.base * tw).clamp(0.0, 0.9);
      final color = pt.white
          ? Colors.white.withOpacity(opacity * 0.8)
          : accent.withOpacity(opacity);
      final center = Offset(_mod1(x) * w, y * h);
      // 은은한 글로우
      canvas.drawCircle(center, pt.size * 2.4,
          Paint()..color = color.withOpacity(opacity * 0.18));
      canvas.drawCircle(center, pt.size, Paint()..color = color);
    }
  }

  double _mod1(double v) {
    v = v % 1.0;
    return v < 0 ? v + 1.0 : v;
  }

  @override
  bool shouldRepaint(covariant _DreamyPainter old) =>
      old.p != p || old.accent != accent || old.still != still;
}
