import 'dart:io';
import 'dart:isolate';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../../wukong_base/utils/image_cache.dart';

typedef CacheDirectoryBytesMeasurer = Future<int> Function(Directory directory);

class CacheCleanService {
  const CacheCleanService({
    required this.resolveCacheDirectories,
    required this.clearAdditionalCaches,
    CacheDirectoryBytesMeasurer? measureDirectoryBytes,
  }) : measureDirectoryBytes =
           measureDirectoryBytes ?? _defaultMeasureDirectoryBytes;

  factory CacheCleanService.platform() {
    return CacheCleanService(
      resolveCacheDirectories: () async => <Directory>[
        await getTemporaryDirectory(),
      ],
      clearAdditionalCaches: () async {
        await DefaultCacheManager().emptyCache();
        await WKImageCache.instance.clearDiskCache();
      },
    );
  }

  final Future<List<Directory>> Function() resolveCacheDirectories;
  final Future<void> Function() clearAdditionalCaches;
  final CacheDirectoryBytesMeasurer measureDirectoryBytes;

  Future<int> getTotalCacheBytes() async {
    final directories = await _resolveCacheDirectoriesBestEffort();
    var total = 0;
    for (final directory in directories) {
      try {
        total += await measureDirectoryBytes(directory);
      } on FileSystemException {
        continue;
      }
    }
    return total;
  }

  Future<void> clearAllCache() async {
    final directories = await _resolveCacheDirectoriesBestEffort();
    for (final directory in directories) {
      await _clearDirectoryContents(directory);
    }
    await clearAdditionalCaches();
  }

  Future<List<Directory>> _resolveCacheDirectoriesBestEffort() async {
    try {
      return await resolveCacheDirectories();
    } on FileSystemException {
      return const <Directory>[];
    }
  }

  static Future<int> _defaultMeasureDirectoryBytes(Directory directory) async {
    return Isolate.run(() => _measureDirectorySize(directory.path));
  }

  static int _measureDirectorySize(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return 0;
    }

    return _measureDirectoryTree(directory);
  }

  static int _measureDirectoryTree(Directory directory) {
    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync(followLinks: false);
    } on FileSystemException {
      return 0;
    }

    var total = 0;
    for (final entity in entities) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } on FileSystemException {
          continue;
        }
        continue;
      }
      if (entity is Directory) {
        total += _measureDirectoryTree(entity);
      }
    }
    return total;
  }

  Future<void> _clearDirectoryContents(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    List<FileSystemEntity> entities;
    try {
      entities = directory.listSync();
    } on FileSystemException {
      return;
    }

    for (final entity in entities) {
      try {
        if (entity.existsSync()) {
          await entity.delete(recursive: true);
        }
      } on FileSystemException {
        continue;
      }
    }
  }
}
