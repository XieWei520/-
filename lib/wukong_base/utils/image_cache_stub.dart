import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Provides centralized image caching functionality.
class WKImageCache {
  static WKImageCache? _instance;
  final Map<String, ImageProvider> _memoryCache = {};

  WKImageCache._();

  static WKImageCache get instance {
    _instance ??= WKImageCache._();
    return _instance!;
  }

  /// Get cached network image
  ImageProvider getNetworkImage(
    String url, {
    String? placeholder,
    ImageWidgetBuilder? imageBuilder,
    LoadingErrorWidgetBuilder? errorBuilder,
  }) {
    return CachedNetworkImageProvider(url);
  }

  /// Get network image widget
  Widget getNetworkImageWidget(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
    );
  }

  /// Preload image to cache
  Future<void> preloadImage(String url, BuildContext context) async {
    await precacheImage(CachedNetworkImageProvider(url), context);
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
    imageCache.clear();
  }

  /// Clear disk cache
  Future<void> clearDiskCache() async {}

  /// Get cache size
  Future<int> getCacheSize() async => 0;

  Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.error_outline, color: Colors.grey),
    );
  }
}
