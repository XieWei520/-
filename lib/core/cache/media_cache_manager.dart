import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Three-level media cache for chat images and video thumbnails.
///
/// - L1 memory: decoded image providers with a byte budget.
/// - L2 disk: handled by [CachedNetworkImage] / flutter_cache_manager.
/// - L3 network: original fetch from the server.
class MediaCacheManager with WidgetsBindingObserver {
  MediaCacheManager._({int maxL1Bytes = defaultMaxL1Bytes})
    : maxL1Bytes = maxL1Bytes < 1 ? 1 : maxL1Bytes;

  static final MediaCacheManager instance = MediaCacheManager._();

  @visibleForTesting
  factory MediaCacheManager.forTesting({int maxL1Bytes = defaultMaxL1Bytes}) {
    return MediaCacheManager._(maxL1Bytes: maxL1Bytes);
  }

  static const int defaultMaxL1Bytes = 32 * 1024 * 1024;
  static const int defaultEstimatedDecodedBytes = 1024 * 1024;

  final int maxL1Bytes;
  final LinkedHashMap<String, _L1MediaCacheEntry> _l1Cache = LinkedHashMap();

  bool _initialized = false;
  int _l1Bytes = 0;

  /// Initialize the cache manager and register for memory pressure events.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    WidgetsBinding.instance.removeObserver(this);
    clearL1();
  }

  /// Called by the framework when the system is running low on memory.
  @override
  void didHaveMemoryPressure() {
    clearL1();
  }

  /// Get a cached [ImageProvider] from L1 memory, or null if not cached.
  ImageProvider? getFromL1(String cacheKey) {
    final entry = _l1Cache.remove(cacheKey);
    if (entry == null) {
      return null;
    }
    _l1Cache[cacheKey] = entry;
    return entry.provider;
  }

  /// Store an [ImageProvider] in L1 memory cache.
  void putToL1(String cacheKey, ImageProvider provider, {int? estimatedBytes}) {
    final bytes = _normalizeEstimatedBytes(estimatedBytes);
    final previous = _l1Cache.remove(cacheKey);
    if (previous != null) {
      _l1Bytes -= previous.estimatedBytes;
    }

    if (bytes > maxL1Bytes) {
      return;
    }

    while (_l1Bytes + bytes > maxL1Bytes && _l1Cache.isNotEmpty) {
      _evictOldest();
    }

    _l1Cache[cacheKey] = _L1MediaCacheEntry(
      provider: provider,
      estimatedBytes: bytes,
    );
    _l1Bytes += bytes;
  }

  /// Evict a specific entry from L1 memory cache.
  void evictFromL1(String cacheKey) {
    final entry = _l1Cache.remove(cacheKey);
    if (entry != null) {
      _l1Bytes -= entry.estimatedBytes;
    }
  }

  /// Clear all L1 memory cache entries.
  void clearL1() {
    _l1Cache.clear();
    _l1Bytes = 0;
  }

  /// Current number of entries in L1 memory cache.
  int get l1Size => _l1Cache.length;

  int get l1Bytes => _l1Bytes;

  @visibleForTesting
  static bool shouldUseBrowserNetworkImageForTesting({required bool isWeb}) {
    return _shouldUseBrowserNetworkImage(isWeb: isWeb);
  }

  static int estimateDecodedBytes({int? width, int? height}) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return defaultEstimatedDecodedBytes;
    }
    return width * height * 4;
  }

  int _normalizeEstimatedBytes(int? estimatedBytes) {
    if (estimatedBytes == null || estimatedBytes <= 0) {
      return defaultEstimatedDecodedBytes;
    }
    return estimatedBytes;
  }

  void _evictOldest() {
    if (_l1Cache.isEmpty) {
      return;
    }
    evictFromL1(_l1Cache.keys.first);
  }

  static bool _shouldUseBrowserNetworkImage({required bool isWeb}) => isWeb;
}

class _L1MediaCacheEntry {
  const _L1MediaCacheEntry({
    required this.provider,
    required this.estimatedBytes,
  });

  final ImageProvider provider;
  final int estimatedBytes;
}

/// A widget that wraps [CachedNetworkImage] with L1 memory caching.
///
/// Uses [ResizeImage] to limit decoded image memory usage, and stores
/// the result in the L1 cache for instant re-display when scrolling back.
class CachedMediaImage extends StatelessWidget {
  const CachedMediaImage({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  final String imageUrl;
  final String cacheKey;
  final double? width;
  final double? height;
  final int? maxWidth;
  final int? maxHeight;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (MediaCacheManager._shouldUseBrowserNetworkImage(isWeb: kIsWeb)) {
      return _buildBrowserNetworkImage();
    }

    final l1Provider = MediaCacheManager.instance.getFromL1(cacheKey);
    if (l1Provider != null) {
      Widget image = Image(
        image: l1Provider,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, error, stack) {
          MediaCacheManager.instance.evictFromL1(cacheKey);
          return _buildNetworkImage();
        },
      );
      if (borderRadius != null) {
        image = ClipRRect(borderRadius: borderRadius!, child: image);
      }
      return image;
    }

    return _buildNetworkImage();
  }

  Widget _buildNetworkImage() {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: maxWidth,
      memCacheHeight: maxHeight,
      placeholder: placeholder,
      errorWidget: errorWidget,
      imageBuilder: (context, imageProvider) {
        MediaCacheManager.instance.putToL1(
          cacheKey,
          imageProvider,
          estimatedBytes: MediaCacheManager.estimateDecodedBytes(
            width: maxWidth,
            height: maxHeight,
          ),
        );
        return Image(
          image: imageProvider,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildBrowserNetworkImage() {
    Widget image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: maxWidth,
      cacheHeight: maxHeight,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return placeholder?.call(context, imageUrl) ??
            SizedBox(width: width, height: height);
      },
      errorBuilder: (context, error, stackTrace) =>
          errorWidget?.call(context, imageUrl, error) ??
          SizedBox(width: width, height: height),
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
