import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';

void main() {
  group('MediaCacheManager', () {
    test(
      'evicts least recently used entries when decoded byte budget is exceeded',
      () {
        final manager = MediaCacheManager.forTesting(maxL1Bytes: 100);
        final first = MemoryImage(Uint8List.fromList([1]));
        final second = MemoryImage(Uint8List.fromList([2]));
        final third = MemoryImage(Uint8List.fromList([3]));

        manager.putToL1('a', first, estimatedBytes: 40);
        manager.putToL1('b', second, estimatedBytes: 40);
        expect(manager.getFromL1('a'), same(first));

        manager.putToL1('c', third, estimatedBytes: 40);

        expect(manager.getFromL1('b'), isNull);
        expect(manager.getFromL1('a'), same(first));
        expect(manager.getFromL1('c'), same(third));
        expect(manager.l1Bytes, lessThanOrEqualTo(100));
      },
    );

    test('does not cache a single decoded image over the byte budget', () {
      final manager = MediaCacheManager.forTesting(maxL1Bytes: 100);
      final image = MemoryImage(Uint8List.fromList([1]));

      manager.putToL1('huge', image, estimatedBytes: 120);

      expect(manager.getFromL1('huge'), isNull);
      expect(manager.l1Size, 0);
      expect(manager.l1Bytes, 0);
    });

    test('bypasses Dart image cache for browser-rendered web media', () {
      expect(
        MediaCacheManager.shouldUseBrowserNetworkImageForTesting(isWeb: true),
        isTrue,
      );
      expect(
        MediaCacheManager.shouldUseBrowserNetworkImageForTesting(isWeb: false),
        isFalse,
      );
    });
  });
}
