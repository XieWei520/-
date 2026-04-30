import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// File utilities
class WKFileUtils {
  /// Get app documents directory
  static Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get app cache directory
  static Future<Directory> getCacheDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

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
  static Future<bool> exists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Delete file
  static Future<bool> delete(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get file name from path
  static String getFileName(String filePath) {
    return path.basename(filePath);
  }

  /// Get file name without extension
  static String getFileNameWithoutExtension(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  /// Create directory if not exists
  static Future<Directory> ensureDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get cache directory path for images
  static Future<String> getImageCacheDir() async {
    final cacheDir = await getCacheDirectory();
    final imageDir = Directory(path.join(cacheDir.path, 'images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  /// Get cache directory path for audio
  static Future<String> getAudioCacheDir() async {
    final cacheDir = await getCacheDirectory();
    final audioDir = Directory(path.join(cacheDir.path, 'audio'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// Get cache directory path for video
  static Future<String> getVideoCacheDir() async {
    final cacheDir = await getCacheDirectory();
    final videoDir = Directory(path.join(cacheDir.path, 'video'));
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir.path;
  }
}
