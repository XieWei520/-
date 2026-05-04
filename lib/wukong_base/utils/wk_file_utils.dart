import 'wk_file_exists_probe.dart';

/// File utilities
class WKFileUtils {
  /// Get file size string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Check if file exists
  static Future<bool> fileExists(String path) {
    return wkFileExists(path);
  }

  /// Get file name from path
  static String getFileName(String path) {
    final normalized = path
        .trim()
        .split('?')
        .first
        .split('#')
        .first
        .replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? '' : segments.last;
  }
}
