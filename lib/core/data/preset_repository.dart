import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/preset.dart';
import 'local_store.dart';
import 'migrations.dart';

/// 프리셋 저장소.
/// - 기본 프리셋: 번들 asset(JSON)에서 로드
/// - 사용자 프리셋 + 기본 프리셋 수정본: 로컬 JSON 파일에 저장
class PresetRepository {
  static const _userFile = 'user_presets.json';
  static const _overrideFile = 'builtin_overrides.json';

  List<Preset> _builtIns = [];
  final Map<String, Preset> _overrides = {}; // builtin id -> 수정본
  List<Preset> _userPresets = [];
  final Set<String> _favorites = {};

  List<Preset> get builtIns => _builtIns
      .map((p) => _overrides[p.id] ?? p)
      .map((p) => p..favorite = _favorites.contains(p.id))
      .toList();

  List<Preset> get userPresets =>
      _userPresets.map((p) => p..favorite = _favorites.contains(p.id)).toList();

  List<Preset> get all => [...builtIns, ...userPresets];

  List<Preset> get favorites =>
      all.where((p) => _favorites.contains(p.id)).toList();

  List<Preset> get chakraPresets =>
      builtIns.where((p) => p.chakraIndex != null).toList()
        ..sort((a, b) => a.chakraIndex!.compareTo(b.chakraIndex!));

  Preset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _builtIns = await _loadBuiltIns();
    await _loadOverrides();
    await _loadUser();
  }

  Future<List<Preset>> _loadBuiltIns() async {
    final result = <Preset>[];
    for (final asset in const [
      'assets/presets/default_presets.json',
      'assets/presets/chakra_presets.json',
      'assets/presets/wellness_presets.json',
    ]) {
      final text = await rootBundle.loadString(asset);
      final raw = jsonDecode(text) as Map<String, dynamic>;
      final migrated = migratePresetCollection(raw);
      for (final e in (migrated['presets'] as List)) {
        final p = Preset.fromJson((e as Map).cast());
        p.isBuiltIn = true;
        result.add(p);
      }
    }
    return result;
  }

  Future<void> _loadOverrides() async {
    _overrides.clear();
    final raw = await LocalStore.readJson(_overrideFile);
    final list = raw['presets'] as List? ?? [];
    for (final e in list) {
      final p = Preset.fromJson((e as Map).cast());
      _overrides[p.id] = p;
    }
    _favorites
      ..clear()
      ..addAll((raw['favorites'] as List?)?.cast<String>() ?? const []);
  }

  Future<void> _loadUser() async {
    final raw = await LocalStore.readJson(_userFile);
    final migrated = migratePresetCollection(raw.isEmpty ? {'presets': []} : raw);
    _userPresets = (migrated['presets'] as List)
        .map((e) => Preset.fromJson((e as Map).cast()))
        .toList();
  }

  Future<void> _persistUser() async {
    await LocalStore.writeJson(_userFile, {
      'schemaVersion': kPresetSchemaVersion,
      'presets': _userPresets.map((p) => p.toJson()).toList(),
    });
  }

  Future<void> _persistOverrides() async {
    await LocalStore.writeJson(_overrideFile, {
      'schemaVersion': kPresetSchemaVersion,
      'presets': _overrides.values.map((p) => p.toJson()).toList(),
      'favorites': _favorites.toList(),
    });
  }

  /// 사용자 프리셋 저장/갱신.
  Future<void> saveUserPreset(Preset p) async {
    p.isBuiltIn = false;
    final i = _userPresets.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      _userPresets[i] = p;
    } else {
      _userPresets.add(p);
    }
    await _persistUser();
  }

  /// 기본 프리셋 수정본 저장(원본 asset은 유지, 오버라이드만 기록).
  Future<void> saveBuiltInOverride(Preset p) async {
    _overrides[p.id] = p;
    await _persistOverrides();
  }

  /// 기본 프리셋 기본값 복원(오버라이드 제거).
  Future<void> restoreBuiltIn(String id) async {
    _overrides.remove(id);
    await _persistOverrides();
  }

  Future<void> deleteUserPreset(String id) async {
    _userPresets.removeWhere((p) => p.id == id);
    _favorites.remove(id);
    await _persistUser();
    await _persistOverrides();
  }

  Future<Preset> duplicate(Preset source, {String? newTitle}) async {
    final copy = source.deepCopy();
    copy.id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    copy.title = newTitle ?? '${source.title} (복제)';
    copy.isBuiltIn = false;
    copy.favorite = false;
    await saveUserPreset(copy);
    return copy;
  }

  Future<void> toggleFavorite(String id) async {
    if (_favorites.contains(id)) {
      _favorites.remove(id);
    } else {
      _favorites.add(id);
    }
    await _persistOverrides();
  }

  bool isFavorite(String id) => _favorites.contains(id);

  /// 백업용 사용자 데이터 전체 직렬화(오디오 원본은 포함하지 않음).
  Map<String, dynamic> exportData() => {
        'schemaVersion': kPresetSchemaVersion,
        'kind': 'mindsound_presets_backup',
        'exportedAt': DateTime.now().toIso8601String(),
        'userPresets': _userPresets.map((p) => p.toJson()).toList(),
        'builtinOverrides': _overrides.values.map((p) => p.toJson()).toList(),
        'favorites': _favorites.toList(),
      };

  /// 백업에서 사용자 프리셋 병합. overwrite=true면 동일 id 덮어쓰기.
  Future<int> importData(Map<String, dynamic> data,
      {bool overwrite = true}) async {
    var count = 0;
    final ups = (data['userPresets'] as List?) ?? const [];
    for (final e in ups) {
      final p = Preset.fromJson((e as Map).cast());
      final exists = _userPresets.any((u) => u.id == p.id);
      if (exists && !overwrite) continue;
      _userPresets.removeWhere((u) => u.id == p.id);
      _userPresets.add(p);
      count++;
    }
    final ovs = (data['builtinOverrides'] as List?) ?? const [];
    for (final e in ovs) {
      final p = Preset.fromJson((e as Map).cast());
      _overrides[p.id] = p;
    }
    _favorites.addAll(((data['favorites'] as List?) ?? const []).cast<String>());
    await _persistUser();
    await _persistOverrides();
    return count;
  }

  Future<void> resetUserData() async {
    _userPresets.clear();
    _overrides.clear();
    _favorites.clear();
    await _persistUser();
    await _persistOverrides();
  }
}
