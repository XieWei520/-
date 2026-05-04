import 'dart:io';

Future<bool> localAttachmentFileExists(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return false;
  }
  try {
    return File(normalizedPath).exists();
  } catch (_) {
    return false;
  }
}

Future<int?> localAttachmentFileLength(String path) async {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return null;
  }
  try {
    final file = File(normalizedPath);
    if (!await file.exists()) {
      return null;
    }
    return file.length();
  } catch (_) {
    return null;
  }
}
