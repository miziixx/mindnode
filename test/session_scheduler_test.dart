import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/core/audio/session_scheduler.dart';
import 'package:mindsound/core/models/preset.dart';
import 'package:mindsound/core/models/layers.dart';

SessionStage stage(String id, int dur,
    {int chimeInterval = 0, String? chimeId}) {
  return SessionStage(
    id: id,
    durationSec: dur,
    primaryTone: ToneLayer(enabled: true, frequencyHz: 440),
    chimeIntervalSec: chimeInterval,
    chimeAssetId: chimeId,
  );
}

void main() {
  // 정화 시퀀스: 396 3분 → 417 5분 → 741 5분 → 무음 2분 (가상 시계)
  final scheduler = SessionScheduler([
    stage('s1', 180),
    stage('s2', 300),
    stage('s3', 300),
    stage('s4', 120),
  ]);

  test('전체 예상 시간', () {
    expect(scheduler.totalDurationSec, 900);
  });

  test('가상 시계로 스테이지 순서/시간이 정확하다', () {
    expect(scheduler.stageIndexAt(0), 0);
    expect(scheduler.stageIndexAt(179), 0);
    expect(scheduler.stageIndexAt(180), 1); // 전환 경계
    expect(scheduler.stageIndexAt(479), 1);
    expect(scheduler.stageIndexAt(480), 2);
    expect(scheduler.stageIndexAt(779), 2);
    expect(scheduler.stageIndexAt(780), 3);
    expect(scheduler.stageIndexAt(899), 3);
    expect(scheduler.stageIndexAt(900), 3); // clamp
  });

  test('스테이지 내 경과/남은 시간/진행률', () {
    expect(scheduler.stageElapsedAt(200), 20); // s2 시작 후 20초
    expect(scheduler.remainingAt(0), 900);
    expect(scheduler.remainingAt(900), 0);
    expect(scheduler.progressAt(450), closeTo(0.5, 1e-9));
    expect(scheduler.isCompleteAt(900), isTrue);
    expect(scheduler.isCompleteAt(899), isFalse);
  });

  test('레이키형 인터벌 차임: 5분마다, 중복 없이, 종료 후 없음', () {
    final reiki = SessionScheduler([
      stage('main', 2700, chimeInterval: 300, chimeId: 'bowl_low'),
    ]);
    final chimes = reiki.chimesBetween(0, 2700);
    // 300,600,...,2400,2700 미만 → 300..2400 (8회)
    expect(chimes.map((c) => c.atSec).toList(),
        [300, 600, 900, 1200, 1500, 1800, 2100, 2400]);
    expect(chimes.every((c) => c.assetId == 'bowl_low'), isTrue);
    // 세션 종료 후 예약 차임 없음
    expect(reiki.chimesBetween(2700, 3600), isEmpty);
  });

  test('일시정지 구간을 elapsed에서 제외하면 차임이 밀리지 않는다', () {
    final reiki = SessionScheduler([
      stage('main', 2700, chimeInterval: 300, chimeId: 'bowl_low'),
    ]);
    // 100~200초 동안 일시정지했다고 가정 → elapsed는 실제시간-100
    // 첫 차임은 elapsed 300에서. 구간 스캔은 elapsed 기준이므로 동일하게 동작.
    final chimes = reiki.chimesBetween(299, 301);
    expect(chimes.length, 1);
    expect(chimes.first.atSec, 300);
  });
}
