import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 백업 JSON을 임시 파일로 쓰고 공유 시트로 내보낸다(모바일/데스크톱).
Future<void> exportJson(
    String filename, Map<String, dynamic> data, String shareText) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  await Share.shareXFiles([XFile(f.path)], text: shareText);
}
