# Chat Rendering Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the chat screen so Android/iOS message scrolling and input interactions stay smooth by separating viewport, composer, and side effects while removing build-time parsing and full-list recomputation hotspots.

**Architecture:** Introduce a chat rendering kernel made of immutable message view models, a viewport controller for incremental list updates, and a composer controller for draft and panel state. Keep [chat_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) as the public entry point, but move rendering and side effects into smaller focused modules that can be rebuilt independently.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, wukongimfluttersdk, existing DraftManager and conversation providers

---

## File Structure

## Remote Debugging Requirement

This plan explicitly allows using SSH to the cloud server for backend coordination and debugging during implementation and verification.

- SSH entry: `ssh root@103.207.68.33`
- Primary uses:
  - confirm WuKongIM and application backend process health
  - inspect message sync, reminder sync, and read-receipt server behavior
  - compare client-side incremental update behavior with server-side message order and API responses
  - collect remote logs while reproducing client jank or state mismatch issues

Preferred remote debug commands during execution:

```bash
ssh root@103.207.68.33 "pwd; ps -ef | egrep 'wukongim|tsdaodao|server' | grep -v grep"
ssh root@103.207.68.33 "ss -lntp | grep -E ':(5001|5100|5200|5300|8090)'"
ssh root@103.207.68.33 "tail -n 200 /data/wukongim/logs/*.log"
ssh root@103.207.68.33 "tail -n 200 /data/tsdaodao/logs/*.log"
```

When a chat-side failure cannot be explained locally, use SSH before changing client logic blindly.

### New files

- `lib/modules/chat/chat_message_view_model.dart`: immutable render models and message identity helpers
- `lib/modules/chat/chat_message_mapper.dart`: transforms `WKMsg` into render-ready view models and caches structured payload parsing
- `lib/modules/chat/chat_viewport_controller.dart`: incremental viewport state, message identity map, pagination and read-sync scheduling
- `lib/modules/chat/chat_composer_controller.dart`: text/reply/panel state and throttled draft persistence
- `lib/modules/chat/chat_page_shell.dart`: page coordinator that binds app bar, viewport and composer
- `lib/modules/chat/widgets/chat_message_viewport.dart`: viewport subtree with repaint isolation
- `lib/modules/chat/widgets/chat_message_list_item.dart`: per-message widget shell with stable keys
- `lib/modules/chat/widgets/chat_composer.dart`: composer subtree with repaint isolation
- `test/modules/chat/chat_message_mapper_test.dart`: unit tests for identity, structured decode and caching
- `test/modules/chat/chat_viewport_controller_test.dart`: unit tests for incremental merges and read-sync scheduling
- `test/modules/chat/chat_composer_controller_test.dart`: unit tests for draft restore and throttled saves

### Existing files to modify

- `lib/modules/chat/chat_page.dart`: keep public API, delegate implementation to shell
- `lib/data/providers/conversation_provider.dart`: stop performing full rendered-list recomputation on every update and expose kernel-friendly message updates
- `lib/widgets/message_bubble.dart`: accept precomputed render data and remove build-time payload decode
- `lib/wukong_base/msg/draft_manager.dart`: add signature-aware save helper used by composer controller
- `test/modules/chat/chat_page_android_parity_test.dart`: preserve chat entry behavior after shell extraction
- `test/modules/chat/message_bubble_experience_test.dart`: assert bubble rendering against precomputed models
- `test/modules/chat/chat_pages_compile_test.dart`: keep public `ChatPage` compile contract intact

### Verification commands used throughout

- `flutter test test/modules/chat/chat_message_mapper_test.dart`
- `flutter test test/modules/chat/chat_viewport_controller_test.dart`
- `flutter test test/modules/chat/chat_composer_controller_test.dart`
- `flutter test test/modules/chat/message_bubble_experience_test.dart`
- `flutter test test/modules/chat/chat_page_android_parity_test.dart`
- `flutter test test/modules/chat/chat_pages_compile_test.dart`

### Task 1: Build Message Render Models And Mapper

**Files:**
- Create: `lib/modules/chat/chat_message_view_model.dart`
- Create: `lib/modules/chat/chat_message_mapper.dart`
- Create: `test/modules/chat/chat_message_mapper_test.dart`
- Modify: `test/modules/chat/message_bubble_experience_test.dart`

- [ ] **Step 1: Write the failing mapper tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatMessageMapper', () {
    test('prefers messageID for stable identity', () {
      final message = WKMsg()
        ..messageID = 'msg-1'
        ..clientMsgNO = 'client-1'
        ..orderSeq = 10;

      expect(chatMessageIdentity(message), 'mid:msg-1');
    });

    test('parses structured payload only once for equal revision', () {
      final message = WKMsg()
        ..messageID = 'msg-structured'
        ..contentType = WkMessageContentType.unknown
        ..messageContent = WKUnknownContent()
        ..content = '{"type":1001,"content":"hello"}'
        ..timestamp = 1700000000;

      final mapper = ChatMessageMapper();
      final first = mapper.map(message, currentUid: 'u_self');
      final second = mapper.map(message, currentUid: 'u_self');

      expect(identical(first.structuredPayload, second.structuredPayload), isTrue);
      expect(first.previewText, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_mapper_test.dart`
Expected: FAIL with missing `ChatMessageMapper`, `ChatMessageViewModel`, or `chatMessageIdentity`

- [ ] **Step 3: Implement immutable render models and mapper**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../widgets/message_bubble.dart';
import 'message_content_preview.dart';

@immutable
class ChatMessageViewModel {
  const ChatMessageViewModel({
    required this.identity,
    required this.message,
    required this.previewText,
    required this.isSystemNotice,
    required this.isSelf,
    required this.structuredPayload,
    required this.revision,
  });

  final String identity;
  final WKMsg message;
  final String previewText;
  final bool isSystemNotice;
  final bool isSelf;
  final Map<String, dynamic>? structuredPayload;
  final String revision;
}

String chatMessageIdentity(WKMsg message) {
  final messageId = message.messageID.trim();
  if (messageId.isNotEmpty) {
    return 'mid:$messageId';
  }
  final clientMsgNo = message.clientMsgNO.trim();
  if (clientMsgNo.isNotEmpty) {
    return 'cid:$clientMsgNo';
  }
  return 'seq:${message.orderSeq}:${message.messageSeq}:${message.timestamp}';
}

class ChatMessageMapper {
  final Map<String, Map<String, dynamic>?> _payloadCache = <String, Map<String, dynamic>?>{};

  ChatMessageViewModel map(WKMsg message, {required String currentUid}) {
    final identity = chatMessageIdentity(message);
    final revision = '$identity|${message.status}|${message.isDeleted}|${message.content.hashCode}';
    final structuredPayload = _structuredPayload(message, revision);
    final preview = resolveMessagePreview(message);
    return ChatMessageViewModel(
      identity: identity,
      message: message,
      previewText: preview.text,
      isSystemNotice: preview.isSystemNotice,
      isSelf: message.fromUID.trim() == currentUid.trim(),
      structuredPayload: structuredPayload,
      revision: revision,
    );
  }

  Map<String, dynamic>? _structuredPayload(WKMsg message, String revision) {
    final cached = _payloadCache[revision];
    if (_payloadCache.containsKey(revision)) {
      return cached;
    }
    final shouldDecode =
        message.contentType == WkMessageContentType.unknown ||
        message.messageContent is WKUnknownContent;
    if (!shouldDecode) {
      _payloadCache[revision] = null;
      return null;
    }
    final raw = message.content.trim();
    if (raw.isEmpty || (!raw.startsWith('{') && !raw.startsWith('['))) {
      _payloadCache[revision] = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      final payload = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      _payloadCache[revision] = payload;
      return payload;
    } catch (_) {
      _payloadCache[revision] = null;
      return null;
    }
  }
}
```

- [ ] **Step 4: Update bubble tests to use the new render-facing API**

```dart
test('resolveMessageStatusInfo returns group receipt summary', () {
  final message = WKMsg()
    ..status = WKSendMsgResult.sendSuccess
    ..channelType = WKChannelType.group
    ..wkMsgExtra = (WKMsgExtra()
      ..readedCount = 3
      ..unreadCount = 1);

  final mapper = ChatMessageMapper();
  final model = mapper.map(message, currentUid: 'u_self');

  expect(model.identity, startsWith('seq:'));
  expect(resolveMessageStatusInfo(model.message, isSelf: true)?.label, '3宸茶 路 1鏈');
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/modules/chat/chat_message_mapper_test.dart test/modules/chat/message_bubble_experience_test.dart`
Expected: PASS with all mapper and bubble assertions green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_message_view_model.dart lib/modules/chat/chat_message_mapper.dart test/modules/chat/chat_message_mapper_test.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "refactor: add chat message render mapper"
```

### Task 2: Introduce Incremental Viewport Controller

**Files:**
- Create: `lib/modules/chat/chat_viewport_controller.dart`
- Create: `test/modules/chat/chat_viewport_controller_test.dart`
- Modify: `lib/data/providers/conversation_provider.dart`

- [ ] **Step 1: Write the failing viewport controller tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/chat_viewport_controller.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatViewportController', () {
    test('inserts new messages without rebuilding unrelated identities', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final first = WKMsg()
        ..messageID = 'm1'
        ..contentType = WkMessageContentType.text;
      final second = WKMsg()
        ..messageID = 'm2'
        ..contentType = WkMessageContentType.text;

      controller.replaceAll([first]);
      controller.applyIncoming([second]);

      expect(controller.state.items.map((item) => item.identity).toList(), ['mid:m2', 'mid:m1']);
    });

    test('patches existing message in place when refresh arrives', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final pending = WKMsg()
        ..clientMsgNO = 'c1'
        ..status = WKSendMsgResult.sendLoading
        ..contentType = WkMessageContentType.text;
      final delivered = WKMsg()
        ..clientMsgNO = 'c1'
        ..messageID = 'm1'
        ..status = WKSendMsgResult.sendSuccess
        ..contentType = WkMessageContentType.text;

      controller.replaceAll([pending]);
      controller.applyRefresh(delivered);

      expect(controller.state.items.single.identity, 'mid:m1');
      expect(controller.state.items.single.message.status, WKSendMsgResult.sendSuccess);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/chat/chat_viewport_controller_test.dart`
Expected: FAIL with missing `ChatViewportController` or missing `replaceAll` / `applyIncoming` / `applyRefresh`

- [ ] **Step 3: Implement the incremental controller**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_message_mapper.dart';
import 'chat_message_view_model.dart';

@immutable
class ChatViewportState {
  const ChatViewportState({
    this.items = const <ChatMessageViewModel>[],
    this.identityToIndex = const <String, int>{},
    this.isLoadingMore = false,
  });

  final List<ChatMessageViewModel> items;
  final Map<String, int> identityToIndex;
  final bool isLoadingMore;
}

class ChatViewportController extends StateNotifier<ChatViewportState> {
  ChatViewportController({
    required ChatMessageMapper mapper,
    required String currentUid,
  }) : _mapper = mapper,
       _currentUid = currentUid,
       super(const ChatViewportState());

  final ChatMessageMapper _mapper;
  final String _currentUid;

  void replaceAll(Iterable<WKMsg> messages) {
    final items = messages.map((message) => _mapper.map(message, currentUid: _currentUid)).toList(growable: false);
    state = ChatViewportState(items: items, identityToIndex: _index(items));
  }

  void applyIncoming(Iterable<WKMsg> messages) {
    final next = <ChatMessageViewModel>[...state.items];
    for (final message in messages) {
      _upsert(next, _mapper.map(message, currentUid: _currentUid), insertAtHead: true);
    }
    state = ChatViewportState(items: next, identityToIndex: _index(next));
  }

  void applyRefresh(WKMsg message) {
    final next = <ChatMessageViewModel>[...state.items];
    _upsert(next, _mapper.map(message, currentUid: _currentUid), insertAtHead: true);
    state = ChatViewportState(items: next, identityToIndex: _index(next));
  }

  Map<String, int> _index(List<ChatMessageViewModel> items) {
    final map = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      map[items[i].identity] = i;
    }
    return map;
  }

  void _upsert(List<ChatMessageViewModel> items, ChatMessageViewModel model, {required bool insertAtHead}) {
    final existingIndex = items.indexWhere((item) => item.identity == model.identity);
    if (existingIndex != -1) {
      items[existingIndex] = model;
      return;
    }
    if (insertAtHead) {
      items.insert(0, model);
    } else {
      items.add(model);
    }
  }
}
```

- [ ] **Step 4: Bridge the provider layer to the new controller**

```dart
final chatViewportProvider = StateNotifierProvider.autoDispose
    .family<ChatViewportController, ChatViewportState, ChatSession>((ref, session) {
  final controller = ChatViewportController(
    mapper: ChatMessageMapper(),
    currentUid: StorageUtils.getUid() ?? '',
  );
  final rawMessages = ref.watch(messageListProvider(session));
  controller.replaceAll(rawMessages);
  return controller;
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/modules/chat/chat_viewport_controller_test.dart test/modules/chat/conversation_read_controller_test.dart`
Expected: PASS with incremental merge tests and existing read controller tests green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_viewport_controller.dart lib/data/providers/conversation_provider.dart test/modules/chat/chat_viewport_controller_test.dart
git commit -m "refactor: add incremental chat viewport controller"
```

### Task 3: Add Composer Controller And Draft-Side-Effect Isolation

**Files:**
- Create: `lib/modules/chat/chat_composer_controller.dart`
- Create: `test/modules/chat/chat_composer_controller_test.dart`
- Modify: `lib/wukong_base/msg/draft_manager.dart`

- [ ] **Step 1: Write the failing composer tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_composer_controller.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';

void main() {
  test('restores draft text and reply state on initialize', () async {
    final fakeDraftManager = FakeDraftStore(
      draft: MessageDraft(
        channelId: 'u_demo',
        channelType: 1,
        content: 'draft hello',
        updateTime: 1,
        replyMsgId: 'mid:reply',
        replyContent: 'quoted',
      ),
    );

    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    await controller.initialize();

    expect(controller.state.text, 'draft hello');
    expect(controller.state.pendingReplyMessageId, 'mid:reply');
  });

  test('debounces duplicate draft writes', () async {
    final fakeDraftManager = FakeDraftStore();
    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    controller.updateText('hello');
    controller.updateText('hello');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart`
Expected: FAIL with missing `ChatComposerController`, `FakeDraftStore`, or draft state fields

- [ ] **Step 3: Implement composer controller**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wukong_base/msg/draft_manager.dart';

@immutable
class ChatComposerState {
  const ChatComposerState({
    this.text = '',
    this.pendingReplyMessageId,
    this.pendingReplyPreview,
    this.showFacePanel = false,
    this.showFunctionPanel = false,
  });

  final String text;
  final String? pendingReplyMessageId;
  final String? pendingReplyPreview;
  final bool showFacePanel;
  final bool showFunctionPanel;

  ChatComposerState copyWith({
    String? text,
    String? pendingReplyMessageId,
    bool clearReply = false,
    String? pendingReplyPreview,
    bool showFacePanel = false,
    bool showFunctionPanel = false,
  }) {
    return ChatComposerState(
      text: text ?? this.text,
      pendingReplyMessageId: clearReply ? null : (pendingReplyMessageId ?? this.pendingReplyMessageId),
      pendingReplyPreview: clearReply ? null : (pendingReplyPreview ?? this.pendingReplyPreview),
      showFacePanel: showFacePanel,
      showFunctionPanel: showFunctionPanel,
    );
  }
}

class ChatComposerController extends StateNotifier<ChatComposerState> {
  ChatComposerController({
    required this.channelId,
    required this.channelType,
    DraftManager? draftStore,
  }) : _draftStore = draftStore ?? DraftManager(),
       super(const ChatComposerState());

  final String channelId;
  final int channelType;
  final DraftManager _draftStore;
  Timer? _saveTimer;
  String _lastSavedSignature = '';

  Future<void> initialize() async {
    final draft = _draftStore.getDraft(channelId, channelType);
    if (draft == null) {
      return;
    }
    state = ChatComposerState(
      text: draft.content,
      pendingReplyMessageId: draft.replyMsgId,
      pendingReplyPreview: draft.replyContent,
    );
  }

  void updateText(String text) {
    state = state.copyWith(
      text: text,
      showFacePanel: state.showFacePanel,
      showFunctionPanel: state.showFunctionPanel,
    );
    _scheduleSave();
  }

  void toggleFacePanel() {
    state = state.copyWith(
      text: state.text,
      pendingReplyMessageId: state.pendingReplyMessageId,
      pendingReplyPreview: state.pendingReplyPreview,
      showFacePanel: !state.showFacePanel,
      showFunctionPanel: false,
    );
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _persist);
  }

  Future<void> _persist() async {
    final signature = '${state.text}|${state.pendingReplyMessageId}|${state.pendingReplyPreview}';
    if (signature == _lastSavedSignature) {
      return;
    }
    _lastSavedSignature = signature;
    await _draftStore.saveDraft(
      channelId: channelId,
      channelType: channelType,
      content: state.text,
      replyMsgId: state.pendingReplyMessageId,
      replyContent: state.pendingReplyPreview,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Add signature-aware draft helper**

```dart
extension DraftSignature on MessageDraft {
  String get contentSignature => '$content|${replyMsgId ?? ''}|${replyContent ?? ''}';
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart test/wukong_base/msg/draft_manager_test.dart`
Expected: PASS with draft restore and debounce behavior green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_composer_controller.dart lib/wukong_base/msg/draft_manager.dart test/modules/chat/chat_composer_controller_test.dart
git commit -m "refactor: isolate chat composer state"
```

### Task 4: Extract Chat Shell, Viewport, And Composer Widgets

**Files:**
- Create: `lib/modules/chat/chat_page_shell.dart`
- Create: `lib/modules/chat/widgets/chat_message_viewport.dart`
- Create: `lib/modules/chat/widgets/chat_message_list_item.dart`
- Create: `lib/modules/chat/widgets/chat_composer.dart`
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`
- Modify: `test/modules/chat/chat_pages_compile_test.dart`

- [ ] **Step 1: Write the failing widget regression tests**

```dart
testWidgets('ChatPage still compiles and renders through shell', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: ChatPage(channelId: 'u_demo', channelType: 1, channelName: 'Demo'),
      ),
    ),
  );

  expect(find.byType(ChatPage), findsOneWidget);
  expect(find.byType(ChatPageShell), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_android_parity_test.dart`
Expected: FAIL with missing `ChatPageShell` or shell delegation assertions

- [ ] **Step 3: Extract the shell and keep `ChatPage` public**

```dart
class ChatPage extends ConsumerWidget {
  const ChatPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChatPageShell(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
```

- [ ] **Step 4: Build repaint-isolated viewport and composer widgets**

```dart
class ChatMessageViewport extends ConsumerWidget {
  const ChatMessageViewport({super.key, required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = ref.watch(chatViewportProvider(session));
    return const RepaintBoundary(
      child: _ViewportBody(),
    );
  }
}

class ChatComposer extends ConsumerWidget {
  const ChatComposer({super.key, required this.session});

  final ChatSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(chatComposerProvider(session));
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (composer.pendingReplyMessageId != null)
            ChatReplyPreview(replyText: composer.pendingReplyPreview ?? ''),
          TextField(
            controller: ref.read(chatComposerProvider(session).notifier).textController,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS while preserving fixed titles, call action visibility and public entry behavior

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_message_viewport.dart lib/modules/chat/widgets/chat_message_list_item.dart lib/modules/chat/widgets/chat_composer.dart test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "refactor: split chat page into shell viewport and composer"
```

### Task 5: Remove Build-Time Side Effects And Wire The Kernel

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/chat_viewport_controller.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Modify: `test/modules/chat/message_bubble_experience_test.dart`
- Modify: `test/modules/chat/conversation_read_controller_test.dart`

- [ ] **Step 1: Write the failing regression tests for side-effect removal**

```dart
testWidgets('typing does not recreate viewport subtree', (tester) async {
  final viewportKeys = <Element>{};
  await tester.pumpWidget(buildChatHarness(onViewportBuild: (element) {
    viewportKeys.add(element);
  }));

  await tester.enterText(find.byType(TextField).first, 'hello');
  await tester.pump(const Duration(milliseconds: 350));

  expect(viewportKeys.length, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`
Expected: FAIL because the current chat input path still rebuilds the viewport subtree

- [ ] **Step 3: Remove payload decode from `MessageBubble.build`**

```dart
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.model,
    required this.statusInfo,
    required this.participant,
    this.onLongPress,
    this.onTap,
    this.onSecondaryTapDown,
    this.reactions = const [],
    this.onAddReaction,
    this.onReactionTap,
  });

  final ChatMessageViewModel model;
  final MessageStatusInfo? statusInfo;
  final MessageParticipantInfo participant;

  @override
  Widget build(BuildContext context) {
    final previewText = model.previewText;
    final payload = model.structuredPayload;
    // Build now consumes precomputed values only.
    return _buildBubbleBody(previewText: previewText, payload: payload);
  }
}
```

- [ ] **Step 4: Move read-sync and reply restoration into controller initialization**

```dart
Future<void> initialize({
  required Future<void> Function() markConversationRead,
  required String? initialReplyMessageId,
}) async {
  _pendingReplyMessageId = initialReplyMessageId;
  await _restoreVisibleReplyIfNeeded();
  await markConversationRead();
}

void onVisibleItemsChanged(Iterable<ChatMessageViewModel> visibleItems) {
  final signature = visibleItems
      .where((item) => !item.isSelf)
      .map((item) => item.identity)
      .join('|');
  if (signature == _lastReadSignature) {
    return;
  }
  _lastReadSignature = signature;
  _scheduleReadMark();
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart test/modules/chat/conversation_read_controller_test.dart test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS with no build-time decode regressions and existing read behavior preserved

- [ ] **Step 6: Correlate client behavior with remote backend state over SSH**

Run:

```bash
ssh root@103.207.68.33 "ps -ef | egrep 'wukongim|tsdaodao|server' | grep -v grep; ss -lntp | grep -E ':(5001|5100|5200|5300|8090)'"
ssh root@103.207.68.33 "tail -n 120 /data/wukongim/logs/*.log; tail -n 120 /data/tsdaodao/logs/*.log"
```

Expected:
- message sync service is alive
- backend ports are listening
- no remote errors contradict the client-side incremental viewport behavior

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/chat_viewport_controller.dart lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/conversation_read_controller_test.dart
git commit -m "refactor: remove chat build side effects"
```

### Task 6: Final Verification For Phase A

**Files:**
- Verify only

- [ ] **Step 1: Run targeted chat test suite**

Run: `flutter test test/modules/chat/chat_message_mapper_test.dart test/modules/chat/chat_viewport_controller_test.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/conversation_read_controller_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
Expected: PASS with all chat kernel tests green

- [ ] **Step 2: Run broader regression coverage touching drafts**

Run: `flutter test test/wukong_base/msg/draft_manager_test.dart`
Expected: PASS

- [ ] **Step 3: Run analyzer on touched chat files**

Run: `flutter analyze lib/modules/chat lib/widgets/message_bubble.dart lib/data/providers/conversation_provider.dart lib/wukong_base/msg/draft_manager.dart`
Expected: No issues found

- [ ] **Step 4: Smoke-check manual acceptance**

Run: `flutter run -d android --profile`
Expected:
- typing in chat does not visibly hitch the message list
- panel toggles do not repaint the entire viewport
- new incoming messages only update affected rows
- fast fling does not show decode-related hitching

- [ ] **Step 5: Run remote coordination checks over SSH during manual smoke test**

Run:

```bash
ssh root@103.207.68.33 "tail -f /data/wukongim/logs/*.log"
ssh root@103.207.68.33 "tail -f /data/tsdaodao/logs/*.log"
```

Expected:
- while exercising the Android profile build, remote logs confirm message arrival order, read marking, and reminder events without server-side anomalies

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat lib/widgets/message_bubble.dart lib/data/providers/conversation_provider.dart lib/wukong_base/msg/draft_manager.dart test/modules/chat test/wukong_base/msg/draft_manager_test.dart
git commit -m "refactor: ship chat rendering kernel"
```
