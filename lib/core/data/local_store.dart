/// 플랫폼별 로컬 저장소 선택.
/// - 기본(웹): localStorage 기반 `local_store_web.dart`
/// - dart:io 사용 가능(모바일/데스크톱): 파일 기반 `local_store_io.dart`
export 'local_store_web.dart' if (dart.library.io) 'local_store_io.dart';
