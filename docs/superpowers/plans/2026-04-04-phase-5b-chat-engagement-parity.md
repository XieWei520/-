# Phase 5B Chat Engagement Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align Flutter chat reactions and chat-mainline favorite consistency with the TangSengDaoDao Android original on Android, without reopening the Phase 4/5A architecture.

**Architecture:** This plan keeps all work on the existing scene mainline. Favorites gain a thin persistent registry plus controller-side busy/feedback semantics, while reactions reuse `ReactionManager` as the low-level source of truth and add only a narrow UI bridge for per-message updates and picker interaction. The viewport stays scene-owned, but reaction rendering is isolated per message so engagement changes do not force list-wide rebuilds.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, shared_preferences via `StorageUtils`, wukongimfluttersdk, existing scene providers, PowerShell, optional SSH validation

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only the approved design in [2026-04-04-phase-5b-chat-engagement-parity-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-04-phase-5b-chat-engagement-parity-design.md).

In scope:

- chat-mainline favorite consistency through the long-press favorite action
- persistent favorite deduplication across refresh and re-entry
- expanded reaction picker depth from long-press reaction entry and bubble `+`
- same-emoji cancel and different-emoji switch semantics
- reaction chip rendering, ordering, highlight, and retap behavior
- message-scoped busy guards and chat-visible success/failure feedback
- Android parity tests for favorite/reaction entry and interaction meaning

Out of scope for this plan:

- favorites page or favorites tab
- reaction member-detail sheet
- `@member`, typing, or broader chat-search parity
- unfavorite flow from the chat timeline
- backend contract rewrites unless deployed behavior proves a verified mismatch

## File Structure

### New Files

- `lib/modules/chat/chat_message_favorite_registry.dart`
  - Persistent best-known favorite registry keyed by stable message identity.
- `lib/modules/chat/chat_message_reaction_mapping.dart`
  - Maps `ReactionManager` domain objects into `WKMessageReaction` widget models and exposes the current-user selected emoji.
- `lib/modules/chat/widgets/chat_message_engagement_bubble.dart`
  - Message-scoped reaction bridge that listens for reaction updates and feeds `MessageBubble` without rebuilding the full viewport.
- `lib/modules/chat/widgets/chat_reaction_picker_popup.dart`
  - Lightweight Android-style reaction picker popup that reuses `WKReactionPicker`.
- `test/modules/chat/chat_message_engagement_bubble_test.dart`
  - Verifies prepared reactions, reaction-stream updates, and per-message isolation.

### Existing Files To Modify

- `lib/modules/chat/chat_message_action_controller.dart`
  - Extend favorite/reaction semantics with busy guards, persistent favorite knowledge, and feedback lifecycle.
- `lib/modules/chat/chat_scene_gateway.dart`
  - Expose reaction preparation and reaction-update streaming on top of `ReactionManager`.
- `lib/modules/chat/chat_scene_providers.dart`
  - Inject the new favorite registry into the action controller.
- `lib/modules/chat/chat_page_shell.dart`
  - Swap raw `MessageBubble` usage to the engagement wrapper, open the reaction picker from both entries, and surface favorite/reaction feedback.
- `lib/wukong_base/msg/widget/wk_message_reaction.dart`
  - Add stable test keys and selected-emoji highlighting to the existing picker/chips.
- `test/modules/chat/chat_message_action_controller_test.dart`
  - Lock favorite deduplication, favorite failure rollback, and reaction/favorite busy semantics.
- `test/modules/chat/chat_page_scene_flow_test.dart`
  - Lock chat-mainline reaction picker, chip toggle, and favorite feedback flows.
- `test/modules/chat/chat_page_android_parity_test.dart`
  - Lock Android-facing reaction/favorite entry positions and picker reachability.
- `test/modules/chat/message_bubble_experience_test.dart`
  - Lock selected-reaction visual state and expanded picker emoji exposure.

## Verification Commands Used Throughout

- `flutter test test/modules/chat/chat_message_action_controller_test.dart`
- `flutter test test/modules/chat/chat_message_engagement_bubble_test.dart`
- `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "reaction"`
- `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "favorite"`
- `flutter test test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart`
- `flutter analyze lib/modules/chat lib/widgets/message_bubble.dart lib/wukong_base/msg/widget/wk_message_reaction.dart`
- `flutter test test/modules/chat/chat_message_action_controller_test.dart test/modules/chat/chat_message_engagement_bubble_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/chat_message_action_sheet_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_pages_compile_test.dart`

If local reaction or favorite behavior looks correct but deployed behavior diverges, run:

- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'reaction|favorite'"`

### Task 1: Add Persistent Favorite Registry And Controller Consistency Rules

**Files:**
- Create: `lib/modules/chat/chat_message_favorite_registry.dart`
- Modify: `lib/modules/chat/chat_message_action_controller.dart`
- Modify: `lib/modules/chat/chat_scene_providers.dart`
- Modify: `test/modules/chat/chat_message_action_controller_test.dart`

- [ ] **Step 1: Write the failing favorite-consistency controller tests**

```dart
test('favorite suppresses duplicate in-flight requests for the same message', () async {
  final completer = Completer<void>();
  final gateway = _FakeChatSceneGateway(
    onFavorite: (message) => completer.future,
  );
  final registry = _FakeFavoriteRegistry();
  final controller = ChatMessageActionController(
    gateway: gateway,
    favoriteRegistry: registry,
  );
  addTearDown(controller.dispose);
  final message = WKMsg()
    ..messageID = 'mid-favorite'
    ..clientMsgNO = 'client-favorite'
    ..channelID = 'u_favorite'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('favorite me');

  final first = controller.favorite(message);
  final second = controller.favorite(message);

  expect(gateway.favoriteCalls, <String>['client-favorite']);
  expect(controller.state.busyMessageIds, contains('mid-favorite'));

  completer.complete();
  await Future.wait<void>(<Future<void>>[first, second]);

  expect(controller.state.busyMessageIds, isEmpty);
  expect(controller.state.knownFavoriteMessageIds, contains('mid-favorite'));
  expect(registry.savedKeys, contains('mid-favorite'));
});

test('favorite uses restored registry state to skip duplicate post after re-entry', () async {
  final gateway = _FakeChatSceneGateway();
  final registry = _FakeFavoriteRegistry(seedKeys: const <String>{'mid-known'});
  final controller = ChatMessageActionController(
    gateway: gateway,
    favoriteRegistry: registry,
  );
  addTearDown(controller.dispose);
  final message = WKMsg()
    ..messageID = 'mid-known'
    ..clientMsgNO = 'client-known'
    ..channelID = 'u_known'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('already favorited');

  await controller.favorite(message);

  expect(gateway.favoriteCalls, isEmpty);
  expect(controller.state.feedbackMessage, '\u5df2\u6536\u85cf');
});

test('favorite failure clears busy state and does not persist fake favorite state', () async {
  final gateway = _FakeChatSceneGateway(
    onFavorite: (message) async => throw Exception('favorite failed'),
  );
  final registry = _FakeFavoriteRegistry();
  final controller = ChatMessageActionController(
    gateway: gateway,
    favoriteRegistry: registry,
  );
  addTearDown(controller.dispose);
  final message = WKMsg()
    ..messageID = 'mid-failed'
    ..clientMsgNO = 'client-failed'
    ..channelID = 'u_failed'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('favorite failure');

  await expectLater(controller.favorite(message), throwsException);

  expect(controller.state.busyMessageIds, isEmpty);
  expect(controller.state.knownFavoriteMessageIds, isNot(contains('mid-failed')));
  expect(controller.state.feedbackMessage, '\u6536\u85cf\u5931\u8d25');
  expect(registry.savedKeys, isEmpty);
});
```

- [ ] **Step 2: Run the controller test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart`
Expected: FAIL with missing `favoriteRegistry`, missing `knownFavoriteMessageIds`, or old favorite semantics that still issue duplicate requests

- [ ] **Step 3: Implement the persistent registry and controller changes**

```dart
// lib/modules/chat/chat_message_favorite_registry.dart
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/utils/storage_utils.dart';

String favoriteMessageKeyOf(WKMsg message) {
  final messageId = message.messageID.trim();
  if (messageId.isNotEmpty) {
    return 'mid:$messageId';
  }
  final clientMsgNo = message.clientMsgNO.trim();
  if (clientMsgNo.isNotEmpty) {
    return 'cid:$clientMsgNo';
  }
  return '';
}

abstract class ChatMessageFavoriteRegistry {
  Set<String> snapshot();
  bool contains(String key);
  Future<void> markFavorited(String key);
}

class SharedPrefsChatMessageFavoriteRegistry
    implements ChatMessageFavoriteRegistry {
  static const String _storageKey = 'chat.favorite.known_message_keys';

  Set<String>? _cache;

  @override
  Set<String> snapshot() {
    _cache ??= {...?StorageUtils.getStringList(_storageKey)};
    return Set<String>.unmodifiable(_cache ?? const <String>{});
  }

  @override
  bool contains(String key) {
    if (key.isEmpty) {
      return false;
    }
    return snapshot().contains(key);
  }

  @override
  Future<void> markFavorited(String key) async {
    if (key.isEmpty) {
      return;
    }
    final next = {...snapshot(), key};
    _cache = next;
    await StorageUtils.setStringList(_storageKey, next.toList(growable: false));
  }
}
```

```dart
// lib/modules/chat/chat_message_action_controller.dart
import 'chat_message_favorite_registry.dart';

const String _favoriteFailureMessage = '\u6536\u85cf\u5931\u8d25';

@immutable
class ChatMessageActionState {
  ChatMessageActionState({
    this.feedbackMessage,
    this.forwardRequest,
    Set<String> busyMessageIds = const <String>{},
    Set<String> knownFavoriteMessageIds = const <String>{},
  }) : busyMessageIds = Set<String>.unmodifiable(busyMessageIds),
       knownFavoriteMessageIds =
           Set<String>.unmodifiable(knownFavoriteMessageIds);

  final String? feedbackMessage;
  final ChatForwardRequest? forwardRequest;
  final Set<String> busyMessageIds;
  final Set<String> knownFavoriteMessageIds;

  ChatMessageActionState copyWith({
    String? feedbackMessage,
    bool clearFeedbackMessage = false,
    ChatForwardRequest? forwardRequest,
    bool clearForwardRequest = false,
    Set<String>? busyMessageIds,
    Set<String>? knownFavoriteMessageIds,
  }) {
    return ChatMessageActionState(
      feedbackMessage: clearFeedbackMessage
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      forwardRequest: clearForwardRequest
          ? null
          : (forwardRequest ?? this.forwardRequest),
      busyMessageIds: busyMessageIds ?? this.busyMessageIds,
      knownFavoriteMessageIds:
          knownFavoriteMessageIds ?? this.knownFavoriteMessageIds,
    );
  }
}

class ChatMessageActionController
    extends StateNotifier<ChatMessageActionState> {
  ChatMessageActionController({
    required ChatSceneGateway gateway,
    ChatMessageFavoriteRegistry? favoriteRegistry,
  }) : _gateway = gateway,
       _favoriteRegistry =
           favoriteRegistry ?? SharedPrefsChatMessageFavoriteRegistry(),
       super(
         ChatMessageActionState(
           knownFavoriteMessageIds:
               (favoriteRegistry ?? SharedPrefsChatMessageFavoriteRegistry())
                   .snapshot(),
         ),
       );

  final ChatSceneGateway _gateway;
  final ChatMessageFavoriteRegistry _favoriteRegistry;

  Future<void> favorite(WKMsg message) async {
    final key = favoriteMessageKeyOf(message);
    if (key.isNotEmpty && state.busyMessageIds.contains(key)) {
      return;
    }
    if (key.isNotEmpty &&
        (state.knownFavoriteMessageIds.contains(key) ||
            _favoriteRegistry.contains(key))) {
      state = state.copyWith(
        feedbackMessage: _favoriteSuccessMessage,
        knownFavoriteMessageIds: {...state.knownFavoriteMessageIds, key},
      );
      return;
    }

    final nextBusy = key.isEmpty
        ? state.busyMessageIds
        : {...state.busyMessageIds, key};
    state = state.copyWith(busyMessageIds: nextBusy);
    try {
      await _gateway.addFavorite(message);
      if (key.isNotEmpty) {
        await _favoriteRegistry.markFavorited(key);
      }
      state = state.copyWith(
        feedbackMessage: _favoriteSuccessMessage,
        knownFavoriteMessageIds: key.isEmpty
            ? state.knownFavoriteMessageIds
            : {...state.knownFavoriteMessageIds, key},
      );
    } catch (_) {
      state = state.copyWith(feedbackMessage: _favoriteFailureMessage);
      rethrow;
    } finally {
      if (key.isNotEmpty) {
        final clearedBusy = {...state.busyMessageIds}..remove(key);
        state = state.copyWith(busyMessageIds: clearedBusy);
      }
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearFeedbackMessage: true);
  }
}
```

```dart
// lib/modules/chat/chat_scene_providers.dart
final chatMessageFavoriteRegistryProvider =
    Provider.autoDispose<ChatMessageFavoriteRegistry>((ref) {
  return SharedPrefsChatMessageFavoriteRegistry();
});

final chatMessageActionControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatMessageActionController, ChatMessageActionState, ChatSession>((
      ref,
      session,
    ) {
      return ChatMessageActionController(
        gateway: ref.watch(chatSceneGatewayProvider(session)),
        favoriteRegistry: ref.watch(chatMessageFavoriteRegistryProvider),
      );
    });
```

```dart
// test/modules/chat/chat_message_action_controller_test.dart
class _FakeFavoriteRegistry implements ChatMessageFavoriteRegistry {
  _FakeFavoriteRegistry({Set<String> seedKeys = const <String>{}})
      : _keys = {...seedKeys};

  final Set<String> _keys;
  Set<String> get savedKeys => Set<String>.unmodifiable(_keys);

  @override
  bool contains(String key) => _keys.contains(key);

  @override
  Future<void> markFavorited(String key) async {
    _keys.add(key);
  }

  @override
  Set<String> snapshot() => Set<String>.unmodifiable(_keys);
}

class _FakeChatSceneGateway implements ChatSceneGateway {
  _FakeChatSceneGateway({
    this.onRecall,
    this.onFavorite,
  });

  final List<String> favoriteCalls = <String>[];
  final List<String> recallCalls = <String>[];
  final List<String> reactionCalls = <String>[];
  final Future<void> Function(WKMsg message)? onRecall;
  final Future<void> Function(WKMsg message)? onFavorite;

  @override
  Future<void> addFavorite(WKMsg message) async {
    favoriteCalls.add(message.clientMsgNO);
    await onFavorite?.call(message);
  }

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {
    recallCalls.add(message.clientMsgNO);
    await onRecall?.call(message);
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    reactionCalls.add('${message.messageID}:$emoji');
  }
}
```

- [ ] **Step 4: Run the controller test to verify it passes**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart`
Expected: PASS with favorite deduplication, restored favorite knowledge, and failure rollback all green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_message_favorite_registry.dart lib/modules/chat/chat_message_action_controller.dart lib/modules/chat/chat_scene_providers.dart test/modules/chat/chat_message_action_controller_test.dart
git commit -m "feat: add chat favorite consistency registry"
```

### Task 2: Bridge ReactionManager Into Message-Scoped Bubble Rendering

**Files:**
- Create: `lib/modules/chat/chat_message_reaction_mapping.dart`
- Create: `lib/modules/chat/widgets/chat_message_engagement_bubble.dart`
- Create: `test/modules/chat/chat_message_engagement_bubble_test.dart`
- Modify: `lib/modules/chat/chat_scene_gateway.dart`

- [ ] **Step 1: Write the failing engagement-bubble tests**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_engagement_bubble.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('engagement bubble renders prepared reactions and forwards chip taps', (tester) async {
    final message = WKMsg()
      ..messageID = 'mid-engagement'
      ..channelID = 'u_engagement'
      ..channelType = WKChannelType.personal
      ..fromUID = 'u_other'
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('hello');
    final gateway = _FakeReactionGateway(
      preparedReactions: <String, List<MessageReaction>>{
        'mid-engagement': const <MessageReaction>[
          MessageReaction(
            type: 0,
            emoji: '\u{1F44D}',
            count: 2,
            isMe: true,
            userIds: <String>['u_self', 'u_other'],
            usernames: <String>['Self', 'Other'],
          ),
        ],
      },
    );
    final model = ChatMessageMapper().map(message, currentUid: 'u_self');
    String? tappedEmoji;
    var addTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageEngagementBubble(
            model: model,
            participant: null,
            statusInfo: null,
            gateway: gateway,
            onLongPress: () {},
            onAddReaction: () => addTapped = true,
            onReactionTap: (emoji) => tappedEmoji = emoji,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F44D}')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F44D}')));
    await tester.pump();
    expect(tappedEmoji, '\u{1F44D}');

    await tester.tap(find.byKey(const ValueKey<String>('message-reaction-add')));
    await tester.pump();
    expect(addTapped, isTrue);
  });

  testWidgets('engagement bubble applies only matching reaction stream updates', (tester) async {
    final message = WKMsg()
      ..messageID = 'mid-stream'
      ..channelID = 'u_stream'
      ..channelType = WKChannelType.personal
      ..fromUID = 'u_other'
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('stream me');
    final gateway = _FakeReactionGateway();
    final model = ChatMessageMapper().map(message, currentUid: 'u_self');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageEngagementBubble(
            model: model,
            participant: null,
            statusInfo: null,
            gateway: gateway,
            onLongPress: () {},
            onAddReaction: () {},
            onReactionTap: (_) {},
          ),
        ),
      ),
    );

    gateway.emit(
      const ReactionUpdate(
        messageId: 'mid-other',
        reactions: <MessageReaction>[
          MessageReaction(
            type: 0,
            emoji: '\u{1F389}',
            count: 1,
            isMe: false,
            userIds: <String>['u_other'],
            usernames: <String>['Other'],
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')), findsNothing);

    gateway.emit(
      const ReactionUpdate(
        messageId: 'mid-stream',
        reactions: <MessageReaction>[
          MessageReaction(
            type: 0,
            emoji: '\u{1F389}',
            count: 1,
            isMe: true,
            userIds: <String>['u_self'],
            usernames: <String>['Self'],
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')), findsOneWidget);
  });
}

class _FakeReactionGateway implements ChatSceneGateway {
  _FakeReactionGateway({
    Map<String, List<MessageReaction>> preparedReactions = const <String, List<MessageReaction>>{},
  }) : _preparedReactions = Map<String, List<MessageReaction>>.from(preparedReactions);

  final Map<String, List<MessageReaction>> _preparedReactions;
  final StreamController<ReactionUpdate> _controller =
      StreamController<ReactionUpdate>.broadcast();

  void emit(ReactionUpdate update) => _controller.add(update);

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return List<MessageReaction>.from(
      _preparedReactions[message.messageID] ?? const <MessageReaction>[],
      growable: false,
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() => _controller.stream;

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}
}
```

- [ ] **Step 2: Run the engagement-bubble test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_engagement_bubble_test.dart`
Expected: FAIL with missing `prepareReactions`, missing `watchReactionUpdates`, or missing `ChatMessageEngagementBubble`

- [ ] **Step 3: Implement the reaction bridge, mapper, and message-scoped wrapper**

```dart
// lib/modules/chat/chat_message_reaction_mapping.dart
import '../../wukong_base/msg/reaction_manager.dart';
import '../../wukong_base/msg/widget/wk_message_reaction.dart';

List<WKMessageReaction> mapReactionWidgets(
  Iterable<MessageReaction> reactions,
) {
  return reactions
      .map(
        (reaction) => WKMessageReaction(
          emoji: reaction.emoji,
          count: reaction.count,
          isMe: reaction.isMe,
          usernames: List<String>.from(reaction.usernames, growable: false),
        ),
      )
      .toList(growable: false);
}

String? selectedReactionEmojiOf(Iterable<MessageReaction> reactions) {
  for (final reaction in reactions) {
    if (reaction.isMe) {
      return reaction.emoji;
    }
  }
  return null;
}
```

```dart
// lib/modules/chat/chat_scene_gateway.dart
abstract class ChatSceneGateway {
  Future<void> addFavorite(WKMsg message);
  Future<void> recallMessage(WKMsg message);
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  });
  Future<void> toggleReaction(WKMsg message, String emoji);
  List<MessageReaction> prepareReactions(WKMsg message);
  Stream<ReactionUpdate> watchReactionUpdates();
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
  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return _reactionManager.prepareReactions(message);
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return _reactionManager.reactionUpdates;
  }
}
```

```dart
// lib/modules/chat/widgets/chat_message_engagement_bubble.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/chat/chat_message_reaction_mapping.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class ChatMessageEngagementBubble extends StatefulWidget {
  const ChatMessageEngagementBubble({
    super.key,
    required this.model,
    required this.participant,
    required this.statusInfo,
    required this.gateway,
    this.onLongPress,
    this.onTap,
    this.onSecondaryTapDown,
    this.onAddReaction,
    this.onReactionTap,
  });

  final ChatMessageViewModel model;
  final MessageParticipantInfo? participant;
  final MessageStatusInfo? statusInfo;
  final ChatSceneGateway gateway;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final VoidCallback? onAddReaction;
  final void Function(String emoji)? onReactionTap;

  @override
  State<ChatMessageEngagementBubble> createState() =>
      _ChatMessageEngagementBubbleState();
}

class _ChatMessageEngagementBubbleState
    extends State<ChatMessageEngagementBubble> {
  late List<WKMessageReaction> _reactions;
  StreamSubscription<ReactionUpdate>? _subscription;

  WKMsg get _message => widget.model.message;

  @override
  void initState() {
    super.initState();
    _syncFromMessage();
    _subscribe();
  }

  @override
  void didUpdateWidget(ChatMessageEngagementBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway != widget.gateway ||
        oldWidget.model.revision != widget.model.revision) {
      _subscription?.cancel();
      _syncFromMessage();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _syncFromMessage() {
    _reactions = mapReactionWidgets(widget.gateway.prepareReactions(_message));
  }

  void _subscribe() {
    _subscription = widget.gateway.watchReactionUpdates().listen((update) {
      final messageId = _message.messageID.trim();
      if (messageId.isEmpty || update.messageId != messageId || !mounted) {
        return;
      }
      setState(() {
        _reactions = mapReactionWidgets(update.reactions);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MessageBubble(
      model: widget.model,
      participant: widget.participant,
      statusInfo: widget.statusInfo,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      reactions: _reactions,
      onAddReaction: widget.onAddReaction,
      onReactionTap: widget.onReactionTap,
    );
  }
}
```

- [ ] **Step 4: Run the engagement-bubble test to verify it passes**

Run: `flutter test test/modules/chat/chat_message_engagement_bubble_test.dart`
Expected: PASS with prepared reactions, stream updates, and message isolation green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_message_reaction_mapping.dart lib/modules/chat/chat_scene_gateway.dart lib/modules/chat/widgets/chat_message_engagement_bubble.dart test/modules/chat/chat_message_engagement_bubble_test.dart
git commit -m "feat: bridge reaction manager into chat bubbles"
```

### Task 3: Add The Expanded Reaction Picker And Wire Both Entry Paths

**Files:**
- Create: `lib/modules/chat/widgets/chat_reaction_picker_popup.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/wukong_base/msg/widget/wk_message_reaction.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/modules/chat/message_bubble_experience_test.dart`

- [ ] **Step 1: Write the failing reaction-flow and picker tests**

```dart
// test/modules/chat/chat_page_scene_flow_test.dart
testWidgets('long press reaction entry opens picker, applies chip, and chip retap cancels', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:reaction'
    ..clientMsgNO = 'client:reaction'
    ..channelID = 'u_scene'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('react to me');
  final gateway = _FakeChatSceneGateway();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_scene' ? <WKMsg>[message] : const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: WKChannelType.personal,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u8868\u60c5\u56de\u5e94'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('message-reaction-chip-\u{1F389}')), findsNothing);
  expect(gateway.reactionCalls, <String>[
    'mid:reaction:\u{1F389}',
    'mid:reaction:\u{1F389}',
  ]);
});

testWidgets('bubble add button opens the same expanded reaction picker', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:add'
    ..clientMsgNO = 'client:add'
    ..channelID = 'u_scene'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('open picker');
  final gateway = _FakeChatSceneGateway();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_scene' ? <WKMsg>[message] : const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: WKChannelType.personal,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('message-reaction-add')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')), findsOneWidget);
});
```

```dart
// test/modules/chat/message_bubble_experience_test.dart
testWidgets('reaction picker highlights the selected emoji', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: WKReactionPicker(
          selectedEmoji: '\u{1F44D}',
          onEmojiSelected: _noopSelect,
        ),
      ),
    ),
  );

  final selected = tester.widget<Container>(
    find.descendant(
      of: find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')),
      matching: find.byType(Container),
    ).first,
  );

  final decoration = selected.decoration as BoxDecoration;
  expect(decoration.border, isNotNull);
});

void _noopSelect(String _) {}
```

- [ ] **Step 2: Run the reaction-focused tests to verify they fail**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "reaction"`
Expected: FAIL because `ChatSceneAction.react` still applies a fixed default emoji and the bubble does not open an expanded picker

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`
Expected: FAIL because `WKReactionPicker` does not yet support `selectedEmoji` or stable picker keys

- [ ] **Step 3: Implement the picker popup, selected state, and shell wiring**

```dart
// lib/wukong_base/msg/widget/wk_message_reaction.dart
class WKMessageReactions extends StatelessWidget {
  Widget _buildReactionChip(WKMessageReaction reaction) {
    return GestureDetector(
      key: ValueKey<String>('message-reaction-chip-${reaction.emoji}'),
      onTap: () => onReactionTap?.call(reaction.emoji),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: reaction.isMe ? Colors.blue.withAlpha(26) : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: reaction.isMe ? Border.all(color: Colors.blue, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reaction.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('${reaction.count}'),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      key: const ValueKey<String>('message-reaction-add'),
      onTap: onAddReaction,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.add, size: 18, color: Colors.grey[600]),
      ),
    );
  }
}

class WKReactionPicker extends StatelessWidget {
  static const List<String> commonEmojis = [
    '\u{1F44D}',
    '\u2764\uFE0F',
    '\u{1F600}',
    '\u{1F389}',
    '\u{1F44F}',
    '\u{1F525}',
    '\u{1F60F}',
    '\u{1F637}',
    '\u{1F629}',
    '\u{1F616}',
    '\u{1F4AA}',
    '\u{1F44C}',
  ];

  const WKReactionPicker({
    super.key,
    required this.onEmojiSelected,
    this.selectedEmoji,
    this.emojis = commonEmojis,
  });

  final void Function(String emoji) onEmojiSelected;
  final String? selectedEmoji;
  final List<String> emojis;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: emojis.map((emoji) {
          final selected = emoji == selectedEmoji;
          return InkWell(
            key: ValueKey<String>('reaction-picker-$emoji'),
            onTap: () => onEmojiSelected(emoji),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.blue.withAlpha(26) : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: selected ? Border.all(color: Colors.blue) : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
```

```dart
// lib/modules/chat/widgets/chat_reaction_picker_popup.dart
import 'package:flutter/material.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';

Future<String?> showChatReactionPicker({
  required BuildContext context,
  required bool isSelf,
  String? selectedEmoji,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black12,
    builder: (dialogContext) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Align(
              alignment: isSelf
                  ? const Alignment(0.75, 0.30)
                  : const Alignment(-0.75, 0.30),
              child: GestureDetector(
                onTap: () {},
                child: WKReactionPicker(
                  selectedEmoji: selectedEmoji,
                  onEmojiSelected: (emoji) {
                    Navigator.of(dialogContext).pop(emoji);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
```

```dart
// lib/modules/chat/chat_page_shell.dart
import 'chat_message_reaction_mapping.dart';
import 'widgets/chat_message_engagement_bubble.dart';
import 'widgets/chat_reaction_picker_popup.dart';

@override
Widget build(BuildContext context) {
  final viewport = ref.watch(chatViewportProvider(widget.session));
  final readController = ref.watch(chatReadControllerProvider(widget.session));
  final gateway = ref.watch(chatSceneGatewayProvider(widget.session));

  return ChatMessageViewport(
    onBuild: widget.onBuild,
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels ==
                notification.metrics.minScrollExtent) {
          ref.read(messageListProvider(widget.session).notifier).loadMore();
        }
        return false;
      },
      child: viewport.items.isEmpty
          ? const Center(child: Text(_emptyMessageText))
          : ListView.builder(
              controller: _scrollController,
              reverse: true,
              cacheExtent: 640,
              itemCount: viewport.items.length,
              findChildIndexCallback: (key) {
                if (key is ValueKey<String>) {
                  return viewport.identityToIndex[key.value];
                }
                return null;
              },
              itemBuilder: (context, index) {
                final item = viewport.items[index];
                return ChatMessageListItem(
                  itemKey: ValueKey<String>(item.identity),
                  child: ChatMessageEngagementBubble(
                    model: item,
                    participant: resolveMessageParticipantInfo(item.message),
                    statusInfo: resolveMessageStatusInfo(
                      item.message,
                      isSelf: item.isSelf,
                    ),
                    gateway: gateway,
                    onLongPress: () => _showMessageActionSheet(item),
                    onAddReaction: () => _openReactionPicker(item),
                    onReactionTap: (emoji) => _toggleReaction(item, emoji),
                  ),
                );
              },
            ),
    ),
  );
}

Future<void> _openReactionPicker(ChatMessageViewModel model) async {
  final gateway = ref.read(chatSceneGatewayProvider(widget.session));
  final selectedEmoji =
      selectedReactionEmojiOf(gateway.prepareReactions(model.message));
  final pickedEmoji = await showChatReactionPicker(
    context: context,
    isSelf: model.isSelf,
    selectedEmoji: selectedEmoji,
  );
  if (!mounted || pickedEmoji == null) {
    return;
  }
  await _toggleReaction(model, pickedEmoji);
}

Future<void> _toggleReaction(
  ChatMessageViewModel model,
  String emoji,
) async {
  await ref
      .read(chatMessageActionControllerProvider(widget.session).notifier)
      .toggleReaction(model.message, emoji);
}

Future<void> _handleSceneAction(
  ChatSceneAction action,
  ChatMessageViewModel model,
) async {
  switch (action) {
    // existing cases stay the same
    case ChatSceneAction.react:
      await _openReactionPicker(model);
      return;
  }
}
```

```dart
// test/modules/chat/chat_page_scene_flow_test.dart
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';

class _FakeChatSceneGateway implements ChatSceneGateway {
  _FakeChatSceneGateway({this.targets = const <ForwardTarget>[]});

  final List<ForwardTarget> targets;
  final List<String> reactionCalls = <String>[];
  final Map<String, List<MessageReaction>> _reactionCache =
      <String, List<MessageReaction>>{};
  final StreamController<ReactionUpdate> _reactionController =
      StreamController<ReactionUpdate>.broadcast();

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return targets;
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
      growable: false,
    );
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    reactionCalls.add('${message.messageID}:$emoji');
    final current = List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
    );
    final existingIndex = current.indexWhere((reaction) => reaction.isMe);
    if (existingIndex != -1 && current[existingIndex].emoji == emoji) {
      current.removeAt(existingIndex);
    } else {
      if (existingIndex != -1) {
        current.removeAt(existingIndex);
      }
      current.add(
        MessageReaction(
          type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
          emoji: emoji,
          count: 1,
          isMe: true,
          userIds: const <String>['u_self'],
          usernames: const <String>['Self'],
        ),
      );
    }
    _reactionCache[message.messageID] = current;
    _reactionController.add(
      ReactionUpdate(
        messageId: message.messageID,
        reactions: List<MessageReaction>.unmodifiable(current),
      ),
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() => _reactionController.stream;
}
```

- [ ] **Step 4: Run the reaction-focused tests to verify they pass**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "reaction"`
Expected: PASS with long-press reaction entry, picker selection, and same-chip cancel behavior green

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`
Expected: PASS with real emoji coverage plus selected picker highlighting green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_reaction_picker_popup.dart lib/wukong_base/msg/widget/wk_message_reaction.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: add expanded chat reaction picker flow"
```

### Task 4: Surface Favorite Feedback And Lock Android Parity For Favorite/Reaction

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Write the failing favorite-feedback and parity tests**

```dart
// test/modules/chat/chat_page_scene_flow_test.dart
testWidgets('favorite success shows snackbar and second tap stays deduplicated', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:favorite'
    ..clientMsgNO = 'client:favorite'
    ..channelID = 'u_scene'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('favorite me');
  final gateway = _FakeChatSceneGateway();
  final registry = _FakeFavoriteRegistry();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_scene' ? <WKMsg>[message] : const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatMessageFavoriteRegistryProvider.overrideWithValue(registry),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: WKChannelType.personal,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u6536\u85cf'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expect(find.text('\u5df2\u6536\u85cf'), findsOneWidget);
  expect(gateway.favoriteCalls, <String>['client:favorite']);

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u6536\u85cf'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expect(gateway.favoriteCalls, <String>['client:favorite']);
});

testWidgets('favorite failure shows snackbar and keeps registry empty', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:favorite-failed'
    ..clientMsgNO = 'client:favorite-failed'
    ..channelID = 'u_scene'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('favorite failure');
  final gateway = _FakeChatSceneGateway(
    onFavorite: (message) async => throw Exception('favorite failed'),
  );
  final registry = _FakeFavoriteRegistry();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_scene' ? <WKMsg>[message] : const <WKMsg>[],
          ),
        ),
        chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
        chatMessageFavoriteRegistryProvider.overrideWithValue(registry),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: WKChannelType.personal,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u6536\u85cf'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expect(find.text('\u6536\u85cf\u5931\u8d25'), findsOneWidget);
  expect(registry.savedKeys, isEmpty);
});
```

```dart
// test/modules/chat/chat_page_android_parity_test.dart
testWidgets('reaction action and bubble add button both reach the Android reaction picker', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:parity-reaction'
    ..clientMsgNO = 'client:parity-reaction'
    ..channelID = 'u_android'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u_self'
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('reaction parity');
  final gateway = _ParityReactionGateway();

  await pumpChatPage(
    tester,
    channelId: 'u_android',
    channelType: WKChannelType.personal,
    channelName: 'Android Parity',
    overrides: <Override>[
      messageListProvider.overrideWith(
        (ref, session) => _StaticMessageListNotifier(
          session.channelId,
          session.channelType,
          session.channelId == 'u_android' ? <WKMsg>[message] : const <WKMsg>[],
        ),
      ),
      chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
      chatMarkConversationReadProvider.overrideWithValue(
        (session, messageIds) async {},
      ),
    ],
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u8868\u60c5\u56de\u5e94'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')), findsOneWidget);

  await tester.pageBack();
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('message-reaction-add')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F44D}')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('reaction-picker-\u{1F389}')), findsOneWidget);
});
```

- [ ] **Step 2: Run the favorite/parity tests to verify they fail**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "favorite"`
Expected: FAIL because the shell does not yet surface controller feedback as snackbars and the favorite registry is not injected into page-level tests

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`
Expected: FAIL because parity tests cannot yet reach the same picker from both Android-facing reaction entries

- [ ] **Step 3: Wire shell feedback, update test fakes, and lock parity**

```dart
// lib/modules/chat/chat_page_shell.dart
ref.listen<ChatMessageActionState>(
  chatMessageActionControllerProvider(_chatSession),
  (previous, next) {
    final feedback = next.feedbackMessage;
    if (feedback == null || feedback.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
    ref
        .read(chatMessageActionControllerProvider(_chatSession).notifier)
        .clearFeedback();
  },
);
```

```dart
// test/modules/chat/chat_page_scene_flow_test.dart
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';

class _FakeFavoriteRegistry implements ChatMessageFavoriteRegistry {
  _FakeFavoriteRegistry({Set<String> seedKeys = const <String>{}})
      : _keys = {...seedKeys};

  final Set<String> _keys;

  Set<String> get savedKeys => Set<String>.unmodifiable(_keys);

  @override
  bool contains(String key) => _keys.contains(key);

  @override
  Future<void> markFavorited(String key) async {
    _keys.add(key);
  }

  @override
  Set<String> snapshot() => Set<String>.unmodifiable(_keys);
}

class _FakeChatSceneGateway implements ChatSceneGateway {
  _FakeChatSceneGateway({
    this.targets = const <ForwardTarget>[],
    this.onFavorite,
  });

  final List<ForwardTarget> targets;
  final Future<void> Function(WKMsg message)? onFavorite;
  final List<String> favoriteCalls = <String>[];
  final List<String> reactionCalls = <String>[];
  final List<Object> sentContents = <Object>[];
  final List<String> sentChannels = <String>[];
  final List<List<ForwardTarget>> forwardedTargets = <List<ForwardTarget>>[];
  final Map<String, List<MessageReaction>> _reactionCache =
      <String, List<MessageReaction>>{};
  final StreamController<ReactionUpdate> _reactionController =
      StreamController<ReactionUpdate>.broadcast();

  @override
  Future<void> addFavorite(WKMsg message) async {
    favoriteCalls.add(message.clientMsgNO);
    await onFavorite?.call(message);
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
      growable: false,
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() => _reactionController.stream;

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    reactionCalls.add('${message.messageID}:$emoji');
    final current = List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
    );
    final existingIndex = current.indexWhere((reaction) => reaction.isMe);
    final targetIndex = current.indexWhere((reaction) => reaction.emoji == emoji);
    if (existingIndex != -1 && current[existingIndex].emoji == emoji) {
      current.removeAt(existingIndex);
    } else {
      if (existingIndex != -1) {
        current.removeAt(existingIndex);
      }
      if (targetIndex != -1) {
        final target = current[targetIndex];
        current[targetIndex] = target.copyWith(
          count: target.count + 1,
          isMe: true,
          userIds: <String>[...target.userIds, 'u_self'],
          usernames: <String>[...target.usernames, 'Self'],
        );
      } else {
        current.add(
          MessageReaction(
            type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
            emoji: emoji,
            count: 1,
            isMe: true,
            userIds: const <String>['u_self'],
            usernames: const <String>['Self'],
          ),
        );
      }
    }
    current.sort((left, right) => right.count.compareTo(left.count));
    _reactionCache[message.messageID] = current;
    _reactionController.add(
      ReactionUpdate(
        messageId: message.messageID,
        reactions: List<MessageReaction>.unmodifiable(current),
      ),
    );
  }
  
  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return targets;
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {
    forwardedTargets.add(List<ForwardTarget>.from(targets, growable: false));
  }

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {
    sentContents.add(content);
    sentChannels.add('$channelType:$channelId');
  }
}
```

```dart
// test/modules/chat/chat_page_android_parity_test.dart
import 'dart:async';

import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

class _ParityReactionGateway implements ChatSceneGateway {
  final Map<String, List<MessageReaction>> _reactionCache =
      <String, List<MessageReaction>>{};
  final StreamController<ReactionUpdate> _controller =
      StreamController<ReactionUpdate>.broadcast();

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
      growable: false,
    );
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    final current = List<MessageReaction>.from(
      _reactionCache[message.messageID] ?? const <MessageReaction>[],
    );
    final existingIndex = current.indexWhere((reaction) => reaction.isMe);
    if (existingIndex != -1 && current[existingIndex].emoji == emoji) {
      current.removeAt(existingIndex);
    } else {
      if (existingIndex != -1) {
        current.removeAt(existingIndex);
      }
      current.add(
        MessageReaction(
          type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
          emoji: emoji,
          count: 1,
          isMe: true,
          userIds: const <String>['u_self'],
          usernames: const <String>['Self'],
        ),
      );
    }
    _reactionCache[message.messageID] = current;
    _controller.add(
      ReactionUpdate(
        messageId: message.messageID,
        reactions: List<MessageReaction>.unmodifiable(current),
      ),
    );
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() => _controller.stream;
}
```

- [ ] **Step 4: Run the favorite/parity tests to verify they pass**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "favorite"`
Expected: PASS with success/failure snackbar coverage and favorite deduplication green

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart`
Expected: PASS with Android reaction entry reachability and existing Phase 5A parity assertions still green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "test: lock chat engagement parity to android behavior"
```

### Task 5: Run Full Phase 5B Verification And Optional Remote Validation

**Files:**
- No new files in this task

- [ ] **Step 1: Run focused analyzer verification**

Run: `flutter analyze lib/modules/chat lib/widgets/message_bubble.dart lib/wukong_base/msg/widget/wk_message_reaction.dart`
Expected: PASS with no new analyze errors in the chat engagement path

- [ ] **Step 2: Run focused Phase 5B tests**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart test/modules/chat/chat_message_engagement_bubble_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart`
Expected: PASS with all favorite/reaction coverage green

- [ ] **Step 3: Run combined chat-mainline regression coverage including Phase 5A**

Run: `flutter test test/modules/chat/chat_message_action_controller_test.dart test/modules/chat/chat_message_engagement_bubble_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/chat_message_action_sheet_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_pages_compile_test.dart`
Expected: PASS with no regressions in action sheet, forward flow, compile coverage, or Android parity

- [ ] **Step 4: If deployed behavior diverges, inspect the server logs**

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'reaction|favorite'"`
Expected: no new backend errors introduced by favorite or reaction requests; empty output is acceptable

- [ ] **Step 5: Record the completion checkpoint**

```bash
git add lib/modules/chat/chat_message_favorite_registry.dart lib/modules/chat/chat_message_reaction_mapping.dart lib/modules/chat/chat_scene_gateway.dart lib/modules/chat/chat_scene_providers.dart lib/modules/chat/chat_message_action_controller.dart lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_message_engagement_bubble.dart lib/modules/chat/widgets/chat_reaction_picker_popup.dart lib/wukong_base/msg/widget/wk_message_reaction.dart test/modules/chat/chat_message_action_controller_test.dart test/modules/chat/chat_message_engagement_bubble_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: complete chat engagement parity"
```
