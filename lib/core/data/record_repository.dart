import '../models/session_record.dart';
import 'local_store.dart';

/// 세션 기록 저장소.
class RecordRepository {
  static const _file = 'records.json';
  List<SessionRecord> _records = [];

  List<SessionRecord> get records =>
      [..._records]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  Future<void> load() async {
    final raw = await LocalStore.readJson(_file);
    _records = ((raw['records'] as List?) ?? const [])
        .map((e) => SessionRecord.fromJson((e as Map).cast()))
        .toList();
  }

  Future<void> add(SessionRecord r) async {
    _records.add(r);
    await _persist();
  }

  Future<void> delete(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _persist();
  }

  Future<void> clear() async {
    _records.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await LocalStore.writeJson(_file, {
      'schemaVersion': 1,
      'records': _records.map((r) => r.toJson()).toList(),
    });
  }

  /// 이번 달 요약(횟수, 총 시간 초).
  ({int count, int totalSeconds}) monthSummary(DateTime now) {
    final month = _records.where(
        (r) => r.startedAt.year == now.year && r.startedAt.month == now.month);
    return (
      count: month.length,
      totalSeconds: month.fold(0, (s, r) => s + r.playedSeconds),
    );
  }

  Map<String, dynamic> exportData() => {
        'schemaVersion': 1,
        'kind': 'mindsound_records_backup',
        'exportedAt': DateTime.now().toIso8601String(),
        'records': _records.map((r) => r.toJson()).toList(),
      };

  Future<int> importData(Map<String, dynamic> data) async {
    final incoming = ((data['records'] as List?) ?? const [])
        .map((e) => SessionRecord.fromJson((e as Map).cast()))
        .toList();
    final existingIds = _records.map((r) => r.id).toSet();
    var count = 0;
    for (final r in incoming) {
      if (existingIds.contains(r.id)) continue;
      _records.add(r);
      count++;
    }
    await _persist();
    return count;
  }
}
