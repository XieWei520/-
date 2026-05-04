import 'package:flutter/material.dart';

/// Image utilities
class WKImageUtils {
  /// Get image dimensions
  static Future<Size?> getImageSize(String imagePath) async => null;

  /// Calculate thumbnail size maintaining aspect ratio
  static Size calculateThumbnailSize(
    Size original, {
    double maxWidth = 200,
    double maxHeight = 200,
  }) {
    if (original.width <= maxWidth && original.height <= maxHeight) {
      return original;
    }

    final aspectRatio = original.width / original.height;
    if (original.width > original.height) {
      return Size(maxWidth, maxWidth / aspectRatio);
    } else {
      return Size(maxHeight * aspectRatio, maxHeight);
    }
  }

  /// Check if image is portrait
  static bool isPortrait(String imagePath, Size size) {
    return size.height > size.width;
  }

  /// Check if image is landscape
  static bool isLandscape(String imagePath, Size size) {
    return size.width > size.height;
  }

  /// Get appropriate border radius for image
  static BorderRadius getImageBorderRadius(
    Size size, {
    double defaultRadius = 8,
  }) {
    if (size.width == size.height) {
      return BorderRadius.circular(100);
    }
    return BorderRadius.circular(defaultRadius);
  }
}
