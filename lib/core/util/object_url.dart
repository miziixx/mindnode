/// 바이트 → 재생 가능한 URL(플랫폼별).
/// - 기본(웹): blob URL 생성
/// - dart:io(모바일/데스크톱): 파일 경로를 직접 쓰므로 null
export 'object_url_web.dart' if (dart.library.io) 'object_url_io.dart';
