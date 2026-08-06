import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/core/models/preset.dart';
import 'package:mindsound/core/models/layers.dart';
import 'package:mindsound/core/models/user_settings.dart';
import 'package:mindsound/core/models/session_record.dart';

void main() {
  test('Preset JSON 왕복이 값을 보존한다', () {
    final p = Preset(
      id: 'test',
      title: '테스트',
      category: PresetCategory.abundance,
      fadeInSec: 5,
      fadeOutSec: 20,
      masterGainDb: -12,
      stages: [
        SessionStage(
          id: 'main',
          durationSec: 1200,
          primaryTone: ToneLayer(enabled: false, frequencyHz: 432, gainDb: -30),
          drone: DroneLayer(enabled: true, centerHz: 432, gainDb: -24),
          secondaryTone: ToneLayer(enabled: true, frequencyHz: 888, gainDb: -36),
          pulse: PulseLayer(enabled: true, rateHz: 8.8, depth: 0.2),
          padAssetId: 'warm_air',
          chimeAssetId: 'bowl_high',
        ),
      ],
    );
    final round = Preset.fromJson(p.toJson());
    expect(round.id, 'test');
    expect(round.category, PresetCategory.abundance);
    expect(round.schemaVersion, kPresetSchemaVersion);
    expect(round.stages.first.drone.centerHz, 432);
    expect(round.stages.first.secondaryTone.frequencyHz, 888);
    expect(round.stages.first.pulse.rateHz, 8.8);
    expect(round.stages.first.padAssetId, 'warm_air');
    expect(round.totalDurationSec, 1200);
  });

  test('바이노럴 좌우 계산과 반전', () {
    final b = BinauralLayer(carrierHz: 220, beatHz: 10);
    expect(b.leftHz, 220);
    expect(b.rightHz, 230);
    b.invert = true;
    expect(b.leftHz, 230);
    expect(b.rightHz, 220);
  });

  test('드론 하위/상위 옥타브', () {
    final d = DroneLayer(centerHz: 432);
    expect(d.subHz, 216);
    expect(d.mainHz, 432);
    expect(d.airHz, 864);
  });

  test('UserSettings 왕복', () {
    final s = UserSettings(initialMasterVolumePercent: 15, endFadeSec: 10);
    final r = UserSettings.fromJson(s.toJson());
    expect(r.initialMasterVolumePercent, 15);
    expect(r.endFadeSec, 10);
    expect(r.pauseOnHeadphoneUnplug, isTrue);
  });

  test('SessionRecord 왕복', () {
    final rec = SessionRecord(
      id: 'r1',
      startedAt: DateTime(2026, 8, 6, 19, 30),
      presetId: 'uplift_mind',
      presetTitle: '마음 끌어올리기',
      playedSeconds: 900,
      plannedSeconds: 900,
      completed: true,
      frequencies: const [528],
    );
    final r = SessionRecord.fromJson(rec.toJson());
    expect(r.presetTitle, '마음 끌어올리기');
    expect(r.completed, isTrue);
    expect(r.frequencies, [528]);
  });

  test('알 수 없는 파형은 사인으로 폴백', () {
    expect(waveformFromString('square'), Waveform.sine);
  });
}
