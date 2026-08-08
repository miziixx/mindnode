import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/core/audio/tone_probe.dart';

/// 자가진단 코어 검증: 생성한 톤의 지배 주파수가 선언값과 일치하는지(Goertzel).
void main() {
  test('renderTone + measureDominantHz 가 선언 주파수를 복원한다', () {
    const sr = 48000.0;
    for (final f in [174.0, 432.0, 528.0, 741.0, 963.0]) {
      final buf = renderTone(f, sr, 8192);
      final measured = measureDominantHz(buf, sr, lo: f - 60, hi: f + 60);
      expect((measured - f).abs() < 1.5, isTrue,
          reason: '$f Hz → 측정 $measured Hz');
    }
  });

  test('runToneSelfCheck 전 항목 통과', () {
    final results = runToneSelfCheck();
    expect(results.every((r) => r.pass), isTrue,
        reason: results.map((r) => '${r.label}:${r.measuredHz}').join(', '));
  });

  test('다른 주파수는 잘못된 매칭을 하지 않는다', () {
    const sr = 48000.0;
    final buf = renderTone(440, sr, 8192);
    final measured = measureDominantHz(buf, sr, lo: 380, hi: 500);
    expect((measured - 440).abs() < 1.5, isTrue);
    expect((measured - 432).abs() > 3, isTrue); // 432 로 오인 안 함
  });
}
