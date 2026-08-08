import 'dart:math' as math;

import 'dsp_reference.dart';

/// 기기 CPU에서 **생성 알고리즘(Dart 레퍼런스)** 을 직접 돌려 주파수를 검증하는 도구.
///
/// 마이크를 쓰지 않는다. 네이티브(Kotlin/Swift) 오디오 엔진은 이 [PhaseOsc] 와
/// 1:1 동일한 알고리즘이므로, 여기서 "생성한 톤이 정확한 Hz 다"를 확인하면
/// 앱이 내보내는 톤의 정확성에 대한 강한 근거가 된다.
/// (스피커에서 나온 실제 음향까지 측정하는 것은 아니다 — 그건 외부 스펙트럼 앱으로.)

/// 사인 톤 [freqHz] 를 [n] 샘플 렌더링(모노).
List<double> renderTone(double freqHz, double sampleRate, int n) {
  final osc = PhaseOsc(0.0);
  final out = List<double>.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    out[i] = osc.next(freqHz, sampleRate);
  }
  return out;
}

/// Goertzel 파워(특정 주파수의 에너지). Hann 창을 적용해 스펙트럼 누설을 줄인다.
double goertzelPower(List<double> x, double freqHz, double sampleRate) {
  final n = x.length;
  final k = freqHz / sampleRate;
  final w = 2 * math.pi * k;
  final coeff = 2 * math.cos(w);
  double s0 = 0.0, s1 = 0.0, s2 = 0.0;
  for (var i = 0; i < n; i++) {
    // Hann 창
    final win = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
    s0 = win * x[i] + coeff * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

/// [lo,hi] 구간을 [step] 간격으로 훑어 지배 주파수를 찾는다(포물선 보간으로 정밀화).
double measureDominantHz(List<double> x, double sampleRate,
    {double lo = 50, double hi = 1100, double step = 1.0}) {
  double bestF = lo, bestP = -1;
  final grid = <double>[];
  final powers = <double>[];
  for (var f = lo; f <= hi; f += step) {
    final p = goertzelPower(x, f, sampleRate);
    grid.add(f);
    powers.add(p);
    if (p > bestP) {
      bestP = p;
      bestF = f;
    }
  }
  // 포물선 보간(이웃 3점)
  final i = grid.indexOf(bestF);
  if (i > 0 && i < grid.length - 1) {
    final a = powers[i - 1], b = powers[i], c = powers[i + 1];
    final denom = (a - 2 * b + c);
    if (denom != 0) {
      final delta = 0.5 * (a - c) / denom;
      return bestF + delta * step;
    }
  }
  return bestF;
}

/// 자가진단 한 항목 결과.
class ProbeResult {
  final String label;
  final double expectedHz;
  final double measuredHz;
  final bool pass;
  ProbeResult(this.label, this.expectedHz, this.measuredHz, this.pass);

  double get errorHz => (measuredHz - expectedHz).abs();
}

/// 여러 주파수를 렌더링→측정해 선언값과 비교한다. 허용 오차 [tolHz].
List<ProbeResult> runToneSelfCheck({
  double sampleRate = 48000,
  int n = 8192,
  double tolHz = 1.5,
  List<(String, double)> cases = const [
    ('174 Hz', 174.0),
    ('285 Hz', 285.0),
    ('432 Hz', 432.0),
    ('528 Hz', 528.0),
    ('741 Hz', 741.0),
    ('963 Hz', 963.0),
  ],
}) {
  final results = <ProbeResult>[];
  for (final (label, f) in cases) {
    final buf = renderTone(f, sampleRate, n);
    final lo = math.max(50.0, f - 60);
    final hi = f + 60;
    final measured = measureDominantHz(buf, sampleRate, lo: lo, hi: hi);
    results.add(ProbeResult(label, f, measured, (measured - f).abs() <= tolHz));
  }
  return results;
}
