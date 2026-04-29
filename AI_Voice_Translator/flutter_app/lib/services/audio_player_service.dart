import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

// Conditional import for File (not available on web)
import 'package:ai_voice_translator/services/file_helper.dart'
    if (dart.library.html) 'package:ai_voice_translator/services/file_helper_web.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playBase64(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      await _player.stop();

      if (kIsWeb) {
        // Web: use data URI
        final b64 = base64Encode(bytes);
        final uri = 'data:audio/mpeg;base64,$b64';
        await _player.setUrl(uri);
      } else {
        // Native: write temp file and play
        final tempPath = await writeTempMp3(bytes);
        await _player.setFilePath(tempPath);
      }
      await _player.play();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  bool get isPlaying => _player.playing;

  Stream<bool> get playingStream => _player.playingStream;

  void dispose() {
    _player.dispose();
  }
}
