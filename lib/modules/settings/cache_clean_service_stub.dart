typedef CacheDirectoryBytesMeasurer = Future<int> Function(Object directory);

class CacheCleanService {
  const CacheCleanService({
    required this.resolveCacheDirectories,
    required this.clearAdditionalCaches,
    CacheDirectoryBytesMeasurer? measureDirectoryBytes,
  }) : measureDirectoryBytes = measureDirectoryBytes ?? _measureNoBytes;

  factory CacheCleanService.platform() {
    return CacheCleanService(
      resolveCacheDirectories: () async => const <Object>[],
      clearAdditionalCaches: () async {},
    );
  }

  final Future<List<Object>> Function() resolveCacheDirectories;
  final Future<void> Function() clearAdditionalCaches;
  final CacheDirectoryBytesMeasurer measureDirectoryBytes;

  Future<int> getTotalCacheBytes() async {
    final directories = await resolveCacheDirectories();
    var total = 0;
    for (final directory in directories) {
      total += await measureDirectoryBytes(directory);
    }
    return total;
  }

  Future<void> clearAllCache() async {
    await clearAdditionalCaches();
  }

  static Future<int> _measureNoBytes(Object directory) async => 0;
}
