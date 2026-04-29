import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

// Conditional import for dart:io — only accessed on non-web
import 'package:ai_voice_translator/services/file_helper.dart'
    if (dart.library.html) 'package:ai_voice_translator/services/file_helper_web.dart';

class TranslationSettings {
  final String backendUrl;
  final String sourceLang;
  final String targetLang;
  final OutputMode outputMode;
  const TranslationSettings({
    required this.backendUrl,
    required this.sourceLang,
    required this.targetLang,
    required this.outputMode,
  });
}

class TranslationResult {
  final String transcript;
  final String translation;
  final String? audioBase64;
  final String sourceLang;
  final String targetLang;
  const TranslationResult({
    required this.transcript,
    required this.translation,
    this.audioBase64,
    required this.sourceLang,
    required this.targetLang,
  });
}

class TranslationService {
  static const _kBackendUrl = 'backend_url';
  static const _kSourceLang = 'source_lang';
  static const _kTargetLang = 'target_lang';
  static const _kOutputMode = 'output_mode';

  Future<TranslationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return TranslationSettings(
      backendUrl: prefs.getString(_kBackendUrl) ?? kDefaultBackendUrl,
      sourceLang: prefs.getString(_kSourceLang) ?? 'auto',
      targetLang: prefs.getString(_kTargetLang) ?? 'en',
      outputMode: prefs.getString(_kOutputMode) == 'speaker' ? OutputMode.speaker : OutputMode.text,
    );
  }

  Future<void> saveSettings(TranslationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackendUrl, settings.backendUrl);
    await prefs.setString(_kSourceLang, settings.sourceLang);
    await prefs.setString(_kTargetLang, settings.targetLang);
    await prefs.setString(_kOutputMode, settings.outputMode == OutputMode.speaker ? 'speaker' : 'text');
  }

  /// Translate from an audio file path (native platforms: Android, Windows)
  Future<TranslationResult> translateFromFile({
    required String filePath,
    required String sourceLang,
    required String targetLang,
    required OutputMode outputMode,
    required String backendUrl,
  }) async {
    final bytes = await _readFileBytes(filePath);
    return _sendToBackend(
      audioBytes: bytes,
      filename: 'audio.wav',
      sourceLang: sourceLang,
      targetLang: targetLang,
      outputMode: outputMode,
      backendUrl: backendUrl,
    );
  }

  /// Translate from raw audio bytes (web or native via stopAndGetBytes)
  Future<TranslationResult> translateFromBytes({
    required Uint8List audioBytes,
    required String sourceLang,
    required String targetLang,
    required OutputMode outputMode,
    required String backendUrl,
    String filename = 'audio.webm',
  }) async {
    return _sendToBackend(
      audioBytes: audioBytes,
      filename: filename,
      sourceLang: sourceLang,
      targetLang: targetLang,
      outputMode: outputMode,
      backendUrl: backendUrl,
    );
  }

  Future<Uint8List> _readFileBytes(String filePath) async {
    if (kIsWeb) throw Exception('File paths not supported on web');
    return readNativeFileBytes(filePath);
  }

  /// Translate typed text directly (no audio).
  Future<TranslationResult> translateTextOnly({
    required String text,
    required String sourceLang,
    required String targetLang,
    required String backendUrl,
  }) async {
    final cleanBackendUrl = normalizeUrl(backendUrl);
    final uri = Uri.parse('$cleanBackendUrl/api/translate-text');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'sourceLang': sourceLang, 'targetLang': targetLang}),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      print('❌ API Error (${response.statusCode}) at $uri: ${response.body}');
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Server error ${response.statusCode}');
      } catch (e) {
        throw Exception('Server error ${response.statusCode}: ${response.reasonPhrase}');
      }
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['success'] != true) throw Exception(json['error'] ?? 'Translation failed');
    return TranslationResult(
      transcript: json['transcript'] as String,
      translation: json['translation'] as String,
      sourceLang: json['sourceLang'] as String,
      targetLang: json['targetLang'] as String,
    );
  }

  Future<TranslationResult> _sendToBackend({
    required Uint8List audioBytes,
    required String filename,
    required String sourceLang,
    required String targetLang,
    required OutputMode outputMode,
    required String backendUrl,
  }) async {
    final cleanBackendUrl = normalizeUrl(backendUrl);
    final uri = Uri.parse('$cleanBackendUrl/api/translate');
    final request = http.MultipartRequest('POST', uri);

    request.fields['sourceLang'] = sourceLang;
    request.fields['targetLang'] = targetLang;
    // Always request text from backend — TTS is handled client-side for free
    request.fields['outputMode'] = 'text';

    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: filename,
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      print('❌ Multipart Error (${streamed.statusCode}) at $uri: $body');
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Server error ${streamed.statusCode}');
      } catch (e) {
        throw Exception('Server error ${streamed.statusCode}');
      }
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['success'] != true) {
      throw Exception(json['error'] ?? 'Translation failed');
    }

    return TranslationResult(
      transcript: json['transcript'] as String,
      translation: json['translation'] as String,
      audioBase64: json['audioBase64'] as String?,
      sourceLang: json['sourceLang'] as String,
      targetLang: json['targetLang'] as String,
    );
  }
}
