import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/core/models/preset.dart';
import 'package:mindsound/core/models/layers.dart';

/// 번들 기본 프리셋 JSON을 실제로 로드/검증. (flutter test는 패키지 루트에서 실행)
List<Preset> loadFile(String path) {
  final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (raw['presets'] as List)
      .map((e) => Preset.fromJson((e as Map).cast()))
      .toList();
}

void main() {
  test('기본 프리셋 6개가 로드된다', () {
    final ps = loadFile('assets/presets/default_presets.json');
    expect(ps.length, 6);
    expect(ps.map((p) => p.id),
        containsAll(['uplift_mind', 'abundance_ritual', 'cleanse_negative']));
  });

  test('차크라 프리셋 8개(1~7 + 전체순환)가 로드된다', () {
    final ps = loadFile('assets/presets/chakra_presets.json');
    expect(ps.length, 8);
    final chakraIdx = ps.where((p) => p.chakraIndex != null).map((p) => p.chakraIndex).toList()
      ..sort();
    expect(chakraIdx, [1, 2, 3, 4, 5, 6, 7]);
  });

  test('정화 프리셋은 4단계 시퀀스(396→417→741→무음)', () {
    final ps = loadFile('assets/presets/default_presets.json');
    final cleanse = ps.firstWhere((p) => p.id == 'cleanse_negative');
    expect(cleanse.stages.length, 4);
    expect(cleanse.stages[0].primaryTone.frequencyHz, 396);
    expect(cleanse.stages[1].primaryTone.frequencyHz, 417);
    expect(cleanse.stages[2].primaryTone.frequencyHz, 741);
    // 4단계는 무음(모든 톤 비활성) + 종료 차임
    final last = cleanse.stages[3];
    expect(last.primaryTone.enabled, isFalse);
    expect(last.drone.enabled, isFalse);
    expect(last.chimeAssetId, isNotNull);
  });

  test('6·7차크라는 하위 옥타브 드론 + 낮은 원주파수', () {
    final ps = loadFile('assets/presets/chakra_presets.json');
    final six = ps.firstWhere((p) => p.chakraIndex == 6);
    final seven = ps.firstWhere((p) => p.chakraIndex == 7);
    expect(six.stages.first.drone.centerHz, 426.0); // 852의 하위 옥타브
    expect(six.stages.first.primaryTone.gainDb, lessThan(-30)); // 852 낮은 음량
    expect(seven.stages.first.drone.centerHz, 481.5); // 963의 하위 옥타브
  });

  test('모든 기본 프리셋에 schemaVersion과 최소 1개 스테이지', () {
    final all = [
      ...loadFile('assets/presets/default_presets.json'),
      ...loadFile('assets/presets/chakra_presets.json'),
    ];
    expect(all.length, 14);
    for (final p in all) {
      expect(p.schemaVersion, kPresetSchemaVersion);
      expect(p.stages, isNotEmpty);
      expect(p.symbolicUse, isTrue); // 상징적 초기값 표기
      for (final s in p.stages) {
        // 주파수 안전 범위 내
        for (final tone in [s.primaryTone, s.secondaryTone]) {
          if (tone.enabled) {
            expect(tone.frequencyHz, inInclusiveRange(FreqLimits.min, FreqLimits.maxAbsolute));
          }
        }
      }
    }
  });
}
