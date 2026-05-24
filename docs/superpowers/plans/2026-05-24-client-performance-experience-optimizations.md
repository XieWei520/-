# Client Performance Experience Optimizations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Web cache startup cost, improve PWA workstation behavior, lower Web raster pressure, move native image preprocessing off the UI isolate, route large uploads through resumable multipart upload, and reduce list-row animation work in high-frequency IM views.

**Architecture:** Keep the existing Flutter/Riverpod/client boundaries. Add small testable policy APIs around platform behaviors, then update existing adapters and widgets to use those policies. Prefer existing upload, cache, motion, and telemetry primitives over introducing new dependencies.

**Tech Stack:** Flutter/Dart, IndexedDB through `package:web`, Riverpod, Flutter isolates via `compute`, existing multipart upload APIs, Flutter widget tests, static policy tests.

---

## File Structure

- Modify `lib/data/cache/indexed_db_web_chat_cache_store_adapter_base.dart`: add partition query and delete APIs to avoid requiring whole-store hydration.
- Modify `lib/data/cache/indexed_db_web_chat_cache_store_adapter_web.dart`: query `byUserChannelOrderSeq` with bounded IndexedDB cursors and delete old partition records by index.
- Modify `lib/data/cache/indexed_db_web_chat_cache_store_adapter_io.dart`: implement unavailable methods for non-Web platforms.
- Modify `lib/data/cache/indexed_db_web_chat_cache_store.dart`: remove full-cache hydration from hot reads/writes, keep only per-partition memory snapshots, and use adapter pagination.
- Modify `test/data/cache/indexed_db_web_chat_cache_store_test.dart`: add tests proving reads and writes use partition queries instead of `readAll`.
- Modify `web/manifest.json`: remove portrait lock so desktop Web and tablets can use landscape/wide workspaces.
- Modify `test/web_pwa_service_worker_test.dart` or add `test/web_manifest_policy_test.dart`: guard manifest orientation policy.
- Create `lib/widgets/liquid_glass_performance.dart`: pure policy for deciding whether expensive blur should be disabled.
- Modify `lib/widgets/liquid_glass_panel.dart`: use a solid/lightweight rendering branch when blur is disabled.
- Modify `lib/modules/chat/chat_frame_jank_monitor.dart`: expose a small controller/provider that can disable glass blur after repeated raster/total jank on Web.
- Create/modify tests under `test/widgets/` and `test/modules/chat/` for the fallback policy.
- Modify `lib/core/media/media_preprocess_service_io.dart`: run probe/decode/resize/re-encode in `compute` so native UI isolate is not blocked by large images.
- Modify `test/core/media/media_preprocess_service_io_test.dart`: verify isolate runner is invoked for probe and preprocess.
- Modify `lib/service/im/attachment_upload_pipeline.dart`: add size-aware upload routing so files over a threshold call a resumable uploader before ordinary upload.
- Modify `test/service/im/attachment_upload_pipeline_test.dart`: verify large files take the resumable path and small files keep the existing path.
- Modify `lib/widgets/wk_conversation_item.dart`: avoid animating every list row background/margin on ordinary rebuilds; animate only selection-state changes.
- Modify `lib/core/theme/chat_micro_interactions.dart` or existing motion tests if needed: make row animation respect `ChatMotion`.
- Modify `test/widgets/wk_conversation_item_parity_test.dart` or create focused tests for row animation scoping.

## Task 1: IndexedDB Partition Paging

**Files:**
- Modify: `lib/data/cache/indexed_db_web_chat_cache_store_adapter_base.dart`
- Modify: `lib/data/cache/indexed_db_web_chat_cache_store_adapter_web.dart`
- Modify: `lib/data/cache/indexed_db_web_chat_cache_store_adapter_io.dart`
- Modify: `lib/data/cache/indexed_db_web_chat_cache_store.dart`
- Test: `test/data/cache/indexed_db_web_chat_cache_store_test.dart`

- [ ] **Step 1: Add failing adapter-use tests**

Add a fake adapter that counts `readAll`, `readMessages`, and `deleteOldMessages` calls. Add tests:

```dart
test('indexeddb web chat cache store reads a partition without full hydration', () async {
  final adapter = QueryTrackingIndexedDbChatCacheAdapter();
  await adapter.applyChanges(
    upserts: [
      _record('u1', 'c1', 1, 'm1', 1, 1000),
      _record('u1', 'c1', 1, 'm2', 2, 2000),
      _record('u2', 'c1', 1, 'other', 1, 1000),
    ],
    deleteKeys: const <String>[],
  );
  final store = IndexedDbWebChatCacheStore(adapter: adapter);

  final cached = await store.readMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 1,
    limit: 1,
  );

  expect(cached.map((message) => message.messageID), ['m2']);
  expect(adapter.readMessagesCalls, 1);
  expect(adapter.readAllCalls, 0);
});

test('indexeddb web chat cache store trims a partition without scanning all records', () async {
  final adapter = QueryTrackingIndexedDbChatCacheAdapter();
  final store = IndexedDbWebChatCacheStore(
    adapter: adapter,
    maxMessagesPerChannel: 2,
  );

  await store.upsertMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 1,
    messages: [
      _message('m1', 1, 'u1', 'c1', 1000),
      _message('m2', 2, 'u1', 'c1', 2000),
      _message('m3', 3, 'u1', 'c1', 3000),
    ],
  );

  final cached = await store.readMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 1,
    limit: 20,
  );

  expect(cached.map((message) => message.messageID), ['m2', 'm3']);
  expect(adapter.deleteOldMessagesCalls, 1);
  expect(adapter.readAllCalls, 0);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected: FAIL because `IndexedDbChatCacheAdapter` has no partition query/delete methods.

- [ ] **Step 3: Add adapter APIs**

Add to `IndexedDbChatCacheAdapter`:

```dart
Future<List<Map<String, Object?>>> readMessages({
  required String uid,
  required String channelId,
  required int channelType,
  required int limit,
  int beforeOrderSeq = 0,
  int aroundOrderSeq = 0,
});

Future<void> deleteOldMessages({
  required String uid,
  required String channelId,
  required int channelType,
  required int keepLatest,
});
```

- [ ] **Step 4: Implement Web IndexedDB index queries**

Use `byUserChannelOrderSeq` and array keys `[uid, channelType, channelId, orderSeq]`. Implement latest and older reads with bounded cursor ranges and reverse direction. Implement around reads by combining a backward page before anchor and forward page after anchor.

- [ ] **Step 5: Update store to avoid full hydration**

Change `readMessages` to call adapter `readMessages`, decode only returned records, and cache only that partition. Change `upsertMessages` to merge with the current partition query result, persist upserts, then call `deleteOldMessages`.

- [ ] **Step 6: Run Task 1 tests**

Run:

```powershell
flutter test test/data/cache/indexed_db_web_chat_cache_store_test.dart
```

Expected: PASS.

## Task 2: Web Manifest Workstation Orientation

**Files:**
- Modify: `web/manifest.json`
- Test: `test/web_manifest_policy_test.dart`

- [ ] **Step 1: Add failing manifest policy test**

Create:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA manifest does not force portrait orientation', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(manifest['orientation'], isNot('portrait-primary'));
  });
}
```

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/web_manifest_policy_test.dart
```

Expected: FAIL while the manifest still says `portrait-primary`.

- [ ] **Step 3: Remove the orientation lock**

Delete the `orientation` field from `web/manifest.json`.

- [ ] **Step 4: Run Task 2 test**

Run:

```powershell
flutter test test/web_manifest_policy_test.dart
```

Expected: PASS.

## Task 3: Liquid Glass Low-Performance Fallback

**Files:**
- Create: `lib/widgets/liquid_glass_performance.dart`
- Modify: `lib/widgets/liquid_glass_panel.dart`
- Modify: `lib/modules/chat/chat_frame_jank_monitor.dart`
- Test: `test/widgets/liquid_glass_panel_test.dart`
- Test: `test/modules/chat/chat_frame_jank_monitor_test.dart`

- [ ] **Step 1: Add failing policy/widget tests**

Add tests that assert:

```dart
expect(
  shouldDisableLiquidGlassBlur(
    isWeb: true,
    disableAnimations: false,
    rasterJankCount: 3,
    totalJankCount: 0,
  ),
  isTrue,
);
```

And widget tests that pump `LiquidGlassPanel(disableBlur: true, child: Text('x'))` and expect no `BackdropFilter` is found.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/widgets/liquid_glass_panel_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart
```

Expected: FAIL because no policy or `disableBlur` path exists.

- [ ] **Step 3: Implement policy and panel fallback**

Create `shouldDisableLiquidGlassBlur`. Add optional `disableBlur` to `LiquidGlassPanel`; when true, render the same padding/shadow/decorated surface without `BackdropFilter`.

- [ ] **Step 4: Connect chat jank monitor**

Track repeated raster/total jank samples in `ChatFrameJankMonitor` and expose a provider/state that UI can use later. Keep behavior small: Web only, threshold 3 samples, no global side effects outside the provider.

- [ ] **Step 5: Run Task 3 tests**

Run:

```powershell
flutter test test/widgets/liquid_glass_panel_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart
```

Expected: PASS.

## Task 4: Native Image Preprocessing Off UI Isolate

**Files:**
- Modify: `lib/core/media/media_preprocess_service_io.dart`
- Test: `test/core/media/media_preprocess_service_io_test.dart`

- [ ] **Step 1: Add failing isolate runner tests**

Inject a compute runner into `DefaultMediaPreprocessService` and assert `probeImage` and `preprocessImage` invoke it for valid files.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/core/media/media_preprocess_service_io_test.dart
```

Expected: FAIL because no compute runner is injectable or used.

- [ ] **Step 3: Implement compute runner**

Add:

```dart
typedef MediaPreprocessComputeRunner = Future<R> Function<Q, R>(
  ComputeCallback<Q, R> callback,
  Q message,
);
```

Use `compute` by default. Move byte read, decode, resize, and encode into top-level functions with serializable request/response objects.

- [ ] **Step 4: Run Task 4 tests**

Run:

```powershell
flutter test test/core/media/media_preprocess_service_io_test.dart
```

Expected: PASS.

## Task 5: Size-Aware Multipart Upload Routing

**Files:**
- Modify: `lib/service/im/attachment_upload_pipeline.dart`
- Test: `test/service/im/attachment_upload_pipeline_test.dart`

- [ ] **Step 1: Add failing routing tests**

Add tests that configure `multipartUploadThresholdBytes: 64` and fake file lengths. Assert a 128-byte file uses `resumableUploader`, and a 32-byte file uses the existing `chatFileUploader`.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/service/im/attachment_upload_pipeline_test.dart
```

Expected: FAIL because `AttachmentUploadPipeline` has no threshold-aware resumable route.

- [ ] **Step 3: Implement route injection**

Add:

```dart
typedef ResumableChatFileUploader = Future<String> Function({
  required String filePath,
  required String channelId,
  required int channelType,
});
```

Add constructor fields `resumableChatFileUploader` and `multipartUploadThresholdBytes`. In `uploadLocalFile`, check file length first. If `length >= threshold` and a resumable uploader exists, use it. Otherwise keep existing upload behavior.

- [ ] **Step 4: Run Task 5 tests**

Run:

```powershell
flutter test test/service/im/attachment_upload_pipeline_test.dart
```

Expected: PASS.

## Task 6: Conversation Row Animation Scoping

**Files:**
- Modify: `lib/widgets/wk_conversation_item.dart`
- Test: `test/widgets/wk_conversation_item_parity_test.dart`

- [ ] **Step 1: Add failing animation scoping test**

Add a widget test that pumps a non-selected `WKConversationItem` and expects no `AnimatedContainer` in the ordinary row shell. Add a second test that selected state still renders an animated shell or active indicator.

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/widgets/wk_conversation_item_parity_test.dart
```

Expected: FAIL because every row uses `AnimatedContainer`.

- [ ] **Step 3: Implement scoped animation**

Use a plain `Container` for ordinary rows. Use `AnimatedContainer` only when `selected == true` or when the row is in explicit selection mode from the caller. Keep unread badge and send-status animations unchanged.

- [ ] **Step 4: Run Task 6 tests**

Run:

```powershell
flutter test test/widgets/wk_conversation_item_parity_test.dart
```

Expected: PASS.

## Final Verification

- [ ] Run focused tests:

```powershell
flutter test test/data/cache/indexed_db_web_chat_cache_store_test.dart test/web_manifest_policy_test.dart test/widgets/liquid_glass_panel_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart test/core/media/media_preprocess_service_io_test.dart test/service/im/attachment_upload_pipeline_test.dart test/widgets/wk_conversation_item_parity_test.dart
```

- [ ] Run analyzer:

```powershell
flutter analyze
```

- [ ] Report any failing pre-existing tests separately from new failures.

