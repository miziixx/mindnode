import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;

import '../audio/audio_engine.dart';
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
class PlaybackController extends ChangeNotifier with WidgetsBindingObserver {
  PlaybackController({
    required this.engine,
    required this.presets,
    required this.records,
    required this.settingsRepo,
  }) {
    _sub = engine.events.listen(_onEvent, onError: (_) {});
    WidgetsBinding.instance.addObserver(this);
  }

  /// 앱이 백그라운드로 갈 때, '백그라운드 재생'이 꺼져 있으면 일시정지한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      if (!settingsRepo.settings.backgroundPlayback &&
          state == PlaybackState.playing) {
        pause();
      }
    }
  }

  final AudioEngine engine;
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

  // 수면 타이머(0 = 꺼짐). 남은 시간이 0에 도달하면 부드럽게 종료.
  int sleepRemainingSec = 0;
  int sleepTimerSetMinutes = 0; // UI 선택 표시용(원래 설정값)
  // 세션 반복. 몇 번째 반복인지 추적(0-based 완료 횟수).
  int _repeatsDone = 0;
  // 사용자 배경 음악(엔진과 별개 스트림). 파일 경로/이름/음량.
  AudioPlayer? _music;
  String? backgroundMusicPath;
  String? backgroundMusicName;
  double musicVolume01 = 0.6;
  // 청력 배려: 큰 음량으로 오래 들으면 1회 안내.
  int _playingElapsedSec = 0;
  bool _hearingNudged = false;
  bool hearingNudgeActive = false;
  static const int _hearingNudgeAfterSec = 3600; // 60분
  static const double _hearingNudgeVolume = 0.5; // 50% 이상

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

  // 반복 관련.
  int get repeatCount => _session?.repeatCount ?? 1;
  bool get isRepeatInfinite => repeatCount == 0;
  int get currentRepeat => _repeatsDone + 1; // 1-based 표시용
  bool get hasBackgroundMusic => backgroundMusicPath != null;

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
    _playingElapsedSec = 0;
    _repeatsDone = 0;
    sleepRemainingSec = 0;
    sleepTimerSetMinutes = 0;
    _hearingNudged = false;
    hearingNudgeActive = false;
    _musicPause();
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
    await _musicResume();
    state = PlaybackState.playing;
    _startTicker();
    notifyListeners();
  }

  Future<void> pause() async {
    if (state != PlaybackState.playing) return;
    await engine.pause();
    await _musicPause();
    state = PlaybackState.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != PlaybackState.paused) return;
    await engine.resume();
    await _musicResume();
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

  /// 단일 단계 세션인지(재생 길이를 통째로 조정 가능한지).
  /// 시퀀스(다단계)는 스튜디오에서 단계별로 시간을 조정한다.
  bool get canAdjustDuration => (_session?.stages.length ?? 0) == 1;

  /// 현재 세션의 전체 재생 길이(분, 반올림).
  int get sessionDurationMinutes =>
      _session == null ? 0 : (totalDurationSec / 60).round();

  /// 단일 단계 세션의 재생 길이(분)를 조정한다. 준비/재생 중 모두 즉시 반영.
  /// 세션은 원본 프리셋의 복제본이라 원본은 바뀌지 않는다.
  void setSessionDurationMinutes(int minutes) {
    final s = _session;
    if (s == null || s.stages.length != 1) return;
    final newSec = minutes.clamp(1, 180) * 60;
    // 단일 단계에선 (전체 길이 - 남은 시간) == 지금까지 흐른 시간.
    final elapsed = (totalDurationSec - totalRemainingSec).clamp(0, newSec);
    s.stages.first.durationSec = newSec;
    totalDurationSec = s.totalDurationSec;
    totalRemainingSec = (totalDurationSec - elapsed).clamp(0, totalDurationSec);
    if (totalDurationSec > 0) {
      progressFraction =
          1.0 - (totalRemainingSec / totalDurationSec).clamp(0.0, 1.0);
    }
    _markModified();
    notifyListeners();
  }

  /// 세션 반복 횟수 설정. 1=한 번, 0=무한 반복. 재생 중에도 즉시 반영.
  void setRepeatCount(int count) {
    final s = _session;
    if (s == null) return;
    s.repeatCount = count < 0 ? 0 : count;
    _markModified();
    notifyListeners();
  }

  /// 사용자가 고른 배경 음악을 설정하고 바로 재생을 시작한다.
  /// [isUrl]이 true면 URL(웹 blob 등), false면 로컬 파일 경로로 취급한다.
  /// 성공 시 null, 실패 시 오류 메시지를 반환한다(UI에서 표시용).
  Future<String?> setBackgroundMusic(String path, String name,
      {bool isUrl = false}) async {
    backgroundMusicPath = path;
    backgroundMusicName = name;
    _music ??= AudioPlayer();
    try {
      await _music!.setReleaseMode(ReleaseMode.loop);
      await _music!.setVolume(musicVolume01);
      // play()로 즉시 재생 — 파일 선택(사용자 제스처) 직후라 웹 자동재생 정책 통과.
      await _music!.play(isUrl ? UrlSource(path) : DeviceFileSource(path));
      lastError = null;
      notifyListeners();
      return null;
    } catch (e) {
      lastError = 'music: $e';
      notifyListeners();
      return '$e';
    }
  }

  /// 배경 음악 음량(0..1).
  Future<void> setMusicVolume(double v01) async {
    musicVolume01 = v01.clamp(0.0, 1.0);
    try {
      await _music?.setVolume(musicVolume01);
    } catch (_) {}
    notifyListeners();
  }

  /// 배경 음악 제거.
  Future<void> clearBackgroundMusic() async {
    backgroundMusicPath = null;
    backgroundMusicName = null;
    try {
      await _music?.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _musicResume() async {
    if (backgroundMusicPath == null) return;
    try {
      await _music?.resume();
    } catch (_) {}
  }

  Future<void> _musicPause() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> _musicStop() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  /// 수면 타이머 설정(분). 0이면 끔. 재생 중 카운트다운, 0에서 부드럽게 종료.
  void setSleepTimerMinutes(int minutes) {
    sleepTimerSetMinutes = minutes <= 0 ? 0 : minutes;
    sleepRemainingSec = minutes <= 0 ? 0 : minutes * 60;
    notifyListeners();
  }

  /// 청력 안내 배너 닫기.
  void dismissHearingNudge() {
    hearingNudgeActive = false;
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

      // 수면 타이머(프리셋 길이와 무관하게 우선 종료).
      if (sleepRemainingSec > 0) {
        sleepRemainingSec--;
        if (sleepRemainingSec <= 0) {
          _completeByTimer();
          return;
        }
      }
      // 청력 배려: 큰 음량 장시간 재생 시 1회 안내.
      _playingElapsedSec++;
      if (!_hearingNudged &&
          _playingElapsedSec >= _hearingNudgeAfterSec &&
          masterVolume01 >= _hearingNudgeVolume) {
        _hearingNudged = true;
        hearingNudgeActive = true;
      }

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
        } else if (_shouldRepeat()) {
          // 반복: 정지 없이 처음으로 되감아 계속 재생.
          _loopToStart();
        } else {
          _completeByTimer();
          return;
        }
      }
      notifyListeners();
    });
  }

  /// 아직 반복이 남았는지. repeatCount 0이면 무한.
  bool _shouldRepeat() {
    final rc = _session?.repeatCount ?? 1;
    if (rc == 0) return true;
    return _repeatsDone + 1 < rc;
  }

  /// 세션을 처음으로 되감아 반복 재생(오디오는 끊지 않는다).
  void _loopToStart() {
    _repeatsDone++;
    currentStageIndex = 0;
    _stageElapsedSec = 0;
    totalRemainingSec = totalDurationSec;
    progressFraction = 0;
    if (stageCount > 1) engine.seekToStage(0);
    notifyListeners();
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
    await _musicStop();
    if (!completed) {
      state = PlaybackState.idle;
    }
    // 카운터 초기화 — 다음에 다른 프리셋을 틀면 그 프리셋 시간에서 시작하도록.
    currentStageIndex = 0;
    _stageElapsedSec = 0;
    _playingElapsedSec = 0;
    _repeatsDone = 0;
    sleepRemainingSec = 0;
    sleepTimerSetMinutes = 0;
    _hearingNudged = false;
    hearingNudgeActive = false;
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
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _sub?.cancel();
    _music?.dispose();
    engine.dispose();
    super.dispose();
  }
}
