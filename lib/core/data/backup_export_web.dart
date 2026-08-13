import 'dart:convert';
import 'dart:html' as html;

/// 백업 JSON을 브라우저 다운로드로 저장한다(웹). shareText는 사용하지 않는다.
Future<void> exportJson(
    String filename, Map<String, dynamic> data, String shareText) async {
  final text = const JsonEncoder.withIndent('  ').convert(data);
  final blob = html.Blob([text], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
