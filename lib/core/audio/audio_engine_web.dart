import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:web_audio' as wa;

import '../models/layers.dart';
import '../models/preset.dart';
import 'audio_engine.dart';
import 'audio_events.dart';
import 'playback_state.dart';

/// Web Audio API 기반 오디오 엔진(웹 전용).
///
/// 네이티브 DSP와 동일한 레이어 구성을 브라우저에서 합성한다:
/// primary/secondary 톤 · 드론(sub/main/air) · 바이노럴(L/R) · 펄스(트레몰로)
/// · 자연음/패드(루프 버퍼) · 차임(원샷). 시간 진행/반복은 Dart 컨트롤러가 관리.
class WebAudioEngine implements AudioEngine {
  final _eventCtrl = StreamController<AudioEngineEvent>.broadcast();
  @override
  Stream<AudioEngineEvent> get events => _eventCtrl.stream;

  wa.AudioContext? _ctx;
  wa.GainNode? _master;
  double _masterTarget = 0.15;
  int _startFadeMs = 5000;
  int _endFadeMs = 10000;
  bool _playing = false;
  bool _hooksAttached = false;

  Preset? _preset;
  int _stageIndex = 0;
  Map<String, String> _assetPaths = const {};

  // 현재 스테이지의 활성 소스 노드들(스테이지 교체/정지 시 정리).
  final List<wa.AudioNode> _sources = [];
  final Map<String, wa.GainNode> _layerGains = {}; // layerId -> gain
  final Map<String, double> _layerTargetGain = {}; // 활성 시 목표 선형 게인

  double _dbToLin(double db) => math.pow(10, db / 20).toDouble();
  double get _now => _ctx?.currentTime?.toDouble() ?? 0.0;

  @override
  Future<void> initialize() async {
    final ctx = _ctx ??= wa.AudioContext();
    if (_master == null) {
      final m = ctx.createGain();
      m.gain!.value = 0;
      m.connectNode(ctx.destination!);
      _master = m;
    }
    _attachResumeHooks();
    _eventCtrl
        .add(EngineReady(sampleRate: ctx.sampleRate?.toDouble() ?? 48000));
  }

  /// iOS 사파리 등은 다른 앱으로 가면 AudioContext를 강제로 suspend 한다.
  /// 페이지로 돌아오거나(가시성 복귀) 화면을 탭할 때 자동으로 재개한다.
  void _attachResumeHooks() {
    if (_hooksAttached) return;
    _hooksAttached = true;
    void resumeIfNeeded() {
      final c = _ctx;
      if (c == null) return;
      if (_playing && c.state == 'suspended') {
        try {
          c.resume();
        } catch (_) {}
      }
    }

    html.document.addEventListener('visibilitychange', (_) {
      if (html.document.visibilityState == 'visible') resumeIfNeeded();
    });
    html.window.addEventListener('focus', (_) => resumeIfNeeded());
    // 어떤 탭/터치든 suspended 상태면 해제(사용자 제스처 컨텍스트에서만 허용됨).
    for (final ev in const ['pointerdown', 'touchend', 'click']) {
      html.document.addEventListener(ev, (_) => resumeIfNeeded());
    }
  }

  @override
  Future<void> loadPreset(
    Preset preset, {
    required Map<String, String> assetPaths,
    required int startFadeMs,
    required int endFadeMs,
    required double masterGain01,
  }) async {
    await initialize();
    _preset = preset;
    _assetPaths = assetPaths;
    _startFadeMs = startFadeMs;
    _endFadeMs = endFadeMs;
    _masterTarget = masterGain01;
    _stageIndex = 0;
    _buildStage(0);
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.ready));
  }

  SessionStage? get _stage {
    final p = _preset;
    if (p == null || p.stages.isEmpty) return null;
    return p.stages[_stageIndex.clamp(0, p.stages.length - 1)];
  }

  void _teardownStage() {
    for (final s in _sources) {
      _stopNode(s);
      try {
        s.disconnect();
      } catch (_) {}
    }
    _sources.clear();
    _layerGains.clear();
    _layerTargetGain.clear();
  }

  // --- 노드 생성 헬퍼 ---
  wa.GainNode _gain(double value) {
    final g = _ctx!.createGain();
    g.gain!.value = value;
    return g;
  }

  wa.StereoPannerNode _panner(double pan) {
    final p = _ctx!.createStereoPanner();
    p.pan!.value = pan.clamp(-1.0, 1.0);
    return p;
  }

  /// 오실레이터를 만들고 즉시 start + 추적한다(연결은 호출측에서).
  wa.OscillatorNode _osc(double hz) {
    final o = _ctx!.createOscillator();
    o.type = 'sine';
    o.frequency!.value = hz.clamp(FreqLimits.min, FreqLimits.maxAbsolute);
    _startNode(o);
    _sources.add(o);
    return o;
  }

  // dart:web_audio 바인딩에 start/stop이 노출되지 않는 경우가 있어,
  // JS 메서드를 이름으로 직접 호출한다(런타임 JS 노드엔 항상 존재).
  void _startNode(wa.AudioNode n) {
    try {
      js_util.callMethod(n, 'start', const []);
    } catch (_) {}
  }

  void _stopNode(wa.AudioNode n) {
    try {
      js_util.callMethod(n, 'stop', const []);
    } catch (_) {}
  }

  /// 스테이지의 모든 레이어 노드를 새로 구성한다.
  void _buildStage(int index) {
    final p = _preset;
    final ctx = _ctx;
    final master = _master;
    if (p == null || ctx == null || master == null) return;
    _teardownStage();
    _stageIndex = index.clamp(0, p.stages.length - 1);
    final st = p.stages[_stageIndex];

    _buildTone('primary', st.primaryTone, master);
    _buildTone('secondary', st.secondaryTone, master);

    // drone (sub/main/air)
    {
      final d = st.drone;
      final target = _dbToLin(d.gainDb);
      final g = _gain(d.enabled ? target : 0.0);
      g.connectNode(master);
      _layerGains['drone'] = g;
      _layerTargetGain['drone'] = target;
      final voices = <List<double>>[
        [d.subHz, d.subVoiceRatio],
        [d.mainHz, d.mainVoiceRatio],
        [d.airHz, d.airVoiceRatio],
      ];
      for (final v in voices) {
        final vg = _gain(v[1]);
        vg.connectNode(g);
        _osc(v[0]).connectNode(vg);
      }
    }

    // binaural (L/R)
    {
      final b = st.binaural;
      final target = _dbToLin(b.gainDb);
      final g = _gain(b.enabled ? target : 0.0);
      g.connectNode(master);
      _layerGains['binaural'] = g;
      _layerTargetGain['binaural'] = target;
      final pL = _panner(-1)..connectNode(g);
      final pR = _panner(1)..connectNode(g);
      _osc(b.leftHz).connectNode(pL);
      _osc(b.rightHz).connectNode(pR);
    }

    // pulse (트레몰로)
    {
      final pl = st.pulse;
      final base = _dbToLin(pl.gainDb);
      final baseline = base * (1 - pl.depth / 2);
      final g = _gain(pl.enabled ? baseline : 0.0);
      g.connectNode(master);
      _layerGains['pulse'] = g;
      _layerTargetGain['pulse'] = baseline;
      _osc(pl.frequencyHz).connectNode(g);
      // LFO로 게인 변조.
      final lfoDepth = _gain(base * (pl.depth / 2));
      lfoDepth.connectParam(g.gain!);
      final lfo = _ctx!.createOscillator();
      lfo.type = 'sine';
      lfo.frequency!.value = pl.rateHz.clamp(0.1, 20);
      _startNode(lfo);
      _sources.add(lfo);
      lfo.connectNode(lfoDepth);
    }

    // 음원(자연음/패드) 루프
    final natureGain = _gain(0.5)..connectNode(master);
    final padGain = _gain(0.4)..connectNode(master);
    _loadLoop(st.natureAssetId, natureGain);
    _loadLoop(st.padAssetId, padGain);
  }

  void _buildTone(String id, ToneLayer t, wa.GainNode master) {
    final target = _dbToLin(t.gainDb);
    final g = _gain(t.enabled ? target : 0.0);
    final p = _panner(t.pan)..connectNode(master);
    g.connectNode(p);
    _layerGains[id] = g;
    _layerTargetGain[id] = target;
    _osc(t.frequencyHz).connectNode(g);
  }

  Future<void> _loadLoop(String? assetId, wa.GainNode dest) async {
    if (assetId == null) return;
    final path = _assetPaths[assetId];
    final ctx = _ctx;
    if (path == null || ctx == null) return;
    try {
      final req =
          await html.HttpRequest.request(path, responseType: 'arraybuffer');
      final buf = await ctx.decodeAudioData(req.response);
      final src = ctx.createBufferSource();
      src.buffer = buf;
      src.loop = true;
      src.connectNode(dest);
      _startNode(src);
      _sources.add(src);
    } catch (_) {
      // 음원 로드 실패는 무시(합성 톤은 계속 재생).
    }
  }

  @override
  Future<void> start() async {
    final ctx = _ctx;
    final master = _master;
    if (ctx == null || master == null) return;
    await ctx.resume();
    _playing = true;
    final now = _now;
    final g = master.gain!;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value ?? 0, now);
    g.linearRampToValueAtTime(_masterTarget, now + _startFadeMs / 1000.0);
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.playing));
  }

  @override
  Future<void> pause() async {
    _playing = false;
    await _ctx?.suspend();
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.paused));
  }

  @override
  Future<void> resume() async {
    await _ctx?.resume();
    _playing = true;
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.playing));
  }

  @override
  Future<void> stop({bool graceful = true}) async {
    final master = _master;
    if (master == null) return;
    final fade = graceful ? _endFadeMs / 1000.0 : 0.02;
    final now = _now;
    final g = master.gain!;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value ?? _masterTarget, now);
    g.linearRampToValueAtTime(0, now + fade);
    _playing = false;
    Future.delayed(Duration(milliseconds: (fade * 1000).round() + 60), () {
      _teardownStage();
      _ctx?.suspend();
    });
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.idle));
  }

  @override
  Future<void> seekToStage(int index) async => _buildStage(index);

  @override
  Future<void> nextStage() => seekToStage(_stageIndex + 1);

  @override
  Future<void> previousStage() => seekToStage(_stageIndex - 1);

  @override
  Future<void> setMasterGain(double gain01) async {
    _masterTarget = gain01.clamp(0.0, 1.0);
    final master = _master;
    if (master == null || !_playing) return;
    final now = _now;
    final g = master.gain!;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value ?? 0, now);
    g.linearRampToValueAtTime(_masterTarget, now + 0.05);
  }

  void _rampLayerGain(String layerId, double target) {
    final gn = _layerGains[layerId];
    if (gn == null) return;
    final now = _now;
    final g = gn.gain!;
    g.cancelScheduledValues(now);
    g.setValueAtTime(g.value ?? 0, now);
    g.linearRampToValueAtTime(target, now + 0.03);
  }

  @override
  Future<void> setLayerGain(String layerId, double gainDb) async {
    final target = _dbToLin(gainDb);
    _layerTargetGain[layerId] = target;
    _rampLayerGain(layerId, target);
  }

  @override
  Future<void> setLayerEnabled(String layerId, bool enabled) async {
    _rampLayerGain(layerId, enabled ? (_layerTargetGain[layerId] ?? 0) : 0);
  }

  @override
  Future<void> setFrequency(double hz) async => _setToneFreq('primary', hz);

  @override
  Future<void> setSecondaryFrequency(double hz) async =>
      _setToneFreq('secondary', hz);

  void _setToneFreq(String id, double hz) {
    final st = _stage;
    if (st == null) return;
    if (id == 'primary') {
      st.primaryTone.frequencyHz = hz;
    } else {
      st.secondaryTone.frequencyHz = hz;
    }
    _buildStage(_stageIndex);
  }

  @override
  Future<void> setDroneParameters(DroneLayer d) async =>
      _buildStage(_stageIndex);

  @override
  Future<void> setBinauralParameters(BinauralLayer b) async =>
      _buildStage(_stageIndex);

  @override
  Future<void> setPulseParameters(PulseLayer p) async =>
      _buildStage(_stageIndex);

  @override
  Future<void> setNatureAsset(String? assetId, String? assetPath) async {
    if (assetPath != null && assetId != null) {
      _assetPaths = {..._assetPaths, assetId: assetPath};
    }
    final st = _stage;
    if (st != null) st.natureAssetId = assetId;
    _buildStage(_stageIndex);
  }

  @override
  Future<void> setPadAsset(String? assetId, String? assetPath) async {
    if (assetPath != null && assetId != null) {
      _assetPaths = {..._assetPaths, assetId: assetPath};
    }
    final st = _stage;
    if (st != null) st.padAssetId = assetId;
    _buildStage(_stageIndex);
  }

  @override
  Future<void> triggerChime(String? assetId, String? assetPath) async {
    final ctx = _ctx;
    final master = _master;
    final path = assetPath ?? (assetId != null ? _assetPaths[assetId] : null);
    if (ctx == null || master == null || path == null) return;
    try {
      final req =
          await html.HttpRequest.request(path, responseType: 'arraybuffer');
      final buf = await ctx.decodeAudioData(req.response);
      final g = _gain(0.7)..connectNode(master);
      final src = ctx.createBufferSource();
      src.buffer = buf;
      src.connectNode(g);
      _startNode(src);
    } catch (_) {}
  }

  @override
  Future<void> setTimer(int seconds) async {
    // 타이머/종료는 Dart 컨트롤러가 관리하므로 웹 엔진은 별도 처리 없음.
  }

  @override
  Future<void> dispose() async {
    _teardownStage();
    try {
      await _ctx?.close();
    } catch (_) {}
    _ctx = null;
    _master = null;
    await _eventCtrl.close();
  }
}
