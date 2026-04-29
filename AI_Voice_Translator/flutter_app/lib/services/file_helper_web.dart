import 'dart:typed_data';

/// Web stub: should never be called for file writing on web.
Future<String> writeTempMp3(Uint8List bytes) async {
  throw UnsupportedError('writeTempMp3 is not supported on web');
}

/// Web stub: should never be called for file reading on web.
Future<Uint8List> readNativeFileBytes(String filePath) async {
  throw UnsupportedError('readNativeFileBytes is not supported on web');
}
