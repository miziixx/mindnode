import 'dart:math' as math;

/// 파형. 초기 버전은 사인만 구현. (사각/톱니/삼각은 후속)
enum Waveform { sine }

Waveform waveformFromString(String? s) => Waveform.sine;
String waveformToString(Waveform w) => 'sine';

/// 주파수 안전 범위. 최대는 min(20000, sampleRate*0.45)로 엔진 단에서 다시 클램프.
class FreqLimits {
  FreqLimits._();
  static const double min = 20.0;
  static const double maxAbsolute = 20000.0;
  static double maxForSampleRate(double sampleRate) =>
      math.min(maxAbsolute, sampleRate * 0.45);
  static double clamp(double hz, {double sampleRate = 48000}) =>
      hz.clamp(min, maxForSampleRate(sampleRate));
}

/// 실시간 생성 단일 톤(주파수) 레이어.
class ToneLayer {
  bool enabled;
  double frequencyHz;
  double gainDb;
  double pan; // -1.0 (L) .. 1.0 (R)

  ToneLayer({
    this.enabled = false,
    this.frequencyHz = 528.0,
    this.gainDb = -26,
    this.pan = 0,
  });

  factory ToneLayer.fromJson(Map<String, dynamic> j) => ToneLayer(
        enabled: j['enabled'] as bool? ?? false,
        frequencyHz: (j['frequencyHz'] as num?)?.toDouble() ?? 528.0,
        gainDb: (j['gainDb'] as num?)?.toDouble() ?? -26,
        pan: (j['pan'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'frequencyHz': frequencyHz,
        'gainDb': gainDb,
        'pan': pan,
      };

  ToneLayer copy() => ToneLayer.fromJson(toJson());
}

/// 실시간 드론. 중심 주파수 기반 다중 사인 합성(Sub/Main/Air).
class DroneLayer {
  bool enabled;
  double centerHz;
  double gainDb;
  double movementRateHz; // 0.03~0.10 매우 느린 진폭 변화
  double stereoWidth; // 0..1
  double subVoiceRatio; // 상대 비율 (기본 0.35)
  double mainVoiceRatio; // 0.55
  double airVoiceRatio; // 0.10

  DroneLayer({
    this.enabled = false,
    this.centerHz = 528.0,
    this.gainDb = -24,
    this.movementRateHz = 0.05,
    this.stereoWidth = 0.2,
    this.subVoiceRatio = 0.35,
    this.mainVoiceRatio = 0.55,
    this.airVoiceRatio = 0.10,
  });

  double get subHz => centerHz * 0.5;
  double get mainHz => centerHz;
  double get airHz => centerHz * 2.0;

  factory DroneLayer.fromJson(Map<String, dynamic> j) => DroneLayer(
        enabled: j['enabled'] as bool? ?? false,
        centerHz: (j['centerHz'] as num?)?.toDouble() ?? 528.0,
        gainDb: (j['gainDb'] as num?)?.toDouble() ?? -24,
        movementRateHz: (j['movementRateHz'] as num?)?.toDouble() ?? 0.05,
        stereoWidth: (j['stereoWidth'] as num?)?.toDouble() ?? 0.2,
        subVoiceRatio: (j['subVoiceRatio'] as num?)?.toDouble() ?? 0.35,
        mainVoiceRatio: (j['mainVoiceRatio'] as num?)?.toDouble() ?? 0.55,
        airVoiceRatio: (j['airVoiceRatio'] as num?)?.toDouble() ?? 0.10,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'centerHz': centerHz,
        'gainDb': gainDb,
        'movementRateHz': movementRateHz,
        'stereoWidth': stereoWidth,
        'subVoiceRatio': subVoiceRatio,
        'mainVoiceRatio': mainVoiceRatio,
        'airVoiceRatio': airVoiceRatio,
      };

  DroneLayer copy() => DroneLayer.fromJson(toJson());
}

/// 바이노럴 비트. 좌우 다른 주파수(이어폰 전제).
class BinauralLayer {
  bool enabled;
  double carrierHz;
  double beatHz;
  bool invert; // true면 왼쪽을 더 높게
  double gainDb;

  BinauralLayer({
    this.enabled = false,
    this.carrierHz = 220,
    this.beatHz = 10,
    this.invert = false,
    this.gainDb = -30,
  });

  double get leftHz => invert ? carrierHz + beatHz : carrierHz;
  double get rightHz => invert ? carrierHz : carrierHz + beatHz;

  factory BinauralLayer.fromJson(Map<String, dynamic> j) => BinauralLayer(
        enabled: j['enabled'] as bool? ?? false,
        carrierHz: (j['carrierHz'] as num?)?.toDouble() ?? 220,
        beatHz: (j['beatHz'] as num?)?.toDouble() ?? 10,
        invert: j['invert'] as bool? ?? false,
        gainDb: (j['gainDb'] as num?)?.toDouble() ?? -30,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'carrierHz': carrierHz,
        'beatHz': beatHz,
        'invert': invert,
        'gainDb': gainDb,
      };

  BinauralLayer copy() => BinauralLayer.fromJson(toJson());
}

enum PulseStereoMode { center, alternate }

/// 부드러운 진폭 펄스(주파수 변경 없이 음량만 사인형 변조).
class PulseLayer {
  bool enabled;
  double frequencyHz; // 펄스가 실릴 중심 톤
  double rateHz;
  double depth; // 0..1
  PulseStereoMode stereoMode;
  double gainDb;

  PulseLayer({
    this.enabled = false,
    this.frequencyHz = 432.0,
    this.rateHz = 7.83,
    this.depth = 0.2,
    this.stereoMode = PulseStereoMode.center,
    this.gainDb = -30,
  });

  factory PulseLayer.fromJson(Map<String, dynamic> j) => PulseLayer(
        enabled: j['enabled'] as bool? ?? false,
        frequencyHz: (j['frequencyHz'] as num?)?.toDouble() ?? 432.0,
        rateHz: (j['rateHz'] as num?)?.toDouble() ?? 7.83,
        depth: (j['depth'] as num?)?.toDouble() ?? 0.2,
        stereoMode: (j['stereoMode'] == 'alternate')
            ? PulseStereoMode.alternate
            : PulseStereoMode.center,
        gainDb: (j['gainDb'] as num?)?.toDouble() ?? -30,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'frequencyHz': frequencyHz,
        'rateHz': rateHz,
        'depth': depth,
        'stereoMode': stereoMode == PulseStereoMode.alternate
            ? 'alternate'
            : 'center',
        'gainDb': gainDb,
      };

  PulseLayer copy() => PulseLayer.fromJson(toJson());
}

/// 로컬 음원 레이어(자연음/패드/차임). 실제 샘플은 네이티브가 로드.
class AssetLayer {
  bool enabled;
  String? assetId;
  double gainDb;

  AssetLayer({this.enabled = false, this.assetId, this.gainDb = -22});

  factory AssetLayer.fromJson(Map<String, dynamic> j) => AssetLayer(
        enabled: j['enabled'] as bool? ?? false,
        assetId: j['assetId'] as String?,
        gainDb: (j['gainDb'] as num?)?.toDouble() ?? -22,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'assetId': assetId,
        'gainDb': gainDb,
      };

  AssetLayer copy() => AssetLayer.fromJson(toJson());
}
