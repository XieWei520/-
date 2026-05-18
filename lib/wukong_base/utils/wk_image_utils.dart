import 'dart:ui';

import '../../core/media/media_preprocess_service.dart';

/// Image utilities
class WKImageUtils {
  static final MediaPreprocessService _mediaPreprocessService =
      DefaultMediaPreprocessService();

  /// Get image size
  static Future<Size?> getImageSize(String path) async {
    final info = await _mediaPreprocessService.probeImage(path);
    if (info == null) {
      return null;
    }
    return Size(info.width.toDouble(), info.height.toDouble());
  }

  /// Compress image
  static Future<String?> compressImage(
    String path, {
    int quality = 80,
    int maxDimension = 2048,
    String? outputDirectoryPath,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final result = await _mediaPreprocessService.preprocessImage(
      normalizedPath,
      options: MediaPreprocessOptions(
        quality: quality,
        maxDimension: maxDimension,
        outputDirectoryPath: outputDirectoryPath,
      ),
    );
    return result.outputPath;
  }
}
