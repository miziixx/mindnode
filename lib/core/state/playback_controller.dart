import 'dart:async';
import 'package:flutter/foundation.dart';

import '../audio/audio_engine_interface.dart';
import '../audio/audio_events.dart';
import '../audio/playback_state.dart';
import '../models/audio_asset.dart';
import '../models/preset.dart';
import '../models/session_record.dart';
import '../data/preset_repository.dart';
import '../data/record_repository.dart';
import '../data/settings_repository.dart';

/// 재생 세션 컨트롤러. UI ↔ 네이티브 오디오 엔진을 동기화한다.
///
/// - 재생 상태 머신으로 중복 재생/유령 재생을 방지한다.
/// - 세션은 프리셋의 **깊은 복제**를 사용해 원본을 덮어쓰지 않는다.
/// - 네이티브 이벤트를 authoritative 로 반영하되, 네이티브 미연결 상황에서도
///   UI가 일관되도록 Dart 측 1초 틱커를 보조 진행 표시로 둔다.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.engine,
    required this.presets,
    required this.records,
    required this.settingsRepo,
  }) {
    _sub = engine.events.listen(_onEvent, onError: (_) {});
  }

  final AudioEngineInterface engine;
  final PresetRepository presets;
  final RecordRepository records;
  final SettingsRepository settingsRepo;

  StreamSubscription<AudioEngineEvent>? _sub;
  Timer? _ticker;

  // --- 세션 상태 ---
  PlaybackState state = PlaybackState.idle;
  Preset? _session; // 편집 가능한 복제본
  Preset? _sourcePreset; // 저장 시 비교용 원본 참조
  bool sessionModified = false;

  int currentStageIndex = 0;
  int _stageElapsedSec = 0;
  int totalRemainingSec = 0;
  int totalDurationSec = 0;
  double progressFraction = 0;
  double masterVolume01 = 0.15;
  bool headphonesConnected = false;
  double sampleRate = 48000;
  String? lastError;
  bool engineReady = false;
  DateTime? _sessionStartedAt;

  Preset? get session => _session;
  Preset? get sourcePreset => _sourcePreset;

  SessionStage? get currentStage {
    final s = _session;
    if (s == null || s.stages.isEmpty) return null;
    return s.stages[currentStageIndex.clamp(0, s.stages.length - 1)];
  }

  int get stageCount => _session?.stages.length ?? 0;
  bool get isSequence => stageCount > 1;

  double? get currentFrequency => currentStage?.displayFrequencyHz;

  bool get isActive => state.isActive;
  bool get isPlaying => state == PlaybackState.playing;

  Future<void> ensureInitialized() async {
    if (!engineReady) {
      await engine.initialize();
    }
  }

  /// assetId -> flutter asset key 맵(네이티브가 PCM 준비에 사용).
  Map<String, String> _assetPathsFor(Preset p) {
    final map = <String, String>{};
    for (final stage in p.stages) {
      for (final id in [
        stage.natureAssetId,
        stage.padAssetId,
        stage.chimeAssetId,
      ]) {
        final meta = AssetCatalog.byId(id);
        if (meta != null) map[meta.id] = meta.assetPath;
      }
    }
    return map;
  }

  /// 프리셋을 세션으로 준비(자동 재생하지 않음). 플레이어 화면 진입 시 호출.
  Future<void> prepareSession(Preset preset) async {
    // 다른 세션이 재생 중이면 부드럽게 정리 후 교체(크로스페이드는 네이티브).
    _ticker?.cancel();
    state = PlaybackState.preparing;
    _session = preset.deepCopy();
    _sourcePreset = preset;
    sessionModified = false;
    currentStageIndex = 0;
    _stageElapsedSec = 0;
    totalDurationSec = _session!.totalDurationSec;
    totalRemainingSec = totalDurationSec;
    progressFraction = 0;
    final settings = settingsRepo.settings;
    masterVolume01 = settings.initialMasterVolumePercent / 100.0;
    notifyListeners();

    await ensureInitialized();
    await engine.loadPreset(
      _session!,
      assetPaths: _assetPathsFor(_session!),
      startFadeMs: settings.startFadeSec * 1000,
      endFadeMs: settings.endFadeSec * 1000,
      masterGain01: masterVolume01,
    );
    state = PlaybackState.ready;
    notifyListeners();
  }

  /// 재생 시작(시작 페이드 적용). 앱 실행 직후 자동 호출 금지.
  Future<void> start() async {
    if (state == PlaybackState.playing) return;
    if (_session == null) return;
    if (state == PlaybackState.paused) {
      return resume();
    }
    _sessionStartedAt = DateTime.now();
    await engine.setMasterGain(masterVolume01);
    await engine.start();
    state = PlaybackState.playing;
    _startTicker();
    notifyListeners();
  }

  Future<void> pause() async {
    if (state != PlaybackState.playing) return;
    await engine.pause();
    state = PlaybackState.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != PlaybackState.paused) return;
    await engine.resume();
    state = PlaybackState.playing;
    _startTicker();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (state == PlaybackState.playing) {
      await pause();
    } else if (state == PlaybackState.paused) {
      await resume();
    } else if (state == PlaybackState.ready ||
        state == PlaybackState.completed) {
      await start();
    }
  }

  /// 천천히 종료(기본 10초 페이드아웃). 종료 후 기록 저장.
  Future<void> stopGraceful() async {
    if (!state.isActive) return;
    state = PlaybackState.fadingOut;
    notifyListeners();
    await engine.stop(graceful: true);
    // 페이드 완료는 네이티브 playbackStateChanged(idle)로 확정되지만,
    // 보조로 기록을 남긴다.
    await _finishSession(completed: false);
  }

  Future<void> stopImmediate() async {
    await engine.stop(graceful: false);
    await _finishSession(completed: false);
  }

  Future<void> nextStage() async {
    if (currentStageIndex >= stageCount - 1) return;
    await engine.nextStage();
    _applyStageIndex(currentStageIndex + 1);
  }

  Future<void> previousStage() async {
    if (currentStageIndex <= 0) return;
    await engine.previousStage();
    _applyStageIndex(currentStageIndex - 1);
  }

  void _applyStageIndex(int i) {
    currentStageIndex = i.clamp(0, stageCount - 1);
    _stageElapsedSec = 0;
    notifyListeners();
  }

  // --- 실시간 파라미터(재생 중 즉시 반영, 저장 전 원본 미변경) ---

  Future<void> setMasterVolume(double v01) async {
    masterVolume01 = v01.clamp(0.0, 1.0);
    await engine.setMasterGain(masterVolume01);
    notifyListeners();
  }

  Future<void> setPrimaryFrequency(double hz) async {
    final st = currentStage;
    if (st == null) return;
    st.primaryTone.frequencyHz = hz;
    _markModified();
    await engine.setFrequency(hz);
    notifyListeners();
  }

  Future<void> setSecondaryFrequency(double hz) async {
    final st = currentStage;
    if (st == null) return;
    st.secondaryTone.frequencyHz = hz;
    _markModified();
    await engine.setSecondaryFrequency(hz);
    notifyListeners();
  }

  Future<void> setLayerEnabled(String layerId, bool enabled) async {
    final st = currentStage;
    if (st == null) return;
    switch (layerId) {
      case 'primary':
        st.primaryTone.enabled = enabled;
        break;
      case 'drone':
        st.drone.enabled = enabled;
        break;
      case 'secondary':
        st.secondaryTone.enabled = enabled;
        break;
      case 'binaural':
        st.binaural.enabled = enabled;
        break;
      case 'pulse':
        st.pulse.enabled = enabled;
        break;
    }
    _markModified();
    await engine.setLayerEnabled(layerId, enabled);
    notifyListeners();
  }

  Future<void> setLayerGainDb(String layerId, double gainDb) async {
    final st = currentStage;
    if (st == null) return;
    switch (layerId) {
      case 'primary':
        st.primaryTone.gainDb = gainDb;
        break;
      case 'drone':
        st.drone.gainDb = gainDb;
        break;
      case 'secondary':
        st.secondaryTone.gainDb = gainDb;
        break;
      case 'binaural':
        st.binaural.gainDb = gainDb;
        break;
      case 'pulse':
        st.pulse.gainDb = gainDb;
        break;
      case 'nature':
      case 'pad':
      case 'chime':
        break;
    }
    _markModified();
    await engine.setLayerGain(layerId, gainDb);
    notifyListeners();
  }

  Future<void> updateDrone() async {
    final st = currentStage;
    if (st == null) return;
    _markModified();
    await engine.setDroneParameters(st.drone);
    notifyListeners();
  }

  Future<void> updateBinaural() async {
    final st = currentStage;
    if (st == null) return;
    _markModified();
    await engine.setBinauralParameters(st.binaural);
    notifyListeners();
  }

  Future<void> updatePulse() async {
    final st = currentStage;
    if (st == null) return;
    _markModified();
    await engine.setPulseParameters(st.pulse);
    notifyListeners();
  }

  Future<void> setNatureAsset(String? assetId) async {
    final st = currentStage;
    if (st == null) return;
    st.natureAssetId = assetId;
    _markModified();
    await engine.setNatureAsset(assetId, AssetCatalog.byId(assetId)?.assetPath);
    notifyListeners();
  }

  Future<void> setPadAsset(String? assetId) async {
    final st = currentStage;
    if (st == null) return;
    st.padAssetId = assetId;
    _markModified();
    await engine.setPadAsset(assetId, AssetCatalog.byId(assetId)?.assetPath);
    notifyListeners();
  }

  Future<void> triggerChimeNow(String? assetId) async {
    await engine.triggerChime(assetId, AssetCatalog.byId(assetId)?.assetPath);
  }

  void _markModified() {
    sessionModified = true;
  }

  // --- 저장 ---

  /// 현재 세션을 새 사용자 프리셋으로 저장.
  Future<Preset> saveAsNewPreset(String title, PresetCategory category) async {
    final p = _session!.deepCopy();
    p.id = 'user_${DateTime.now().millisecondsSinceEpoch}';
    p.title = title;
    p.category = category;
    p.isBuiltIn = false;
    await presets.saveUserPreset(p);
    sessionModified = false;
    return p;
  }

  /// 기본 프리셋 수정본으로 저장(오버라이드).
  Future<void> saveAsBuiltInOverride() async {
    final src = _sourcePreset;
    if (src == null || !src.isBuiltIn) return;
    final p = _session!.deepCopy();
    p.id = src.id;
    p.isBuiltIn = true;
    await presets.saveBuiltInOverride(p);
    sessionModified = false;
  }

  // --- 네이티브 이벤트 ---

  void _onEvent(AudioEngineEvent e) {
    switch (e) {
      case EngineReady(:final sampleRate):
        engineReady = true;
        this.sampleRate = sampleRate;
        notifyListeners();
      case PlaybackStateChanged(:final state):
        this.state = state;
        if (state == PlaybackState.idle || state == PlaybackState.completed) {
          _ticker?.cancel();
        }
        notifyListeners();
      // 시간/단계는 Dart 틱커가 단일 권위로 관리한다(네이티브 이벤트와의 이중
      // 카운팅/이중 단계전환으로 인한 지멋대로 카운터를 방지). 네이티브의 아래
      // 이벤트들은 무시한다.
      case CurrentStageChanged():
        break;
      case ProgressChanged():
        break;
      case RemainingTimeChanged():
        break;
      case RouteChanged(:final headphonesConnected):
        this.headphonesConnected = headphonesConnected;
        // 이어폰 분리 시 기본 일시정지(설정 존중).
        if (!headphonesConnected &&
            settingsRepo.settings.pauseOnHeadphoneUnplug &&
            state == PlaybackState.playing) {
          pause();
        }
        notifyListeners();
      case InterruptionChanged(:final began):
        if (began && state == PlaybackState.playing) {
          pause();
        }
        notifyListeners();
      case SessionCompleted():
        // 네이티브 페이드아웃 완료 통지. Dart 틱커가 이미 완료 처리했으면 무시.
        if (state != PlaybackState.completed && _session != null) {
          _onCompleted();
        }
      case ErrorOccurred(:final code, :final message):
        lastError = '[$code] $message';
        // 비정상 출력 감지 시 안전하게 상태 표기(음소거는 네이티브가 처리).
        notifyListeners();
      case UnderrunDetected():
        // 로그성 이벤트. UI 강제 반응 없음.
        break;
      case ChimeTriggered():
        break;
      case UnknownEvent():
        break;
    }
  }

  Future<void> _onCompleted() async {
    state = PlaybackState.completed;
    _ticker?.cancel();
    await _finishSession(completed: true);
  }

  // --- 진행 틱커(시간·단계·차임의 단일 권위) ---

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state != PlaybackState.playing) return;
      final st = currentStage;
      if (st == null) return;
      _stageElapsedSec++;
      if (totalRemainingSec > 0) totalRemainingSec--;
      if (totalDurationSec > 0) {
        progressFraction =
            1.0 - (totalRemainingSec / totalDurationSec).clamp(0.0, 1.0);
      }
      // 인터벌 차임(스테이지 시작 기준). 종료 시점에는 울리지 않는다.
      if (st.chimeIntervalSec > 0 &&
          _stageElapsedSec > 0 &&
          _stageElapsedSec % st.chimeIntervalSec == 0 &&
          _stageElapsedSec < st.durationSec) {
        triggerChimeNow(st.chimeAssetId);
      }
      if (_stageElapsedSec >= st.durationSec) {
        if (currentStageIndex < stageCount - 1) {
          // 네이티브에 단계 전환을 지시(크로스페이드는 네이티브가 처리).
          currentStageIndex++;
          _stageElapsedSec = 0;
          engine.nextStage();
        } else {
          _completeByTimer();
          return;
        }
      }
      notifyListeners();
    });
  }

  /// 타이머 종료 → 부드러운 페이드아웃 후 완료 처리.
  Future<void> _completeByTimer() async {
    _ticker?.cancel();
    state = PlaybackState.completed;
    totalRemainingSec = 0;
    progressFraction = 1.0;
    notifyListeners();
    await engine.stop(graceful: true); // 종료 페이드
    await _finishSession(completed: true);
  }

  Future<void> _finishSession({required bool completed}) async {
    _ticker?.cancel();
    final s = _session;
    final started = _sessionStartedAt;
    if (s != null && started != null) {
      final played = totalDurationSec - totalRemainingSec;
      final freqs = <double>{};
      for (final stg in s.stages) {
        final f = stg.displayFrequencyHz;
        if (f != null) freqs.add(f);
      }
      final first = s.stages.isNotEmpty ? s.stages.first : null;
      await records.add(SessionRecord(
        id: 'rec_${started.millisecondsSinceEpoch}',
        startedAt: started,
        presetId: _sourcePreset?.id ?? s.id,
        presetTitle: s.title,
        playedSeconds: played.clamp(0, totalDurationSec),
        plannedSeconds: totalDurationSec,
        completed: completed,
        modified: sessionModified,
        frequencies: freqs.toList(),
        natureAssetId: first?.natureAssetId,
        padAssetId: first?.padAssetId,
        chimeAssetId: first?.chimeAssetId,
      ));
    }
    _sessionStartedAt = null;
    if (!completed) {
      state = PlaybackState.idle;
    }
    // 카운터 초기화 — 다음에 다른 프리셋을 틀면 그 프리셋 시간에서 시작하도록.
    currentStageIndex = 0;
    _stageElapsedSec = 0;
    totalRemainingSec = 0;
    totalDurationSec = 0;
    progressFraction = 0;
    sessionModified = false;
    _session = null;
    _sourcePreset = null;
    notifyListeners();
  }

  String formatTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    engine.dispose();
    super.dispose();
  }
}
