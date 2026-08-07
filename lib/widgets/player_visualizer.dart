import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 재생 중 나타나는 추상 시각화. **재생 파라미터 기반 은유**이며 실제 FFT 분석이 아니다.
///
/// 5가지 스타일(오로라 링·사운드 만다라·궤도 입자·꽃 개화·퍼지는 물결)을
/// 제공하고, 화면 중앙을 탭하면 다음 스타일로 순환한다. 프리셋마다 기본 스타일이
/// 달라지도록 [seed] 로 초기 스타일을 고른다.
/// reduceMotion / 정지 상태에선 애니메이션을 멈춘다.
enum VizStyle { aurora, mandala, orbit, bloom, ripple }

const List<String> kVizStyleNames = [
  '오로라 링',
  '사운드 만다라',
  '궤도 입자',
  '꽃 개화',
  '퍼지는 물결',
];

class PlayerVisualizer extends StatefulWidget {
  const PlayerVisualizer({
    super.key,
    required this.accent,
    required this.active,
    this.reduceMotion = false,
    this.pulseActive = false,
    this.pulseRateHz = 0,
    this.binauralActive = false,
    this.size = 300,
    this.seed = 0,
    this.onStyleChanged,
  });

  final Color accent;
  final bool active; // 재생 중 여부(멈추면 정적)
  final bool reduceMotion;
  final bool pulseActive;
  final double pulseRateHz;
  final bool binauralActive;
  final double size;
  final int seed; // 프리셋별 기본 스타일 선택용
  final ValueChanged<VizStyle>? onStyleChanged;

  @override
  State<PlayerVisualizer> createState() => _PlayerVisualizerState();
}

class _PlayerVisualizerState extends State<PlayerVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late int _style;

  @override
  void initState() {
    super.initState();
    _style = widget.seed % VizStyle.values.length;
    // 느린 기준 주기(16초). 각 스타일이 배수로 파생.
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 16));
    _maybeAnimate();
  }

  void _maybeAnimate() {
    if (widget.active && !widget.reduceMotion) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  void _cycle() {
    setState(() {
      _style = (_style + 1) % VizStyle.values.length;
    });
    widget.onStyleChanged?.call(VizStyle.values[_style]);
  }

  @override
  void didUpdateWidget(covariant PlayerVisualizer old) {
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _cycle,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return CustomPaint(
              painter: _VizPainter(
                style: VizStyle.values[_style],
                t: _c.value,
                accent: widget.accent,
                active: widget.active && !widget.reduceMotion,
                pulseActive: widget.pulseActive,
                binauralActive: widget.binauralActive,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  _VizPainter({
    required this.style,
    required this.t,
    required this.accent,
    required this.active,
    required this.pulseActive,
    required this.binauralActive,
  });

  final VizStyle style;
  final double t; // 0..1 위상
  final Color accent;
  final bool active;
  final bool pulseActive;
  final bool binauralActive;

  Color _lighten(Color c, double a) => Color.lerp(c, Colors.white, a)!;
  Color _shift(Color c, double a) =>
      Color.lerp(c, const Color(0xFF9E7EB8), a)!; // 살짝 바이올렛으로

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 공통 배경광(드론 느낌)
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        accent.withOpacity(0.14),
        accent.withOpacity(0.03),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 0.78])
          .createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, glow);

    switch (style) {
      case VizStyle.aurora:
        _aurora(canvas, center, maxR);
        break;
      case VizStyle.mandala:
        _mandala(canvas, center, maxR);
        break;
      case VizStyle.orbit:
        _orbit(canvas, center, maxR);
        break;
      case VizStyle.bloom:
        _bloom(canvas, center, maxR);
        break;
      case VizStyle.ripple:
        _ripple(canvas, center, maxR);
        break;
    }
  }

  // ── 오로라 링: 은은하게 호흡하는 동심원 + 셔머 ──────────────────
  void _aurora(Canvas canvas, Offset center, double maxR) {
    final specs = [0.30, 0.48, 0.66, 0.84, 1.0];
    for (var i = 0; i < specs.length; i++) {
      final breath =
          active ? 1.0 + 0.035 * math.sin((t + i * 0.16) * 2 * math.pi) : 1.0;
      final r = maxR * specs[i] * breath;
      final f = i / (specs.length - 1);
      final col = _shift(_lighten(accent, 0.1), f * 0.6);
      final op = [0.42, 0.30, 0.20, 0.12, 0.07][i];
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = col.withOpacity(op);
      canvas.drawCircle(center, r, p);
    }
    // 셔머 하이라이트 호(회전)
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          _lighten(accent, 0.5).withOpacity(0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxR * 0.66));
    canvas.drawCircle(center, maxR * 0.66, hi);
    _core(canvas, center, maxR * 0.05);
  }

  // ── 사운드 만다라: 방사형 막대(아이콘과 통일), 천천히 회전 ───────
  void _mandala(Canvas canvas, Offset center, double maxR) {
    const n = 48;
    final inner = maxR * 0.30;
    final rot = active ? t * 2 * math.pi : 0.0;
    final pulseBoost = (pulseActive && active)
        ? 1.0 + 0.06 * math.sin(t * 2 * math.pi * 4)
        : 1.0;
    for (var i = 0; i < n; i++) {
      final ang = i / n * 2 * math.pi + rot;
      final wave = 0.5 +
          0.5 *
              math.sin(i / n * 2 * math.pi * 3 -
                  (active ? t * 2 * math.pi : 0.0));
      final outer = inner + maxR * (0.06 + 0.34 * wave) * pulseBoost;
      final f = i / n;
      final col = _shift(_lighten(accent, 0.05), f);
      final p = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = maxR * 0.028
        ..color = col.withOpacity(0.85);
      final o = Offset(center.dx + inner * math.cos(ang),
          center.dy + inner * math.sin(ang));
      final e = Offset(center.dx + outer * math.cos(ang),
          center.dy + outer * math.sin(ang));
      canvas.drawLine(o, e, p);
    }
    _core(canvas, center, maxR * 0.06);
  }

  // ── 궤도 입자: 여러 입자가 타원 궤도를 돌며 잔상을 남김 ──────────
  void _orbit(Canvas canvas, Offset center, double maxR) {
    // 은은한 궤도 링
    for (final rr in [0.42, 0.70]) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = accent.withOpacity(0.10);
      canvas.drawOval(
          Rect.fromCenter(
              center: center, width: maxR * 2 * rr, height: maxR * 2 * rr * 0.82),
          p);
    }
    final orbits = [
      [0.42, 1.0, 0.0],
      [0.70, -1.0, 0.35],
      [0.56, 2.0, 0.6],
      [0.86, -1.0, 0.15],
    ];
    for (var oi = 0; oi < orbits.length; oi++) {
      final rad = maxR * orbits[oi][0];
      final speed = orbits[oi][1];
      final phase = orbits[oi][2];
      final f = oi / (orbits.length - 1);
      final col = _shift(_lighten(accent, 0.15), f);
      // 잔상 3개 + 본체
      for (var k = 0; k < 4; k++) {
        final tt = active ? t : phase;
        final a = (tt * speed + phase) * 2 * math.pi - k * 0.14 * speed.sign;
        final pos = Offset(
          center.dx + rad * math.cos(a),
          center.dy + rad * 0.82 * math.sin(a),
        );
        final op = (k == 0 ? 0.9 : 0.9 * (1 - k / 4)) * 0.8;
        final rr = maxR * (k == 0 ? 0.035 : 0.024);
        if (k == 0) {
          canvas.drawCircle(
              pos,
              rr * 2.4,
              Paint()
                ..color = col.withOpacity(0.18)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        }
        canvas.drawCircle(pos, rr, Paint()..color = col.withOpacity(op));
      }
    }
    _core(canvas, center, maxR * 0.05);
  }

  // ── 꽃 개화: 꽃잎 수가 호흡하며 열리고 닫히는 부드러운 형태 ──────
  void _bloom(Canvas canvas, Offset center, double maxR) {
    final petals = binauralActive ? 6 : 5;
    final base = maxR * 0.5;
    final open =
        active ? 0.18 + 0.10 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)) : 0.22;
    final rot = active ? t * 2 * math.pi * 0.25 : 0.0;
    for (var layer = 0; layer < 3; layer++) {
      final scale = 1.0 - layer * 0.24;
      final path = Path();
      const steps = 120;
      for (var i = 0; i <= steps; i++) {
        final th = i / steps * 2 * math.pi;
        final r = base *
            scale *
            (1 + open * math.sin(petals * th + rot + layer * 0.5));
        final pt = Offset(
            center.dx + r * math.cos(th), center.dy + r * math.sin(th));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      final f = layer / 2;
      final col = _shift(_lighten(accent, 0.1), f * 0.8);
      // 채움(옅게)
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = col.withOpacity(0.06));
      // 윤곽선
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = col.withOpacity(0.5 - layer * 0.12));
    }
    _core(canvas, center, maxR * 0.055);
  }

  // ── 퍼지는 물결: 중심에서 연속적으로 확산되는 파동 ──────────────
  void _ripple(Canvas canvas, Offset center, double maxR) {
    const rings = 5;
    for (var i = 0; i < rings; i++) {
      final phase = ((active ? t : 0.0) + i / rings) % 1.0;
      final r = maxR * (0.06 + phase * 0.94);
      final op = (1 - phase) * 0.5;
      final f = i / rings;
      final col = _shift(_lighten(accent, 0.1), f);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + 1.6 * (1 - phase)
        ..color = col.withOpacity(op.clamp(0.0, 1.0));
      canvas.drawCircle(center, r, p);
    }
    // 바이노럴이면 좌우로 살짝 어긋난 두 겹
    if (binauralActive) {
      final off = maxR * 0.05;
      for (final dx in [-off, off]) {
        final phase = ((active ? t : 0.0) + 0.5) % 1.0;
        final r = maxR * (0.06 + phase * 0.7);
        canvas.drawCircle(
            center.translate(dx, 0),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0
              ..color = accent.withOpacity((1 - phase) * 0.22));
      }
    }
    _core(canvas, center, maxR * 0.05);
  }

  // ── 중심 코어(공통) ──────────────────────────────────────────
  void _core(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(
        center,
        r * 2.6,
        Paint()
          ..color = _lighten(accent, 0.3).withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(
        center, r, Paint()..color = _lighten(accent, 0.55).withOpacity(0.9));
  }

  @override
  bool shouldRepaint(covariant _VizPainter old) =>
      old.t != t ||
      old.style != style ||
      old.accent != accent ||
      old.active != active ||
      old.pulseActive != pulseActive ||
      old.binauralActive != binauralActive;
}
