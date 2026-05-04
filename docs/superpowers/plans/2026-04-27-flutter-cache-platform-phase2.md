# Flutter Cache And Platform Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce chat image decoded-memory risk and remove the direct `dart:io` dependency from shared platform detection.

**Architecture:** Keep the existing public singleton `MediaCacheManager.instance`, but change its L1 cache from entry-count eviction to decoded-byte budget eviction. Keep `PlatformUtils` as the call-site API, but implement it with Flutter `kIsWeb/defaultTargetPlatform` instead of importing `dart:io`.

**Tech Stack:** Flutter, Dart, `flutter_test`, `cached_network_image`.

---

### Task 1: Byte-Budgeted L1 Media Cache

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\cache\media_cache_manager.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\core\cache\media_cache_manager_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('evicts least recently used entries when decoded byte budget is exceeded', () {
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
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/core/cache/media_cache_manager_test.dart`

Expected: FAIL because `MediaCacheManager.forTesting`, `estimatedBytes`, and `l1Bytes` do not exist.

- [ ] **Step 3: Implement the minimal cache model**

Implement `_L1MediaCacheEntry`, `defaultMaxL1Bytes`, `defaultEstimatedDecodedBytes`, `l1Bytes`, `forTesting`, and byte-budget eviction in `putToL1`.

- [ ] **Step 4: Wire widget insertion to byte estimates**

In `CachedMediaImage.imageBuilder`, call `putToL1(cacheKey, imageProvider, estimatedBytes: MediaCacheManager.estimateDecodedBytes(width: maxWidth, height: maxHeight))`.

- [ ] **Step 5: Run GREEN**

Run: `flutter test test/core/cache/media_cache_manager_test.dart`

Expected: PASS.

### Task 2: Web-Safe PlatformUtils

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\utils\platform_utils.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\core\utils\platform_utils_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('PlatformUtils source does not import dart:io', () {
  final source = File('lib/core/utils/platform_utils.dart').readAsStringSync();
  expect(source, isNot(contains("import 'dart:io'")));
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/core/utils/platform_utils_test.dart`

Expected: FAIL because `platform_utils.dart` currently imports `dart:io`.

- [ ] **Step 3: Replace implementation**

Use `package:flutter/foundation.dart` and switch on `defaultTargetPlatform`. Keep the existing getters: `isWeb`, `isAndroid`, `isIOS`, `isMacOS`, `isWindows`, `isLinux`, `isMobile`, `isDesktop`, `platformName`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/core/utils/platform_utils_test.dart`

Expected: PASS.

### Task 3: Combined Verification

**Files:**
- Verify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\cache\media_cache_manager.dart`
- Verify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\utils\platform_utils.dart`

- [ ] **Step 1: Format**

Run: `dart format lib/core/cache/media_cache_manager.dart lib/core/utils/platform_utils.dart test/core/cache/media_cache_manager_test.dart test/core/utils/platform_utils_test.dart`

Expected: format completes successfully.

- [ ] **Step 2: Analyze**

Run: `dart analyze lib/core/cache/media_cache_manager.dart lib/core/utils/platform_utils.dart test/core/cache/media_cache_manager_test.dart test/core/utils/platform_utils_test.dart`

Expected: `No issues found!`

- [ ] **Step 3: Run targeted tests**

Run: `flutter test test/core/cache/media_cache_manager_test.dart test/core/utils/platform_utils_test.dart`

Expected: all tests pass.
