import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/cache_clean_service.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cache_clean_service_test');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'getTotalCacheBytes sums files recursively across cache roots',
    () async {
      final nested = Directory('${root.path}\\nested')
        ..createSync(recursive: true);
      File('${root.path}\\cover.jpg').writeAsBytesSync(List<int>.filled(10, 1));
      File(
        '${nested.path}\\voice.aac',
      ).writeAsBytesSync(List<int>.filled(25, 2));

      final service = CacheCleanService(
        resolveCacheDirectories: () async => <Directory>[root],
        clearAdditionalCaches: () async {},
      );

      expect(await service.getTotalCacheBytes(), 35);
    },
  );

  test(
    'clearAllCache removes files under each cache root and runs extras',
    () async {
      final nested = Directory('${root.path}\\nested')
        ..createSync(recursive: true);
      File('${root.path}\\cover.jpg').writeAsBytesSync(List<int>.filled(10, 1));
      File(
        '${nested.path}\\voice.aac',
      ).writeAsBytesSync(List<int>.filled(25, 2));
      var extraCleared = false;

      final service = CacheCleanService(
        resolveCacheDirectories: () async => <Directory>[root],
        clearAdditionalCaches: () async {
          extraCleared = true;
        },
      );

      await service.clearAllCache();

      expect(extraCleared, isTrue);
      expect(await service.getTotalCacheBytes(), 0);
      expect(await root.exists(), isTrue);
    },
  );

  test(
    'getTotalCacheBytes skips inaccessible cache roots instead of throwing',
    () async {
      final accessible = Directory('${root.path}\\accessible')
        ..createSync(recursive: true);
      File(
        '${accessible.path}\\cover.jpg',
      ).writeAsBytesSync(List<int>.filled(12, 3));
      final blocked = Directory('${root.path}\\blocked');

      final service = CacheCleanService(
        resolveCacheDirectories: () async => <Directory>[accessible, blocked],
        clearAdditionalCaches: () async {},
        measureDirectoryBytes: (directory) async {
          if (directory is Directory && directory.path == blocked.path) {
            throw FileSystemException(
              'Directory listing failed',
              blocked.path,
              const OSError('Access denied', 5),
            );
          }
          return 12;
        },
      );

      expect(await service.getTotalCacheBytes(), 12);
    },
  );

  test(
    'cache size falls back to zero when cache roots cannot be resolved',
    () async {
      final service = CacheCleanService(
        resolveCacheDirectories: () async {
          throw const FileSystemException('cache root unavailable');
        },
        clearAdditionalCaches: () async {},
      );

      expect(await service.getTotalCacheBytes(), 0);
    },
  );

  test(
    'clearAllCache still runs additional cleanup when roots cannot resolve',
    () async {
      var extraCleared = false;
      final service = CacheCleanService(
        resolveCacheDirectories: () async {
          throw const FileSystemException('cache root unavailable');
        },
        clearAdditionalCaches: () async {
          extraCleared = true;
        },
      );

      await expectLater(service.clearAllCache(), completes);

      expect(extraCleared, isTrue);
    },
  );

  test(
    'clearAllCache skips locked files instead of aborting the whole cleanup',
    () async {
      final nested = Directory('${root.path}\\nested')
        ..createSync(recursive: true);
      final lockedFile = File('${root.path}\\locked.tmp')
        ..writeAsBytesSync(List<int>.filled(8, 7));
      final removableFile = File('${nested.path}\\cover.jpg')
        ..writeAsBytesSync(List<int>.filled(12, 9));
      final lockHandle = lockedFile.openSync(mode: FileMode.append);
      addTearDown(() async {
        await lockHandle.close();
      });

      var extraCleared = false;
      final service = CacheCleanService(
        resolveCacheDirectories: () async => <Directory>[root],
        clearAdditionalCaches: () async {
          extraCleared = true;
        },
      );

      await expectLater(service.clearAllCache(), completes);

      expect(extraCleared, isTrue);
      expect(await removableFile.exists(), isFalse);
      expect(await lockedFile.exists(), isTrue);
    },
  );
}
