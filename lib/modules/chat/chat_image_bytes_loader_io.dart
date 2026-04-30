import 'dart:io';
import 'dart:typed_data';

const int maxChatImageDecodeBytes = 16 * 1024 * 1024;

Future<Uint8List?> loadChatImageBytes(String localPath) async {
  final normalizedPath = localPath.trim();
  if (normalizedPath.isEmpty) {
    return null;
  }
  try {
    final file = File(normalizedPath);
    if (!await file.exists()) {
      return null;
    }
    if (await file.length() > maxChatImageDecodeBytes) {
      return null;
    }
    return file.readAsBytes();
  } catch (_) {
    return null;
  }
}
