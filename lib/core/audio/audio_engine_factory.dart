/// 플랫폼별 오디오 엔진 팩토리 선택.
/// - 기본(웹): Web Audio 엔진
/// - dart:io 사용 가능(모바일/데스크톱): 네이티브 엔진
export 'audio_engine_factory_web.dart'
    if (dart.library.io) 'audio_engine_factory_native.dart';
