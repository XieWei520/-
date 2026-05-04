import 'dart:io';

Future<bool> wkFileExists(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return Future<bool>.value(false);
  }
  return File(normalizedPath).exists();
}
