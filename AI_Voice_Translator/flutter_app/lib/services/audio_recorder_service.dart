import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:ai_voice_translator/services/file_helper.dart'
    if (dart.library.html) 'package:ai_voice_translator/services/file_helper_web.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async => _recorder.hasPermission();

  Future<void> start() async {
    if (kIsWeb) {
      // Web: record to an in-browser blob (path param is ignored by the plugin)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: 'blob',
      );
    } else {
      final dir = await getTemporaryDirectory();
      final path = p.join(
          dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    }
  }

  /// Stops recording and returns the raw audio bytes + a filename hint.
  /// On web  → fetches blob URL returned by the recorder → returns WebM bytes.
  /// On native → reads the WAV file from the path returned by stop().
  Future<AudioData?> stopAndGetBytes() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;

    if (kIsWeb) {
      try {
        // path is a blob: URL — fetch its bytes via HTTP
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return AudioData(bytes: response.bodyBytes, filename: 'audio.webm');
        }
        return null;
      } catch (e) {
        return null;
      }
    } else {
      try {
        final bytes = await readNativeFileBytes(path);
        return AudioData(bytes: bytes, filename: 'audio.wav');
      } catch (e) {
        return null;
      }
    }
  }

  Future<bool> isRecording() async => _recorder.isRecording();

  Future<void> cancel() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  void dispose() => _recorder.dispose();
}

class AudioData {
  final Uint8List bytes;
  final String filename;
  const AudioData({required this.bytes, required this.filename});
}
