import 'package:flutter_tts/flutter_tts.dart';

/// 호흡 음성 안내(기기 내장 TTS, 오프라인). 실패해도 조용히 무시.
///
/// 한국어 음성이 기기에 없으면 소리가 나지 않을 수 있다(크래시 없음).
class BreathCoach {
  BreathCoach._();
  static final BreathCoach instance = BreathCoach._();

  FlutterTts? _tts;
  bool _ready = false;
  bool _initing = false;

  Future<void> _ensure() async {
    if (_ready || _initing) return;
    _initing = true;
    try {
      final t = FlutterTts();
      await t.setLanguage('ko-KR');
      await t.setSpeechRate(0.42); // 차분하게
      await t.setVolume(0.85);
      await t.setPitch(0.96);
      _tts = t;
      _ready = true;
    } catch (_) {
      _ready = false;
    } finally {
      _initing = false;
    }
  }

  /// 짧은 안내 문구를 말한다(이전 발화는 끊고).
  Future<void> say(String text) async {
    await _ensure();
    try {
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
