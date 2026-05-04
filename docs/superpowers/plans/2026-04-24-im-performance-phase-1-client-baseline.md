# IM Performance Phase 1 Client Hot Paths And Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Subagent requirement from user:** use at least GPT-5.3-codex and `xhigh` reasoning for every subagent. In this Codex tool environment, the available explicit override shown to the parent agent is `gpt-5.5`; if `GPT-5.3-codex` is not selectable, use the highest available compliant/equivalent model and set `reasoning_effort: "xhigh"`. Do not silently dispatch a weaker model.

**Goal:** Reduce Flutter conversation/chat hot-path work and create a repeatable production baseline collector before higher-risk backend or Nginx tuning.

**Architecture:** Phase 1 stays low-risk and local-first: add a bounded conversation metadata resolver to coalesce duplicate user/group display fetches, replace repeated message duplicate scans with an indexed matcher, and add a read-only SSH baseline script. Backend metrics middleware, Nginx changes, and load-test expansion are handled by follow-up plans after this baseline exists.

**Tech Stack:** Flutter, Dart, flutter_test, Riverpod, WKIM Flutter SDK, PowerShell, SSH, Docker read-only inspection

---

## Scope Note

The approved design spans independent subsystems: Flutter client, backend metrics, Nginx edge policy, database/Redis observation, and load testing. This plan covers the first executable phase only: Flutter hot-path reductions plus a production baseline collector. It produces working, testable improvements without touching production service behavior. Backend metrics/Nginx/load-test implementation should be planned after this phase creates a safe baseline and after deciding how remote backend source will be versioned.

## File Structure And Ownership

- Create: `lib/modules/conversation/conversation_metadata_resolver.dart` - in-flight coalescing and TTL cache for personal user and group display metadata.
- Modify: `lib/modules/conversation/conversation_list_page.dart` - wires the metadata resolver into existing row resolution.
- Modify: `lib/modules/conversation/conversation_list_item_loader.dart` - normalizes request-key inputs to avoid churn.
- Create: `test/modules/conversation/conversation_metadata_resolver_test.dart` - tests coalescing, cache expiry, failure recovery, clear behavior, and empty IDs.
- Modify: `test/modules/conversation/conversation_list_item_loader_test.dart` - tests stable request key normalization.
- Create: `lib/modules/chat/chat_message_match_index.dart` - indexed lookup for `WKMsg` equivalence.
- Modify: `lib/modules/chat/chat_viewport_controller.dart` - delegates equivalence to indexed matcher.
- Modify: `lib/modules/conversation/chat_timeline_controller.dart` - uses indexed matcher for timeline upsert lookup.
- Modify: `lib/data/providers/conversation_provider.dart` - uses indexed matcher for message merge duplicate detection.
- Modify: `test/modules/chat/chat_viewport_controller_test.dart` - tests indexed match semantics and no duplicate delivery updates.
- Create: `scripts/ops/collect_im_performance_baseline.ps1` - read-only production baseline collector.

## Task 1: Add Conversation Metadata Resolver

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_metadata_resolver.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\conversation\conversation_metadata_resolver_test.dart`

- [ ] **Step 1: Write failing resolver tests**

Create `test/modules/conversation/conversation_metadata_resolver_test.dart` with:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_metadata_resolver.dart';

void main() {
  group('ConversationMetadataResolver', () {
    test('coalesces duplicate in-flight personal loads', () async {
      final completer = Completer<UserInfo?>();
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (uid) {
          calls += 1;
          return completer.future;
        },
        groupLoader: (_) async => null,
      );

      final first = resolver.loadPersonal('u_alice');
      final second = resolver.loadPersonal(' u_alice ');

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      completer.complete(UserInfo(uid: 'u_alice', name: 'Alice'));
      expect((await second)?.name, 'Alice');
      expect(calls, 1);
    });

    test('serves cached personal loads until ttl expires', () async {
      var now = DateTime.utc(2026, 4, 24, 10);
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        ttl: const Duration(minutes: 5),
        now: () => now,
        personalLoader: (uid) async {
          calls += 1;
          return UserInfo(uid: uid, name: 'Alice $calls');
        },
        groupLoader: (_) async => null,
      );

      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 1');
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 1');
      expect(calls, 1);

      now = now.add(const Duration(minutes: 6));
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Alice 2');
      expect(calls, 2);
    });

    test('does not cache failed personal loads', () async {
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async {
          calls += 1;
          if (calls == 1) throw StateError('temporary failure');
          return UserInfo(uid: 'u_alice', name: 'Recovered Alice');
        },
        groupLoader: (_) async => null,
      );

      expect(await resolver.loadPersonal('u_alice'), isNull);
      expect((await resolver.loadPersonal('u_alice'))?.name, 'Recovered Alice');
      expect(calls, 2);
    });

    test('coalesces and clears group loads', () async {
      var calls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async => null,
        groupLoader: (groupNo) async {
          calls += 1;
          return GroupInfo(groupNo: groupNo, name: 'Group $calls');
        },
      );

      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 1');
      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 1');
      expect(calls, 1);

      resolver.clear();
      expect((await resolver.loadGroup('g_demo'))?.name, 'Group 2');
      expect(calls, 2);
    });

    test('empty ids return null without calling loaders', () async {
      var personalCalls = 0;
      var groupCalls = 0;
      final resolver = ConversationMetadataResolver(
        personalLoader: (_) async {
          personalCalls += 1;
          return null;
        },
        groupLoader: (_) async {
          groupCalls += 1;
          return null;
        },
      );

      expect(await resolver.loadPersonal('   '), isNull);
      expect(await resolver.loadGroup(''), isNull);
      expect(personalCalls, 0);
      expect(groupCalls, 0);
    });
  });
}
```

- [ ] **Step 2: Run resolver tests and verify they fail because the file under test is missing**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/conversation/conversation_metadata_resolver_test.dart
```

Expected result: FAIL with an import error for `conversation_metadata_resolver.dart`.

- [ ] **Step 3: Implement resolver**

Create `lib/modules/conversation/conversation_metadata_resolver.dart` with:

```dart
import '../../data/models/group.dart';
import '../../data/models/user.dart';

typedef ConversationPersonalLoader = Future<UserInfo?> Function(String uid);
typedef ConversationGroupLoader = Future<GroupInfo?> Function(String groupNo);
typedef ConversationMetadataClock = DateTime Function();

class ConversationMetadataResolver {
  ConversationMetadataResolver({
    required ConversationPersonalLoader personalLoader,
    required ConversationGroupLoader groupLoader,
    this.ttl = const Duration(minutes: 10),
    ConversationMetadataClock? now,
  }) : _personalLoader = personalLoader,
       _groupLoader = groupLoader,
       _now = now ?? DateTime.now;

  final ConversationPersonalLoader _personalLoader;
  final ConversationGroupLoader _groupLoader;
  final ConversationMetadataClock _now;
  final Duration ttl;

  final Map<String, Future<UserInfo?>> _personalInFlight = <String, Future<UserInfo?>>{};
  final Map<String, _CacheEntry<UserInfo>> _personalCache = <String, _CacheEntry<UserInfo>>{};
  final Map<String, Future<GroupInfo?>> _groupInFlight = <String, Future<GroupInfo?>>{};
  final Map<String, _CacheEntry<GroupInfo>> _groupCache = <String, _CacheEntry<GroupInfo>>{};

  Future<UserInfo?> loadPersonal(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty) return Future<UserInfo?>.value(null);
    final cached = _readCache(_personalCache, normalized);
    if (cached != null) return Future<UserInfo?>.value(cached);
    final existing = _personalInFlight[normalized];
    if (existing != null) return existing;
    final future = _personalLoader(normalized)
        .then((value) {
          if (value != null) {
            _personalCache[normalized] = _CacheEntry<UserInfo>(value: value, expiresAt: _now().add(ttl));
          }
          return value;
        }, onError: (_, _) => null)
        .whenComplete(() => _personalInFlight.remove(normalized));
    _personalInFlight[normalized] = future;
    return future;
  }

  Future<GroupInfo?> loadGroup(String groupNo) {
    final normalized = groupNo.trim();
    if (normalized.isEmpty) return Future<GroupInfo?>.value(null);
    final cached = _readCache(_groupCache, normalized);
    if (cached != null) return Future<GroupInfo?>.value(cached);
    final existing = _groupInFlight[normalized];
    if (existing != null) return existing;
    final future = _groupLoader(normalized)
        .then((value) {
          if (value != null) {
            _groupCache[normalized] = _CacheEntry<GroupInfo>(value: value, expiresAt: _now().add(ttl));
          }
          return value;
        }, onError: (_, _) => null)
        .whenComplete(() => _groupInFlight.remove(normalized));
    _groupInFlight[normalized] = future;
    return future;
  }

  void clear() {
    _personalInFlight.clear();
    _personalCache.clear();
    _groupInFlight.clear();
    _groupCache.clear();
  }

  T? _readCache<T>(Map<String, _CacheEntry<T>> cache, String key) {
    final entry = cache[key];
    if (entry == null) return null;
    if (!_now().isBefore(entry.expiresAt)) {
      cache.remove(key);
      return null;
    }
    return entry.value;
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});
  final T value;
  final DateTime expiresAt;
}
```

- [ ] **Step 4: Run resolver tests and verify they pass**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/conversation/conversation_metadata_resolver_test.dart
```

Expected result: PASS.

- [ ] **Step 5: Commit Task 1**

Run:

```powershell
git add lib/modules/conversation/conversation_metadata_resolver.dart test/modules/conversation/conversation_metadata_resolver_test.dart
git commit -m "feat: add conversation metadata resolver"
```

## Task 2: Wire Metadata Resolver Into Conversation Rows

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_item_loader.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\conversation\conversation_list_item_loader_test.dart`

- [ ] **Step 1: Add a failing request-key normalization test**

Append this test inside the existing group in `test/modules/conversation/conversation_list_item_loader_test.dart`:

```dart
    test('identical preferred metadata keeps the request key stable', () {
      final first = buildConversationListItemRequestKey(
        channelId: 'u_alice',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 0,
        lastMsgTimestamp: 100,
        preferredTitle: 'Alice',
        preferredAvatarUrl: 'https://example.com/a.png',
        preferredCategory: 'customer_service',
        preferredVipLevel: 1,
        refreshToken: 7,
      );
      final second = buildConversationListItemRequestKey(
        channelId: ' u_alice ',
        channelType: 1,
        clientMsgNo: ' client_1 ',
        unreadCount: 0,
        lastMsgTimestamp: 100,
        preferredTitle: ' Alice ',
        preferredAvatarUrl: ' https://example.com/a.png ',
        preferredCategory: ' CUSTOMER_SERVICE ',
        preferredVipLevel: 1,
        refreshToken: 7,
      );

      expect(first, second);
    });
```

- [ ] **Step 2: Run the request-key test and verify it fails**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/conversation/conversation_list_item_loader_test.dart
```

Expected result: FAIL because `clientMsgNo` or `preferredAvatarUrl` normalization is incomplete.

- [ ] **Step 3: Normalize request-key inputs**

In `lib/modules/conversation/conversation_list_item_loader.dart`, replace `buildConversationListItemRequestKey` with:

```dart
@visibleForTesting
String buildConversationListItemRequestKey({
  required String channelId,
  required int channelType,
  String? clientMsgNo,
  required int unreadCount,
  required int lastMsgTimestamp,
  String? preferredTitle,
  String? preferredAvatarUrl,
  String? preferredCategory,
  int preferredVipLevel = 0,
  required int refreshToken,
}) {
  return [
    channelType,
    channelId.trim(),
    clientMsgNo?.trim() ?? '',
    unreadCount,
    lastMsgTimestamp,
    preferredTitle?.trim() ?? '',
    preferredAvatarUrl?.trim() ?? '',
    preferredCategory?.trim().toLowerCase() ?? '',
    preferredVipLevel,
    refreshToken,
  ].join('|');
}
```

- [ ] **Step 4: Add resolver provider and pass it into row data resolution**

In `lib/modules/conversation/conversation_list_page.dart`, add:

```dart
import 'conversation_metadata_resolver.dart';
```

Add this provider after `conversationListItemLoaderProvider`:

```dart
final conversationMetadataResolverProvider =
    Provider.autoDispose<ConversationMetadataResolver>((ref) {
      final resolver = ConversationMetadataResolver(
        personalLoader: (uid) => UserApi.instance
            .getUserInfo(uid)
            .then<UserInfo?>((user) => user, onError: (_, _) => null),
        groupLoader: (groupNo) => GroupApi.instance
            .getGroupInfo(groupNo)
            .then<GroupInfo?>((group) => group, onError: (_, _) => null),
      );
      ref.onDispose(resolver.clear);
      return resolver;
    });
```

Replace `conversationListItemDataProvider` with:

```dart
final conversationListItemDataProvider = FutureProvider.autoDispose
    .family<WKConversationItemData, ConversationListItemRequest>((
      ref,
      request,
    ) {
      final loader = ref.watch(conversationListItemLoaderProvider);
      final metadataResolver = ref.watch(conversationMetadataResolverProvider);
      final currentUid = WKIM.shared.options.uid?.trim() ?? '';
      return loader.load(
        request.requestKey,
        () => resolveConversationListItemData(
          request,
          currentUid: currentUid,
          metadataResolver: metadataResolver,
        ),
      );
    });
```

- [ ] **Step 5: Extend `resolveConversationListItemData` to accept the resolver**

Change the signature to:

```dart
Future<WKConversationItemData> resolveConversationListItemData(
  ConversationListItemRequest request, {
  required String currentUid,
  Future<UserInfo?> Function(String uid)? personalUserInfoLoader,
  ConversationMetadataResolver? metadataResolver,
}) async {
```

Replace the personal fallback block with:

```dart
  Future<UserInfo?> personalInfoFuture = Future<UserInfo?>.value(null);
  if (shouldFetchPersonalConversationUserInfo(
    conversation: conversation,
    currentUid: currentUid,
    resolvedTitle: title,
  )) {
    if (personalUserInfoLoader != null) {
      personalInfoFuture = personalUserInfoLoader(
        conversation.channelID,
      ).then<UserInfo?>((user) => user, onError: (_, _) => null);
    } else if (metadataResolver != null) {
      personalInfoFuture = metadataResolver.loadPersonal(conversation.channelID);
    } else {
      personalInfoFuture = UserApi.instance
          .getUserInfo(conversation.channelID)
          .then<UserInfo?>((user) => user, onError: (_, _) => null);
    }
  }
```

Replace the group fallback block with:

```dart
  Future<GroupInfo?> groupInfoFuture = Future<GroupInfo?>.value(null);
  if (conversation.channelType == WKChannelType.group &&
      title == conversation.channelID) {
    if (metadataResolver != null) {
      groupInfoFuture = metadataResolver.loadGroup(conversation.channelID);
    } else {
      groupInfoFuture = GroupApi.instance
          .getGroupInfo(conversation.channelID)
          .then((group) => group, onError: (_, stackTrace) => null);
    }
  }
```

- [ ] **Step 6: Run targeted conversation tests**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/conversation/conversation_list_item_loader_test.dart test/modules/conversation/conversation_metadata_resolver_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart
```

Expected result: PASS.

- [ ] **Step 7: Commit Task 2**

Run:

```powershell
git add lib/modules/conversation/conversation_list_item_loader.dart lib/modules/conversation/conversation_list_page.dart test/modules/conversation/conversation_list_item_loader_test.dart
git commit -m "perf: coalesce conversation metadata lookups"
```

## Task 3: Add Indexed Message Matching For Chat Timeline

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_message_match_index.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_viewport_controller.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\chat_timeline_controller.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\conversation_provider.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\chat\chat_viewport_controller_test.dart`

- [ ] **Step 1: Add failing indexed-match tests**

Add this import to `test/modules/chat/chat_viewport_controller_test.dart`:

```dart
import 'package:wukong_im_app/modules/chat/chat_message_match_index.dart';
```

Append this group inside `main()`:

```dart
  group('ChatMessageMatchIndex', () {
    test('finds equivalent message by client message number', () {
      final existing = <WKMsg>[
        WKMsg()
          ..messageID = 'm_existing'
          ..clientMsgNO = 'client_1'
          ..contentType = WkMessageContentType.text,
      ];
      final candidate = WKMsg()
        ..clientMsgNO = 'client_1'
        ..messageID = 'm_delivered'
        ..contentType = WkMessageContentType.text;

      expect(ChatMessageMatchIndex.findMessageIndex(existing, candidate), 0);
    });

    test('chat viewport refresh does not duplicate delivered pending message', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final pending = WKMsg()
        ..channelID = 'u_alice'
        ..channelType = 1
        ..clientMsgNO = 'client_1'
        ..status = WKSendMsgResult.sendLoading
        ..contentType = WkMessageContentType.text;
      final delivered = WKMsg()
        ..channelID = 'u_alice'
        ..channelType = 1
        ..clientMsgNO = 'client_1'
        ..messageID = 'm1'
        ..messageSeq = 1
        ..orderSeq = 1000
        ..status = WKSendMsgResult.sendSuccess
        ..contentType = WkMessageContentType.text;

      controller.replaceAll(<WKMsg>[pending]);
      controller.applyIncoming(<WKMsg>[delivered]);

      expect(controller.state.items, hasLength(1));
      expect(controller.state.items.single.identity, 'mid:m1');
      expect(controller.state.items.single.message.status, WKSendMsgResult.sendSuccess);
    });
  });
```

- [ ] **Step 2: Run chat viewport tests and verify they fail because the indexed matcher is missing**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/chat/chat_viewport_controller_test.dart
```

Expected result: FAIL with an import error for `chat_message_match_index.dart`.

- [ ] **Step 3: Implement indexed matcher**

Create `lib/modules/chat/chat_message_match_index.dart` with:

```dart
import 'package:wukongimfluttersdk/entity/msg.dart';

class ChatMessageMatchIndex {
  ChatMessageMatchIndex(Iterable<WKMsg> messages) {
    var index = 0;
    for (final message in messages) {
      _add(_clientSeq, index, _clientSeqKey(message));
      _add(_clientMsgNo, index, _clientMsgNoKey(message));
      _add(_messageId, index, _messageIdKey(message));
      _add(_messageSeq, index, _messageSeqKey(message));
      _add(_orderSeq, index, _orderSeqKey(message));
      index += 1;
    }
  }

  final Map<String, int> _clientSeq = <String, int>{};
  final Map<String, int> _clientMsgNo = <String, int>{};
  final Map<String, int> _messageId = <String, int>{};
  final Map<String, int> _messageSeq = <String, int>{};
  final Map<String, int> _orderSeq = <String, int>{};

  static int findMessageIndex(List<WKMsg> messages, WKMsg target) {
    return ChatMessageMatchIndex(messages).find(target);
  }

  int find(WKMsg target) {
    return _find(_clientSeq, _clientSeqKey(target)) ??
        _find(_clientMsgNo, _clientMsgNoKey(target)) ??
        _find(_messageId, _messageIdKey(target)) ??
        _find(_messageSeq, _messageSeqKey(target)) ??
        _find(_orderSeq, _orderSeqKey(target)) ??
        -1;
  }

  static bool equivalent(WKMsg left, WKMsg right) {
    return _sameKey(_clientSeqKey(left), _clientSeqKey(right)) ||
        _sameKey(_clientMsgNoKey(left), _clientMsgNoKey(right)) ||
        _sameKey(_messageIdKey(left), _messageIdKey(right)) ||
        _sameKey(_messageSeqKey(left), _messageSeqKey(right)) ||
        _sameKey(_orderSeqKey(left), _orderSeqKey(right));
  }

  void _add(Map<String, int> index, int value, String? key) {
    if (key == null) return;
    index.putIfAbsent(key, () => value);
  }

  int? _find(Map<String, int> index, String? key) {
    if (key == null) return null;
    return index[key];
  }

  static bool _sameKey(String? left, String? right) {
    return left != null && right != null && left == right;
  }

  static String? _clientSeqKey(WKMsg message) {
    if (message.clientSeq <= 0) return null;
    return 'clientSeq:${message.clientSeq}';
  }

  static String? _clientMsgNoKey(WKMsg message) {
    final value = message.clientMsgNO.trim();
    if (value.isEmpty) return null;
    return 'clientMsgNo:$value';
  }

  static String? _messageIdKey(WKMsg message) {
    final value = message.messageID.trim();
    if (value.isEmpty) return null;
    return 'messageId:$value';
  }

  static String? _messageSeqKey(WKMsg message) {
    if (message.messageSeq <= 0 || !_hasConversation(message)) return null;
    return 'messageSeq:${message.channelType}:${message.channelID.trim()}:${message.messageSeq}';
  }

  static String? _orderSeqKey(WKMsg message) {
    if (message.orderSeq <= 0 || !_hasConversation(message)) return null;
    return 'orderSeq:${message.channelType}:${message.channelID.trim()}:${message.orderSeq}';
  }

  static bool _hasConversation(WKMsg message) {
    return message.channelID.trim().isNotEmpty;
  }
}
```

- [ ] **Step 4: Delegate viewport equivalence to indexed matcher**

In `lib/modules/chat/chat_viewport_controller.dart`, add:

```dart
import 'chat_message_match_index.dart';
```

Replace `ChatViewportMessageMatcher.equivalent` with:

```dart
  static bool equivalent(WKMsg left, WKMsg right) {
    return chatMessageIdentity(left) == chatMessageIdentity(right) ||
        ChatMessageMatchIndex.equivalent(left, right);
  }
```

Remove unused private helpers in `ChatViewportMessageMatcher`: `_sameClientSeq`, `_sameClientMsgNo`, `_sameMessageId`, `_sameMessageSeq`, `_sameOrderSeq`, and `_sameConversation`.

- [ ] **Step 5: Use index lookup inside viewport and timeline upserts**

In `ChatViewportController._findExistingIndex`, replace the method with:

```dart
  int _findExistingIndex(
    List<ChatMessageViewModel> items,
    ChatMessageViewModel model,
  ) {
    final directIndex = state.identityToIndex[model.identity];
    if (directIndex != null && directIndex >= 0 && directIndex < items.length) {
      return directIndex;
    }
    return ChatMessageMatchIndex.findMessageIndex(
      items.map((item) => item.message).toList(growable: false),
      model.message,
    );
  }
```

In `lib/modules/conversation/chat_timeline_controller.dart`, add:

```dart
import '../chat/chat_message_match_index.dart';
```

Replace `ChatTimelineController._findExistingIndex` with:

```dart
  int _findExistingIndex(
    List<ChatMessageViewModel> items,
    ChatMessageViewModel model,
  ) {
    final directIndex = state.identityToIndex[model.identity];
    if (directIndex != null && directIndex >= 0 && directIndex < items.length) {
      return directIndex;
    }
    return ChatMessageMatchIndex.findMessageIndex(
      items.map((item) => item.message).toList(growable: false),
      model.message,
    );
  }
```

- [ ] **Step 6: Use the indexed matcher in conversation provider message merging**

In `lib/data/providers/conversation_provider.dart`, add:

```dart
import '../../modules/chat/chat_message_match_index.dart';
```

Replace `findConversationMessageIndex` with:

```dart
int findConversationMessageIndex(List<WKMsg> messages, WKMsg target) {
  return ChatMessageMatchIndex.findMessageIndex(messages, target);
}
```

Remove unused private helpers in this file: `_sameClientSeq`, `_sameClientMsgNo`, `_sameMessageId`, `_sameMessageSeq`, `_sameOrderSeq`, and `_sameConversation`.

- [ ] **Step 7: Run chat and IM provider tests**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/chat/chat_viewport_controller_test.dart test/service/im/im_service_test.dart test/modules/conversation/conversation_list_item_loader_test.dart
```

Expected result: PASS.

- [ ] **Step 8: Commit Task 3**

Run:

```powershell
git add lib/modules/chat/chat_message_match_index.dart lib/modules/chat/chat_viewport_controller.dart lib/modules/conversation/chat_timeline_controller.dart lib/data/providers/conversation_provider.dart test/modules/chat/chat_viewport_controller_test.dart
git commit -m "perf: index chat message matching"
```

## Task 4: Add Read-Only Production Baseline Collector

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\collect_im_performance_baseline.ps1`
- Create on first run: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\baselines\`

- [ ] **Step 1: Create the baseline collector script**

Create `scripts/ops/collect_im_performance_baseline.ps1` with:

```powershell
param(
  [string]$HostName = 'ubuntu@42.194.218.158',
  [string]$OutputDir = 'docs/production/baselines'
)

$ErrorActionPreference = 'Stop'

function Invoke-RemoteReadOnly {
  param([Parameter(Mandatory=$true)][string]$Command)
  ssh -o BatchMode=yes -o ConnectTimeout=15 $HostName $Command
}

function Add-Section {
  param(
    [Parameter(Mandatory=$true)][System.Collections.Generic.List[string]]$Lines,
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string[]]$Body
  )
  $Lines.Add('')
  $Lines.Add("## $Title")
  $Lines.Add('')
  $Lines.Add('```text')
  foreach ($line in $Body) { $Lines.Add($line) }
  $Lines.Add('```')
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputPath = Join-Path $OutputDir "im-performance-baseline-$timestamp.md"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# IM Performance Baseline $timestamp")
$lines.Add('')
$lines.Add("Target: $HostName")
$lines.Add("Captured at: $(Get-Date -Format o)")

$hostSummary = Invoke-RemoteReadOnly "hostname; date -Is; uname -a; nproc; free -h; df -h /; ss -s" 2>&1
Add-Section -Lines $lines -Title 'Host Summary' -Body $hostSummary

$dockerPs = Invoke-RemoteReadOnly "docker ps --format 'table {{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}'" 2>&1
Add-Section -Lines $lines -Title 'Docker Services' -Body $dockerPs

$dockerStats = Invoke-RemoteReadOnly "docker stats --no-stream --format 'table {{.Name}}	{{.CPUPerc}}	{{.MemUsage}}	{{.NetIO}}	{{.BlockIO}}	{{.PIDs}}'" 2>&1
Add-Section -Lines $lines -Title 'Docker Stats' -Body $dockerStats

$nginxErrors = Invoke-RemoteReadOnly "docker logs --tail 300 wukongim_prod-nginx-1 2>&1 | grep -E ' 5[0-9][0-9] |upstream|timeout|error' || true" 2>&1
Add-Section -Lines $lines -Title 'Recent Nginx Error Signals' -Body $nginxErrors

$apiLatency = Invoke-RemoteReadOnly "docker logs --tail 500 wukongim_prod-tsdd-api-1 2>&1 | sed -E 's/(password|token|secret|key|pwd|dsn)[^ ,;]*/<redacted>/Ig' | tail -n 120" 2>&1
Add-Section -Lines $lines -Title 'Recent API Latency Sample' -Body $apiLatency

Set-Content -Path $outputPath -Value $lines -Encoding UTF8
Write-Host "Baseline written to $outputPath"
```

- [ ] **Step 2: Parse-check the PowerShell script**

Run:

```powershell
$script = Get-Content -Raw scripts/ops/collect_im_performance_baseline.ps1
$null = [scriptblock]::Create($script)
```

Expected result: no parser error.

- [ ] **Step 3: Run the collector once with SSH approval**

Run:

```powershell
& .\scripts\ops\collect_im_performance_baseline.ps1
```

Expected result: command prints `Baseline written to docs/production/baselines/im-performance-baseline-<timestamp>.md`.

- [ ] **Step 4: Inspect the generated baseline for secret leakage before committing any generated sample**

Run:

```powershell
Get-ChildItem docs/production/baselines/im-performance-baseline-*.md |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1 |
  ForEach-Object {
    Select-String -Path $_.FullName -Pattern 'PASSWORD|SECRET|TOKEN|KEY|DSN|APP_KEY|MYSQL_PWD' -CaseSensitive:$false
  }
```

Expected result: no actual secret values. Sanitized `<redacted>` log text is acceptable.

- [ ] **Step 5: Commit the collector script**

Run:

```powershell
git add scripts/ops/collect_im_performance_baseline.ps1
git commit -m "chore: add im performance baseline collector"
```

## Task 5: Final Verification For Phase 1

**Files:**
- No new files. This task verifies committed changes.

- [ ] **Step 1: Run focused Flutter tests**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' test test/modules/conversation/conversation_metadata_resolver_test.dart test/modules/conversation/conversation_list_item_loader_test.dart test/modules/conversation/conversation_list_preferred_info_test.dart test/modules/chat/chat_viewport_controller_test.dart test/service/im/im_service_test.dart
```

Expected result: PASS.

- [ ] **Step 2: Run static analysis on touched Dart files**

Run:

```powershell
& 'D:\Apps\flutter\bin\flutter.bat' analyze lib/modules/conversation/conversation_metadata_resolver.dart lib/modules/conversation/conversation_list_item_loader.dart lib/modules/conversation/conversation_list_page.dart lib/modules/chat/chat_message_match_index.dart lib/modules/chat/chat_viewport_controller.dart lib/modules/conversation/chat_timeline_controller.dart lib/data/providers/conversation_provider.dart
```

Expected result: analyzer exits successfully for the touched files.

- [ ] **Step 3: Confirm git only shows unrelated pre-existing work or generated baseline samples**

Run:

```powershell
git status --short
```

Expected result: files from Tasks 1-4 are committed. The repository may still show pre-existing unrelated user work that this plan did not touch.

- [ ] **Step 4: Report phase result**

Use this final response structure:

```text
Implemented:
- Conversation metadata resolver with in-flight coalescing and TTL cache.
- Conversation row resolver integration.
- Indexed chat message matching for merge/upsert hot paths.
- Read-only production baseline collector.

Verified:
- Focused Flutter tests passed.
- Analyzer passed on touched Dart files.
- Baseline collector generated a local report without committed secrets.

Next recommended plan:
- Backend HTTP/operation metrics and protected metrics exposure.
- Nginx edge hygiene after baseline comparison.
- Controlled load-test run using the baseline collector.
```

## Spec Coverage Self-Review

- Observability and guardrails: covered by Task 4 baseline collector. Backend in-process metrics are a follow-up plan because remote backend source is not versioned in the local repo.
- Flutter startup/network fan-out: partially covered by Task 1 and Task 2 through metadata fetch coalescing and request-key stability.
- Flutter conversation list rendering: covered by Task 1 and Task 2.
- Flutter chat timeline/local message merge: covered by Task 3.
- Backend/API low-risk performance work: not implemented in this phase; follow-up plan starts after baseline and remote source versioning decision.
- Nginx/public edge tuning: not implemented in this phase; follow-up plan starts after baseline data confirms safe rules.
- Database/Redis: observed by Task 4; schema mutation is deliberately excluded from Phase 1.
- Load testing: not implemented in this phase; the baseline collector is the prerequisite for the load-test closure plan.
