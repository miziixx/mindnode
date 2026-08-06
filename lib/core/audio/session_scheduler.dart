import '../models/preset.dart';

/// 시퀀스 타이밍·차임 스케줄의 순수 함수 레퍼런스(가상 시계로 테스트 가능).
///
/// 네이티브 엔진(Kotlin/Swift)의 스테이지 전환·차임 인터벌 로직은 이 규칙과 동일하다.
/// UI/오디오 출력과 분리되어 injectable clock 으로 결정적으로 검증한다.
class SessionScheduler {
  SessionScheduler(this.stages) {
    _cumulative = [];
    var acc = 0;
    for (final s in stages) {
      acc += s.durationSec;
      _cumulative.add(acc);
    }
  }

  final List<SessionStage> stages;
  late final List<int> _cumulative; // 누적 종료 시간(초)

  int get totalDurationSec => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// 경과 초 → 현재 스테이지 인덱스(마지막 스테이지에서 clamp).
  int stageIndexAt(int elapsedSec) {
    for (var i = 0; i < _cumulative.length; i++) {
      if (elapsedSec < _cumulative[i]) return i;
    }
    return stages.isEmpty ? 0 : stages.length - 1;
  }

  /// 현재 스테이지 내 경과 초.
  int stageElapsedAt(int elapsedSec) {
    final idx = stageIndexAt(elapsedSec);
    final startOfStage = idx == 0 ? 0 : _cumulative[idx - 1];
    return elapsedSec - startOfStage;
  }

  int remainingAt(int elapsedSec) =>
      (totalDurationSec - elapsedSec).clamp(0, totalDurationSec);

  double progressAt(int elapsedSec) =>
      totalDurationSec == 0 ? 0 : (elapsedSec / totalDurationSec).clamp(0.0, 1.0);

  bool isCompleteAt(int elapsedSec) => elapsedSec >= totalDurationSec;

  /// [fromSec, toSec) 동안 차임이 울려야 하는 (초, assetId) 목록.
  /// 인터벌 차임은 스테이지 시작 기준. 일시정지 구간은 호출자가 elapsed에서 제외한다.
  List<({int atSec, String? assetId})> chimesBetween(int fromSec, int toSec) {
    final events = <({int atSec, String? assetId})>[];
    // 세션 종료 시점 이후로는 예약 차임이 남지 않는다.
    final end = toSec < totalDurationSec ? toSec : totalDurationSec;
    for (var sec = fromSec; sec < end; sec++) {
      final idx = stageIndexAt(sec);
      final stage = stages[idx];
      if (stage.chimeIntervalSec <= 0) continue;
      final stageStart = idx == 0 ? 0 : _cumulative[idx - 1];
      final within = sec - stageStart;
      // 인터벌 경계(첫 인터벌 지난 시점부터)
      if (within > 0 && within % stage.chimeIntervalSec == 0) {
        events.add((atSec: sec, assetId: stage.chimeAssetId));
      }
    }
    return events;
  }
}
