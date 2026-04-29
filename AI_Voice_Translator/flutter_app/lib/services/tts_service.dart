import 'package:flutter_tts/flutter_tts.dart';

/// Client-side TTS using Web Speech API (web) or native TTS (mobile/desktop).
/// Completely free — no API key required.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    _initialized = true;
  }

  /// Speak [text] in [languageCode] (e.g. 'en-US', 'fr-FR', 'hi-IN').
  Future<void> speak(String text, {String languageCode = 'en-US'}) async {
    await _init();
    await _tts.setLanguage(languageCode);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }

  /// Maps ISO 639-1 language codes to BCP-47 locale codes for TTS.
  static String localeFor(String langCode) {
    const map = {
      'en': 'en-US', 'es': 'es-ES', 'fr': 'fr-FR', 'de': 'de-DE',
      'it': 'it-IT', 'pt': 'pt-PT', 'ru': 'ru-RU', 'ja': 'ja-JP',
      'ko': 'ko-KR', 'zh': 'zh-CN', 'ar': 'ar-SA', 'hi': 'hi-IN',
      'tr': 'tr-TR', 'pl': 'pl-PL', 'nl': 'nl-NL', 'sv': 'sv-SE',
      'da': 'da-DK', 'fi': 'fi-FI', 'cs': 'cs-CZ', 'hu': 'hu-HU',
      'ro': 'ro-RO', 'uk': 'uk-UA', 'el': 'el-GR', 'he': 'he-IL',
      'th': 'th-TH', 'vi': 'vi-VN', 'id': 'id-ID', 'ms': 'ms-MY',
      'fa': 'fa-IR', 'ur': 'ur-PK', 'bn': 'bn-BD', 'ta': 'ta-IN',
      'te': 'te-IN', 'ml': 'ml-IN', 'kn': 'kn-IN', 'gu': 'gu-IN',
      'pa': 'pa-IN', 'mr': 'mr-IN', 'ne': 'ne-NP', 'sw': 'sw-KE',
    };
    return map[langCode] ?? 'en-US';
  }
}
