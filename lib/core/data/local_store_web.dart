import 'dart:convert';
import 'dart:html' as html;

/// 로컬 JSON 저장소(웹). 파일 대신 브라우저 localStorage에 저장한다.
/// 키는 'mindsound/<name>' 형태로 네임스페이스를 준다.
class LocalStore {
  static String _key(String name) => 'mindsound/$name';

  static Future<Map<String, dynamic>> readJson(String name) async {
    try {
      final text = html.window.localStorage[_key(name)];
      if (text == null || text.trim().isEmpty) return {};
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> writeJson(String name, Map<String, dynamic> data) async {
    html.window.localStorage[_key(name)] =
        const JsonEncoder.withIndent('  ').convert(data);
  }
}
