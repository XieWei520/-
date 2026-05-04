# Phase 5A Chat Action Surface Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compress the Flutter chat action surface so long-press actions, multi-select batch mode, and forward target selection behave like the TangSengDaoDao Android original on Android while preserving the Phase 4 scene kernel.

**Architecture:** This plan does not add a second chat state machine. It introduces one small action-policy layer, then reuses the existing `ChatSceneAction`, `ChatSelectionController`, `ChatMessageActionController`, and `ForwardMessagePage` route to push labels, ordering, visibility, and exit behavior toward Android parity. Batch forward cleanup remains owned by `ChatPageShell`, while the forward chooser keeps its own local page state.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, wukongimfluttersdk, existing scene providers, PowerShell, optional SSH validation

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only the approved design in [2026-04-04-phase-5a-chat-action-surface-parity-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-04-phase-5a-chat-action-surface-parity-design.md).

In scope:

- policy-driven long-press action ordering and labels
- Android-style multi-select toolbar wording and mode cleanup
- Android-style forward chooser title, search, selection, and submit states
- compatibility-wrapper alignment with the same scene action policy
- widget and flow regression coverage for the action surface

Out of scope for this plan:

- in-chat search parity
- keyboard and panel choreography parity
- reply-rendering polish outside action entry/exit semantics
- new Flutter-only action types or chat surface redesign

## Android Reference Anchors

The implementation in this plan is pinned to the following Android surfaces:

- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java`
  - multi-select entry and count updates around lines `1920-1933`
  - multi-select cancel cleanup around lines `1730-1745`
  - reply/showReply and action continuity around lines `1938-1965`
- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/contacts/ChooseContactsActivity.java`
  - chooser title/search/confirm flow around lines `59-75`, `139-144`, `277-311`, and `462-471`
- `TangSengDaoDaoAndroid-master/wkuikit/src/main/res/values/strings.xml`
  - `choose_chat`, `hint_search`, `forward`, `wk_kit_collect`, `max_select_count_chat`, and related chooser labels

## File Structure

### New Files

- `lib/modules/chat/chat_message_action_policy.dart`
  - One authoritative action descriptor model plus Android-ordered visibility helpers for scene and compatibility callers.
- `test/modules/chat/chat_message_action_policy_test.dart`
  - Verifies action ordering, labels, and recall visibility.
- `test/modules/chat/chat_message_action_sheet_test.dart`
  - Verifies the rendered action sheet uses the supplied descriptors in Android order.

### Existing Files To Modify

- `lib/modules/chat/widgets/chat_message_action_sheet.dart`
  - Render a supplied descriptor list instead of hardcoding a fixed action set.
- `lib/modules/chat/chat_page_shell.dart`
  - Build policy-driven actions for long-press, preserve selection on forward cancel, and clear selection on forward success.
- `lib/modules/chat/widgets/chat_selection_toolbar.dart`
  - Render Android-aligned batch wording and stable keys for tests.
- `lib/modules/chat/forward_message_page.dart`
  - Render chooser-style copy, search hint, explicit loading/empty/failure/submitting states, and selection-aware confirm text.
- `lib/modules/chat/message_forwarding.dart`
  - Keep forward target filtering stable and expose any tiny helpers needed by the chooser surface.
- `lib/wukong_uikit/chat/message_long_press_menu.dart`
  - Keep the compatibility wrapper thin while routing through the new policy.
- `test/modules/chat/forward_message_page_test.dart`
  - Expand chooser tests to cover title, disabled submit, selection-aware submit, and empty states.
- `test/modules/chat/chat_page_scene_flow_test.dart`
  - Expand flow tests to cover localized action sheet copy, batch forward success cleanup, and cancel-preserve behavior.
- `test/modules/chat/chat_page_android_parity_test.dart`
  - Add Android parity assertions for action labels/order and batch toolbar copy.
- `test/modules/chat/chat_pages_compile_test.dart`
  - Keep compile coverage for the compatibility wrapper after the action policy is introduced.

## Verification Commands Used Throughout

- `flutter analyze lib/modules/chat lib/wukong_uikit/chat/message_long_press_menu.dart`
- `flutter test test/modules/chat/chat_message_action_policy_test.dart`
- `flutter test test/modules/chat/chat_message_action_sheet_test.dart`
- `flutter test test/modules/chat/forward_message_page_test.dart`
- `flutter test test/modules/chat/chat_page_scene_flow_test.dart`
- `flutter test test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
- `flutter test test/modules/chat/chat_message_action_policy_test.dart test/modules/chat/chat_message_action_sheet_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`

If local forward verification shows payload-delivery drift, run:

- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'favorite|revoke|forward'"`

### Task 1: Add The Android Action Policy Layer

**Files:**
- Create: `lib/modules/chat/chat_message_action_policy.dart`
- Test: `test/modules/chat/chat_message_action_policy_test.dart`

- [ ] **Step 1: Write the failing action-policy tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('self text message keeps Android action order with recall', () {
    final message = WKMsg()
      ..messageID = 'mid:self'
      ..fromUID = 'u_self'
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('hello');

    final descriptors = buildChatMessageActionDescriptors(
      message: message,
      isSelf: true,
      canRecall: true,
    );

    expect(
      descriptors.map((item) => item.action).toList(),
      <ChatSceneAction>[
        ChatSceneAction.reply,
        ChatSceneAction.forward,
        ChatSceneAction.favorite,
        ChatSceneAction.select,
        ChatSceneAction.recall,
        ChatSceneAction.react,
      ],
    );
    expect(
      descriptors.map((item) => item.label).toList(),
      <String>[
        '\u56de\u590d',
        '\u8f6c\u53d1',
        '\u6536\u85cf',
        '\u591a\u9009',
        '\u64a4\u56de',
        '\u8868\u60c5\u56de\u5e94',
      ],
    );
  });

  test('foreign text message omits recall but keeps Android order', () {
    final message = WKMsg()
      ..messageID = 'mid:foreign'
      ..fromUID = 'u_other'
      ..contentType = WkMessageContentType.text
      ..messageContent = WKTextContent('hello');

    final descriptors = buildChatMessageActionDescriptors(
      message: message,
      isSelf: false,
      canRecall: false,
    );

    expect(
      descriptors.map((item) => item.action).toList(),
      <ChatSceneAction>[
        ChatSceneAction.reply,
        ChatSceneAction.forward,
        ChatSceneAction.favorite,
        ChatSceneAction.select,
        ChatSceneAction.react,
      ],
    );
  });

  test('legacy wrapper builder uses the same ordered action set', () {
    final descriptors = buildLegacyLongPressActionDescriptors(
      messageType: 'text',
      isFromMe: true,
      canRecall: true,
    );

    expect(descriptors.first.action, ChatSceneAction.reply);
    expect(descriptors.last.action, ChatSceneAction.react);
    expect(
      descriptors.map((item) => item.label).contains('\u8f6c\u53d1'),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Run the action-policy test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_action_policy_test.dart`
Expected: FAIL with missing `buildChatMessageActionDescriptors`, `buildLegacyLongPressActionDescriptors`, or `ChatMessageActionDescriptor`

- [ ] **Step 3: Implement the descriptor model and Android ordering policy**

```dart
// lib/modules/chat/chat_message_action_policy.dart
import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import 'widgets/chat_message_action_sheet.dart';

const String _replyLabel = '\u56de\u590d';
const String _forwardLabel = '\u8f6c\u53d1';
const String _favoriteLabel = '\u6536\u85cf';
const String _selectLabel = '\u591a\u9009';
const String _recallLabel = '\u64a4\u56de';
const String _reactionLabel = '\u8868\u60c5\u56de\u5e94';

@immutable
class ChatMessageActionDescriptor {
  const ChatMessageActionDescriptor({
    required this.action,
    required this.label,
    required this.order,
  });

  final ChatSceneAction action;
  final String label;
  final int order;
}

List<ChatMessageActionDescriptor> buildChatMessageActionDescriptors({
  required WKMsg message,
  required bool isSelf,
  required bool canRecall,
}) {
  final isInteractive = message.isDeleted == 0 && message.remoteExtra.revoke != 1;
  if (!isInteractive) {
    return const <ChatMessageActionDescriptor>[];
  }

  final descriptors = <ChatMessageActionDescriptor>[
    const ChatMessageActionDescriptor(
      action: ChatSceneAction.reply,
      label: _replyLabel,
      order: 10,
    ),
    const ChatMessageActionDescriptor(
      action: ChatSceneAction.forward,
      label: _forwardLabel,
      order: 20,
    ),
    const ChatMessageActionDescriptor(
      action: ChatSceneAction.favorite,
      label: _favoriteLabel,
      order: 30,
    ),
    const ChatMessageActionDescriptor(
      action: ChatSceneAction.select,
      label: _selectLabel,
      order: 40,
    ),
    if (isSelf && canRecall)
      const ChatMessageActionDescriptor(
        action: ChatSceneAction.recall,
        label: _recallLabel,
        order: 50,
      ),
    const ChatMessageActionDescriptor(
      action: ChatSceneAction.react,
      label: _reactionLabel,
      order: 60,
    ),
  ];

  return List<ChatMessageActionDescriptor>.unmodifiable(
    [...descriptors]..sort((left, right) => left.order.compareTo(right.order)),
  );
}

List<ChatMessageActionDescriptor> buildLegacyLongPressActionDescriptors({
  required String messageType,
  required bool isFromMe,
  required bool canRecall,
}) {
  final message = WKMsg()..isDeleted = messageType == 'system' ? 1 : 0;
  return buildChatMessageActionDescriptors(
    message: message,
    isSelf: isFromMe,
    canRecall: canRecall,
  );
}
```

- [ ] **Step 4: Run the action-policy test to verify it passes**

Run: `flutter test test/modules/chat/chat_message_action_policy_test.dart`
Expected: PASS with all three action-order assertions green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/chat/chat_message_action_policy.dart test/modules/chat/chat_message_action_policy_test.dart
git commit -m "feat: add chat action ordering policy"
```

### Task 2: Rebuild The Action Sheet And Compatibility Wrapper Around The Policy

**Files:**
- Create: `test/modules/chat/chat_message_action_sheet_test.dart`
- Modify: `lib/modules/chat/widgets/chat_message_action_sheet.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/wukong_uikit/chat/message_long_press_menu.dart`

- [ ] **Step 1: Write the failing action-sheet widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';

void main() {
  testWidgets('action sheet renders descriptors in Android order', (
    tester,
  ) async {
    final actions = <ChatMessageActionDescriptor>[
      const ChatMessageActionDescriptor(
        action: ChatSceneAction.reply,
        label: '\u56de\u590d',
        order: 10,
      ),
      const ChatMessageActionDescriptor(
        action: ChatSceneAction.forward,
        label: '\u8f6c\u53d1',
        order: 20,
      ),
      const ChatMessageActionDescriptor(
        action: ChatSceneAction.recall,
        label: '\u64a4\u56de',
        order: 50,
      ),
    ];

    ChatSceneAction? selectedAction;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => ChatMessageActionSheet(
                      actions: actions,
                      onSelected: (action) {
                        selectedAction = action;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles[0].title as Text).data, '\u56de\u590d');
    expect((tiles[1].title as Text).data, '\u8f6c\u53d1');
    expect((tiles[2].title as Text).data, '\u64a4\u56de');

    await tester.tap(find.text('\u64a4\u56de'));
    await tester.pumpAndSettle();

    expect(selectedAction, ChatSceneAction.recall);
  });
}
```

- [ ] **Step 2: Run the action-sheet widget test to verify it fails**

Run: `flutter test test/modules/chat/chat_message_action_sheet_test.dart`
Expected: FAIL because `ChatMessageActionSheet` still expects `canRecall` instead of an explicit descriptor list

- [ ] **Step 3: Update the action sheet to render supplied descriptors**

```dart
// lib/modules/chat/widgets/chat_message_action_sheet.dart
import 'package:flutter/material.dart';

import '../chat_message_action_policy.dart';

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
    required this.actions,
    required this.onSelected,
  });

  final List<ChatMessageActionDescriptor> actions;
  final ValueChanged<ChatSceneAction> onSelected;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final descriptor in actions)
            ListTile(
              key: ValueKey<String>('chat-action-${descriptor.action.name}'),
              title: Text(descriptor.label),
              onTap: () {
                Navigator.of(context).pop();
                onSelected(descriptor.action);
              },
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Route both the scene shell and the compatibility wrapper through the same policy**

```dart
// lib/modules/chat/chat_page_shell.dart
import 'chat_message_action_policy.dart';

Future<void> _showMessageActionSheet(ChatMessageViewModel model) {
  final actions = buildChatMessageActionDescriptors(
    message: model.message,
    isSelf: model.isSelf,
    canRecall: model.isSelf,
  );
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => ChatMessageActionSheet(
      actions: actions,
      onSelected: (action) {
        unawaited(_handleSceneAction(action, model));
      },
    ),
  );
}
```

```dart
// lib/wukong_uikit/chat/message_long_press_menu.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';

class MessageLongPressMenu extends StatelessWidget {
  const MessageLongPressMenu({
    super.key,
    required this.messageType,
    required this.isFromMe,
    required this.canRecall,
    required this.onActionSelected,
  });

  final String messageType;
  final bool isFromMe;
  final bool canRecall;
  final ValueChanged<ChatSceneAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return ChatMessageActionSheet(
      actions: buildLegacyLongPressActionDescriptors(
        messageType: messageType,
        isFromMe: isFromMe,
        canRecall: canRecall,
      ),
      onSelected: onActionSelected,
    );
  }
}
```

- [ ] **Step 5: Run the focused action-sheet tests to verify they pass**

Run: `flutter test test/modules/chat/chat_message_action_policy_test.dart test/modules/chat/chat_message_action_sheet_test.dart`
Expected: PASS with the policy and rendering tests green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/widgets/chat_message_action_sheet.dart lib/modules/chat/chat_page_shell.dart lib/wukong_uikit/chat/message_long_press_menu.dart test/modules/chat/chat_message_action_sheet_test.dart
git commit -m "feat: align chat action sheet with android ordering"
```

### Task 3: Align Multi-Select Toolbar Behavior And Forward Cleanup

**Files:**
- Modify: `lib/modules/chat/widgets/chat_selection_toolbar.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`

- [ ] **Step 1: Extend the failing scene-flow tests for batch-mode parity**

```dart
testWidgets('selection forward success clears selection and returns normal', (
  tester,
) async {
  final message = WKMsg()
    ..messageID = 'mid:s1'
    ..clientMsgNO = 'client:s1'
    ..channelID = 'u_scene'
    ..channelType = 1
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('select then forward');
  final gateway = _FakeChatSceneGateway(
    targets: const <ForwardTarget>[
      ForwardTarget(
        channelId: 'g_target',
        channelType: 2,
        name: 'Group Target',
        subtitle: 'Group chat',
        isGroup: true,
      ),
    ],
  );
  final container = ProviderContainer(
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
  );
  addTearDown(container.dispose);
  const session = ChatSession(channelId: 'u_scene', channelType: 1);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: 1,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u591a\u9009'));
  await tester.pumpAndSettle();

  expect(find.text('\u5df2\u9009\u62e9 1 \u6761'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey<String>('chat-selection-forward')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('forward-target-2:g_target')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('forward-submit')));
  await tester.pumpAndSettle();

  expect(
    container.read(chatSceneControllerProvider(session)).mode,
    ChatSceneMode.normal,
  );
  expect(
    container.read(chatSelectionControllerProvider(session)).selectedCount,
    0,
  );
});

testWidgets('selection forward cancel preserves selection mode', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:s2'
    ..clientMsgNO = 'client:s2'
    ..channelID = 'u_scene'
    ..channelType = 1
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('cancel forward');
  final gateway = _FakeChatSceneGateway(
    targets: const <ForwardTarget>[
      ForwardTarget(
        channelId: 'u_target',
        channelType: 1,
        name: 'Target Chat',
        subtitle: 'Direct chat',
      ),
    ],
  );
  final container = ProviderContainer(
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
  );
  addTearDown(container.dispose);
  const session = ChatSession(channelId: 'u_scene', channelType: 1);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_scene',
          channelType: 1,
          channelName: 'Scene Chat',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u591a\u9009'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('chat-selection-forward')));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(
    container.read(chatSceneControllerProvider(session)).mode,
    ChatSceneMode.selecting,
  );
  expect(
    container.read(chatSelectionControllerProvider(session)).selectedCount,
    1,
  );
});
```

- [ ] **Step 2: Run the selection scene-flow test to verify it fails**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "selection"`
Expected: FAIL because the toolbar text, forward button key, and post-forward cleanup semantics are not implemented yet

- [ ] **Step 3: Rebuild the selection toolbar with Android-style wording and stable keys**

```dart
// lib/modules/chat/widgets/chat_selection_toolbar.dart
import 'package:flutter/material.dart';

const String _selectionCountPrefix = '\u5df2\u9009\u62e9';
const String _selectionCountSuffix = '\u6761';
const String _forwardLabel = '\u8f6c\u53d1';

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
      key: const ValueKey<String>('chat-selection-toolbar'),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey<String>('chat-selection-cancel'),
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                '$_selectionCountPrefix $selectedCount $_selectionCountSuffix',
                key: const ValueKey<String>('chat-selection-count'),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('chat-selection-forward'),
              onPressed: onForward,
              child: const Text(_forwardLabel),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Make `ChatPageShell` clear selection only on successful forward**

```dart
// lib/modules/chat/chat_page_shell.dart
onForward: () async {
  final List<WKMsg> selectedMessages = selection.selectedIdentities
      .map(
        (identity) => ref
            .read(chatViewportProvider(_chatSession).notifier)
            .itemByIdentity(identity)
            ?.message,
      )
      .whereType<WKMsg>()
      .toList(growable: false);
  if (selectedMessages.isEmpty) {
    return;
  }

  ref
      .read(chatMessageActionControllerProvider(_chatSession).notifier)
      .prepareForward(selectedMessages);
  final request = ref.read(chatMessageActionControllerProvider(_chatSession)).forwardRequest;
  if (request == null || request.payloads.isEmpty) {
    return;
  }

  final didSubmit = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => ForwardMessagePage(
        payloads: request.payloads,
        channelId: _chatSession.channelId,
        channelType: _chatSession.channelType,
        gateway: ref.read(chatSceneGatewayProvider(_chatSession)),
      ),
    ),
  );

  ref
      .read(chatMessageActionControllerProvider(_chatSession).notifier)
      .clearTransientState();
  if (didSubmit == true) {
    ref.read(chatSelectionControllerProvider(_chatSession).notifier).clear();
    ref.read(chatSceneControllerProvider(_chatSession).notifier).restoreNormal();
  }
},
```

- [ ] **Step 5: Run the focused scene-flow tests to verify they pass**

Run: `flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "selection"`
Expected: PASS with the localized toolbar copy and success/cancel cleanup behavior green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/widgets/chat_selection_toolbar.dart lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_page_scene_flow_test.dart
git commit -m "feat: align batch selection flow with android parity"
```

### Task 4: Rebuild The Forward Chooser Surface For Android Parity

**Files:**
- Modify: `lib/modules/chat/forward_message_page.dart`
- Modify: `lib/modules/chat/message_forwarding.dart`
- Modify: `test/modules/chat/forward_message_page_test.dart`

- [ ] **Step 1: Replace the forward-page test with chooser-specific parity assertions**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/forward_message_page.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

void main() {
  testWidgets('forward chooser uses Android title and selection-aware submit', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway(
      targets: const <ForwardTarget>[
        ForwardTarget(
          channelId: 'g_product',
          channelType: 2,
          name: 'Product Team',
          subtitle: 'Group chat',
          isGroup: true,
        ),
        ForwardTarget(
          channelId: 'u_alice',
          channelType: 1,
          name: 'Alice',
          subtitle: 'Direct chat',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForwardMessagePage(
          payloads: const <ForwardPayload>[
            ForwardPayload(clientMsgNo: 'client-1', content: null),
          ],
          channelId: 'source_chat',
          channelType: 1,
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u9009\u62e9\u4f1a\u8bdd'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '\u786e\u5b9a'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byKey(const ValueKey<String>('forward-submit'))).enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey<String>('forward-target-2:g_product')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, '\u786e\u5b9a(1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('forward-submit')));
    await tester.pumpAndSettle();

    expect(gateway.sentPayloads, hasLength(1));
    expect(gateway.sentTargets.single.channelId, 'g_product');
  });

  testWidgets('forward chooser shows empty state for unmatched search', (
    tester,
  ) async {
    final gateway = _FakeChatSceneGateway(
      targets: const <ForwardTarget>[
        ForwardTarget(
          channelId: 'u_alice',
          channelType: 1,
          name: 'Alice',
          subtitle: 'Direct chat',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForwardMessagePage(
          payloads: const <ForwardPayload>[
            ForwardPayload(clientMsgNo: 'client-1', content: null),
          ],
          channelId: 'source_chat',
          channelType: 1,
          gateway: gateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('forward-search-field')),
      'nobody',
    );
    await tester.pumpAndSettle();

    expect(find.text('\u6682\u65e0\u4f1a\u8bdd'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the forward-page tests to verify they fail**

Run: `flutter test test/modules/chat/forward_message_page_test.dart`
Expected: FAIL because the page still uses generic English copy, checkbox rows, and a static `Send` button label

- [ ] **Step 3: Rebuild `ForwardMessagePage` into an Android-style chooser surface**

```dart
// lib/modules/chat/forward_message_page.dart
import 'package:flutter/material.dart';

import 'chat_scene_gateway.dart';
import 'message_forwarding.dart';

const String _title = '\u9009\u62e9\u4f1a\u8bdd';
const String _searchHint = '\u641c\u7d22(\u7cbe\u786e\u641c\u7d22)';
const String _emptyChats = '\u6682\u65e0\u4f1a\u8bdd';
const String _loadFailure = '\u52a0\u8f7d\u4f1a\u8bdd\u5931\u8d25';
const String _confirmLabel = '\u786e\u5b9a';
const String _submittingLabel = '\u53d1\u9001\u4e2d...';

class ForwardMessagePage extends StatefulWidget {
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
  State<ForwardMessagePage> createState() => _ForwardMessagePageState();
}

class _ForwardMessagePageState extends State<ForwardMessagePage> {
  late final ChatSceneGateway _gateway = widget.gateway ?? ApiChatSceneGateway();
  late final Future<List<ForwardTarget>> _targetsFuture = _gateway.loadForwardTargets(
    excludedChannelId: widget.channelId,
    excludedChannelType: widget.channelType,
  );

  final Set<String> _selectedTargetKeys = <String>{};
  String _query = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ForwardTarget>>(
      future: _targetsFuture,
      builder: (context, snapshot) {
        final allTargets = snapshot.data ?? const <ForwardTarget>[];
        final filteredTargets = filterForwardTargets(allTargets, _query);
        final submitText = _isSubmitting
            ? _submittingLabel
            : _selectedTargetKeys.isEmpty
                ? _confirmLabel
                : '$_confirmLabel(${_selectedTargetKeys.length})';

        return Scaffold(
          appBar: AppBar(title: const Text(_title)),
          body: switch (snapshot.connectionState) {
            ConnectionState.none ||
            ConnectionState.waiting ||
            ConnectionState.active => const Center(child: CircularProgressIndicator()),
            ConnectionState.done => snapshot.hasError
                ? const Center(child: Text(_loadFailure))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: TextField(
                          key: const ValueKey<String>('forward-search-field'),
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: _searchHint,
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredTargets.isEmpty
                            ? const Center(child: Text(_emptyChats))
                            : ListView.builder(
                                itemCount: filteredTargets.length,
                                itemBuilder: (context, index) {
                                  final target = filteredTargets[index];
                                  final selected = _selectedTargetKeys.contains(target.key);
                                  return ListTile(
                                    key: ValueKey<String>('forward-target-${target.key}'),
                                    leading: CircleAvatar(
                                      child: Text(targetAvatarLabel(target.displayName)),
                                    ),
                                    title: Text(target.displayName),
                                    subtitle: Text(target.subtitle),
                                    trailing: Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                    ),
                                    onTap: () {
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
                    ],
                  ),
          },
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey<String>('forward-submit'),
                  onPressed: _selectedTargetKeys.isEmpty || _isSubmitting
                      ? null
                      : () => _submit(allTargets),
                  child: Text(submitText),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(List<ForwardTarget> allTargets) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final selectedTargets = allTargets
          .where((target) => _selectedTargetKeys.contains(target.key))
          .toList(growable: false);
      await _gateway.sendForwardPayloads(widget.payloads, selectedTargets);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
```

- [ ] **Step 4: Keep target filtering stable and test-friendly**

```dart
// lib/modules/chat/message_forwarding.dart
List<ForwardTarget> filterForwardTargets(
  List<ForwardTarget> targets,
  String keyword,
) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) {
    return List<ForwardTarget>.from(targets, growable: false);
  }

  return targets.where((target) {
    final haystack = [
      target.displayName,
      target.subtitle,
      target.channelId,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList(growable: false);
}
```

- [ ] **Step 5: Run the forward-page tests to verify they pass**

Run: `flutter test test/modules/chat/forward_message_page_test.dart`
Expected: PASS with the localized chooser title, dynamic confirm label, and empty-search-state assertions green

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/forward_message_page.dart lib/modules/chat/message_forwarding.dart test/modules/chat/forward_message_page_test.dart
git commit -m "feat: align forward chooser with android chat flow"
```

### Task 5: Finish Android Parity Regression Coverage And Full Verification

**Files:**
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`
- Modify: `test/modules/chat/chat_pages_compile_test.dart`

- [ ] **Step 1: Add Android-parity assertions for localized long-press copy and ordering**

```dart
testWidgets('long press uses Android labels in Android order', (tester) async {
  final message = WKMsg()
    ..messageID = 'mid:android'
    ..clientMsgNO = 'client:android'
    ..channelID = 'u_android'
    ..channelType = 1
    ..fromUID = 'u_self'
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('hello action sheet');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messageListProvider.overrideWith(
          (ref, session) => _StaticMessageListNotifier(
            session.channelId,
            session.channelType,
            session.channelId == 'u_android'
                ? <WKMsg>[message]
                : const <WKMsg>[],
          ),
        ),
        chatMarkConversationReadProvider.overrideWithValue(
          (session, messageIds) async {},
        ),
      ],
      child: const MaterialApp(
        home: ChatPage(
          channelId: 'u_android',
          channelType: 1,
          channelName: 'Android Parity',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.longPress(find.byKey(const ValueKey<String>('message-bubble-body')));
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
  expect((tiles[0].title as Text).data, '\u56de\u590d');
  expect((tiles[1].title as Text).data, '\u8f6c\u53d1');
  expect((tiles[2].title as Text).data, '\u6536\u85cf');
  expect((tiles[3].title as Text).data, '\u591a\u9009');
  expect((tiles[4].title as Text).data, '\u64a4\u56de');
  expect((tiles[5].title as Text).data, '\u8868\u60c5\u56de\u5e94');
});
```

- [ ] **Step 2: Keep compile coverage for the compatibility wrapper**

```dart
testWidgets('compatibility long-press wrapper still renders the shared action copy', (
  tester,
) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  final future = showMessageLongPressMenu(
    context: capturedContext,
    position: Offset.zero,
    messageType: 'text',
    isFromMe: true,
    canRecall: true,
  );
  await tester.pumpAndSettle();

  expect(find.text('\u56de\u590d'), findsOneWidget);
  expect(find.text('\u8f6c\u53d1'), findsOneWidget);

  Navigator.of(capturedContext).pop();
  await future;
});
```

- [ ] **Step 3: Run the parity-focused tests to verify they fail first**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
Expected: FAIL until the localized action copy, action ordering, and compatibility wrapper behavior are fully wired

- [ ] **Step 4: Update the existing scene-flow and parity tests to the Android-aligned copy**

```dart
// test/modules/chat/chat_page_scene_flow_test.dart
expect(find.text('\u56de\u590d'), findsOneWidget);
expect(find.text('\u8f6c\u53d1'), findsOneWidget);
expect(find.text('\u6536\u85cf'), findsOneWidget);
expect(find.text('\u591a\u9009'), findsOneWidget);
expect(find.text('\u8868\u60c5\u56de\u5e94'), findsOneWidget);
expect(find.text('\u5df2\u9009\u62e9 1 \u6761'), findsOneWidget);
await tester.tap(find.text('\u591a\u9009'));
await tester.tap(find.byKey(const ValueKey<String>('chat-selection-forward')));
```

```dart
// test/modules/chat/chat_page_android_parity_test.dart
expect(find.text('\u5df2\u9009\u62e9 1 \u6761'), findsOneWidget);
expect(find.byKey(const ValueKey<String>('chat-selection-forward')), findsOneWidget);
```

- [ ] **Step 5: Run full Phase 5A verification**

Run: `flutter analyze lib/modules/chat lib/wukong_uikit/chat/message_long_press_menu.dart`
Expected: PASS with no new analyze errors in the chat action-surface files

Run: `flutter test test/modules/chat/chat_message_action_policy_test.dart test/modules/chat/chat_message_action_sheet_test.dart test/modules/chat/forward_message_page_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart`
Expected: PASS with all Phase 5A action-surface parity and regression coverage green

If forward payload delivery appears inconsistent during manual Android verification, run:

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'favorite|revoke|forward'"`
Expected: output may be empty, but it must not show new forward/favorite/recall backend errors caused by the parity-compression work

- [ ] **Step 6: Commit**

```bash
git add test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/chat_pages_compile_test.dart
git commit -m "test: lock chat action surface to android parity"
```
