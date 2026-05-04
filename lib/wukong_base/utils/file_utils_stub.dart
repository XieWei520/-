import 'package:path/path.dart' as path;

class UnsupportedLocalDirectory {
  const UnsupportedLocalDirectory(this.path);

  final String path;
}

/// File utilities
class WKFileUtils {
  /// Get app documents directory
  static Future<UnsupportedLocalDirectory> getDocumentsDirectory() async {
    return const UnsupportedLocalDirectory('');
  }

  /// Get app cache directory
  static Future<UnsupportedLocalDirectory> getCacheDirectory() async {
    return const UnsupportedLocalDirectory('');
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async => 0;

  /// Format file size to human readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get file extension
  static String getExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  /// Check if file is image
  static bool isImage(String filePath) {
    final ext = getExtension(filePath);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  /// Check if file is video
  static bool isVideo(String filePath) {
    final ext = getExtension(filePath);
    return ['.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv'].contains(ext);
  }

  /// Check if file is audio
  static bool isAudio(String filePath) {
    final ext = getExtension(filePath);
    return ['.mp3', '.wav', '.aac', '.m4a', '.ogg', '.wma'].contains(ext);
  }

  /// Check if file exists
  static Future<bool> exists(String filePath) async => false;

  /// Delete file
  static Future<bool> delete(String filePath) async => false;

  /// Get file name from path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Create directory if not exists
  static Future<UnsupportedLocalDirectory> ensureDirectory(
    String dirPath,
  ) async {
    return UnsupportedLocalDirectory(dirPath);
  }

  /// Get cache directory path for images
  static Future<String> getImageCacheDir() async => '';

  /// Get cache directory path for audio
  static Future<String> getAudioCacheDir() async => '';

  /// Get cache directory path for video
  static Future<String> getVideoCacheDir() async => '';
}
