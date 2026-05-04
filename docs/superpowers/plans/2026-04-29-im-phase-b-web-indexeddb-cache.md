# IM Phase B Web IndexedDB Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Web-only chat cache boundary that can later be backed by IndexedDB, then wire Web history fallback through it without changing native behavior.

**Architecture:** Keep `ChatHistoryGateway` as the existing history API, but inject a `WebChatCacheStore` into `WkImChatHistoryGateway`. The first production-safe slice writes successful Web remote history pages to the cache and reads cache only when remote sync fails or auth is missing; native platforms keep the current SDK path.

**Tech Stack:** Flutter, Dart conditional imports, WuKongIM SDK `WKMsg`, Riverpod tests, later Web IndexedDB implementation with `dart:js_interop`.

---

### Task 1: Cache Store Contract

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_memory.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\cache\web_chat_cache_store_contract_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('memory web chat cache stores latest messages per channel', () async {
  final store = MemoryWebChatCacheStore();
  final messages = [
    WKMsg()
      ..messageID = 'm1'
      ..channelID = 'c1'
      ..channelType = 1
      ..orderSeq = 1000
      ..contentType = 1,
  ];

  await store.upsertMessages(
    channelId: 'c1',
    channelType: 1,
    messages: messages,
  );

  final cached = await store.readMessages(
    channelId: 'c1',
    channelType: 1,
    limit: 20,
  );

  expect(cached.single.messageID, 'm1');
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\data\cache\web_chat_cache_store_contract_test.dart`

Expected: FAIL because cache store classes do not exist.

- [ ] **Step 3: Implement minimal memory store**

Create `WebChatCacheStore` and `MemoryWebChatCacheStore`. Store `WKMsg` instances in memory, dedupe by `messageID/clientMsgNO/orderSeq`, sort by `orderSeq` ascending, and cap per channel to 500 messages.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\data\cache\web_chat_cache_store_contract_test.dart`

Expected: PASS.

### Task 2: ChatHistoryGateway Cache Fallback

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\chat_history_gateway.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\providers\chat_history_gateway_web_cache_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('web direct history sync writes successful remote latest page to cache', () async {
  final cache = MemoryWebChatCacheStore();
  final gateway = WkImChatHistoryGateway(
    useDirectRemoteSync: true,
    webCacheStore: cache,
    authTokenProvider: () => 'token',
    syncChannelMessages: (...) async => remoteResult,
  );

  await gateway.loadLatest(channelId: 'c1', channelType: 1, limit: 20);
  final cached = await cache.readMessages(channelId: 'c1', channelType: 1, limit: 20);

  expect(cached, isNotEmpty);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\data\providers\chat_history_gateway_web_cache_test.dart`

Expected: FAIL because `webCacheStore` is not accepted.

- [ ] **Step 3: Implement fallback**

Inject `WebChatCacheStore?`; on Web/direct remote success call `upsertMessages`. If remote sync cannot run or throws, call `readMessages` with the same channel and limit. Keep native `_fetch` path unchanged.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\data\providers\chat_history_gateway_web_cache_test.dart test\data\providers\chat_history_gateway_test.dart`

Expected: PASS.

### Task 3: Future IndexedDB Adapter

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_stub.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\cache\web_chat_cache_store_web.dart`

- [ ] **Step 1: Implement conditional factory**

Create `createWebChatCacheStore()` with conditional import. Stub returns `MemoryWebChatCacheStore`; Web adapter initially delegates to `MemoryWebChatCacheStore` behind the same interface until the `dart:js_interop` IndexedDB bridge is implemented.

- [ ] **Step 2: Add platform safety test**

Run: `flutter test test\data\cache\web_chat_cache_store_contract_test.dart`

Expected: PASS and shared interface does not import `dart:html` or `dart:io`.

### Task 4: Verification

Run:

```powershell
dart analyze lib\data\cache\web_chat_cache_store.dart lib\data\cache\web_chat_cache_store_memory.dart lib\data\providers\chat_history_gateway.dart test\data\cache\web_chat_cache_store_contract_test.dart test\data\providers\chat_history_gateway_web_cache_test.dart
flutter test test\data\cache\web_chat_cache_store_contract_test.dart test\data\providers\chat_history_gateway_web_cache_test.dart test\data\providers\chat_history_gateway_test.dart
```

Expected: analyze has no issues and all tests pass.
