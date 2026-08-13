import 'dart:async';

import '../models/preset.dart';
import '../models/layers.dart';
import 'audio_events.dart';

/// 오디오 엔진 공통 인터페이스.
/// - 모바일/데스크톱: 네이티브 DSP(`AudioEngineInterface`, MethodChannel).
/// - 웹: Web Audio API(`WebAudioEngine`).
///
/// UI/컨트롤러는 이 인터페이스에만 의존하고, 실제 구현은
/// `audio_engine_factory.dart` 가 플랫폼에 맞게 선택한다.
abstract class AudioEngine {
  Stream<AudioEngineEvent> get events;

  Future<void> initialize();

  Future<void> loadPreset(
    Preset preset, {
    required Map<String, String> assetPaths,
    required int startFadeMs,
    required int endFadeMs,
    required double masterGain01,
  });

  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop({bool graceful = true});

  Future<void> seekToStage(int index);
  Future<void> nextStage();
  Future<void> previousStage();

  Future<void> setMasterGain(double gain01);
  Future<void> setLayerGain(String layerId, double gainDb);
  Future<void> setLayerEnabled(String layerId, bool enabled);

  Future<void> setFrequency(double hz);
  Future<void> setSecondaryFrequency(double hz);

  Future<void> setDroneParameters(DroneLayer d);
  Future<void> setBinauralParameters(BinauralLayer b);
  Future<void> setPulseParameters(PulseLayer p);

  Future<void> setNatureAsset(String? assetId, String? assetPath);
  Future<void> setPadAsset(String? assetId, String? assetPath);
  Future<void> triggerChime(String? assetId, String? assetPath);

  Future<void> setTimer(int seconds);

  Future<void> dispose();
}
