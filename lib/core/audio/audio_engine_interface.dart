import 'dart:async';
import 'package:flutter/services.dart';

import '../models/preset.dart';
import '../models/layers.dart';
import 'audio_engine.dart';
import 'audio_events.dart';

/// Flutter ↔ 네이티브 오디오 엔진 브리지(타입 명확한 채널 인터페이스).
///
/// Flutter는 오디오 샘플을 직접 생성/전달하지 않는다. 명령과 파라미터만 보낸다.
/// 슬라이더는 목표값만 보내고, 실제 부드러운 램프는 네이티브 엔진이 담당한다.
class AudioEngineInterface implements AudioEngine {
  static const MethodChannel _method =
      MethodChannel('com.mindsound.app/audio');
  static const EventChannel _events =
      EventChannel('com.mindsound.app/audio_events');

  Stream<AudioEngineEvent>? _eventStream;

  /// 네이티브 이벤트 스트림(engineReady, playbackStateChanged 등).
  Stream<AudioEngineEvent> get events {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .map((e) => AudioEngineEvent.parse(e as Map<Object?, Object?>));
    return _eventStream!;
  }

  Future<void> initialize() => _method.invokeMethod('initialize');

  /// 프리셋 전체를 네이티브로 로드. 자산 경로 목록도 함께 전달해
  /// 네이티브가 백그라운드 스레드에서 PCM 버퍼를 준비한다.
  Future<void> loadPreset(
    Preset preset, {
    required Map<String, String> assetPaths, // assetId -> flutter asset key
    required int startFadeMs,
    required int endFadeMs,
    required double masterGain01,
  }) {
    return _method.invokeMethod('loadPreset', {
      'preset': preset.toJson(),
      'assetPaths': assetPaths,
      'startFadeMs': startFadeMs,
      'endFadeMs': endFadeMs,
      'masterGain01': masterGain01,
    });
  }

  Future<void> start() => _method.invokeMethod('start');
  Future<void> pause() => _method.invokeMethod('pause');
  Future<void> resume() => _method.invokeMethod('resume');

  /// 종료. graceful=true면 fadeOut 후 정지(기본 10초), false면 즉시.
  Future<void> stop({bool graceful = true}) =>
      _method.invokeMethod('stop', {'graceful': graceful});

  Future<void> seekToStage(int index) =>
      _method.invokeMethod('seekToStage', {'index': index});
  Future<void> nextStage() => _method.invokeMethod('nextStage');
  Future<void> previousStage() => _method.invokeMethod('previousStage');

  /// 0..1 상대 마스터 음량(내부 dBFS로 매핑). 램프 적용은 네이티브.
  Future<void> setMasterGain(double gain01) =>
      _method.invokeMethod('setMasterGain', {'gain01': gain01});

  Future<void> setLayerGain(String layerId, double gainDb) =>
      _method.invokeMethod('setLayerGain', {'layerId': layerId, 'gainDb': gainDb});

  Future<void> setLayerEnabled(String layerId, bool enabled) =>
      _method.invokeMethod(
          'setLayerEnabled', {'layerId': layerId, 'enabled': enabled});

  /// 재생 중 주파수 변경(30ms 램프는 네이티브가 처리, 클릭 없음).
  Future<void> setFrequency(double hz) =>
      _method.invokeMethod('setFrequency', {'hz': hz});

  Future<void> setSecondaryFrequency(double hz) =>
      _method.invokeMethod('setSecondaryFrequency', {'hz': hz});

  Future<void> setDroneParameters(DroneLayer d) =>
      _method.invokeMethod('setDroneParameters', d.toJson());

  Future<void> setBinauralParameters(BinauralLayer b) =>
      _method.invokeMethod('setBinauralParameters', b.toJson());

  Future<void> setPulseParameters(PulseLayer p) =>
      _method.invokeMethod('setPulseParameters', p.toJson());

  Future<void> setNatureAsset(String? assetId, String? assetPath) =>
      _method.invokeMethod(
          'setNatureAsset', {'assetId': assetId, 'assetPath': assetPath});

  Future<void> setPadAsset(String? assetId, String? assetPath) =>
      _method.invokeMethod(
          'setPadAsset', {'assetId': assetId, 'assetPath': assetPath});

  Future<void> triggerChime(String? assetId, String? assetPath) =>
      _method.invokeMethod(
          'triggerChime', {'assetId': assetId, 'assetPath': assetPath});

  Future<void> setTimer(int seconds) =>
      _method.invokeMethod('setTimer', {'seconds': seconds});

  Future<void> dispose() => _method.invokeMethod('dispose');
}
