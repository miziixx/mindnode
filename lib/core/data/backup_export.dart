/// 백업 내보내기(플랫폼별).
/// - 기본(웹): 브라우저 다운로드
/// - dart:io 사용 가능(모바일/데스크톱): 임시 파일 + 공유 시트
export 'backup_export_web.dart'
    if (dart.library.io) 'backup_export_io.dart';
