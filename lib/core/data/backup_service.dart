import 'dart:convert';

import '../models/preset.dart';

/// 백업 파일 검증 결과(가져오기 전 미리보기용).
class BackupPreview {
  final bool valid;
  final String? error;
  final String kind;
  final int schemaVersion;
  final int userPresetCount;
  final int recordCount;
  final List<String> presetTitles;
  final List<String> duplicateIds;

  BackupPreview({
    required this.valid,
    this.error,
    this.kind = '',
    this.schemaVersion = 0,
    this.userPresetCount = 0,
    this.recordCount = 0,
    this.presetTitles = const [],
    this.duplicateIds = const [],
  });
}

/// JSON 백업 검증 및 미리보기. 잘못된 파일은 거부한다.
class BackupService {
  /// [text]: 사용자가 가져온 JSON 문자열.
  /// [existingPresetIds]: 현재 사용자 프리셋 id 집합(중복 감지용).
  static BackupPreview inspect(String text, Set<String> existingPresetIds) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return BackupPreview(valid: false, error: '최상위가 객체가 아닙니다.');
      }
      data = decoded;
    } catch (e) {
      return BackupPreview(valid: false, error: 'JSON 파싱 실패: $e');
    }

    final kind = data['kind'] as String? ?? '';
    if (!kind.startsWith('mindsound_')) {
      return BackupPreview(
          valid: false, error: '마인드사운드 백업 파일이 아닙니다.', kind: kind);
    }

    final version = (data['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version > kPresetSchemaVersion) {
      return BackupPreview(
        valid: false,
        error: '이 앱 버전보다 최신 백업입니다(schema $version). 앱을 업데이트하세요.',
        kind: kind,
        schemaVersion: version,
      );
    }

    final userPresets = (data['userPresets'] as List?) ?? const [];
    final records = (data['records'] as List?) ?? const [];
    final titles = <String>[];
    final dupes = <String>[];
    for (final e in userPresets) {
      if (e is! Map) continue;
      final id = e['id'] as String?;
      final title = e['title'] as String? ?? '무제';
      titles.add(title);
      if (id != null && existingPresetIds.contains(id)) dupes.add(id);
    }

    return BackupPreview(
      valid: true,
      kind: kind,
      schemaVersion: version,
      userPresetCount: userPresets.length,
      recordCount: records.length,
      presetTitles: titles,
      duplicateIds: dupes,
    );
  }

  static Map<String, dynamic>? tryParse(String text) {
    try {
      final d = jsonDecode(text);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }
}
