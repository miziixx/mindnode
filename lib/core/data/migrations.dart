import '../models/preset.dart';

/// 프리셋 컬렉션 마이그레이션. schemaVersion에 따라 구조를 최신으로 변환.
/// 구조가 바뀔 때마다 여기에 단계별 변환을 추가한다.
Map<String, dynamic> migratePresetCollection(Map<String, dynamic> raw) {
  var data = Map<String, dynamic>.from(raw);
  var version = (data['schemaVersion'] as num?)?.toInt() ?? 1;

  // 예: v1 -> v2 마이그레이션이 생기면 아래에 추가
  // while (version < kPresetSchemaVersion) {
  //   if (version == 1) { ...transform...; version = 2; }
  // }

  // 개별 프리셋의 schemaVersion도 정규화
  final presets = (data['presets'] as List?) ?? const [];
  for (final p in presets) {
    if (p is Map && (p['schemaVersion'] == null)) {
      p['schemaVersion'] = kPresetSchemaVersion;
    }
  }

  data['schemaVersion'] = version < kPresetSchemaVersion
      ? kPresetSchemaVersion
      : version;
  return data;
}
