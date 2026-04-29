import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Native: writes bytes to a temp MP3 file and returns the path.
Future<String> writeTempMp3(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
  await File(path).writeAsBytes(bytes);
  return path;
}

/// Native: reads a file from a path and returns its bytes.
Future<Uint8List> readNativeFileBytes(String filePath) async {
  return File(filePath).readAsBytes();
}
