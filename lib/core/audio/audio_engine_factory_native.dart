import 'audio_engine.dart';
import 'audio_engine_interface.dart';

/// 네이티브(모바일/데스크톱) 엔진 생성.
AudioEngine createAudioEngine() => AudioEngineInterface();
