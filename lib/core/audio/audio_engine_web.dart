import 'dart:async';
import 'dart:html' as html;
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

  Preset? _preset;
  int _stageIndex = 0;
  Map<String, String> _assetPaths = const {};

  // 현재 스테이지의 활성 노드들(스테이지 교체/정지 시 정리).
  final List<wa.AudioScheduledSourceNode> _sources = [];
  final Map<String, wa.GainNode> _layerGains = {}; // layerId -> gain
  final Map<String, double> _layerTargetGain = {}; // 활성 시 목표 선형 게인
  wa.GainNode? _natureGain;
  wa.GainNode? _padGain;

  double _dbToLin(double db) => math.pow(10, db / 20).toDouble();
  double get _now => _ctx?.currentTime?.toDouble() ?? 0.0;

  @override
  Future<void> initialize() async {
    _ctx ??= wa.AudioContext();
    _master ??= _ctx!.createGain()
      ..gain!.value = 0
      ..connectNode(_ctx!.destination!);
    _eventCtrl.add(EngineReady(
        sampleRate: _ctx!.sampleRate?.toDouble() ?? 48000));
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
      try {
        s.stop();
      } catch (_) {}
      try {
        s.disconnect();
      } catch (_) {}
    }
    _sources.clear();
    _layerGains.clear();
    _layerTargetGain.clear();
    _natureGain = null;
    _padGain = null;
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

    wa.OscillatorNode osc(double hz) {
      final o = ctx.createOscillator()
        ..type = 'sine'
        ..frequency!.value = hz.clamp(FreqLimits.min, FreqLimits.maxAbsolute);
      return o;
    }

    wa.StereoPannerNode panner(double pan) =>
        ctx.createStereoPanner()..pan!.value = pan.clamp(-1.0, 1.0);

    void startAll(List<wa.AudioScheduledSourceNode> nodes) {
      for (final n in nodes) {
        try {
          n.start();
        } catch (_) {}
        _sources.add(n);
      }
    }

    // primary tone
    _buildTone('primary', st.primaryTone, osc, panner, startAll, ctx, master);
    // secondary tone
    _buildTone(
        'secondary', st.secondaryTone, osc, panner, startAll, ctx, master);

    // drone (sub/main/air)
    {
      final d = st.drone;
      final g = ctx.createGain()
        ..gain!.value = d.enabled ? _dbToLin(d.gainDb) : 0.0
        ..connectNode(master);
      _layerGains['drone'] = g;
      _layerTargetGain['drone'] = _dbToLin(d.gainDb);
      final voices = <(double, double)>[
        (d.subHz, d.subVoiceRatio),
        (d.mainHz, d.mainVoiceRatio),
        (d.airHz, d.airVoiceRatio),
      ];
      for (final v in voices) {
        final vg = ctx.createGain()..gain!.value = v.$2;
        final o = osc(v.$1)..connectNode(vg);
        vg.connectNode(g);
        startAll([o]);
      }
    }

    // binaural (L/R)
    {
      final b = st.binaural;
      final g = ctx.createGain()
        ..gain!.value = b.enabled ? _dbToLin(b.gainDb) : 0.0
        ..connectNode(master);
      _layerGains['binaural'] = g;
      _layerTargetGain['binaural'] = _dbToLin(b.gainDb);
      final oL = osc(b.leftHz)..connectNode(panner(-1)..connectNode(g));
      final oR = osc(b.rightHz)..connectNode(panner(1)..connectNode(g));
      startAll([oL, oR]);
    }

    // pulse (tremolo)
    {
      final pl = st.pulse;
      final base = _dbToLin(pl.gainDb);
      final g = ctx.createGain()
        ..gain!.value = pl.enabled ? base * (1 - pl.depth / 2) : 0.0
        ..connectNode(master);
      _layerGains['pulse'] = g;
      _layerTargetGain['pulse'] = base * (1 - pl.depth / 2);
      final o = osc(pl.frequencyHz)..connectNode(g);
      startAll([o]);
      // LFO로 게인 변조.
      final lfo = ctx.createOscillator()
        ..type = 'sine'
        ..frequency!.value = pl.rateHz.clamp(0.1, 20);
      final lfoDepth = ctx.createGain()..gain!.value = base * (pl.depth / 2);
      lfo.connectNode(lfoDepth);
      lfoDepth.connectParam(g.gain!);
      startAll([lfo]);
    }

    // 음원(자연음/패드) 루프 로드
    _natureGain = ctx.createGain()
      ..gain!.value = 0.5
      ..connectNode(master);
    _padGain = ctx.createGain()
      ..gain!.value = 0.4
      ..connectNode(master);
    _loadLoop(st.natureAssetId, _natureGain!);
    _loadLoop(st.padAssetId, _padGain!);
  }

  void _buildTone(
    String id,
    ToneLayer t,
    wa.OscillatorNode Function(double) osc,
    wa.StereoPannerNode Function(double) panner,
    void Function(List<wa.AudioScheduledSourceNode>) startAll,
    wa.AudioContext ctx,
    wa.GainNode master,
  ) {
    final g = ctx.createGain()
      ..gain!.value = t.enabled ? _dbToLin(t.gainDb) : 0.0;
    final p = panner(t.pan)..connectNode(master);
    g.connectNode(p);
    _layerGains[id] = g;
    _layerTargetGain[id] = _dbToLin(t.gainDb);
    final o = osc(t.frequencyHz)..connectNode(g);
    startAll([o]);
  }

  Future<void> _loadLoop(String? assetId, wa.GainNode dest) async {
    if (assetId == null) return;
    final path = _assetPaths[assetId];
    final ctx = _ctx;
    if (path == null || ctx == null) return;
    try {
      final req = await html.HttpRequest.request(path,
          responseType: 'arraybuffer');
      final buf = await ctx.decodeAudioData(req.response);
      final src = ctx.createBufferSource()
        ..buffer = buf
        ..loop = true
        ..connectNode(dest);
      src.start();
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
    master.gain!
      ..cancelScheduledValues(now)
      ..setValueAtTime(master.gain!.value ?? 0, now)
      ..linearRampToValueAtTime(_masterTarget, now + _startFadeMs / 1000.0);
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
    master.gain!
      ..cancelScheduledValues(now)
      ..setValueAtTime(master.gain!.value ?? _masterTarget, now)
      ..linearRampToValueAtTime(0, now + fade);
    _playing = false;
    // 페이드 후 소스 정리.
    Future.delayed(Duration(milliseconds: (fade * 1000).round() + 60), () {
      _teardownStage();
      _ctx?.suspend();
    });
    _eventCtrl.add(const PlaybackStateChanged(PlaybackState.idle));
  }

  @override
  Future<void> seekToStage(int index) async {
    _buildStage(index);
    // 재생 중이면 새 스테이지 노드가 이미 start 됨(마스터 게인 유지).
  }

  @override
  Future<void> nextStage() => seekToStage(_stageIndex + 1);

  @override
  Future<void> previousStage() => seekToStage(_stageIndex - 1);

  @override
  Future<void> setMasterGain(double gain01) async {
    _masterTarget = gain01.clamp(0.0, 1.0);
    final master = _master;
    if (master == null) return;
    final now = _now;
    if (_playing) {
      master.gain!
        ..cancelScheduledValues(now)
        ..setValueAtTime(master.gain!.value ?? 0, now)
        ..linearRampToValueAtTime(_masterTarget, now + 0.05);
    }
  }

  void _rampLayerGain(String layerId, double target) {
    final g = _layerGains[layerId];
    if (g == null) return;
    final now = _now;
    g.gain!
      ..cancelScheduledValues(now)
      ..setValueAtTime(g.gain!.value ?? 0, now)
      ..linearRampToValueAtTime(target, now + 0.03);
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
    // 톤 오실레이터는 게인 노드에 연결돼 있으나, 여기선 스테이지 재구성 없이
    // 주파수만 갱신하기 위해 별도 추적이 필요하므로 스테이지를 다시 만든다.
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
  Future<void> setDroneParameters(DroneLayer d) async => _buildStage(_stageIndex);

  @override
  Future<void> setBinauralParameters(BinauralLayer b) async =>
      _buildStage(_stageIndex);

  @override
  Future<void> setPulseParameters(PulseLayer p) async => _buildStage(_stageIndex);

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
      final req = await html.HttpRequest.request(path,
          responseType: 'arraybuffer');
      final buf = await ctx.decodeAudioData(req.response);
      final g = ctx.createGain()
        ..gain!.value = 0.7
        ..connectNode(master);
      final src = ctx.createBufferSource()
        ..buffer = buf
        ..connectNode(g);
      src.start();
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
