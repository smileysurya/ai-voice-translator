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
    
    try {
      print('🌐 [API] Translating text: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'sourceLang': sourceLang, 'targetLang': targetLang}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        print('❌ [API] Error ${response.statusCode}: ${response.body}');
        Map<String, dynamic>? errorJson;
        try { errorJson = jsonDecode(response.body); } catch (_) {}
        
        String errorMsg = errorJson?['error'] ?? 'Server error ${response.statusCode}';
        if (response.statusCode == 503) errorMsg = 'Backend is starting up... please wait 30 seconds and try again.';
        throw Exception(errorMsg);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) throw Exception(json['error'] ?? 'Translation failed');
      
      return TranslationResult(
        transcript: json['transcript'] as String,
        translation: json['translation'] as String,
        sourceLang: json['sourceLang'] as String,
        targetLang: json['targetLang'] as String,
      );
    } on TimeoutException {
      throw Exception('Request timed out. The backend might be sleeping (Render free tier). Please try again in a few seconds.');
    } catch (e) {
      rethrow;
    }
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
    
    try {
      print('🌐 [API] Sending audio: $filename (${audioBytes.length} bytes) to $uri');
      final request = http.MultipartRequest('POST', uri);

      request.fields['sourceLang'] = sourceLang;
      request.fields['targetLang'] = targetLang;
      request.fields['outputMode'] = 'text';

      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: filename,
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        print('❌ [API] Multipart Error ${response.statusCode}: ${response.body}');
        Map<String, dynamic>? errorJson;
        try { errorJson = jsonDecode(response.body); } catch (_) {}
        
        String errorMsg = errorJson?['error'] ?? 'Server error ${response.statusCode}';
        if (response.statusCode == 503) errorMsg = 'Backend is waking up... please wait and try again.';
        throw Exception(errorMsg);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
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
    } on TimeoutException {
      throw Exception('Request timed out. The backend might be starting up. Please try again.');
    } catch (e) {
      print('❌ [API] Unexpected error: $e');
      rethrow;
    }
  }
}
