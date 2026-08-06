import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/core/audio/dsp_reference.dart';

/// Dart DSP 레퍼런스의 수치 검증. Python 검증 코어와 동일 알고리즘임을 CI에서 확인.
/// (간이 Goertzel로 주파수 성분을 측정한다.)
double goertzel(List<double> x, double sr, double freq) {
  final w = 2 * math.pi * freq / sr;
  final coeff = 2 * math.cos(w);
  double s0, s1 = 0, s2 = 0;
  for (final v in x) {
    s0 = v + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
  return math.sqrt(math.max(power, 0)) / x.length * 2;
}

List<double> renderSine(double f, double sr, int n, {double phase0 = 0}) {
  final osc = PhaseOsc(phase0);
  return List<double>.generate(n, (_) => osc.next(f, sr));
}

void main() {
  const sr = 48000.0;

  test('사인 주파수 성분이 목표 근처에서 가장 강하다', () {
    for (final f in [220.0, 396.0, 432.0, 528.0, 963.0]) {
      final x = renderSine(f, sr, 48000);
      final onTarget = goertzel(x, sr, f);
      final offTarget = goertzel(x, sr, f + 25);
      expect(onTarget, greaterThan(offTarget * 5),
          reason: '$f Hz 성분이 인접 주파수보다 뚜렷해야 함');
      expect(onTarget, greaterThan(0.3));
    }
  });

  test('버퍼 경계에서 위상이 유지된다(연속 vs 분할)', () {
    const f = 432.0;
    const n = 48000;
    final contiguous = renderSine(f, sr, n);
    // 불규칙 블록으로 분할 렌더(위상 보존)
    final osc = PhaseOsc(0);
    final blocks = <double>[];
    final sizes = [64, 192, 480, 128, 1024, 256, 960, 64];
    var produced = 0, i = 0;
    while (produced < n) {
      final b = math.min(sizes[i % sizes.length], n - produced);
      for (var k = 0; k < b; k++) {
        blocks.add(osc.next(f, sr));
      }
      produced += b;
      i++;
    }
    double maxErr = 0;
    for (var j = 0; j < n; j++) {
      maxErr = math.max(maxErr, (contiguous[j] - blocks[j]).abs());
    }
    expect(maxErr, lessThan(1e-9), reason: '분할 렌더가 연속 렌더와 일치해야 함');
  });

  test('소프트 리미터가 −1dBFS ceiling을 넘지 않는다', () {
    final lim = SoftLimiter();
    for (final v in [-5.0, -1.0, 0.0, 0.5, 1.0, 5.0, 100.0]) {
      final y = lim.process(v);
      expect(y.abs(), lessThanOrEqualTo(dbToLinear(-1.0) + 1e-9));
    }
    // NaN/Inf 세이프티
    expect(lim.process(double.nan), 0.0);
    expect(lim.process(double.infinity).abs(),
        lessThanOrEqualTo(dbToLinear(-1.0) + 1e-9));
  });

  test('게인 램프가 목표까지 단조 이동하고 오버슈트하지 않는다', () {
    final ramp = ParamRamp(0.0);
    ramp.setTarget(1.0, sr, 30); // 30ms
    double prev = -1;
    for (var i = 0; i < 2000; i++) {
      final v = ramp.next();
      expect(v, greaterThanOrEqualTo(prev - 1e-12));
      expect(v, lessThanOrEqualTo(1.0 + 1e-12));
      prev = v;
    }
    expect(ramp.current, closeTo(1.0, 1e-9));
  });

  test('드론 Sub/Main/Air 성분이 예상 위치에 존재한다', () {
    final drone = DroneVoiceSet();
    final out = List<double>.filled(2, 0);
    final mono = <double>[];
    const center = 432.0;
    for (var i = 0; i < 48000; i++) {
      drone.nextInto(out,
          centerHz: center,
          sampleRate: sr,
          subRatio: 0.35,
          mainRatio: 0.55,
          airRatio: 0.10,
          movementRateHz: 0.05,
          stereoWidth: 0.25,
          linGain: 0.1);
      mono.add(0.5 * (out[0] + out[1]));
    }
    expect(goertzel(mono, sr, center * 0.5), greaterThan(0.005)); // Sub 216
    expect(goertzel(mono, sr, center), greaterThan(0.01)); // Main 432
    expect(goertzel(mono, sr, center * 2), greaterThan(0.002)); // Air 864
  });
}
