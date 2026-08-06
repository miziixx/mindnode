/// 로컬 음원 카탈로그 항목.
enum AssetKind { nature, pad, chime }

class AudioAssetMetadata {
  final String id;
  final String displayName;
  final AssetKind kind;
  final String assetPath; // flutter asset 경로
  final bool loop; // 자연음/패드=true, 차임=false(one-shot)
  final bool isPlaceholder; // 플레이스홀더 음원 여부

  const AudioAssetMetadata({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.assetPath,
    required this.loop,
    this.isPlaceholder = true,
  });
}

/// 번들 음원 카탈로그. 실제 파일은 assets/audio/** 에 위치.
/// 실제 최종 음원으로 교체하는 방법은 ASSET_GUIDE.md 참고.
class AssetCatalog {
  AssetCatalog._();

  static const List<AudioAssetMetadata> nature = [
    AudioAssetMetadata(
        id: 'rain_soft',
        displayName: '부드러운 비',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/rain_soft_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'forest_morning',
        displayName: '아침 숲',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/forest_morning_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'ocean_calm',
        displayName: '잔잔한 바다',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/ocean_calm_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'stream_soft',
        displayName: '시냇물',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/stream_soft_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'wind_light',
        displayName: '가벼운 바람',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/wind_light_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'fire_soft',
        displayName: '모닥불',
        kind: AssetKind.nature,
        assetPath: 'assets/audio/nature/fire_soft_placeholder.wav',
        loop: true),
  ];

  static const List<AudioAssetMetadata> pads = [
    AudioAssetMetadata(
        id: 'warm_air',
        displayName: 'Warm Air',
        kind: AssetKind.pad,
        assetPath: 'assets/audio/pads/warm_air_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'deep_space',
        displayName: 'Deep Space',
        kind: AssetKind.pad,
        assetPath: 'assets/audio/pads/deep_space_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'soft_light',
        displayName: 'Soft Light',
        kind: AssetKind.pad,
        assetPath: 'assets/audio/pads/soft_light_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'grounding_dark',
        displayName: 'Grounding Dark',
        kind: AssetKind.pad,
        assetPath: 'assets/audio/pads/grounding_dark_placeholder.wav',
        loop: true),
    AudioAssetMetadata(
        id: 'crystal_air',
        displayName: 'Crystal Air',
        kind: AssetKind.pad,
        assetPath: 'assets/audio/pads/crystal_air_placeholder.wav',
        loop: true),
  ];

  static const List<AudioAssetMetadata> chimes = [
    AudioAssetMetadata(
        id: 'bell_soft_01',
        displayName: '부드러운 종 1',
        kind: AssetKind.chime,
        assetPath: 'assets/audio/chimes/bell_soft_01_placeholder.wav',
        loop: false),
    AudioAssetMetadata(
        id: 'bell_soft_02',
        displayName: '부드러운 종 2',
        kind: AssetKind.chime,
        assetPath: 'assets/audio/chimes/bell_soft_02_placeholder.wav',
        loop: false),
    AudioAssetMetadata(
        id: 'bowl_low',
        displayName: '낮은 싱잉볼',
        kind: AssetKind.chime,
        assetPath: 'assets/audio/chimes/bowl_low_placeholder.wav',
        loop: false),
    AudioAssetMetadata(
        id: 'bowl_high',
        displayName: '높은 싱잉볼',
        kind: AssetKind.chime,
        assetPath: 'assets/audio/chimes/bowl_high_placeholder.wav',
        loop: false),
    AudioAssetMetadata(
        id: 'session_end',
        displayName: '세션 종료음',
        kind: AssetKind.chime,
        assetPath: 'assets/audio/chimes/session_end_placeholder.wav',
        loop: false),
  ];

  static List<AudioAssetMetadata> get all => [...nature, ...pads, ...chimes];

  static List<AudioAssetMetadata> byKind(AssetKind k) =>
      all.where((a) => a.kind == k).toList();

  static AudioAssetMetadata? byId(String? id) {
    if (id == null) return null;
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static String displayNameOf(String? id) => byId(id)?.displayName ?? '없음';
}
