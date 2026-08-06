/// 세션 기록. 세션 전/후 상태는 선택 입력이며 의료 진단으로 표현하지 않는다.
class SessionRecord {
  final String id;
  final DateTime startedAt;
  final String presetId;
  final String presetTitle;
  final int playedSeconds;
  final int plannedSeconds;
  final bool completed;
  final bool modified;
  final String? moodBefore; // 선택
  final String? moodAfter; // 선택
  final int? comfortScore; // 0..10 선택
  final String? note;
  final List<double> frequencies; // 사용한 주파수
  final String? natureAssetId;
  final String? padAssetId;
  final String? chimeAssetId;

  SessionRecord({
    required this.id,
    required this.startedAt,
    required this.presetId,
    required this.presetTitle,
    required this.playedSeconds,
    required this.plannedSeconds,
    this.completed = false,
    this.modified = false,
    this.moodBefore,
    this.moodAfter,
    this.comfortScore,
    this.note,
    this.frequencies = const [],
    this.natureAssetId,
    this.padAssetId,
    this.chimeAssetId,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        presetId: j['presetId'] as String? ?? '',
        presetTitle: j['presetTitle'] as String? ?? '',
        playedSeconds: (j['playedSeconds'] as num?)?.toInt() ?? 0,
        plannedSeconds: (j['plannedSeconds'] as num?)?.toInt() ?? 0,
        completed: j['completed'] as bool? ?? false,
        modified: j['modified'] as bool? ?? false,
        moodBefore: j['moodBefore'] as String?,
        moodAfter: j['moodAfter'] as String?,
        comfortScore: (j['comfortScore'] as num?)?.toInt(),
        note: j['note'] as String?,
        frequencies: (j['frequencies'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            const [],
        natureAssetId: j['natureAssetId'] as String?,
        padAssetId: j['padAssetId'] as String?,
        chimeAssetId: j['chimeAssetId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'presetId': presetId,
        'presetTitle': presetTitle,
        'playedSeconds': playedSeconds,
        'plannedSeconds': plannedSeconds,
        'completed': completed,
        'modified': modified,
        'moodBefore': moodBefore,
        'moodAfter': moodAfter,
        'comfortScore': comfortScore,
        'note': note,
        'frequencies': frequencies,
        'natureAssetId': natureAssetId,
        'padAssetId': padAssetId,
        'chimeAssetId': chimeAssetId,
      };
}
