# Phase 4 Chat Mainline Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter active conversation screen around an authoritative scene kernel that can own reply, forward, multi-select, favorites, `@member`, recall, reactions, and in-chat search, then serve as the landing zone for strict Android-reference parity on Android.

**Architecture:** This plan does not throw away the current chat kernel groundwork. It keeps `ChatPage` as the public entry point, layers a new `ChatSceneController` and scene-facing gateway over the existing `messageListProvider`, `ChatViewportController`, and `ChatComposerController`, then ports adjacent subflows one by one into the new mainline. Existing low-level assets such as `MessageApi`, `ReactionManager`, `CollectionApi`, `message_forwarding.dart`, `MentionSuggestionOverlay`, and the search module are reused where they are already real, while placeholders and duplicate active-path logic are retired behind compatibility wrappers.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, wukongimfluttersdk, dio-backed API clients, existing search module, CollectionApi, MessageApi, ReactionManager, WKIM message manager, PowerShell, SSH

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only the approved design in [2026-04-04-phase-4-chat-mainline-rearchitecture-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-04-phase-4-chat-mainline-rearchitecture-design.md).

In scope:

- authoritative chat scene mode orchestration
- real action handling for reply, forward, multi-select, favorites, `@member`, recall, reactions, and in-chat search
- controlled migration from the current chat shell into the new scene kernel
- viewport-anchor preservation needed by selection/search return paths
- compatibility cleanup for old placeholder entry points that still sit on the public chat surface

Out of scope for this plan:

- group-detail rebuild
- pinned-message standalone page
- call signaling and call-page parity
- conversation-list redesign
- new product concepts outside the approved scope

## Android Reference Anchors

The implementation in this plan is pinned to the following Android surfaces:

- `wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java`
  - scene-level chat ownership
  - search entry
  - message action handling
  - reply and multi-select transitions
- `wkuikit/src/main/java/com/chat/uikit/contacts/ChooseContactsActivity.java`
  - forward-target selection behavior
- Android message long-press and reaction semantics already represented in the current Flutter asset set under `lib/wukong_uikit/chat/**`

## File Structure

### New Files

- `lib/modules/chat/chat_scene_models.dart`
  - Defines authoritative scene enums and immutable scene state snapshots.
- `lib/modules/chat/chat_scene_controller.dart`
  - Owns primary-mode transitions and cross-mode cleanup hooks.
- `lib/modules/chat/chat_scene_providers.dart`
  - Wires the new scene controller, action controller, selection controller, search-mode controller, mentions controller, and gateway into Riverpod.
- `lib/modules/chat/chat_scene_gateway.dart`
  - Bridges message actions to `MessageApi`, `CollectionApi`, `ReactionManager`, `WKIM`, and existing forward-target helpers.
- `lib/modules/chat/chat_message_action_controller.dart`
  - Owns reply-action entry, favorites, recall, reactions, and forward-request preparation.
- `lib/modules/chat/chat_selection_controller.dart`
  - Owns selected-message state and batch-action availability.
- `lib/modules/chat/chat_search_mode_controller.dart`
  - Owns search-mode lifecycle, anchor preservation, and return behavior.
- `lib/modules/chat/chat_mentions_controller.dart`
  - Owns `@member` query parsing, candidate filtering, and insertion behavior.
- `lib/modules/chat/forward_message_page.dart`
  - Real forward-target picker for single-message and multi-select forward flows.
- `lib/modules/chat/widgets/chat_message_action_sheet.dart`
  - Authoritative chat action sheet for the active mainline.
- `lib/modules/chat/widgets/chat_selection_toolbar.dart`
  - Batch-mode toolbar for multi-select.
- `lib/modules/chat/widgets/chat_search_mode_bar.dart`
  - Search-mode top bar used by the scene shell.
- `lib/modules/chat/widgets/chat_reply_preview_strip.dart`
  - Composer reply strip used by the new mainline.
- `test/modules/chat/chat_scene_controller_test.dart`
  - Verifies scene-mode transitions and cleanup callbacks.
- `test/modules/chat/chat_message_action_controller_test.dart`
  - Verifies favorites, recall, reactions, and forward-request preparation.
- `test/modules/chat/chat_selection_controller_test.dart`
  - Verifies multi-select behavior and batch availability.
- `test/modules/chat/chat_search_mode_controller_test.dart`
  - Verifies search enter/exit anchor handling.
- `test/modules/chat/chat_mentions_controller_test.dart`
  - Verifies mention-query parsing and suggestion insertion.
- `test/modules/chat/forward_message_page_test.dart`
  - Verifies real forward-target selection and submit flow.
- `test/modules/chat/chat_page_scene_flow_test.dart`
  - Verifies scene-driven shell behavior end to end.

### Existing Files To Modify

- `lib/modules/chat/chat_page.dart`
  - Keep public `ChatPage`, but replace placeholder `ForwardMessagePage` with the real page and keep compatibility wrappers thin.
- `lib/modules/chat/chat_page_shell.dart`
  - Rebuild page composition around scene providers instead of direct local orchestration.
- `lib/modules/chat/chat_composer_controller.dart`
  - Add submit payload extraction and post-send cleanup hooks needed by the new scene path.
- `lib/modules/chat/chat_viewport_controller.dart`
  - Add anchor helpers and targeted lookup used by search return and selection stability.
- `lib/modules/chat/message_forwarding.dart`
  - Add a small forward-payload helper shared by message actions and the new forward page.
- `lib/modules/chat/widgets/chat_composer.dart`
  - Upgrade from a pure repaint wrapper into the actual scene-facing composer shell.
- `lib/modules/chat/widgets/chat_message_viewport.dart`
  - Upgrade from a pure repaint wrapper into the scene-facing viewport shell.
- `lib/modules/chat/widgets/chat_message_list_item.dart`
  - Route long-press and reaction taps through the new scene action system.
- `lib/widgets/message_bubble.dart`
  - Keep render behavior, but wire long-press/reaction callbacks through the new scene shell.
- `lib/data/providers/conversation_provider.dart`
  - Expose the current `ChatSession`-backed providers to the new scene-providers file without duplicating the active message source.
- `lib/wukong_uikit/chat/message_long_press_menu.dart`
  - Reduce to a compatibility wrapper over the new message action sheet so old callers stop drifting.
- `test/modules/chat/chat_composer_controller_test.dart`
  - Expand coverage for submit payload extraction and reply cleanup.
- `test/modules/chat/chat_viewport_controller_test.dart`
  - Expand coverage for anchor helpers and stable lookups.
- `test/modules/chat/chat_page_android_parity_test.dart`
  - Preserve existing Android-entry behavior while asserting the new scene-specific affordances.
- `test/modules/chat/chat_pages_compile_test.dart`
  - Preserve public compile contracts for `ChatPage` and `ForwardMessagePage`.

## Remote Debugging Requirement

This phase explicitly allows backend-assisted validation through `ssh root@103.207.68.33`.

- Use remote inspection when:
  - recall succeeds locally but the message stream does not reflect the revoke state
  - reaction toggles appear stale or duplicated
  - favorites save successfully on the client but do not survive list refresh
  - in-chat search returns inconsistent result sets compared with Android
- Minimum remote checks during implementation and verification:
  - `ssh root@103.207.68.33 "docker ps --format '{{.Names}}'"`
  - `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'revoke|reaction|favorite|search|typing'"`
  - `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-wukongim-1 | grep -E 'revoke|reaction|favorite|search|typing'"`

## Verification Commands Used Throughout

- `flutter analyze lib/modules/chat lib/data/providers/conversation_provider.dart lib/widgets/message_bubble.dart lib/wukong_uikit/chat/message_long_press_menu.dart`
- `flutter test test/modules/chat/chat_scene_controller_test.dart`
- `flutter test test/modules/chat/chat_message_action_controller_test.dart`
- `flutter test test/modules/chat/chat_selection_controller_test.dart`
- `flutter test test/modules/chat/chat_search_mode_controller_test.dart`
- `flutter test test/modules/chat/chat_mentions_controller_test.dart`
- `flutter test test/modules/chat/forward_message_page_test.dart`
- `flutter test test/modules/chat/chat_page_scene_flow_test.dart`
- `flutter test test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_viewport_controller_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'revoke|reaction|favorite|search|typing'"`

### Task 1: Build The Scene State Kernel

**Files:**
- Create: `lib/modules/chat/chat_scene_models.dart`
- Create: `lib/modules/chat/chat_scene_controller.dart`
- Create: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_scene_controller_test.dart`

- [ ] **Step 1: Write the failing scene-controller tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';

void main() {
  group('ChatSceneController', () {
    test('enterReplyMode switches to replying and clears the action target', () {
      final calls = <String>[];
      final controller = ChatSceneController(
        onLeaveReplyMode: () => calls.add('leave-reply'),
        onLeaveSelectionMode: () => calls.add('leave-select'),
        onLeaveSearchMode: () => calls.add('leave-search'),
      );

      controller.showActionMenuFor('mid:1');
      controller.enterReplyMode();

      expect(controller.state.mode, ChatSceneMode.replying);
      expect(controller.state.actionMessageIdentity, isNull);
      expect(calls, isEmpty);
    });

    test('enterSelectionMode from replying leaves reply mode first', () {
      final calls = <String>[];
      final controller = ChatSceneController(
        onLeaveReplyMode: () => calls.add('leave-reply'),
        onLeaveSelectionMode: () => calls.add('leave-select'),
        onLeaveSearchMode: () => calls.add('leave-search'),
      );

      controller.enterReplyMode();
      controller.enterSelectionMode(seedIdentity: 'mid:2');

      expect(controller.state.mode, ChatSceneMode.selecting);
      expect(controller.state.selectionSeedIdentity, 'mid:2');
      expect(calls, <String>['leave-reply']);
    });

    test('enterSearchMode stores anchor and restoreNormal clears search metadata', () {
      final controller = ChatSceneController();

      controller.enterSearchMode(anchorOrderSeq: 88, initialKeyword: 'hello');
      expect(controller.state.mode, ChatSceneMode.searching);
      expect(controller.state.searchAnchorOrderSeq, 88);
      expect(controller.state.searchKeyword, 'hello');

      controller.restoreNormal();

      expect(controller.state.mode, ChatSceneMode.normal);
      expect(controller.state.searchAnchorOrderSeq, 0);
      expect(controller.state.searchKeyword, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the scene-controller test to verify it fails**

Run: `flutter test test/modules/chat/chat_scene_controller_test.dart`
Expected: FAIL with missing `ChatSceneController`, `ChatSceneMode`, or `ChatSceneState`

- [ ] **Step 3: Add the immutable scene models**

```dart
// lib/modules/chat/chat_scene_models.dart
import 'package:flutter/foundation.dart';

enum ChatSceneMode { normal, replying, selecting, searching }

@immutable
class ChatSceneState {
  const ChatSceneState({
    this.mode = ChatSceneMode.normal,
    this.actionMessageIdentity,
    this.selectionSeedIdentity,
    this.searchAnchorOrderSeq = 0,
    this.searchKeyword = '',
  });

  final ChatSceneMode mode;
  final String? actionMessageIdentity;
  final String? selectionSeedIdentity;
  final int searchAnchorOrderSeq;
  final String searchKeyword;

  ChatSceneState copyWith({
    ChatSceneMode? mode,
    String? actionMessageIdentity,
    bool clearActionMessageIdentity = false,
    String? selectionSeedIdentity,
    bool clearSelectionSeedIdentity = false,
    int? searchAnchorOrderSeq,
    String? searchKeyword,
  }) {
    return ChatSceneState(
      mode: mode ?? this.mode,
      actionMessageIdentity: clearActionMessageIdentity
          ? null
          : (actionMessageIdentity ?? this.actionMessageIdentity),
      selectionSeedIdentity: clearSelectionSeedIdentity
          ? null
          : (selectionSeedIdentity ?? this.selectionSeedIdentity),
      searchAnchorOrderSeq: searchAnchorOrderSeq ?? this.searchAnchorOrderSeq,
      searchKeyword: searchKeyword ?? this.searchKeyword,
    );
  }
}
```

- [ ] **Step 4: Implement the scene controller**

```dart
// lib/modules/chat/chat_scene_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_scene_models.dart';

class ChatSceneController extends StateNotifier<ChatSceneState> {
  ChatSceneController({
    VoidCallback? onLeaveReplyMode,
    VoidCallback? onLeaveSelectionMode,
    VoidCallback? onLeaveSearchMode,
  }) : _onLeaveReplyMode = onLeaveReplyMode,
       _onLeaveSelectionMode = onLeaveSelectionMode,
       _onLeaveSearchMode = onLeaveSearchMode,
       super(const ChatSceneState());

  final VoidCallback? _onLeaveReplyMode;
  final VoidCallback? _onLeaveSelectionMode;
  final VoidCallback? _onLeaveSearchMode;

  void showActionMenuFor(String identity) {
    state = state.copyWith(actionMessageIdentity: identity);
  }

  void closeActionMenu() {
    state = state.copyWith(clearActionMessageIdentity: true);
  }

  void enterReplyMode() {
    _leaveCurrentPrimaryMode(nextMode: ChatSceneMode.replying);
    state = state.copyWith(
      mode: ChatSceneMode.replying,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void enterSelectionMode({String? seedIdentity}) {
    _leaveCurrentPrimaryMode(nextMode: ChatSceneMode.selecting);
    state = state.copyWith(
      mode: ChatSceneMode.selecting,
      selectionSeedIdentity: seedIdentity,
      clearActionMessageIdentity: true,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void enterSearchMode({
    required int anchorOrderSeq,
    String initialKeyword = '',
  }) {
    _leaveCurrentPrimaryMode(nextMode: ChatSceneMode.searching);
    state = state.copyWith(
      mode: ChatSceneMode.searching,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: anchorOrderSeq,
      searchKeyword: initialKeyword,
    );
  }

  void updateSearchKeyword(String keyword) {
    if (state.mode != ChatSceneMode.searching) {
      return;
    }
    state = state.copyWith(searchKeyword: keyword);
  }

  void restoreNormal() {
    _leaveCurrentPrimaryMode(nextMode: ChatSceneMode.normal);
    state = state.copyWith(
      mode: ChatSceneMode.normal,
      clearActionMessageIdentity: true,
      clearSelectionSeedIdentity: true,
      searchAnchorOrderSeq: 0,
      searchKeyword: '',
    );
  }

  void _leaveCurrentPrimaryMode({required ChatSceneMode nextMode}) {
    if (state.mode == nextMode) {
      return;
    }
    switch (state.mode) {
      case ChatSceneMode.replying:
        _onLeaveReplyMode?.call();
        break;
      case ChatSceneMode.selecting:
        _onLeaveSelectionMode?.call();
        break;
      case ChatSceneMode.searching:
        _onLeaveSearchMode?.call();
        break;
      case ChatSceneMode.normal:
        break;
    }
  }
}
```

- [ ] **Step 5: Add the scene provider wiring**

```dart
// lib/modules/chat/chat_scene_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/conversation_provider.dart';
import 'chat_scene_controller.dart';
import 'chat_scene_models.dart';

final chatSceneControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSceneController, ChatSceneState, ChatSession>((ref, session) {
      return ChatSceneController();
    });
```

- [ ] **Step 6: Run the scene-controller test to verify it passes**

Run: `flutter test test/modules/chat/chat_scene_controller_test.dart`
Expected: PASS with all three scene transition assertions green

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_scene_models.dart lib/modules/chat/chat_scene_controller.dart lib/modules/chat/chat_scene_providers.dart test/modules/chat/chat_scene_controller_test.dart
git commit -m "feat: add chat scene state kernel"
```

### Task 2: Add The Scene Gateway And Message Action Controller

**Files:**
- Create: `lib/modules/chat/chat_scene_gateway.dart`
- Create: `lib/modules/chat/chat_message_action_controller.dart`
- Modify: `lib/modules/chat/message_forwarding.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_message_action_controller_test.dart`

- [ ] **Step 1: Write the failing action-controller tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatMessageActionController', () {
    test('favorite delegates to gateway and exposes success feedback', () async {
      final gateway = _FakeChatSceneGateway();
      final controller = ChatMessageActionController(gateway: gateway);
      final message = WKMsg()
        ..messageID = 'mid-1'
        ..clientMsgNO = 'client-1'
        ..channelID = 'g1'
        ..channelType = WKChannelType.group
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello');

      await controller.favorite(message);

      expect(gateway.favoriteCalls, <String>['client-1']);
      expect(controller.state.feedbackMessage, '已收藏');
    });

    test('prepareForward ignores unsupported messages and keeps supported payloads', () {
      final controller = ChatMessageActionController(
        gateway: _FakeChatSceneGateway(),
      );
      final supported = WKMsg()
        ..messageID = 'mid-2'
        ..clientMsgNO = 'client-2'
        ..channelID = 'u2'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('forward me');

      controller.prepareForward(<WKMsg>[supported]);

      expect(controller.state.forwardRequest, isNotNull);
      expect(controller.state.forwardRequest!.payloads, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run the action-controller test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart`
Expected: FAIL with missing `ChatSceneGateway`, `ChatMessageActionController`, or `ChatForwardRequest`

- [ ] **Step 3: Add the gateway over favorites, recall, reactions, and forward targets**

```dart
// lib/modules/chat/chat_scene_gateway.dart
import 'package:wukong_im_app/service/api/collection_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'message_forwarding.dart';

abstract class ChatSceneGateway {
  Future<void> addFavorite(WKMsg message);
  Future<void> recallMessage(WKMsg message);
  Future<void> toggleReaction(WKMsg message, String emoji);
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  });
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  );
}

class ApiChatSceneGateway implements ChatSceneGateway {
  ApiChatSceneGateway({
    CollectionApi? collectionApi,
    MessageApi? messageApi,
    ReactionManager? reactionManager,
  }) : _collectionApi = collectionApi ?? CollectionApi.instance,
       _messageApi = messageApi ?? MessageApi.instance,
       _reactionManager = reactionManager ?? ReactionManager();

  final CollectionApi _collectionApi;
  final MessageApi _messageApi;
  final ReactionManager _reactionManager;

  @override
  Future<void> addFavorite(WKMsg message) {
    return _collectionApi.add(
      clientMsgNo: message.clientMsgNO,
      messageId: message.messageID.isEmpty ? null : message.messageID,
      content: message.content,
      contentType: message.contentType,
    );
  }

  @override
  Future<void> recallMessage(WKMsg message) {
    return _messageApi.revokeMessage(message.clientMsgNO);
  }

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) {
    return _reactionManager.toggleReaction(message: message, emoji: emoji);
  }

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    final conversations = await WKIM.shared.conversationManager.getAll();
    return buildForwardTargetsFromConversations(
      conversations,
      excludedChannelId: excludedChannelId,
      excludedChannelType: excludedChannelType,
    );
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {
    for (final target in targets) {
      final channel = WKChannel(target.channelId, target.channelType)
        ..channelName = target.displayName;
      for (final payload in payloads) {
        final content = payload.cloneContent();
        if (content == null) {
          continue;
        }
        WKIM.shared.messageManager.sendMessage(content, channel);
      }
    }
  }
}
```

- [ ] **Step 4: Add forward payloads, the message action controller, and provider wiring**

```dart
// lib/modules/chat/message_forwarding.dart
import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

@immutable
class ForwardPayload {
  const ForwardPayload({
    required this.clientMsgNo,
    required this.content,
  });

  final String clientMsgNo;
  final WKMessageContent? content;

  WKMessageContent? cloneContent() => cloneMessageContentForForward(content);
}

List<ForwardPayload> buildForwardPayloads(Iterable<WKMsg> messages) {
  return messages
      .map(
        (message) => ForwardPayload(
          clientMsgNo: message.clientMsgNO,
          content: cloneMessageContentForForward(message.messageContent),
        ),
      )
      .where((payload) => payload.content != null)
      .toList(growable: false);
}
```

```dart
// lib/modules/chat/chat_message_action_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'chat_scene_gateway.dart';
import 'message_forwarding.dart';

@immutable
class ChatForwardRequest {
  const ChatForwardRequest({required this.payloads});

  final List<ForwardPayload> payloads;
}

@immutable
class ChatMessageActionState {
  const ChatMessageActionState({
    this.feedbackMessage,
    this.forwardRequest,
    this.busyMessageIds = const <String>{},
  });

  final String? feedbackMessage;
  final ChatForwardRequest? forwardRequest;
  final Set<String> busyMessageIds;

  ChatMessageActionState copyWith({
    String? feedbackMessage,
    bool clearFeedbackMessage = false,
    ChatForwardRequest? forwardRequest,
    bool clearForwardRequest = false,
    Set<String>? busyMessageIds,
  }) {
    return ChatMessageActionState(
      feedbackMessage: clearFeedbackMessage
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      forwardRequest: clearForwardRequest
          ? null
          : (forwardRequest ?? this.forwardRequest),
      busyMessageIds: busyMessageIds ?? this.busyMessageIds,
    );
  }
}

class ChatMessageActionController
    extends StateNotifier<ChatMessageActionState> {
  ChatMessageActionController({required ChatSceneGateway gateway})
    : _gateway = gateway,
      super(const ChatMessageActionState());

  final ChatSceneGateway _gateway;

  Future<void> favorite(WKMsg message) async {
    await _gateway.addFavorite(message);
    state = state.copyWith(feedbackMessage: '已收藏');
  }

  Future<void> recall(WKMsg message) async {
    final busy = {...state.busyMessageIds, message.messageID};
    state = state.copyWith(busyMessageIds: busy);
    try {
      await _gateway.recallMessage(message);
      state = state.copyWith(feedbackMessage: '已撤回');
    } finally {
      final nextBusy = {...state.busyMessageIds}..remove(message.messageID);
      state = state.copyWith(busyMessageIds: nextBusy);
    }
  }

  Future<void> toggleReaction(WKMsg message, String emoji) async {
    await _gateway.toggleReaction(message, emoji);
    state = state.copyWith(feedbackMessage: '已更新表情回应');
  }

  void prepareForward(List<WKMsg> messages) {
    final payloads = buildForwardPayloads(messages);
    state = state.copyWith(
      forwardRequest: ChatForwardRequest(payloads: payloads),
    );
  }

  void clearTransientState() {
    state = state.copyWith(
      clearFeedbackMessage: true,
      clearForwardRequest: true,
    );
  }
}
```

```dart
// add to lib/modules/chat/chat_scene_providers.dart
import 'chat_message_action_controller.dart';
import 'chat_scene_gateway.dart';

final chatSceneGatewayProvider = Provider.autoDispose
    .family<ChatSceneGateway, ChatSession>((ref, session) {
      return ApiChatSceneGateway();
    });

final chatMessageActionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMessageActionController, ChatMessageActionState, ChatSession>((
      ref,
      session,
    ) {
      return ChatMessageActionController(
        gateway: ref.watch(chatSceneGatewayProvider(session)),
      );
    });
```

- [ ] **Step 5: Run the action-controller test to verify it passes**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart`
Expected: PASS with favorite and forward-request assertions green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_scene_gateway.dart lib/modules/chat/chat_message_action_controller.dart lib/modules/chat/message_forwarding.dart test/modules/chat/chat_message_action_controller_test.dart
git commit -m "feat: add chat scene action controller"
```

### Task 3: Upgrade The Composer And Add Mention Control

**Files:**
- Create: `lib/modules/chat/chat_mentions_controller.dart`
- Modify: `lib/modules/chat/chat_composer_controller.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_mentions_controller_test.dart`
- Modify: `test/modules/chat/chat_composer_controller_test.dart`

- [ ] **Step 1: Write the failing mentions and composer tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_composer_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_mentions_controller.dart';
import 'package:wukong_im_app/wukong_base/views/mention_suggestion.dart';

void main() {
  test('consumeSubmission trims text and clears reply after success', () async {
    final controller = ChatComposerController(
      channelId: 'group-1',
      channelType: 2,
    );
    controller.updateText('  hello team  ');
    controller.setPendingReply(messageId: 'mid-1', preview: 'original');

    final payload = controller.buildSubmissionPayload();

    expect(payload.text, 'hello team');
    expect(payload.replyMessageId, 'mid-1');

    controller.markSubmitSucceeded();
    expect(controller.state.pendingReplyMessageId, isNull);
  });

  test('mention controller filters by query and inserts selected mention', () {
    final controller = ChatMentionsController(
      loadSuggestions: () async => <MentionSuggestion>[
        MentionSuggestion(id: 'u1', name: 'Alice'),
        MentionSuggestion(id: 'u2', name: 'Bob'),
      ],
    );

    controller.updateFromText('hello @a', cursorOffset: 8);
    expect(controller.state.isActive, isTrue);
    expect(controller.state.suggestions.first.name, 'Alice');

    final result = controller.applySelection('hello @a', cursorOffset: 8);
    expect(result.text, 'hello @Alice ');
    expect(result.mentionedUids, <String>['u1']);
  });
}
```

- [ ] **Step 2: Run the composer and mentions tests to verify they fail**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_mentions_controller_test.dart`
Expected: FAIL with missing `buildSubmissionPayload`, `markSubmitSucceeded`, `ChatMentionsController`, or `MentionApplyResult`

- [ ] **Step 3: Extend the composer controller with submit payload extraction**

```dart
// lib/modules/chat/chat_composer_controller.dart
@immutable
class ChatComposerSubmissionPayload {
  const ChatComposerSubmissionPayload({
    required this.text,
    this.replyMessageId,
    this.replyPreview,
  });

  final String text;
  final String? replyMessageId;
  final String? replyPreview;
}

// add inside ChatComposerController
ChatComposerSubmissionPayload buildSubmissionPayload() {
  return ChatComposerSubmissionPayload(
    text: state.text.trim(),
    replyMessageId: state.pendingReplyMessageId,
    replyPreview: state.pendingReplyPreview,
  );
}

void markSubmitSucceeded() {
  state = state.copyWith(
    text: '',
    clearReply: true,
    showFacePanel: false,
    showFunctionPanel: false,
  );
  _scheduleSave();
}
```

- [ ] **Step 4: Add the mentions controller**

```dart
// lib/modules/chat/chat_mentions_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wukong_base/views/mention_suggestion.dart';

typedef MentionSuggestionLoader = Future<List<MentionSuggestion>> Function();

@immutable
class MentionApplyResult {
  const MentionApplyResult({
    required this.text,
    required this.cursorOffset,
    required this.mentionedUids,
  });

  final String text;
  final int cursorOffset;
  final List<String> mentionedUids;
}

@immutable
class ChatMentionsState {
  const ChatMentionsState({
    this.isActive = false,
    this.query = '',
    this.triggerOffset = -1,
    this.suggestions = const <MentionSuggestion>[],
    this.mentionedUids = const <String>[],
  });

  final bool isActive;
  final String query;
  final int triggerOffset;
  final List<MentionSuggestion> suggestions;
  final List<String> mentionedUids;

  ChatMentionsState copyWith({
    bool? isActive,
    String? query,
    int? triggerOffset,
    List<MentionSuggestion>? suggestions,
    List<String>? mentionedUids,
  }) {
    return ChatMentionsState(
      isActive: isActive ?? this.isActive,
      query: query ?? this.query,
      triggerOffset: triggerOffset ?? this.triggerOffset,
      suggestions: suggestions ?? this.suggestions,
      mentionedUids: mentionedUids ?? this.mentionedUids,
    );
  }
}

class ChatMentionsController extends StateNotifier<ChatMentionsState> {
  ChatMentionsController({required MentionSuggestionLoader loadSuggestions})
    : _loadSuggestions = loadSuggestions,
      super(const ChatMentionsState());

  final MentionSuggestionLoader _loadSuggestions;

  Future<void> updateFromText(String text, {required int cursorOffset}) async {
    final triggerOffset = text.lastIndexOf('@', cursorOffset - 1);
    if (triggerOffset == -1) {
      state = state.copyWith(
        isActive: false,
        query: '',
        triggerOffset: -1,
        suggestions: const <MentionSuggestion>[],
      );
      return;
    }
    final query = text.substring(triggerOffset + 1, cursorOffset).trim();
    final allSuggestions = await _loadSuggestions();
    final filtered = allSuggestions
        .where(
          (item) => query.isEmpty
              ? true
              : item.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
    state = state.copyWith(
      isActive: true,
      query: query,
      triggerOffset: triggerOffset,
      suggestions: filtered,
    );
  }

  MentionApplyResult applySelection(String text, {required int cursorOffset}) {
    final suggestion = state.suggestions.first;
    final prefix = text.substring(0, state.triggerOffset);
    final suffix = text.substring(cursorOffset);
    final inserted = '@${suggestion.name} ';
    final nextText = '$prefix$inserted$suffix';
    final nextMentionedUids = <String>[
      ...state.mentionedUids,
      suggestion.id,
    ];
    state = state.copyWith(
      isActive: false,
      query: '',
      triggerOffset: -1,
      suggestions: const <MentionSuggestion>[],
      mentionedUids: nextMentionedUids,
    );
    return MentionApplyResult(
      text: nextText,
      cursorOffset: prefix.length + inserted.length,
      mentionedUids: nextMentionedUids,
    );
  }

  void clear() {
    state = const ChatMentionsState();
  }
}
```

```dart
// add to lib/modules/chat/chat_scene_providers.dart
import '../../wukong_base/views/mention_suggestion.dart';
import 'chat_mentions_controller.dart';

final chatMentionsControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMentionsController, ChatMentionsState, ChatSession>((ref, session) {
      return ChatMentionsController(
        loadSuggestions: () async => const <MentionSuggestion>[],
      );
    });
```

- [ ] **Step 5: Run the composer and mentions tests to verify they pass**

Run: `flutter test test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_mentions_controller_test.dart`
Expected: PASS with submit-payload and mention-insertion assertions green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_composer_controller.dart lib/modules/chat/chat_mentions_controller.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_mentions_controller_test.dart
git commit -m "feat: add chat composer submit and mentions control"
```

### Task 4: Add Selection, Search Mode, Viewport Anchors, And The Real Forward Page

**Files:**
- Create: `lib/modules/chat/chat_selection_controller.dart`
- Create: `lib/modules/chat/chat_search_mode_controller.dart`
- Create: `lib/modules/chat/forward_message_page.dart`
- Modify: `lib/modules/chat/chat_viewport_controller.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Test: `test/modules/chat/chat_selection_controller_test.dart`
- Test: `test/modules/chat/chat_search_mode_controller_test.dart`
- Test: `test/modules/chat/forward_message_page_test.dart`
- Modify: `test/modules/chat/chat_viewport_controller_test.dart`

- [ ] **Step 1: Write the failing selection, search-mode, forward-page, and viewport tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_search_mode_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_selection_controller.dart';

void main() {
  test('selection controller toggles identities and exposes batch availability', () {
    final controller = ChatSelectionController();

    controller.toggle('mid:1');
    controller.toggle('mid:2');

    expect(controller.state.selectedIdentities, <String>{'mid:1', 'mid:2'});
    expect(controller.state.canForward, isTrue);

    controller.toggle('mid:1');
    expect(controller.state.selectedIdentities, <String>{'mid:2'});
  });

  test('search mode controller stores and restores anchor order seq', () {
    final controller = ChatSearchModeController();

    controller.open(anchorOrderSeq: 321);
    controller.updateKeyword('hello');

    expect(controller.state.isActive, isTrue);
    expect(controller.state.anchorOrderSeq, 321);
    expect(controller.state.keyword, 'hello');

    controller.close();
    expect(controller.state.isActive, isFalse);
    expect(controller.state.anchorOrderSeq, 321);
  });
}
```

```dart
// add to test/modules/chat/chat_viewport_controller_test.dart
test('firstVisibleOrderSeq returns the first rendered order sequence', () {
  final controller = ChatViewportController(
    mapper: ChatMessageMapper(),
    currentUid: 'u_self',
  );
  final first = WKMsg()
    ..messageID = 'm1'
    ..orderSeq = 11;
  final second = WKMsg()
    ..messageID = 'm2'
    ..orderSeq = 12;

  controller.replaceAll(<WKMsg>[first, second]);

  expect(controller.firstVisibleOrderSeq, 11);
});
```

- [ ] **Step 2: Run the selection, search, forward, and viewport tests to verify they fail**

Run: `flutter test test/modules/chat/chat_selection_controller_test.dart test/modules/chat/chat_search_mode_controller_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_viewport_controller_test.dart`
Expected: FAIL with missing controllers, missing `ForwardMessagePage`, or missing viewport anchor helpers

- [ ] **Step 3: Add the selection and search-mode controllers**

```dart
// lib/modules/chat/chat_selection_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatSelectionState {
  const ChatSelectionState({
    this.selectedIdentities = const <String>{},
  });

  final Set<String> selectedIdentities;

  bool get canForward => selectedIdentities.isNotEmpty;
  bool get canFavorite => selectedIdentities.length == 1;
  int get selectedCount => selectedIdentities.length;

  ChatSelectionState copyWith({
    Set<String>? selectedIdentities,
  }) {
    return ChatSelectionState(
      selectedIdentities: selectedIdentities ?? this.selectedIdentities,
    );
  }
}

class ChatSelectionController extends StateNotifier<ChatSelectionState> {
  ChatSelectionController() : super(const ChatSelectionState());

  void seed(String identity) {
    state = state.copyWith(selectedIdentities: <String>{identity});
  }

  void toggle(String identity) {
    final next = {...state.selectedIdentities};
    if (!next.add(identity)) {
      next.remove(identity);
    }
    state = state.copyWith(selectedIdentities: next);
  }

  void clear() {
    state = const ChatSelectionState();
  }
}
```

```dart
// lib/modules/chat/chat_search_mode_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatSearchModeState {
  const ChatSearchModeState({
    this.isActive = false,
    this.anchorOrderSeq = 0,
    this.keyword = '',
  });

  final bool isActive;
  final int anchorOrderSeq;
  final String keyword;

  ChatSearchModeState copyWith({
    bool? isActive,
    int? anchorOrderSeq,
    String? keyword,
  }) {
    return ChatSearchModeState(
      isActive: isActive ?? this.isActive,
      anchorOrderSeq: anchorOrderSeq ?? this.anchorOrderSeq,
      keyword: keyword ?? this.keyword,
    );
  }
}

class ChatSearchModeController extends StateNotifier<ChatSearchModeState> {
  ChatSearchModeController() : super(const ChatSearchModeState());

  void open({required int anchorOrderSeq}) {
    state = state.copyWith(
      isActive: true,
      anchorOrderSeq: anchorOrderSeq,
      keyword: '',
    );
  }

  void updateKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void close() {
    state = state.copyWith(isActive: false);
  }
}
```

```dart
// add to lib/modules/chat/chat_scene_providers.dart
import 'chat_search_mode_controller.dart';
import 'chat_selection_controller.dart';

final chatSelectionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSelectionController, ChatSelectionState, ChatSession>((
      ref,
      session,
    ) {
      return ChatSelectionController();
    });

final chatSearchModeControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatSearchModeController, ChatSearchModeState, ChatSession>((
      ref,
      session,
    ) {
      return ChatSearchModeController();
    });
```

- [ ] **Step 4: Add viewport anchor helpers and the real forward page**

```dart
// lib/modules/chat/chat_viewport_controller.dart
// add inside ChatViewportController
int get firstVisibleOrderSeq {
  if (state.items.isEmpty) {
    return 0;
  }
  return state.items.first.message.orderSeq;
}

ChatMessageViewModel? itemByIdentity(String identity) {
  final index = state.identityToIndex[identity];
  if (index == null || index < 0 || index >= state.items.length) {
    return null;
  }
  return state.items[index];
}
```

```dart
// lib/modules/chat/forward_message_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/conversation_provider.dart';
import 'chat_scene_gateway.dart';
import 'message_forwarding.dart';

class ForwardMessagePage extends ConsumerStatefulWidget {
  const ForwardMessagePage({
    super.key,
    required this.payloads,
    required this.channelId,
    required this.channelType,
    this.gateway,
  });

  final List<ForwardPayload> payloads;
  final String channelId;
  final int channelType;
  final ChatSceneGateway? gateway;

  @override
  ConsumerState<ForwardMessagePage> createState() => _ForwardMessagePageState();
}

class _ForwardMessagePageState extends ConsumerState<ForwardMessagePage> {
  final Set<String> _selectedTargetKeys = <String>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationProvider);
    return FutureBuilder<List<ForwardTarget>>(
      future: buildForwardTargetsFromConversations(
        conversations,
        excludedChannelId: widget.channelId,
        excludedChannelType: widget.channelType,
      ),
      builder: (context, snapshot) {
        final targets = filterForwardTargets(snapshot.data ?? const [], _query);
        return Scaffold(
          appBar: AppBar(title: const Text('Forward')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search chats',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: targets.length,
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    final selected = _selectedTargetKeys.contains(target.key);
                    return CheckboxListTile(
                      value: selected,
                      title: Text(target.displayName),
                      subtitle: target.subtitle.isEmpty
                          ? null
                          : Text(target.subtitle),
                      onChanged: (_) {
                        setState(() {
                          if (!selected) {
                            _selectedTargetKeys.add(target.key);
                          } else {
                            _selectedTargetKeys.remove(target.key);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedTargetKeys.isEmpty
                          ? null
                          : () async {
                              final selectedTargets = targets
                                  .where(
                                    (target) => _selectedTargetKeys.contains(
                                      target.key,
                                    ),
                                  )
                                  .toList(growable: false);
                              final gateway =
                                  widget.gateway ?? ApiChatSceneGateway();
                              await gateway.sendForwardPayloads(
                                widget.payloads,
                                selectedTargets,
                              );
                              if (!mounted) {
                                return;
                              }
                              Navigator.of(context).pop();
                            },
                      child: Text(
                        _selectedTargetKeys.isEmpty
                            ? 'Forward'
                            : 'Forward (${_selectedTargetKeys.length})',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run the selection, search, forward, and viewport tests to verify they pass**

Run: `flutter test test/modules/chat/chat_selection_controller_test.dart test/modules/chat/chat_search_mode_controller_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_viewport_controller_test.dart`
Expected: PASS with selection/search assertions and updated viewport helper coverage green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/chat_selection_controller.dart lib/modules/chat/chat_search_mode_controller.dart lib/modules/chat/forward_message_page.dart lib/modules/chat/chat_viewport_controller.dart test/modules/chat/chat_selection_controller_test.dart test/modules/chat/chat_search_mode_controller_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_viewport_controller_test.dart
git commit -m "feat: add chat selection search and forward flows"
```

### Task 5: Rebuild The Chat Shell Around Scene Providers

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `lib/modules/chat/widgets/chat_composer.dart`
- Modify: `lib/modules/chat/widgets/chat_message_viewport.dart`
- Modify: `lib/modules/chat/widgets/chat_message_list_item.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Create: `lib/modules/chat/widgets/chat_message_action_sheet.dart`
- Create: `lib/modules/chat/widgets/chat_selection_toolbar.dart`
- Create: `lib/modules/chat/widgets/chat_search_mode_bar.dart`
- Create: `lib/modules/chat/widgets/chat_reply_preview_strip.dart`
- Test: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Write the failing scene-flow widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';

void main() {
  testWidgets('reply, search, and selection are scene-driven in the shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatPage(
            channelId: 'u_scene',
            channelType: 1,
            channelName: 'Scene Chat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('chat-open-search')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('chat-search-mode-field')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the scene-flow test to verify it fails**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart`
Expected: FAIL because the current shell still pushes the old search page directly and does not expose the new scene widgets

- [ ] **Step 3: Add the new scene widgets**

```dart
// lib/modules/chat/widgets/chat_message_action_sheet.dart
import 'package:flutter/material.dart';

enum ChatSceneAction {
  reply,
  forward,
  favorite,
  select,
  recall,
  react,
}

class ChatMessageActionSheet extends StatelessWidget {
  const ChatMessageActionSheet({
    super.key,
    required this.onSelected,
    required this.canRecall,
  });

  final ValueChanged<ChatSceneAction> onSelected;
  final bool canRecall;

  @override
  Widget build(BuildContext context) {
    final actions = <(ChatSceneAction, String)>[
      (ChatSceneAction.reply, '回复'),
      (ChatSceneAction.forward, '转发'),
      (ChatSceneAction.favorite, '收藏'),
      (ChatSceneAction.select, '多选'),
      if (canRecall) (ChatSceneAction.recall, '撤回'),
      (ChatSceneAction.react, '表情回应'),
    ];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: actions
            .map(
              (entry) => ListTile(
                title: Text(entry.$2),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(entry.$1);
                },
              ),
            )
            .toList(),
      ),
    );
  }
}
```

```dart
// lib/modules/chat/widgets/chat_selection_toolbar.dart
import 'package:flutter/material.dart';

class ChatSelectionToolbar extends StatelessWidget {
  const ChatSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onForward,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(onPressed: onCancel, icon: const Icon(Icons.close)),
          Expanded(child: Text('已选择 $selectedCount 条')),
          TextButton(onPressed: onForward, child: const Text('转发')),
        ],
      ),
    );
  }
}
```

```dart
// lib/modules/chat/widgets/chat_search_mode_bar.dart
import 'package:flutter/material.dart';

class ChatSearchModeBar extends StatelessWidget {
  const ChatSearchModeBar({
    super.key,
    required this.initialKeyword,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
  });

  final String initialKeyword;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialKeyword);
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey<String>('chat-search-mode-field'),
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(
              hintText: '搜索聊天记录',
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ],
    );
  }
}
```

```dart
// lib/modules/chat/widgets/chat_reply_preview_strip.dart
import 'package:flutter/material.dart';

class ChatReplyPreviewStrip extends StatelessWidget {
  const ChatReplyPreviewStrip({
    super.key,
    required this.previewText,
    required this.onClose,
  });

  final String previewText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(previewText, maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rebuild `ChatPageShell` and the public chat wrapper around scene state**

```dart
// lib/modules/chat/chat_page.dart
import 'forward_message_page.dart';
export 'chat_page_shell.dart' show ChatPageShell;
export 'forward_message_page.dart' show ForwardMessagePage;

class ChatPage extends StatelessWidget {
  const ChatPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.initialAroundOrderSeq,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final int? initialAroundOrderSeq;

  @override
  Widget build(BuildContext context) {
    return ChatPageShell(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      initialAroundOrderSeq: initialAroundOrderSeq,
    );
  }
}
```

```dart
// lib/modules/chat/chat_page_shell.dart
@override
Widget build(BuildContext context) {
  final scene = ref.watch(chatSceneControllerProvider(_chatSession));
  final searchMode = ref.watch(chatSearchModeControllerProvider(_chatSession));
  final selection = ref.watch(chatSelectionControllerProvider(_chatSession));
  final composer = ref.watch(chatComposerProvider(_chatSession));
  final mentions = ref.watch(chatMentionsControllerProvider(_chatSession));

  return Scaffold(
    appBar: AppBar(
      title: searchMode.isActive
          ? ChatSearchModeBar(
              initialKeyword: searchMode.keyword,
              onChanged: (value) {
                ref
                    .read(chatSearchModeControllerProvider(_chatSession).notifier)
                    .updateKeyword(value);
              },
              onSubmitted: (value) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatSearchEntryPage(
                      channelId: widget.channelId,
                      channelType: widget.channelType,
                      channelName: widget.channelName,
                    ),
                  ),
                );
              },
              onClose: () {
                ref
                    .read(chatSearchModeControllerProvider(_chatSession).notifier)
                    .close();
                ref
                    .read(chatSceneControllerProvider(_chatSession).notifier)
                    .restoreNormal();
              },
            )
          : Text(_resolveTitle()),
      actions: searchMode.isActive
          ? const <Widget>[]
          : <Widget>[
              IconButton(
                key: const ValueKey<String>('chat-open-search'),
                onPressed: () {
                  final anchor = ref
                      .read(chatViewportProvider(_chatSession).notifier)
                      .firstVisibleOrderSeq;
                  ref
                      .read(chatSearchModeControllerProvider(_chatSession).notifier)
                      .open(anchorOrderSeq: anchor);
                  ref
                      .read(chatSceneControllerProvider(_chatSession).notifier)
                      .enterSearchMode(anchorOrderSeq: anchor);
                },
                icon: const Icon(Icons.search),
              ),
            ],
    ),
    body: Column(
      children: [
        if (scene.mode == ChatSceneMode.selecting)
          ChatSelectionToolbar(
            selectedCount: selection.selectedCount,
            onCancel: () {
              ref.read(chatSelectionControllerProvider(_chatSession).notifier).clear();
              ref.read(chatSceneControllerProvider(_chatSession).notifier).restoreNormal();
            },
            onForward: () {
              final viewport = ref.read(chatViewportProvider(_chatSession));
              final selectedMessages = selection.selectedIdentities
                  .map((id) => viewport.items.firstWhere((item) => item.identity == id).message)
                  .toList(growable: false);
              ref
                  .read(chatMessageActionControllerProvider(_chatSession).notifier)
                  .prepareForward(selectedMessages);
            },
          ),
        Expanded(
          child: ChatMessageViewport(
            child: _ChatViewportPane(session: _chatSession, onBuild: widget.onViewportBuild),
          ),
        ),
        ChatComposer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (composer.pendingReplyPreview != null)
                ChatReplyPreviewStrip(
                  previewText: composer.pendingReplyPreview!,
                  onClose: () {
                    ref.read(chatComposerProvider(_chatSession).notifier).clearPendingReply();
                    ref.read(chatSceneControllerProvider(_chatSession).notifier).restoreNormal();
                  },
                ),
              if (mentions.isActive && mentions.suggestions.isNotEmpty)
                MentionSuggestionOverlay(
                  suggestions: mentions.suggestions,
                  selectedIndex: 0,
                  onSelected: (suggestion) {
                    final result = ref
                        .read(chatMentionsControllerProvider(_chatSession).notifier)
                        .applySelection(
                          _textController.text,
                          cursorOffset: _textController.selection.baseOffset,
                        );
                    _textController.value = TextEditingValue(
                      text: result.text,
                      selection: TextSelection.collapsed(offset: result.cursorOffset),
                    );
                    ref.read(chatComposerProvider(_chatSession).notifier).updateText(result.text);
                  },
                ),
              _ChatComposerPane(session: _chatSession),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _handleSceneAction(
  ChatSceneAction action,
  ChatMessageViewModel model,
) async {
  switch (action) {
    case ChatSceneAction.reply:
      ref.read(chatComposerProvider(_chatSession).notifier).setPendingReply(
        messageId: model.message.messageID,
        preview: model.previewText,
      );
      ref.read(chatSceneControllerProvider(_chatSession).notifier).enterReplyMode();
      break;
    case ChatSceneAction.forward:
      ref
          .read(chatMessageActionControllerProvider(_chatSession).notifier)
          .prepareForward(<WKMsg>[model.message]);
      final request = ref.read(chatMessageActionControllerProvider(_chatSession)).forwardRequest;
      if (request == null) {
        break;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ForwardMessagePage(
            payloads: request.payloads,
            channelId: widget.channelId,
            channelType: widget.channelType,
          ),
        ),
      );
      break;
    case ChatSceneAction.favorite:
      await ref
          .read(chatMessageActionControllerProvider(_chatSession).notifier)
          .favorite(model.message);
      break;
    case ChatSceneAction.select:
      ref.read(chatSelectionControllerProvider(_chatSession).notifier).seed(model.identity);
      ref
          .read(chatSceneControllerProvider(_chatSession).notifier)
          .enterSelectionMode(seedIdentity: model.identity);
      break;
    case ChatSceneAction.recall:
      await ref
          .read(chatMessageActionControllerProvider(_chatSession).notifier)
          .recall(model.message);
      break;
    case ChatSceneAction.react:
      await ref
          .read(chatMessageActionControllerProvider(_chatSession).notifier)
          .toggleReaction(model.message, '👍');
      break;
  }
}

void _handleComposerChanged(String value) {
  ref.read(chatComposerProvider(_chatSession).notifier).updateText(value);
  final cursorOffset = _textController.selection.baseOffset;
  ref
      .read(chatMentionsControllerProvider(_chatSession).notifier)
      .updateFromText(value, cursorOffset: cursorOffset < 0 ? value.length : cursorOffset);
}
```

- [ ] **Step 5: Route long-press and reaction taps through the scene shell**

```dart
// lib/modules/chat/widgets/chat_message_list_item.dart
return MessageBubble(
  model: model,
  onLongPress: () async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChatMessageActionSheet(
        canRecall: model.isSelf,
        onSelected: (action) {
          onActionSelected(action, model);
        },
      ),
    );
  },
  onAddReaction: () => onActionSelected(ChatSceneAction.react, model),
  onReactionTap: onReactionTap,
  reactions: reactions,
);
```

```dart
// lib/widgets/message_bubble.dart
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.model,
    this.onLongPress,
    this.onAddReaction,
    this.onReactionTap,
    this.reactions = const [],
    this.participant,
    this.statusInfo,
    this.onTap,
    this.onSecondaryTapDown,
  });
}
```

- [ ] **Step 6: Run the scene-flow and parity widget tests to verify they pass**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS with the new search-mode field assertion and the existing Android-title/call-action assertions green

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_composer.dart lib/modules/chat/widgets/chat_message_viewport.dart lib/modules/chat/widgets/chat_message_list_item.dart lib/modules/chat/widgets/chat_message_action_sheet.dart lib/modules/chat/widgets/chat_selection_toolbar.dart lib/modules/chat/widgets/chat_search_mode_bar.dart lib/modules/chat/widgets/chat_reply_preview_strip.dart lib/widgets/message_bubble.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: wire chat shell through scene providers"
```

### Task 6: Finish Compatibility Cleanup, Provider Wiring, And End-To-End Verification

**Files:**
- Modify: `lib/wukong_uikit/chat/message_long_press_menu.dart`
- Modify: `test/modules/chat/chat_pages_compile_test.dart`
- Test: `test/modules/chat/chat_pages_compile_test.dart`

- [ ] **Step 1: Write the failing compile and compatibility assertions**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/chat/forward_message_page.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';

void main() {
  testWidgets('chat exports compile with the real forward page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(
          channelId: 'u_compile',
          channelType: 1,
          channelName: 'Compile',
        ),
      ),
    );
    expect(find.byType(ChatPage), findsOneWidget);

    final widget = ForwardMessagePage(
      payloads: const <ForwardPayload>[],
      channelId: 'u_compile',
      channelType: 1,
    );
    expect(widget, isA<ForwardMessagePage>());
  });
}
```

- [ ] **Step 2: Run the compile test to verify it fails**

Run: `flutter test test/modules/chat/chat_pages_compile_test.dart`
Expected: FAIL until `chat_page.dart` exports the real forward page and provider wiring resolves

- [ ] **Step 3: Reduce the old long-press menu to a wrapper**

```dart
// lib/wukong_uikit/chat/message_long_press_menu.dart
import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';

Future<ChatSceneAction?> showMessageLongPressMenu({
  required BuildContext context,
  required Offset position,
  required String messageType,
  required bool isFromMe,
  required bool canRecall,
}) {
  return showModalBottomSheet<ChatSceneAction>(
    context: context,
    builder: (_) => ChatMessageActionSheet(
      canRecall: canRecall,
      onSelected: (action) {
        Navigator.of(context).pop(action);
      },
    ),
  );
}
```

- [ ] **Step 4: Run full chat verification and the required remote log check**

Run: `flutter analyze lib/modules/chat lib/data/providers/conversation_provider.dart lib/widgets/message_bubble.dart lib/wukong_uikit/chat/message_long_press_menu.dart`
Expected: PASS with no new analyze errors in the chat mainline files

Run: `flutter test test/modules/chat/chat_scene_controller_test.dart test/modules/chat/chat_message_action_controller_test.dart test/modules/chat/chat_selection_controller_test.dart test/modules/chat/chat_search_mode_controller_test.dart test/modules/chat/chat_mentions_controller_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_viewport_controller_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
Expected: PASS with all Phase 4 scene-kernel and regression coverage green

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'revoke|reaction|favorite|search|typing'"`
Expected: output is allowed to be empty, but it must not show new server-side errors introduced by recall, reaction, favorites, or search requests

- [ ] **Step 5: Commit**

```bash
git add lib/wukong_uikit/chat/message_long_press_menu.dart test/modules/chat/chat_pages_compile_test.dart
git commit -m "refactor: finish chat scene mainline wiring"
```
