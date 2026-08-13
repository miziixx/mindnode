import 'dart:html' as html;
import 'dart:typed_data';

/// 바이트에서 브라우저 blob URL을 만든다(웹). audioplayers UrlSource로 재생.
String? makeObjectUrl(Uint8List bytes, String mime) {
  final blob = html.Blob([bytes], mime);
  return html.Url.createObjectUrlFromBlob(blob);
}
