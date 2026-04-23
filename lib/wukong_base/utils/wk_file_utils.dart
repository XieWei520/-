import 'dart:io';

/// File utilities
class WKFileUtils {
  /// Get file size string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Check if file exists
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  /// Get file name from path
  static String getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }
}
