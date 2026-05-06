import 'dart:io';

import 'package:feishu_monitor_agent/src/browser_profile.dart';
import 'package:feishu_monitor_agent/src/message_dedupe_store.dart';
import 'package:test/test.dart';

void main() {
  group('MessageDedupeStore', () {
    late Directory tempDir;
    late BrowserProfilePaths paths;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feishu_dedupe_test_');
      paths = BrowserProfilePaths(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns true once for a new id and false afterwards', () async {
      final store = MessageDedupeStore(paths.dedupeCacheFile);

      expect(await store.markIfNew('a'), isTrue);
      expect(await store.markIfNew('a'), isFalse);
      expect(await store.markIfNew(''), isFalse);
    });

    test('trims persisted ids to max entries when reloaded', () async {
      final store = MessageDedupeStore(paths.dedupeCacheFile, maxEntries: 2);

      expect(await store.markIfNew('a'), isTrue);
      expect(await store.markIfNew('b'), isTrue);
      expect(await store.markIfNew('c'), isTrue);

      final reloaded = MessageDedupeStore(paths.dedupeCacheFile, maxEntries: 2);

      expect(await reloaded.markIfNew('b'), isFalse);
      expect(await reloaded.markIfNew('c'), isFalse);
      expect(await reloaded.markIfNew('a'), isTrue);
    });
  });
}
