import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 로컬 JSON 파일 저장소. 모든 데이터는 기기에만 저장한다.
class LocalStore {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/mindsound');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> file(String name) async {
    final dir = await _dir();
    return File('${dir.path}/$name');
  }

  static Future<Map<String, dynamic>> readJson(String name) async {
    try {
      final f = await file(name);
      if (!await f.exists()) return {};
      final text = await f.readAsString();
      if (text.trim().isEmpty) return {};
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> writeJson(String name, Map<String, dynamic> data) async {
    final f = await file(name);
    // 원자적 쓰기: 임시 파일에 쓰고 rename.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await tmp.rename(f.path);
  }
}
