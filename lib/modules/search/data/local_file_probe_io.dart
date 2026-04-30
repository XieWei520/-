import 'dart:io';

Future<bool> defaultLocalImagePathExists(String path) {
  return File(path).exists();
}
