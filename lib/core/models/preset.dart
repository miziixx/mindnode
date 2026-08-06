import 'layers.dart';

/// 데이터 스키마 버전. 구조가 바뀌면 올리고 마이그레이션한다.
const int kPresetSchemaVersion = 1;

/// 세션의 한 단계. 단계형 시퀀스를 구성한다.
class SessionStage {
  String id;
  String title;
  int durationSec;
  ToneLayer primaryTone;
  DroneLayer drone;
  ToneLayer secondaryTone;
  BinauralLayer binaural;
  PulseLayer pulse;
  String? natureAssetId;
  String? padAssetId;
  String? chimeAssetId;
  int chimeIntervalSec; // 0이면 반복 없음(one-shot은 시작 시)
  double transitionDurationSec; // 단계 전환 크로스페이드(기본 1.5초 이상)

  SessionStage({
    required this.id,
    this.title = '',
    this.durationSec = 600,
    ToneLayer? primaryTone,
    DroneLayer? drone,
    ToneLayer? secondaryTone,
    BinauralLayer? binaural,
    PulseLayer? pulse,
    this.natureAssetId,
    this.padAssetId,
    this.chimeAssetId,
    this.chimeIntervalSec = 0,
    this.transitionDurationSec = 1.5,
  })  : primaryTone = primaryTone ?? ToneLayer(),
        drone = drone ?? DroneLayer(),
        secondaryTone = secondaryTone ?? ToneLayer(enabled: false, gainDb: -34),
        binaural = binaural ?? BinauralLayer(),
        pulse = pulse ?? PulseLayer();

  factory SessionStage.fromJson(Map<String, dynamic> j) => SessionStage(
        id: j['id'] as String? ?? 'stage',
        title: j['title'] as String? ?? '',
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 600,
        primaryTone: j['primaryTone'] is Map
            ? ToneLayer.fromJson((j['primaryTone'] as Map).cast())
            : ToneLayer(),
        drone: j['drone'] is Map
            ? DroneLayer.fromJson((j['drone'] as Map).cast())
            : DroneLayer(),
        secondaryTone: j['secondaryTone'] is Map
            ? ToneLayer.fromJson((j['secondaryTone'] as Map).cast())
            : ToneLayer(enabled: false, gainDb: -34),
        binaural: j['binaural'] is Map
            ? BinauralLayer.fromJson((j['binaural'] as Map).cast())
            : BinauralLayer(),
        pulse: j['pulse'] is Map
            ? PulseLayer.fromJson((j['pulse'] as Map).cast())
            : PulseLayer(),
        natureAssetId: j['natureAssetId'] as String?,
        padAssetId: j['padAssetId'] as String?,
        chimeAssetId: j['chimeAssetId'] as String?,
        chimeIntervalSec: (j['chimeIntervalSec'] as num?)?.toInt() ?? 0,
        transitionDurationSec:
            (j['transitionDurationSec'] as num?)?.toDouble() ?? 1.5,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationSec': durationSec,
        'primaryTone': primaryTone.toJson(),
        'drone': drone.toJson(),
        'secondaryTone': secondaryTone.toJson(),
        'binaural': binaural.toJson(),
        'pulse': pulse.toJson(),
        'natureAssetId': natureAssetId,
        'padAssetId': padAssetId,
        'chimeAssetId': chimeAssetId,
        'chimeIntervalSec': chimeIntervalSec,
        'transitionDurationSec': transitionDurationSec,
      };

  SessionStage copy() => SessionStage.fromJson(toJson());

  /// 이 단계에서 화면에 표시할 대표 중심 주파수.
  double? get displayFrequencyHz {
    if (primaryTone.enabled) return primaryTone.frequencyHz;
    if (drone.enabled) return drone.centerHz;
    if (pulse.enabled) return pulse.frequencyHz;
    if (binaural.enabled) return binaural.carrierHz;
    return null;
  }
}

enum PresetCategory {
  uplift,
  energize,
  abundance,
  cleanse,
  meditation,
  reiki,
  chakra,
  custom,
}

PresetCategory categoryFromString(String? s) {
  switch (s) {
    case 'uplift':
      return PresetCategory.uplift;
    case 'energize':
      return PresetCategory.energize;
    case 'abundance':
      return PresetCategory.abundance;
    case 'cleanse':
      return PresetCategory.cleanse;
    case 'meditation':
      return PresetCategory.meditation;
    case 'reiki':
      return PresetCategory.reiki;
    case 'chakra':
      return PresetCategory.chakra;
    default:
      return PresetCategory.custom;
  }
}

String categoryToString(PresetCategory c) => c.name;

/// 프리셋(세션 정의). UI/엔진에 하드코딩하지 않고 이 모델을 통해 다룬다.
class Preset {
  int schemaVersion;
  String id;
  String title;
  PresetCategory category;
  bool symbolicUse; // 상징적 초기값 표기(치료 효과 아님)
  int fadeInSec;
  int fadeOutSec;
  double masterGainDb;
  List<SessionStage> stages;
  bool isBuiltIn; // 기본 프리셋 여부
  bool favorite;
  int? chakraIndex; // 차크라 프리셋이면 1..7

  Preset({
    this.schemaVersion = kPresetSchemaVersion,
    required this.id,
    required this.title,
    this.category = PresetCategory.custom,
    this.symbolicUse = true,
    this.fadeInSec = 5,
    this.fadeOutSec = 20,
    this.masterGainDb = -12,
    List<SessionStage>? stages,
    this.isBuiltIn = false,
    this.favorite = false,
    this.chakraIndex,
  }) : stages = stages ?? [SessionStage(id: 'main')];

  int get totalDurationSec =>
      stages.fold(0, (sum, s) => sum + s.durationSec);

  factory Preset.fromJson(Map<String, dynamic> j) => Preset(
        schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
        id: j['id'] as String,
        title: j['title'] as String? ?? '무제',
        category: categoryFromString(j['category'] as String?),
        symbolicUse: j['symbolicUse'] as bool? ?? true,
        fadeInSec: (j['fadeInSec'] as num?)?.toInt() ?? 5,
        fadeOutSec: (j['fadeOutSec'] as num?)?.toInt() ?? 20,
        masterGainDb: (j['masterGainDb'] as num?)?.toDouble() ?? -12,
        stages: (j['stages'] as List?)
                ?.map((e) => SessionStage.fromJson((e as Map).cast()))
                .toList() ??
            [SessionStage(id: 'main')],
        isBuiltIn: j['isBuiltIn'] as bool? ?? false,
        favorite: j['favorite'] as bool? ?? false,
        chakraIndex: (j['chakraIndex'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'title': title,
        'category': categoryToString(category),
        'symbolicUse': symbolicUse,
        'fadeInSec': fadeInSec,
        'fadeOutSec': fadeOutSec,
        'masterGainDb': masterGainDb,
        'stages': stages.map((s) => s.toJson()).toList(),
        'isBuiltIn': isBuiltIn,
        'favorite': favorite,
        'chakraIndex': chakraIndex,
      };

  Preset copyWith({String? id, String? title, bool? isBuiltIn}) {
    final json = toJson();
    final p = Preset.fromJson(json);
    if (id != null) p.id = id;
    if (title != null) p.title = title;
    if (isBuiltIn != null) p.isBuiltIn = isBuiltIn;
    return p;
  }

  /// 재생 중 수정용 깊은 복제(원본 프리셋을 덮어쓰지 않기 위함).
  Preset deepCopy() => Preset.fromJson(toJson());
}
