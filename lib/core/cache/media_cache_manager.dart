import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Three-level media cache for chat images and video thumbnails.
///
/// - **L1 (Memory)**: LRU cache of decoded images in memory (fast, limited).
/// - **L2 (Disk)**: Handled automatically by [CachedNetworkImage] /
///   `flutter_cache_manager` (persistent, larger).
/// - **L3 (Network)**: Original fetch from the server.
///
/// This class manages the L1 layer and provides a helper widget that plugs
/// into the existing [CachedNetworkImage] pipeline for L2/L3.
class MediaCacheManager with WidgetsBindingObserver {
  MediaCacheManager._();
  static final MediaCacheManager instance = MediaCacheManager._();

  bool _initialized = false;

  /// Maximum number of entries in the L1 memory cache.
  static const int _maxL1Entries = 200;

  /// L1 memory cache: messageID → ImageProvider.
  final LinkedHashMap<String, ImageProvider> _l1Cache = LinkedHashMap();

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
    _l1Cache.clear();
  }

  /// Called by the framework when the system is running low on memory.
  @override
  void didHaveMemoryPressure() {
    // Evict all L1 entries under memory pressure.
    _l1Cache.clear();
  }

  /// Get a cached [ImageProvider] from L1 memory, or null if not cached.
  ImageProvider? getFromL1(String cacheKey) {
    final provider = _l1Cache.remove(cacheKey);
    if (provider != null) {
      // Move to end (most-recently-used)
      _l1Cache[cacheKey] = provider;
    }
    return provider;
  }

  /// Store an [ImageProvider] in L1 memory cache.
  void putToL1(String cacheKey, ImageProvider provider) {
    // Evict oldest if at capacity
    while (_l1Cache.length >= _maxL1Entries) {
      _l1Cache.remove(_l1Cache.keys.first);
    }
    _l1Cache[cacheKey] = provider;
  }

  /// Evict a specific entry from L1 memory cache.
  void evictFromL1(String cacheKey) {
    _l1Cache.remove(cacheKey);
  }

  /// Clear all L1 memory cache entries.
  void clearL1() {
    _l1Cache.clear();
  }

  /// Current number of entries in L1 memory cache.
  int get l1Size => _l1Cache.length;
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
    // Check L1 first
    final l1Provider = MediaCacheManager.instance.getFromL1(cacheKey);
    if (l1Provider != null) {
      Widget image = Image(
        image: l1Provider,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, error, stack) {
          // L1 stale — evict and fall through to network
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
        // Store in L1 on successful load
        MediaCacheManager.instance.putToL1(cacheKey, imageProvider);
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
}
