# Phase 3：大历史、底层存储与 Web 突破 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver Web IndexedDB persistence, harden large-history SQLite pagination on native, and reduce image-heavy chat list jank for Phase 3 acceptance.

**Architecture:** Keep the existing `ChatHistoryGateway` / `MessageRepository` boundary. Implement Web persistence as a conditional-IO-friendly cache store behind `WebChatCacheStore`, harden native SQLite query paths through explicit index and telemetry checks, and confine image decode/jank work to the chat bubble/media layers so message loading behavior stays stable.

**Tech Stack:** Flutter, Dart, Riverpod, `package:web` + `dart:js_interop` for Web IndexedDB, `sqflite`/SDK SQLite on native, existing telemetry (`MessageQueryTelemetry` / `RealtimeRolloutTelemetry`), and widget tests.

---

## File Structure

### Local workspace files

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_factory.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\chat_history_gateway.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\conversation_provider.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\wk_message_repository.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\repository_providers.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\cache\media_cache_manager.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_message_list_item.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\platform\platform_capabilities.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_base\db\db_helper.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_base\db\database_migration.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\telemetry\message_query_jank_monitor.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\indexed_db_web_chat_cache_store_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\web_chat_cache_store_contract_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\chat_history_gateway_web_cache_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\chat_history_gateway_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\native_message_repository_index_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\core\cache\media_cache_manager_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\telemetry\message_query_jank_monitor_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\conversation_provider_telemetry_test.dart`

### SDK / reference files (read-only guidance)

- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\message.dart`
- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\const.dart`
- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\wk_db_helper.dart`
- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\assets\202604111000.sql`
- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\assets\202604200930.sql`
- Reference: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\assets\202604251100.sql`

---

### Task 1: Add the Web cache factory and IndexedDB-backed store boundary

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_factory.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\indexed_db_web_chat_cache_store.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\web_chat_cache_store_contract_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\indexed_db_web_chat_cache_store_test.dart`

- [ ] **Step 1: Write the failing contract tests**

Add tests that assert the cache store factory exists, that a store can upsert/read `latest`, `older`, and `around` pages, and that the Web store preserves channel/user isolation. Use a `WKMsg` fixture with `messageID`, `clientMsgNO`, `messageSeq`, `orderSeq`, and `timestamp` set.

```dart
test('indexeddb web chat cache store reads latest and older pages in order', () async {
  final store = createWebChatCacheStoreForTesting(useIndexedDb: true);

  await store.upsertMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 2,
    messages: [
      _message('m1', clientMsgNo: 'c1-1', messageSeq: 1, orderSeq: 1000),
      _message('m2', clientMsgNo: 'c1-2', messageSeq: 2, orderSeq: 2000),
      _message('m3', clientMsgNo: 'c1-3', messageSeq: 3, orderSeq: 3000),
    ],
  );

  final latest = await store.readMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 2,
    limit: 2,
  );
  final older = await store.readMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 2,
    limit: 2,
    beforeOrderSeq: 3000,
  );

  expect(latest.map((m) => m.messageID), ['m2', 'm3']);
  expect(older.map((m) => m.messageID), ['m1', 'm2']);
});
```

- [ ] **Step 2: Run the focused cache tests and verify RED**

Run:

```powershell
flutter test test\data\cache\web_chat_cache_store_contract_test.dart test\data\cache\indexed_db_web_chat_cache_store_test.dart
```

Expected: FAIL because the factory and IndexedDB store do not exist yet.

- [ ] **Step 3: Implement the minimal memory-compatible boundary**

Create `web_chat_cache_store_factory.dart` with a `createWebChatCacheStore()` helper that returns the IndexedDB store on Web and the memory store elsewhere. Keep `web_chat_cache_store.dart` as the interface, and extend the contract to include `uid` in read/write methods so the cache can isolate by user.

- [ ] **Step 4: Implement the minimal IndexedDB adapter**

Create `indexed_db_web_chat_cache_store.dart` using `package:web/web.dart`, `dart:js_interop`, and `dart:js_interop_unsafe`. Use one database name and one `messages` object store, and store raw field maps rather than Dart objects. Start with these rules:

- key: `uid|channelType|channelId|identity`
- identity priority: `messageID` > `clientMsgNO` > `messageSeq` > `orderSeq`
- page ordering: ascending `orderSeq`
- retention: trim per channel to the newest 2000 records

If IndexedDB access fails, fall back to memory store behavior without throwing.

- [ ] **Step 5: Run the focused cache tests and verify GREEN**

Run:

```powershell
flutter test test\data\cache\web_chat_cache_store_contract_test.dart test\data\cache\indexed_db_web_chat_cache_store_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong add `
  lib/data/cache/web_chat_cache_store.dart `
  lib/data/cache/web_chat_cache_store_memory.dart `
  lib/data/cache/web_chat_cache_store_factory.dart `
  lib/data/cache/indexed_db_web_chat_cache_store.dart `
  test/data/cache/web_chat_cache_store_contract_test.dart `
  test/data/cache/indexed_db_web_chat_cache_store_test.dart

git -C C:\Users\COLORFUL\Desktop\WuKong commit -m "feat: add web indexeddb chat cache store"
```

Expected: commit succeeds.

---

### Task 2: Wire Web history to IndexedDB and keep native repository behavior intact

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\chat_history_gateway.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\conversation_provider.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\wk_message_repository.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\repository_providers.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\chat_history_gateway_web_cache_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\chat_history_gateway_test.dart`

- [ ] **Step 1: Write the failing gateway tests**

Add tests that assert:

1. Web direct sync writes the remote page into the persistent store.
2. Web direct sync falls back to IndexedDB when remote fetch fails.
3. `clearUser(uid)` clears only the current user's cache partition.
4. Native `WkMessageRepository` still delegates to the gateway without any Web-only branching.

```dart
test('web direct history sync falls back to indexeddb when remote sync fails', () async {
  final cache = createWebChatCacheStoreForTesting(useIndexedDb: false);
  await cache.upsertMessages(
    uid: 'u1',
    channelId: 'c1',
    channelType: 1,
    messages: [_message('cached', orderSeq: 7000)],
  );

  final gateway = WkImChatHistoryGateway(
    useDirectRemoteSync: true,
    webCacheStore: cache,
    authTokenProvider: () => 'token',
    syncChannelMessages: (...) async => throw StateError('network down'),
  );

  final messages = await gateway.loadLatest(channelId: 'c1', channelType: 1, limit: 20);
  expect(messages.single.messageID, 'cached');
});
```

- [ ] **Step 2: Run the focused provider tests and verify RED**

Run:

```powershell
flutter test test\data\providers\chat_history_gateway_web_cache_test.dart test\data\providers\chat_history_gateway_test.dart
```

Expected: FAIL because the new persistent factory and `uid`-aware cache contract are not wired yet.

- [ ] **Step 3: Update the gateway to persist and restore through the cache**

In `chat_history_gateway.dart`, create the Web cache once through the factory, pass `uid` into `readMessages` / `upsertMessages` / `clearUser`, and keep the current remote/local branch split intact. Preserve the current fallback order: remote success -> cache write, remote failure/auth missing -> cache read, native -> SDK path.

- [ ] **Step 4: Wire provider injection without broadening scope**

Update `chatHistoryGatewayProvider` in `conversation_provider.dart` and `messageRepositoryProvider` in `repository_providers.dart` so the Web gateway gets the cache store from the new factory while native repositories remain on the existing SDK path.

- [ ] **Step 5: Run the focused provider tests and verify GREEN**

Run:

```powershell
flutter test test\data\providers\chat_history_gateway_web_cache_test.dart test\data\providers\chat_history_gateway_test.dart test\data\providers\conversation_provider_telemetry_test.dart test\data\providers\message_list_repository_boundary_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 2**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong add `
  lib/data/providers/chat_history_gateway.dart `
  lib/data/providers/conversation_provider.dart `
  lib/data/repositories/wk_message_repository.dart `
  lib/data/repositories/repository_providers.dart `
  test/data/providers/chat_history_gateway_web_cache_test.dart `
  test/data/providers/chat_history_gateway_test.dart

git -C C:\Users\COLORFUL\Desktop\WuKong commit -m "feat: persist web chat history through gateway"
```

Expected: commit succeeds.

---

### Task 3: Harden native SQLite large-history pagination and index coverage

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_base\db\db_helper.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_base\db\database_migration.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\wk_message_repository.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\conversation_provider.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\native_message_repository_index_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\conversation_provider_telemetry_test.dart`

- [ ] **Step 1: Write the failing index tests**

Add a test that asserts the native message database setup contains the required message indexes as idempotent `CREATE INDEX IF NOT EXISTS` statements, and add a repository test that confirms `loadLatest`, `loadOlder`, and `loadAround` continue to call the expected query modes.

```dart
test('native message database setup includes large-history indexes', () {
  final script = _readDbHelperSource();

  expect(script, contains('CREATE INDEX IF NOT EXISTS idx_message_channel_seq'));
  expect(script, contains('CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq'));
  expect(script, contains('CREATE INDEX IF NOT EXISTS idx_message_client_msg_no'));
  expect(script, contains('CREATE INDEX IF NOT EXISTS idx_message_message_id'));
});
```

- [ ] **Step 2: Run the focused native tests and verify RED**

Run:

```powershell
flutter test test\data\providers\native_message_repository_index_test.dart test\data\providers\conversation_provider_telemetry_test.dart test\data\providers\message_list_repository_boundary_test.dart
```

Expected: FAIL because the native index assertions are not yet satisfied.

- [ ] **Step 3: Add missing native indexes with idempotent migrations**

In `db_helper.dart`, add the missing message table indexes using `CREATE INDEX IF NOT EXISTS` in the same style as the existing prohibit-word indexes. If the SDK already creates an equivalent index in its own assets, keep the app-side migration defensive and idempotent rather than duplicating schema semantics.

- [ ] **Step 4: Keep query telemetry explicit for paging modes**

In `conversation_provider.dart`, make sure the `MessageListNotifier` paging path still records `latest_page`, `older_page`, and `around_page` query durations through `MessageQueryTelemetry.recordSqlitePageQuery(duration, mode: ...)`, so large-history regressions are visible.

- [ ] **Step 5: Run the focused native tests and verify GREEN**

Run:

```powershell
flutter test test\data\providers\native_message_repository_index_test.dart test\data\providers\conversation_provider_telemetry_test.dart test\data\providers\message_list_repository_boundary_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong add `
  lib/wukong_base/db/db_helper.dart `
  lib/wukong_base/db/database_migration.dart `
  lib/data/repositories/wk_message_repository.dart `
  lib/data/providers/conversation_provider.dart `
  test/data/providers/native_message_repository_index_test.dart `
  test/data/providers/conversation_provider_telemetry_test.dart

git -C C:\Users\COLORFUL\Desktop\WuKong commit -m "perf: harden native message paging indexes"
```

Expected: commit succeeds.

---

### Task 4: Reduce image-heavy chat list decode pressure

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\cache\media_cache_manager.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\widgets\chat_message_list_item.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\core\cache\media_cache_manager_test.dart`

- [ ] **Step 1: Write the failing media decode tests**

Add tests that assert image decode width/height is capped for list bubbles and that browser-rendered Web images continue using `Image.network` while native paths use `ResizeImage` / `CachedMediaImage` limits. Also extend the list-item test to assert media-heavy content types are marked keep-alive while text items are not.

```dart
test('message height estimator keeps image decode budget bounded', () {
  final height = MessageHeightEstimator.estimate(
    WkMessageContentType.image,
    mediaWidth: 4000,
    mediaHeight: 3000,
  );

  expect(height, lessThanOrEqualTo(320.0));
});
```

- [ ] **Step 2: Run the focused media tests and verify RED**

Run:

```powershell
flutter test test\core\cache\media_cache_manager_test.dart
```

Expected: FAIL because the new decode-budget assertion is not yet true everywhere in the chat bubble flow.

- [ ] **Step 3: Limit list-item decode width in the chat bubble**

In `message_bubble.dart`, keep the existing `resolveMediaDecodeRequest(...)` flow but cap list/bubble decode requests to the chat-list target size rather than the original image dimensions. Reuse the existing `CachedMediaImage(maxWidth/maxHeight)` parameters and avoid touching the full-screen viewer path.

- [ ] **Step 4: Keep list items alive only for media-heavy bubbles**

In `chat_message_list_item.dart`, preserve the existing `MessageHeightEstimator.shouldKeepAlive(...)` logic and adjust any list measurement keys only if needed for image/video/gif/file content. Do not broaden keep-alive to text or system notices.

- [ ] **Step 5: Run the focused media tests and verify GREEN**

Run:

```powershell
flutter test test\core\cache\media_cache_manager_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 4**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong add `
  lib/core/cache/media_cache_manager.dart `
  lib/widgets/message_bubble.dart `
  lib/modules/chat/widgets/chat_message_list_item.dart `
  test/core/cache/media_cache_manager_test.dart

git -C C:\Users\COLORFUL\Desktop\WuKong commit -m "perf: cap chat image decode cost"
```

Expected: commit succeeds.

---

### Task 5: Add Jank timing monitoring for long chat scrolling

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\telemetry\message_query_jank_monitor.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\realtime\telemetry\realtime_rollout_telemetry.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\realtime\telemetry\realtime_rollout_telemetry_provider.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\telemetry\message_query_jank_monitor_test.dart`

- [ ] **Step 1: Write the failing Jank monitor tests**

Add tests that feed fake `FrameTiming` values into a pure helper and assert frames over threshold are counted while normal frames are ignored.

```dart
test('counts only frames above the jank threshold', () {
  final monitor = MessageQueryJankMonitor.forTesting(
    onWarning: (event) => recorded.add(event),
  );

  monitor.recordTimings([
    FakeFrameTiming(buildMs: 4, rasterMs: 4),
    FakeFrameTiming(buildMs: 12, rasterMs: 9),
  ]);

  expect(recorded, hasLength(1));
});
```

- [ ] **Step 2: Run the focused Jank tests and verify RED**

Run:

```powershell
flutter test test\telemetry\message_query_jank_monitor_test.dart
```

Expected: FAIL because the helper does not exist yet.

- [ ] **Step 3: Implement the Jank monitor helper**

Create a small helper that can register `SchedulerBinding.instance.addTimingsCallback`, count build/raster thresholds, and emit telemetry records only in debug/profile or through a test-injectable callback. Keep release behavior quiet unless explicitly enabled.

- [ ] **Step 4: Wire telemetry initialization without changing chat behavior**

Expose the monitor from `realtime_rollout_telemetry_provider.dart` or an adjacent provider so the chat flow can opt into monitoring without changing message loading semantics.

- [ ] **Step 5: Run the focused Jank tests and verify GREEN**

Run:

```powershell
flutter test test\telemetry\message_query_jank_monitor_test.dart test\data\providers\conversation_provider_telemetry_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 5**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong add `
  lib/data/telemetry/message_query_jank_monitor.dart `
  lib/realtime/telemetry/realtime_rollout_telemetry.dart `
  lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart `
  test/telemetry/message_query_jank_monitor_test.dart

git -C C:\Users\COLORFUL\Desktop\WuKong commit -m "feat: add chat jank timing monitor"
```

Expected: commit succeeds.

---

### Task 6: Final verification and Phase 3 acceptance check

**Files:**
- Verify all files changed in `C:\Users\COLORFUL\Desktop\WuKong`.

- [ ] **Step 1: Run the focused Web cache tests**

```powershell
flutter test test\data\cache\web_chat_cache_store_contract_test.dart test\data\cache\indexed_db_web_chat_cache_store_test.dart test\data\providers\chat_history_gateway_web_cache_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run the focused native and telemetry tests**

```powershell
flutter test test\data\providers\chat_history_gateway_test.dart test\data\providers\conversation_provider_telemetry_test.dart test\data\providers\message_list_repository_boundary_test.dart test\data\providers\native_message_repository_index_test.dart test\core\cache\media_cache_manager_test.dart test\telemetry\message_query_jank_monitor_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer on touched Dart files**

```powershell
flutter analyze
```

Expected: PASS, or only pre-existing unrelated warnings explicitly documented before merge.

- [ ] **Step 4: Run the acceptance manual checks**

1. Web open a conversation, load history, refresh, and confirm recent messages still appear from IndexedDB.
2. Open a long history on native and confirm paging remains stable while telemetry records `latest_page`, `older_page`, and `around_page` timings.
3. Scroll an image-heavy chat list and confirm decode width is bounded and no obvious frame jank spikes appear in the monitor logs.

- [ ] **Step 5: Record phase completion**

Update the phase notes or handoff artifact with the exact test commands, browser/manual verification notes, and any remaining follow-up for Phase 4.

---

## Self-Review

- Spec coverage:
  - Web IndexedDB persistence: Tasks 1 and 2.
  - Native large-history SQLite hardening: Task 3.
  - Image decode pressure and jank monitoring: Tasks 4 and 5.
  - Acceptance validation: Task 6.

- Placeholder scan:
  - No TBD/TODO placeholders remain.
  - All tasks name concrete files, tests, and commands.

- Type consistency:
  - `WebChatCacheStore` is the shared boundary.
  - `createWebChatCacheStore()` is the factory entry point used by the gateway/provider layer.
  - `MessageQueryTelemetry.recordSqlitePageQuery(duration, {required String mode})` stays the telemetry contract for paging.
  - `MessageQueryJankMonitor` is the helper name used consistently in tests and provider wiring.
