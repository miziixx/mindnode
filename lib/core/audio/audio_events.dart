import 'playback_state.dart';

/// 네이티브 → Flutter 이벤트(타입 명확). EventChannel의 Map을 파싱.
sealed class AudioEngineEvent {
  const AudioEngineEvent();

  static AudioEngineEvent parse(Map<Object?, Object?> raw) {
    final map = raw.cast<String, Object?>();
    final type = map['type'] as String? ?? 'unknown';
    switch (type) {
      case 'engineReady':
        return EngineReady(
          sampleRate: (map['sampleRate'] as num?)?.toDouble() ?? 48000,
        );
      case 'playbackStateChanged':
        return PlaybackStateChanged(
          PlaybackStateX.fromString(map['state'] as String? ?? 'idle'),
        );
      case 'currentStageChanged':
        return CurrentStageChanged(
          stageIndex: (map['stageIndex'] as num?)?.toInt() ?? 0,
          stageCount: (map['stageCount'] as num?)?.toInt() ?? 1,
          frequencyHz: (map['frequencyHz'] as num?)?.toDouble(),
          title: map['title'] as String?,
        );
      case 'progressChanged':
        return ProgressChanged(
          fraction: (map['fraction'] as num?)?.toDouble() ?? 0,
        );
      case 'remainingTimeChanged':
        return RemainingTimeChanged(
          remainingSec: (map['remainingSec'] as num?)?.toInt() ?? 0,
          totalSec: (map['totalSec'] as num?)?.toInt() ?? 0,
        );
      case 'routeChanged':
        return RouteChanged(
          reason: map['reason'] as String? ?? 'unknown',
          headphonesConnected: map['headphonesConnected'] as bool? ?? false,
        );
      case 'interruptionChanged':
        return InterruptionChanged(began: map['began'] as bool? ?? false);
      case 'underrunDetected':
        return const UnderrunDetected();
      case 'errorOccurred':
        return ErrorOccurred(
          code: map['code'] as String? ?? 'unknown',
          message: map['message'] as String? ?? '',
        );
      case 'sessionCompleted':
        return const SessionCompleted();
      case 'chimeTriggered':
        return ChimeTriggered(assetId: map['assetId'] as String?);
      default:
        return UnknownEvent(type);
    }
  }
}

class EngineReady extends AudioEngineEvent {
  final double sampleRate;
  const EngineReady({required this.sampleRate});
}

class PlaybackStateChanged extends AudioEngineEvent {
  final PlaybackState state;
  const PlaybackStateChanged(this.state);
}

class CurrentStageChanged extends AudioEngineEvent {
  final int stageIndex;
  final int stageCount;
  final double? frequencyHz;
  final String? title;
  const CurrentStageChanged({
    required this.stageIndex,
    required this.stageCount,
    this.frequencyHz,
    this.title,
  });
}

class ProgressChanged extends AudioEngineEvent {
  final double fraction; // 0..1 전체 진행
  const ProgressChanged({required this.fraction});
}

class RemainingTimeChanged extends AudioEngineEvent {
  final int remainingSec;
  final int totalSec;
  const RemainingTimeChanged({required this.remainingSec, required this.totalSec});
}

class RouteChanged extends AudioEngineEvent {
  final String reason;
  final bool headphonesConnected;
  const RouteChanged({required this.reason, required this.headphonesConnected});
}

class InterruptionChanged extends AudioEngineEvent {
  final bool began;
  const InterruptionChanged({required this.began});
}

class UnderrunDetected extends AudioEngineEvent {
  const UnderrunDetected();
}

class ErrorOccurred extends AudioEngineEvent {
  final String code;
  final String message;
  const ErrorOccurred({required this.code, required this.message});
}

class SessionCompleted extends AudioEngineEvent {
  const SessionCompleted();
}

class ChimeTriggered extends AudioEngineEvent {
  final String? assetId;
  const ChimeTriggered({this.assetId});
}

class UnknownEvent extends AudioEngineEvent {
  final String type;
  const UnknownEvent(this.type);
}
