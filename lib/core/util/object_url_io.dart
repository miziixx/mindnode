import 'dart:typed_data';

/// 모바일/데스크톱에선 파일 경로를 직접 쓰므로 blob URL이 필요 없다.
String? makeObjectUrl(Uint8List bytes, String mime) => null;
