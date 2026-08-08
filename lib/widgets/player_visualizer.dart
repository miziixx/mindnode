import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 재생 중 나타나는 추상 시각화. **재생 파라미터 기반 은유**이며 실제 FFT 분석이 아니다.
///
/// 5가지 스타일(오로라 링·사운드 만다라·궤도 혜성·꽃 개화·퍼지는 물결)을
/// 제공하고, 화면 중앙을 탭하면 다음 스타일로 순환한다. 모든 스타일은
/// 끊김 없는 그라데이션과 부드러운 글로우로 그린다. 프리셋마다 기본 스타일이
/// 달라지도록 [seed] 로 초기 스타일을 고른다. reduceMotion/정지 시엔 정적.
enum VizStyle { aurora, mandala, orbit, bloom, ripple }

const List<String> kVizStyleNames = [
  '오로라 링',
  '사운드 만다라',
  '궤도 혜성',
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
  final bool active;
  final bool reduceMotion;
  final bool pulseActive;
  final double pulseRateHz;
  final bool binauralActive;
  final double size;
  final int seed;
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
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));
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
    setState(() => _style = (_style + 1) % VizStyle.values.length);
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

  // ── 이리데센트 팔레트(accent 주변으로 청록·바이올렛 섞음) ──
  static const _violet = Color(0xFFB79BDA);
  static const _cyan = Color(0xFF8FD2DA);
  static const _white = Color(0xFFF3F2EE);
  Color _mix(Color a, Color b, double x) => Color.lerp(a, b, x)!;
  Color get _cA => accent;
  Color get _cB => _mix(accent, _violet, 0.65);
  Color get _cC => _mix(accent, _cyan, 0.55);

  /// 0..1 을 청록→accent→바이올렛→청록 으로 순환(이음새 없음).
  Color _irid(double x) {
    x = x % 1.0;
    if (x < 1 / 3) return _mix(_cC, _cA, x * 3);
    if (x < 2 / 3) return _mix(_cA, _cB, (x - 1 / 3) * 3);
    return _mix(_cB, _cC, (x - 2 / 3) * 3);
  }

  double get _tt => active ? t : 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 공통 배경광(깊고 부드러운 성운 글로우)
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..shader = RadialGradient(colors: [
          _cB.withOpacity(0.16),
          _cA.withOpacity(0.06),
          Colors.transparent,
        ], stops: const [
          0.0,
          0.45,
          0.82
        ]).createShader(Rect.fromCircle(center: center, radius: maxR)),
    );

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

  // 회전 스윕 셰이더(각도를 따라 이리데센트가 흐름).
  Shader _sweep(Offset c, double r, double rot,
      {double opacity = 1.0, double softness = 0.0}) {
    return SweepGradient(
      transform: GradientRotation(rot),
      colors: [
        _cC.withOpacity(opacity * (softness > 0 ? 0.0 : 1.0)),
        _cA.withOpacity(opacity),
        _cB.withOpacity(opacity),
        _white.withOpacity(opacity),
        _cC.withOpacity(opacity),
      ],
      stops: const [0.0, 0.3, 0.55, 0.75, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
  }

  Paint _blurStroke(double w, double blur) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  // ── 오로라 링: 회전하는 이리데센트 링 + 글로우 + 성운 코어 ──
  void _aurora(Canvas canvas, Offset center, double maxR) {
    final specs = [0.34, 0.54, 0.74, 0.94];
    for (var i = 0; i < specs.length; i++) {
      final breath = active
          ? 1.0 + 0.03 * math.sin((_tt + i * 0.17) * 2 * math.pi)
          : 1.0;
      final r = maxR * specs[i] * breath;
      final rot = _tt * 2 * math.pi * (i.isEven ? 1 : -1) + i * 0.7;
      final rect = Rect.fromCircle(center: center, radius: r);
      // 글로우(굵고 흐릿하게)
      canvas.drawCircle(
          center,
          r,
          _blurStroke(maxR * 0.055, maxR * 0.03)
            ..shader = _sweep(center, r, rot, opacity: 0.22));
      // 본선(가늘고 선명)
      canvas.drawArc(rect, 0, 2 * math.pi, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxR * 0.012
            ..strokeCap = StrokeCap.round
            ..shader = _sweep(center, r, rot, opacity: 0.85));
    }
    _core(canvas, center, maxR, 0.9);
  }

  // ── 사운드 만다라: 그라데이션으로 채운 부드러운 코로나(끊김 없음) ──
  void _mandala(Canvas canvas, Offset center, double maxR) {
    final rot = _tt * 2 * math.pi * 0.15;
    final petals = 12;
    final pulseBoost =
        (pulseActive && active) ? 0.06 * math.sin(_tt * 2 * math.pi * 3) : 0.0;
    for (var layer = 0; layer < 2; layer++) {
      final base = maxR * (layer == 0 ? 0.62 : 0.5);
      final amp = 0.16 + (layer == 0 ? 0.0 : 0.03) + pulseBoost;
      final path = Path();
      const steps = 240;
      for (var i = 0; i <= steps; i++) {
        final th = i / steps * 2 * math.pi;
        final r = base * (1 + amp * math.cos(petals * th + rot + layer * 0.4));
        final p = Offset(
            center.dx + r * math.cos(th), center.dy + r * math.sin(th));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      // 채움(방사 그라데이션: 안쪽 밝고 바깥 투명)
      canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(colors: [
              _white.withOpacity(layer == 0 ? 0.10 : 0.16),
              _cA.withOpacity(0.12),
              _cB.withOpacity(0.05),
              Colors.transparent,
            ], stops: const [
              0.0,
              0.45,
              0.8,
              1.0
            ]).createShader(Rect.fromCircle(center: center, radius: base * 1.2)));
      // 윤곽 글로우 + 선명한 스윕 라인
      canvas.drawPath(path,
          _blurStroke(maxR * 0.03, maxR * 0.025)..shader = _sweep(center, base, rot, opacity: 0.28));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxR * 0.01
            ..shader = _sweep(center, base, -rot * 1.6, opacity: 0.9));
    }
    _core(canvas, center, maxR, 1.0);
  }

  // ── 궤도 혜성: 연속된 그라데이션 꼬리(끊긴 점 없음) + 빛나는 머리 ──
  void _orbit(Canvas canvas, Offset center, double maxR) {
    // 은은한 궤도(그라데이션, 아주 옅게)
    for (final rr in [0.44, 0.72]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: center,
              width: maxR * 2 * rr,
              height: maxR * 2 * rr * 0.82),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxR * 0.006
            ..color = _cA.withOpacity(0.10));
    }
    final comets = [
      [0.44, 1.0, 0.0],
      [0.72, -0.7, 0.4],
      [0.58, 1.6, 0.7],
    ];
    for (final o in comets) {
      final rad = maxR * o[0];
      final speed = o[1];
      final phase = o[2];
      final head = (_tt * speed + phase) * 2 * math.pi;
      const span = 2.4; // 꼬리 길이(라디안)
      final start = head - span;
      final rect = Rect.fromCenter(
          center: center, width: rad * 2, height: rad * 2 * 0.82);
      final frac = span / (2 * math.pi);
      final tailShader = SweepGradient(
        transform: GradientRotation(start),
        colors: [
          Colors.transparent,
          _irid(phase).withOpacity(0.5),
          _white.withOpacity(0.95),
        ],
        stops: [0.0, frac * 0.7, frac],
      ).createShader(rect);
      // 글로우 꼬리
      canvas.drawArc(
          rect,
          start,
          span,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = maxR * 0.05
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxR * 0.02)
            ..shader = tailShader);
      // 선명한 꼬리
      canvas.drawArc(
          rect,
          start,
          span,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = maxR * 0.016
            ..shader = tailShader);
      // 빛나는 머리
      final hp = Offset(center.dx + rad * math.cos(head),
          center.dy + rad * 0.82 * math.sin(head));
      canvas.drawCircle(
          hp,
          maxR * 0.06,
          Paint()
            ..shader = RadialGradient(colors: [
              _white,
              _irid(phase).withOpacity(0.6),
              Colors.transparent,
            ]).createShader(Rect.fromCircle(center: hp, radius: maxR * 0.06)));
    }
    _core(canvas, center, maxR, 0.7);
  }

  // ── 꽃 개화: 그라데이션으로 채워 빛나는 꽃잎(끊김 없음) ──
  void _bloom(Canvas canvas, Offset center, double maxR) {
    final petals = binauralActive ? 6 : 5;
    final open = active
        ? 0.16 + 0.10 * (0.5 + 0.5 * math.sin(_tt * 2 * math.pi))
        : 0.20;
    for (var layer = 2; layer >= 0; layer--) {
      final scale = 1.0 - layer * 0.22;
      final rot = _tt * 2 * math.pi * 0.12 + layer * 0.5;
      final base = maxR * 0.62 * scale;
      final path = Path();
      const steps = 220;
      for (var i = 0; i <= steps; i++) {
        final th = i / steps * 2 * math.pi;
        final r = base * (1 + open * math.sin(petals * th + rot));
        final p = Offset(
            center.dx + r * math.cos(th), center.dy + r * math.sin(th));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      final col = _irid(layer / 3 + _tt * 0.1);
      canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(colors: [
              _white.withOpacity(0.14),
              col.withOpacity(0.22),
              col.withOpacity(0.05),
              Colors.transparent,
            ], stops: const [
              0.0,
              0.4,
              0.82,
              1.0
            ]).createShader(
                Rect.fromCircle(center: center, radius: base * 1.15)));
      canvas.drawPath(
          path,
          _blurStroke(maxR * 0.02, maxR * 0.02)
            ..shader = _sweep(center, base, rot, opacity: 0.3));
    }
    _core(canvas, center, maxR, 1.0);
  }

  // ── 퍼지는 물결: 그라데이션 링이 부드럽게 확산(글로우) ──
  void _ripple(Canvas canvas, Offset center, double maxR) {
    const rings = 5;
    for (var i = 0; i < rings; i++) {
      final phase = ((_tt) + i / rings) % 1.0;
      final r = maxR * (0.08 + phase * 0.92);
      final op = (1 - phase);
      final rot = _tt * 2 * math.pi * (i.isEven ? 1 : -1);
      canvas.drawCircle(
          center,
          r,
          _blurStroke(maxR * (0.02 + 0.03 * (1 - phase)), maxR * 0.02)
            ..shader = _sweep(center, r, rot, opacity: 0.5 * op));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxR * 0.008
            ..shader = _sweep(center, r, rot, opacity: 0.7 * op));
    }
    if (binauralActive) {
      final off = maxR * 0.05;
      for (final dx in [-off, off]) {
        final phase = ((_tt) + 0.5) % 1.0;
        final r = maxR * (0.08 + phase * 0.7);
        canvas.drawCircle(
            center.translate(dx, 0),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = maxR * 0.006
              ..color = _cC.withOpacity((1 - phase) * 0.3));
      }
    }
    _core(canvas, center, maxR, 1.0);
  }

  // ── 중심 코어(공통): 겹겹의 그라데이션 광원 ──
  void _core(Canvas canvas, Offset center, double maxR, double intensity) {
    final r = maxR * 0.09;
    canvas.drawCircle(
        center,
        r * 2.4,
        Paint()
          ..shader = RadialGradient(colors: [
            _white.withOpacity(0.30 * intensity),
            _cA.withOpacity(0.12 * intensity),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: center, radius: r * 2.4)));
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            _white,
            _mix(_white, _cA, 0.6),
            _cA.withOpacity(0.0),
          ], stops: const [
            0.0,
            0.5,
            1.0
          ]).createShader(Rect.fromCircle(center: center, radius: r)));
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
