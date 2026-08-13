import 'audio_engine.dart';
import 'audio_engine_web.dart';

/// 웹(Web Audio) 엔진 생성.
AudioEngine createAudioEngine() => WebAudioEngine();
