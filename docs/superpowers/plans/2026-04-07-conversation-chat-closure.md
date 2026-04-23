# Conversation And Chat Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining real conversation-list and chat-mainline parity gaps so Flutter reaches credible Android parity for conversation pin, production chat-info and message-record entry, and active-mainline ownership.

**Architecture:** Keep the verified `ChatPageShell` and `ChatSearchEntryPage` mainline intact. This plan only adds one small conversation action-sheet extraction, one production-named message-record search entry wrapper, and one overflow routing bridge from the active chat shell into the already-existing detail and search surfaces. Legacy placeholder shells are not revived; they are explicitly isolated once the authoritative entrypoints are locked.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, wukongimfluttersdk, existing conversation/search providers, PowerShell

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only `Phase 2: Close Conversation List And Chat Mainline Parity` from [2026-04-07-android-reference-parity-master-blueprint.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/plans/2026-04-07-android-reference-parity-master-blueprint.md).

In scope:

- make conversation pin real from the conversation-list action sheet
- route the active chat shell overflow button to the correct production detail page
- expose a production-named message-record search entry that reuses the verified search mainline
- ensure personal and group detail pages both reach the same production search surface
- keep long-press forward or favorite or recall or reaction or reply behavior owned by `ChatPageShell`
- mark known legacy placeholder chat surfaces as non-authoritative after the active route is verified

Out of scope for this plan:

- rebuilding chat scene architecture from scratch
- reopening Phase 5A or 5B action or engagement work that is already green
- reopening Phase 6 scoped-search controllers unless new production routing reveals a verified gap
- group advanced parity beyond wiring the existing group-detail entry from chat overflow
- backend contract rewrites unless implementation proves a verified server-side blocker

## Current Code Reality To Preserve

- `lib/modules/conversation/conversation_list_page.dart` already has a bottom-sheet menu, but the `Pin conversation` action only closes the sheet and never mutates conversation state.
- `lib/modules/chat/chat_page_shell.dart` already owns the active reply, selection, forward, favorite, recall, reaction, and search mainline. The right-side `topMore` button is still a no-op.
- `lib/modules/chat/chat_details_page.dart` already contains search-history, mute, top, report, and clear-history rows, but it is not routed from the active shell and still contains unreadable garbled copy.
- `lib/modules/search/presentation/chat_search_entry_page.dart` is already the authoritative scoped search surface. It already provides inline search, cancel, type-grid entry, keyword results, and locate-to-chat behavior.
- `lib/wukong_uikit/group/group_detail_page.dart` already contains `查找聊天记录`, `mute`, and `top` capabilities and should remain the authoritative group-detail surface.
- `lib/modules/chat/chat_page_complete.dart` and `lib/wukong_uikit/chat/input_function_menu.dart` are legacy placeholder implementations and must not regain ownership of production chat routing.

## Android Reference Anchors

The implementation in this plan is pinned to the following Android surfaces:

- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatActivity.java`
  - overflow entry routes to group or personal detail around line `555`
- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/ChatPersonalActivity.java`
  - `findContentLayout` opens `MessageRecordActivity` around lines `95-101`
  - `stickSwitchView` updates personal `top` around lines `109-117`
- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/group/GroupDetailActivity.java`
  - `findContentLayout` opens `MessageRecordActivity` around lines `131-137`
  - `stickSwitchView` updates group `top` around lines `159-163`
- `TangSengDaoDaoAndroid-master/wkuikit/src/main/java/com/chat/uikit/chat/search/MessageRecordActivity.kt`
  - inline search plus cancel chrome around lines `44-70`
  - empty-keyword type grid plus keyword-result switching around lines `96-118`
  - paged load-more result behavior around lines `74-78` and `138-164`

## Action Audit Baseline

Use this audit as the starting truth before any code changes:

| Surface | Current State | Evidence |
| --- | --- | --- |
| Conversation pin | partial | action-sheet tile exists, but `onTap` only pops the sheet |
| Chat overflow/details entry | missing | `topMore` button in `ChatPageShell` has `onPressed: () {}` |
| Message-record search page | partial | `ChatSearchEntryPage` exists and is tested, but production entry routing is incomplete |
| Reply | done | active shell owns reply strip and reply submission tests already exist |
| Forward | done | active shell owns single and batch forward flow and tests already exist |
| Favorite | done | active shell and `ChatMessageActionController` already own favorite flow |
| Recall | done | action policy and controller already expose recall |
| Reaction | done | active shell already owns picker and chip toggling |
| Legacy placeholder chat shell | hidden | `chat_page_complete.dart` exists but is not the active exported entrypoint |

The implementation work below should only close the `partial` and `missing` rows while preserving the existing `done` rows.

## File Structure

### New Files

- `lib/modules/conversation/widgets/conversation_action_sheet.dart`
  - Small extracted bottom-sheet widget that owns conversation quick-action copy and callback wiring for pin or mute or delete.
- `lib/modules/search/presentation/message_record_search_page.dart`
  - Production-named wrapper that exposes `ChatSearchEntryPage` under the same semantic role as Android `MessageRecordActivity`.
- `test/modules/conversation/conversation_action_sheet_test.dart`
  - Widget tests for pin-title toggling and action callbacks.
- `test/modules/chat/chat_overflow_navigation_test.dart`
  - Widget tests for `ChatPageShell` overflow routing, personal-detail search entry, and group-detail route selection.

### Existing Files To Modify

- `lib/data/providers/conversation_provider.dart`
  - Add `setTop()` alongside the existing `setMute()` mutation path so the conversation sheet can perform a real top-state update.
- `lib/modules/conversation/conversation_list_page.dart`
  - Replace the inline action-sheet construction with the extracted widget and wire pin to the notifier.
- `lib/modules/chat/chat_page_shell.dart`
  - Turn the `topMore` button into a real production route and reload local channel state after the detail page returns.
- `lib/modules/chat/chat_details_page.dart`
  - Replace unreadable copy with stable constants and route its search-history row to the production message-record page.
- `lib/wukong_uikit/group/group_detail_page.dart`
  - Replace the old `ChatSearchPage` wrapper usage with the new production-named message-record page.
- `lib/modules/chat/chat_page.dart`
  - Mark the old `ChatSearchPage` compatibility wrapper as deprecated once all production callsites move to `MessageRecordSearchPage`.
- `lib/modules/chat/chat_page_complete.dart`
  - Add explicit legacy-only documentation and deprecation so future work does not accidentally route through this placeholder shell.
- `lib/wukong_uikit/chat/input_function_menu.dart`
  - Add explicit legacy-only documentation and deprecation because the active chat shell now owns toolbar slots.
- `test/modules/chat/chat_pages_compile_test.dart`
  - Keep compile coverage on the authoritative `ChatPage`, `ForwardMessagePage`, and the new `MessageRecordSearchPage`.

## Verification Commands Used Throughout

- `flutter analyze lib/data/providers/conversation_provider.dart lib/modules/conversation lib/modules/chat lib/modules/search/presentation/message_record_search_page.dart lib/wukong_uikit/group/group_detail_page.dart lib/wukong_uikit/chat/input_function_menu.dart`
- `flutter test test/modules/conversation/conversation_action_sheet_test.dart`
- `flutter test test/modules/chat/chat_overflow_navigation_test.dart`
- `flutter test test/modules/chat/chat_page_scene_flow_test.dart`
- `flutter test test/modules/chat/chat_pages_compile_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_results_page_test.dart`
- `flutter test test/modules/conversation/conversation_action_sheet_test.dart test/modules/chat/chat_overflow_navigation_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_pages_compile_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_results_page_test.dart`

### Task 1: Make Conversation Pin A Real Action-Sheet Capability

**Files:**
- Create: `lib/modules/conversation/widgets/conversation_action_sheet.dart`
- Modify: `lib/data/providers/conversation_provider.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Test: `test/modules/conversation/conversation_action_sheet_test.dart`

- [ ] **Step 1: Write the failing action-sheet widget tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/widgets/conversation_action_sheet.dart';

void main() {
  testWidgets('pin tile toggles title and reports next pin state', (
    tester,
  ) async {
    bool? nextPinned;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationActionSheet(
            isPinned: false,
            onTogglePin: (value) => nextPinned = value,
            onMute: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Pin conversation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('conversation-pin')));
    expect(nextPinned, isTrue);

    nextPinned = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationActionSheet(
            isPinned: true,
            onTogglePin: (value) => nextPinned = value,
            onMute: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Unpin conversation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('conversation-pin')));
    expect(nextPinned, isFalse);
  });
}
```

- [ ] **Step 2: Run the conversation action-sheet test to verify it fails**

Run: `flutter test test/modules/conversation/conversation_action_sheet_test.dart`
Expected: FAIL with missing `ConversationActionSheet` or missing pin callback wiring

- [ ] **Step 3: Implement the extracted sheet widget and real `setTop()` notifier path**

```dart
// lib/modules/conversation/widgets/conversation_action_sheet.dart
import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';

class ConversationActionSheet extends StatelessWidget {
  const ConversationActionSheet({
    super.key,
    required this.isPinned,
    required this.onTogglePin,
    required this.onMute,
    required this.onDelete,
  });

  final bool isPinned;
  final ValueChanged<bool> onTogglePin;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey<String>('conversation-pin'),
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(
                isPinned ? 'Unpin conversation' : 'Pin conversation',
              ),
              subtitle: Text(
                isPinned
                    ? 'Return this conversation to normal sorting.'
                    : 'Keep this conversation at the top of the list.',
              ),
              onTap: () => onTogglePin(!isPinned),
            ),
            const SizedBox(height: WKSpace.xs),
            ListTile(
              key: const ValueKey<String>('conversation-mute'),
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Mute notifications'),
              subtitle: const Text('Hide alerts but keep messages in sync.'),
              onTap: onMute,
            ),
            const SizedBox(height: WKSpace.xs),
            ListTile(
              key: const ValueKey<String>('conversation-delete'),
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: WKColors.danger,
              ),
              title: const Text(
                'Delete conversation',
                style: TextStyle(color: WKColors.danger),
              ),
              subtitle: const Text(
                  'Delete only local conversations and drafts. Server history is kept.',
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/data/providers/conversation_provider.dart
Future<void> setTop(String channelId, int channelType, bool top) async {
  final existingChannel = await WKIM.shared.channelManager.getChannel(
    channelId,
    channelType,
  );
  final channel = existingChannel ?? WKChannel(channelId, channelType);
  channel.top = top ? 1 : 0;
  WKIM.shared.channelManager.addOrUpdateChannel(channel);
  refresh();
}
```

```dart
// lib/modules/conversation/conversation_list_page.dart
void _showConversationMenu(
  BuildContext context,
  WidgetRef ref,
  WKUIConversationMsg conversation,
) {
  final isPinned = (conversation.channel?.top ?? 0) == 1;

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return ConversationActionSheet(
        isPinned: isPinned,
        onTogglePin: (nextPinned) async {
          Navigator.pop(sheetContext);
          await ref
              .read(conversationProvider.notifier)
              .setTop(conversation.channelID, conversation.channelType, nextPinned);
        },
        onMute: () async {
          Navigator.pop(sheetContext);
          await ref
              .read(conversationProvider.notifier)
              .setMute(conversation.channelID, conversation.channelType, true);
        },
        onDelete: () async {
          Navigator.pop(sheetContext);
          await ref
              .read(conversationProvider.notifier)
              .deleteConversation(conversation.channelID, conversation.channelType);
        },
      );
    },
  );
}
```

- [ ] **Step 4: Run the targeted conversation verification**

Run: `flutter test test/modules/conversation/conversation_action_sheet_test.dart`
Expected: PASS

Run: `flutter analyze lib/data/providers/conversation_provider.dart lib/modules/conversation`
Expected: PASS

- [ ] **Step 5: Commit the conversation pin closure**

```bash
git add lib/data/providers/conversation_provider.dart lib/modules/conversation/conversation_list_page.dart lib/modules/conversation/widgets/conversation_action_sheet.dart test/modules/conversation/conversation_action_sheet_test.dart
git commit -m "feat: make conversation pin a real list action"
```

### Task 2: Wire The Active Chat Overflow Into Real Detail And Message-Record Surfaces

**Files:**
- Create: `lib/modules/search/presentation/message_record_search_page.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/chat_details_page.dart`
- Modify: `lib/wukong_uikit/group/group_detail_page.dart`
- Test: `test/modules/chat/chat_overflow_navigation_test.dart`

- [ ] **Step 1: Write the failing overflow-navigation tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/modules/chat/chat_details_page.dart';
import 'package:wukong_im_app/modules/search/presentation/message_record_search_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('buildChatInfoPage returns group detail for group channels', () {
    final page = buildChatInfoPage(
      channelId: 'g_product',
      channelType: WKChannelType.group,
      channelName: 'Product Group',
      onSearchChatHistory: () {},
    );

    expect(page, isA<GroupDetailPage>());
  });

  test('buildChatInfoPage returns personal detail for personal channels', () {
    final page = buildChatInfoPage(
      channelId: 'u_alex',
      channelType: WKChannelType.personal,
      channelName: 'Alex',
      onSearchChatHistory: () {},
    );

    expect(page, isA<ChatDetailsPage>());
  });

  testWidgets('personal overflow opens details and reaches message record page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPageShell(
          channelId: 'u_alex',
          channelType: WKChannelType.personal,
          channelName: 'Alex',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatDetailsPage), findsOneWidget);

    await tester.tap(find.text('查找聊天记录'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageRecordSearchPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the overflow-navigation test to verify it fails**

Run: `flutter test test/modules/chat/chat_overflow_navigation_test.dart`
Expected: FAIL with missing `buildChatInfoPage`, missing `chat-open-more`, or missing `MessageRecordSearchPage`

- [ ] **Step 3: Implement the production message-record page and shell overflow routing**

```dart
// lib/modules/search/presentation/message_record_search_page.dart
import 'package:flutter/material.dart';

import 'chat_search_entry_page.dart';

class MessageRecordSearchPage extends StatelessWidget {
  const MessageRecordSearchPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return ChatSearchEntryPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
```

```dart
// lib/modules/chat/chat_page_shell.dart
@visibleForTesting
Widget buildChatInfoPage({
  required String channelId,
  required int channelType,
  String? channelName,
  VoidCallback? onSearchChatHistory,
}) {
  if (channelType == WKChannelType.group) {
    return GroupDetailPage(channelId: channelId, channelType: channelType);
  }
  return ChatDetailsPage(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
    onSearchChatHistory: onSearchChatHistory,
  );
}

Future<void> _openChatInfo() async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => buildChatInfoPage(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
        onSearchChatHistory: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MessageRecordSearchPage(
                channelId: widget.channelId,
                channelType: widget.channelType,
                channelName: widget.channelName,
              ),
            ),
          );
        },
      ),
    ),
  );
  if (!mounted) {
    return;
  }
  await _loadChannel();
  ref.read(conversationProvider.notifier).refresh();
}
```

```dart
// lib/modules/chat/chat_page_shell.dart app bar action
IconButton(
  key: const ValueKey<String>('chat-open-more'),
  onPressed: _openChatInfo,
  icon: WKReferenceAssets.image(
    WKReferenceAssets.topMore,
    width: 20,
    height: 20,
    tint: WKColors.popupText,
  ),
),
```

```dart
// lib/modules/chat/chat_details_page.dart
const String _chatInfoTitle = '聊天信息';
const String _searchHistoryTitle = '查找聊天记录';
const String _muteTitle = '消息免打扰';
const String _topTitle = '置顶聊天';
const String _reportTitle = '举报';
const String _clearHistoryTitle = '清空聊天记录';

Future<void> _toggleMute(bool value) async {
  if (_isUpdating) {
    return;
  }
  setState(() {
    _isUpdating = true;
    _isMuted = value;
  });
  try {
    await ref
        .read(conversationProvider.notifier)
        .setMute(widget.channelId, widget.channelType, value);
  } finally {
    if (mounted) {
      setState(() => _isUpdating = false);
    }
  }
}

Future<void> _toggleTop(bool value) async {
  if (_isUpdating) {
    return;
  }
  setState(() {
    _isUpdating = true;
    _isTop = value;
  });
  try {
    await ref
        .read(conversationProvider.notifier)
        .setTop(widget.channelId, widget.channelType, value);
  } finally {
    if (mounted) {
      setState(() => _isUpdating = false);
    }
  }
}
```

```dart
// lib/wukong_uikit/group/group_detail_page.dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => MessageRecordSearchPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: _group?.groupName,
    ),
  ),
);
```

- [ ] **Step 4: Run the targeted overflow and search verification**

Run: `flutter test test/modules/chat/chat_overflow_navigation_test.dart`
Expected: PASS

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_results_page_test.dart`
Expected: PASS

Run: `flutter analyze lib/modules/chat lib/modules/search/presentation/message_record_search_page.dart lib/wukong_uikit/group/group_detail_page.dart`
Expected: PASS

- [ ] **Step 5: Commit the production chat overflow routing**

```bash
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/chat_details_page.dart lib/modules/search/presentation/message_record_search_page.dart lib/wukong_uikit/group/group_detail_page.dart test/modules/chat/chat_overflow_navigation_test.dart
git commit -m "feat: wire message record search from chat overflow"
```

### Task 3: Isolate Legacy Chat Placeholders And Lock Active Entrypoint Ownership

**Files:**
- Modify: `lib/modules/chat/chat_page.dart`
- Modify: `lib/modules/chat/chat_page_complete.dart`
- Modify: `lib/wukong_uikit/chat/input_function_menu.dart`
- Modify: `test/modules/chat/chat_pages_compile_test.dart`
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`

- [ ] **Step 1: Write the failing active-entrypoint coverage**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/search/presentation/message_record_search_page.dart';

void main() {
  test('authoritative entrypoints remain constructible', () {
    expect(
      const ChatPage(channelId: 'u_alex', channelType: 1),
      isA<Widget>(),
    );
    expect(
      const MessageRecordSearchPage(channelId: 'u_alex', channelType: 1),
      isA<Widget>(),
    );
  });
}
```

```dart
testWidgets('overflow route returns without breaking mainline search or forward', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: ChatPageShell(
        channelId: 'u_alex',
        channelType: 1,
        channelName: 'Alex',
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey<String>('chat-open-search')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('chat-open-more')), findsOneWidget);
});
```

- [ ] **Step 2: Run the compile and mainline regression coverage to verify it fails**

Run: `flutter test test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_scene_flow_test.dart`
Expected: FAIL with missing `MessageRecordSearchPage`, missing `chat-open-more`, or broken overflow regression assumptions

- [ ] **Step 3: Mark old wrappers as legacy-only and keep the active exports authoritative**

```dart
// lib/modules/chat/chat_page.dart
@Deprecated('Use MessageRecordSearchPage for production chat-record entry.')
class ChatSearchPage extends StatelessWidget {
  const ChatSearchPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return MessageRecordSearchPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
```

```dart
// lib/modules/chat/chat_page_complete.dart
/// Legacy placeholder shell kept only for historical reference.
/// New production routing must use `lib/modules/chat/chat_page.dart`.
@Deprecated('Legacy placeholder. Use ChatPage from chat_page.dart instead.')
class ChatPage extends ConsumerStatefulWidget {
```

```dart
// lib/wukong_uikit/chat/input_function_menu.dart
/// Legacy placeholder menu retained only for compatibility review.
/// The active chat surface uses `ChatPageShell` toolbar slots instead.
@Deprecated('Legacy placeholder menu. Do not use for new chat flows.')
class InputFunctionMenu extends StatelessWidget {
```

- [ ] **Step 4: Run the final targeted regression pack**

Run: `flutter test test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_scene_flow_test.dart`
Expected: PASS

Run: `flutter analyze lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_complete.dart lib/wukong_uikit/chat/input_function_menu.dart`
Expected: PASS

- [ ] **Step 5: Commit the legacy isolation cleanup**

```bash
git add lib/modules/chat/chat_page.dart lib/modules/chat/chat_page_complete.dart lib/wukong_uikit/chat/input_function_menu.dart test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_scene_flow_test.dart
git commit -m "chore: isolate legacy chat placeholders"
```

## Final Verification Sweep

- [ ] Run `flutter analyze lib/modules/conversation lib/modules/chat lib/modules/search lib/wukong_uikit/group lib/wukong_uikit/chat/input_function_menu.dart`
- [ ] Run `flutter test test/modules/conversation/conversation_action_sheet_test.dart test/modules/chat/chat_overflow_navigation_test.dart test/modules/chat/chat_page_scene_flow_test.dart test/modules/chat/chat_pages_compile_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_results_page_test.dart`
- [ ] Manually verify one personal chat and one group chat:
  - conversation list pin moves the conversation to the top
  - chat overflow opens the correct detail page
  - `查找聊天记录` opens the production message-record search page
  - returning from detail pages leaves the active `ChatPageShell` usable for reply or forward or favorite

## Exit Gate

- Conversation pin is real from the conversation list.
- The active chat shell overflow button opens the correct personal or group detail surface.
- `查找聊天记录` is reachable from production chat detail routes and uses the existing verified search mainline.
- No production path depends on `chat_page_complete.dart` or `input_function_menu.dart`.
