# Chat Page Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Flutter chat composer, emoji assets, emoji rendering, and Android-specific text/GIF behaviors with the approved TangSengDaoDao Android reference.

**Architecture:** Extract the chat composer surface out of the inline `ChatPageShell` layout into a dedicated Android-style two-row presentation widget, keep the existing Riverpod controllers and message send flow as the source of truth, and migrate Android emoji assets into a generated Flutter catalog. Static emoji insertion stays text-based in the editor, while picker cells and message bubbles render Android image assets. Android-only behavior differences that matter for parity are preserved: group-only `@` toolbar entry, rich-text entry beside the text field, GIF sending via `WKGifContent`, and a pre-send `text_to_emoji_sticker` hook for exact emoji-only text messages.

**Tech Stack:** Flutter, Dart, Riverpod, widget tests, unit tests, generated Dart catalog data, local asset copy tooling.

---

## Implementation Notes

This workspace is currently treated as a non-Git workspace by the Codex app. Execute the commit steps only after reopening the project as a Git worktree or a normal Git workspace. Until then, keep the checkbox unchecked and continue with the code/test steps.

Android parity details that must be preserved during implementation:

- The rich-text button lives inside the input row and is hidden while flame chat is enabled.
- The `@` toolbar entry is Android-style and should appear only for group chats.
- The more panel should keep extension-style actions only. Rich text leaves the more panel.
- Exact emoji-only text can be intercepted by a `text_to_emoji_sticker` endpoint hook before falling back to `WKTextContent`.
- GIF sending must remain on the `WKGifContent` path already used by robot GIF search results.

## File Structure Map

**Create**

- `tool/generate_android_emoji_catalog.dart`
- `lib/wukong_base/emoji/android_emoji_catalog.dart`
- `lib/wukong_base/emoji/android_emoji_catalog.g.dart`
- `lib/modules/chat/widgets/chat_emoji_panel.dart`
- `lib/widgets/wk_emoji_text.dart`
- `lib/modules/chat/chat_text_sticker_conversion.dart`
- `test/wukong_base/emoji/android_emoji_catalog_test.dart`
- `test/wukong_base/emoji/emoji_manager_test.dart`
- `test/widgets/wk_emoji_text_test.dart`
- `test/modules/chat/chat_text_sticker_conversion_test.dart`

**Modify**

- `lib/modules/chat/chat_page_shell.dart`
- `lib/modules/chat/widgets/chat_composer.dart`
- `lib/modules/chat/chat_toolbar_slot_assembly.dart`
- `lib/modules/chat/chat_action_capability_policy.dart`
- `lib/wukong_base/emoji/emoji_manager.dart`
- `lib/wukong_base/emoji/sticker_manager.dart`
- `lib/wukong_base/emoji/emoji_exports.dart`
- `lib/widgets/message_bubble.dart`
- `lib/wukong_base/endpoint/menu/endpoint_menu.dart`
- `pubspec.yaml`
- `test/modules/chat/chat_page_android_parity_test.dart`
- `test/modules/chat/chat_toolbar_slot_assembly_test.dart`
- `test/modules/chat/message_bubble_experience_test.dart`
- `test/modules/chat/chat_media_action_service_test.dart`

**Responsibilities**

- `chat_page_shell.dart`: keep controller orchestration, send flow, robot GIF send flow, and message actions, but delegate composer structure/picker rendering to focused widgets and apply the text-to-sticker hook before plain text send.
- `chat_composer.dart`: become the Android-style composer surface wrapper instead of a `RepaintBoundary` pass-through.
- `chat_toolbar_slot_assembly.dart`: expose Android-style toolbar order, group-only `@`, and remove rich text from the more panel.
- `android_emoji_catalog*.dart`: define the generated source of truth for Android emoji IDs, tags, asset paths, groups, and variant families.
- `emoji_manager.dart` and `sticker_manager.dart`: consume the generated catalog so recents, search, and sticker-like surfaces are all backed by the same Android emoji data.
- `chat_emoji_panel.dart`: render recent/category tabs plus an asset-backed emoji grid and backspace action.
- `wk_emoji_text.dart`: render inline image emoji inside message text without changing the stored protocol text.
- `chat_text_sticker_conversion.dart`: isolate the Android-style `text_to_emoji_sticker` pre-send rule so it is unit-testable.

## Task 1: Extract the Android Two-Row Composer Surface

**Files:**

- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/widgets/chat_composer.dart`
- Test: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Replace the current one-row alignment tests with a failing two-row parity test**

```dart
testWidgets(
  'chat composer keeps Android input row above toolbar row and rich text stays inside the input lane',
  (tester) async {
    await pumpChatPage(
      tester,
      channelId: 'u_android_composer_rows',
      channelType: WKChannelType.personal,
      channelName: 'Android Composer Rows',
    );
    await tester.pumpAndSettle();

    final inputRow = find.byKey(
      const ValueKey<String>('chat-composer-input-row'),
    );
    final toolbarRow = find.byKey(
      const ValueKey<String>('chat-composer-toolbar-row'),
    );
    final richButton = find.byKey(
      const ValueKey<String>('chat-compose-rich-text-button'),
    );

    expect(inputRow, findsOneWidget);
    expect(toolbarRow, findsOneWidget);
    expect(richButton, findsOneWidget);

    final inputRect = tester.getRect(inputRow);
    final toolbarRect = tester.getRect(toolbarRow);
    final richRect = tester.getRect(richButton);

    expect(toolbarRect.top, greaterThan(inputRect.bottom));
    expect(inputRect.contains(richRect.center), isTrue);
    expect(
      find.descendant(
        of: toolbarRow,
        matching: find.byKey(
          const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji'),
        ),
      ),
      findsOneWidget,
    );
  },
);
```

- [ ] **Step 2: Run the parity test and verify it fails against the current inline one-row composer**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart --plain-name "chat composer keeps Android input row above toolbar row and rich text stays inside the input lane"`

Expected: FAIL because the current composer does not expose `chat-composer-input-row`, `chat-composer-toolbar-row`, or the input-row rich-text button.

- [ ] **Step 3: Turn `ChatComposer` into the Android surface wrapper instead of a pass-through widget**

```dart
import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    this.header,
    this.robotInlineHeader,
    required this.inputRow,
    required this.toolbarRow,
    required this.panel,
  });

  final Widget? header;
  final Widget? robotInlineHeader;
  final Widget inputRow;
  final Widget toolbarRow;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: WKColors.layoutColorSelected),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) header!,
            if (robotInlineHeader != null) robotInlineHeader!,
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: KeyedSubtree(
                key: const ValueKey<String>('chat-composer-input-row'),
                child: inputRow,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: KeyedSubtree(
                key: const ValueKey<String>('chat-composer-toolbar-row'),
                child: toolbarRow,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Split the inline shell layout into `_buildComposerInputRow` and `_buildComposerToolbarRow`**

```dart
Widget _buildComposerInputRow(
  ChatComposerState composerState,
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
  bool flameEnabled,
) {
  final voiceService = _voiceService!;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: composerState.showVoiceInput
            ? ValueListenableBuilder<ChatVoiceRecordingState>(
                valueListenable: voiceService.recordingStateListenable,
                builder: (context, voiceState, _) {
                  return ChatVoicePressHoldButton(
                    key: const ValueKey<String>('chat-voice-record-button'),
                    isRecording: _isVoiceSessionActive(voiceState),
                    onHoldStart: _startVoiceRecording,
                    onCancelZoneChanged: voiceService.setCancelCandidate,
                    onHoldRelease: (isInCancelZone) => _finishVoiceRecording(
                      composerController,
                      shouldSend: !isInCancelZone,
                    ),
                    onHoldAbort: _cancelVoiceRecording,
                  );
                },
              )
            : TextField(
                controller: _textController,
                onTap: composerController.hidePanels,
                onChanged: (value) => _handleTextChanged(
                  value,
                  composerController,
                  mentionsController,
                ),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入消息',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: WKColors.surfaceSoft,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
      ),
      if (!flameEnabled) ...[
        const SizedBox(width: 8),
        _ComposerToolbarButton(
          key: const ValueKey<String>('chat-compose-rich-text-button'),
          asset: WKReferenceAssets.chatRichEdit,
          onTap: () => unawaited(
            _openRichTextComposer(composerController),
          ),
        ),
      ],
      if (flameEnabled) ...[
        const SizedBox(width: 8),
        _ComposerToolbarButton(
          key: const ValueKey<String>('chat-flame-toggle-button'),
          asset: WKReferenceAssets.flameSmall,
          onTap: composerController.toggleFlamePanel,
        ),
      ],
      const SizedBox(width: 8),
      _ComposerSendButton(
        enabled: composerState.text.trim().isNotEmpty,
        onTap: composerState.text.trim().isEmpty
            ? null
            : () => _handleSendPressed(
                composerController,
                mentionsController,
              ),
      ),
    ],
  );
}

Widget _buildComposerToolbarRow(
  List<ChatToolBarMenu> toolbarItems,
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) {
  return Row(
    children: [
      for (var index = 0; index < toolbarItems.length; index++) ...[
        _ComposerToolbarButton(
          key: ValueKey<String>('chat-toolbar-${toolbarItems[index].sid}'),
          asset: toolbarItems[index].icon ?? '',
          onTap: () => unawaited(
            _handleToolbarTap(
              toolbarItems[index],
              composerController,
              mentionsController,
            ),
          ),
        ),
        if (index != toolbarItems.length - 1) const SizedBox(width: 8),
      ],
      if (widget.robotMenus.isNotEmpty) ...[
        const SizedBox(width: 8),
        _ComposerToolbarButton(
          key: const ValueKey<String>('chat-robot-menu-button'),
          asset: composerController.state.showRobotMenuPanel
              ? WKReferenceAssets.chatMenuClose
              : WKReferenceAssets.chatMenu,
          onTap: composerController.toggleRobotMenuPanel,
        ),
      ],
    ],
  );
}
```

- [ ] **Step 5: Wire the new shell methods into the build tree**

```dart
Widget? _buildComposerHeader(
  ChatComposerState composerState,
  ChatComposerController composerController,
) {
  if (composerState.pendingEditMessageId?.trim().isNotEmpty == true) {
    return ChatEditPreviewStrip(
      previewText: composerState.pendingEditPreview ?? '',
      onClose: composerController.clearPendingEdit,
    );
  }
  if (composerState.pendingReplyMessageId?.trim().isNotEmpty == true) {
    return ChatReplyPreviewStrip(
      previewText: composerState.pendingReplyPreview ?? '',
      onClose: composerController.clearPendingReply,
    );
  }
  return null;
}

Widget? _buildRobotInlineHeader() {
  final placeholder = _robotInlinePlaceholder?.trim() ?? '';
  if (placeholder.isEmpty) {
    return null;
  }
  return Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey<String>('chat-robot-placeholder'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: WKColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          placeholder,
          style: const TextStyle(
            fontSize: 12,
            color: WKColors.color999,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

child: ChatComposer(
  header: _buildComposerHeader(
    composerState,
    composerController,
  ),
  robotInlineHeader: _buildRobotInlineHeader(),
  inputRow: _buildComposerInputRow(
    composerState,
    composerController,
    mentionsController,
    flameEnabled,
  ),
  toolbarRow: _buildComposerToolbarRow(
    toolbarItems,
    composerController,
    mentionsController,
  ),
  panel: _buildPanel(
    composerState,
    functionItems,
    currentChannel,
    composerController,
    mentionsController,
  ),
),
```

- [ ] **Step 6: Run the parity test again and verify the two-row layout now passes**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart --plain-name "chat composer keeps Android input row above toolbar row and rich text stays inside the input lane"`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_composer.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: align composer surface with android rows"
```

## Task 2: Add the Group-Only `@` Toolbar Button and Remove Rich Text from the More Panel

**Files:**

- Modify: `lib/modules/chat/chat_toolbar_slot_assembly.dart`
- Modify: `lib/modules/chat/chat_action_capability_policy.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Test: `test/modules/chat/chat_toolbar_slot_assembly_test.dart`
- Test: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Add failing slot and widget tests for Android toolbar order**

```dart
test(
  'group chats expose Android toolbar order with mention and no rich-text function item',
  () {
    final registry = SlotRegistry();

    final toolbarItems = resolveChatToolbarItems(
      registry,
      const ChatToolbarSlotContext(
        isGroup: true,
        showVoiceInput: false,
        showEmojiPanel: false,
        showFunctionPanel: false,
        isMobile: true,
        isDesktop: false,
        isWeb: false,
      ),
    );
    final functionItems = resolveChatFunctionItems(
      registry,
      const ChatToolbarSlotContext(
        isGroup: true,
        showVoiceInput: false,
        showEmojiPanel: false,
        showFunctionPanel: true,
        isMobile: true,
        isDesktop: false,
        isWeb: false,
      ),
    );

    expect(toolbarItems.map((item) => item.sid), <String>[
      'wk_chat_toolbar_voice',
      'wk_chat_toolbar_emoji',
      'wk_chat_toolbar_album',
      'wk_chat_toolbar_mention',
      'wk_chat_toolbar_more',
    ]);
    expect(functionItems.map((item) => item.sid), isNot(contains('composeRichText')));
  },
);

testWidgets(
  'group chats show Android mention entry while personal chats hide it',
  (tester) async {
    await pumpChatPage(
      tester,
      channelId: 'g_android_mention',
      channelType: WKChannelType.group,
      channelName: 'Android Mention',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpChatPage(
      tester,
      channelId: 'u_android_mention',
      channelType: WKChannelType.personal,
      channelName: 'No Mention',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_mention')),
      findsNothing,
    );
  },
);
```

- [ ] **Step 2: Run the slot and parity tests and verify they fail**

Run: `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart test/modules/chat/chat_page_android_parity_test.dart`

Expected: FAIL because `wk_chat_toolbar_mention` does not exist yet and `composeRichText` is still present in the more panel.

- [ ] **Step 3: Register the Android mention toolbar item and remove rich text from capability policy**

```dart
if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_mention')) {
  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_mention',
      priority: 97,
      predicate: (context) => context.isGroup,
      build: (_) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_mention',
        icon: WKReferenceAssets.chatToolbarMention,
      ),
    ),
  );
}

if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_more')) {
  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_more',
      priority: 96,
      build: (context) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_more',
        icon: WKReferenceAssets.chatToolbarMore,
        isSelected: context.showFunctionPanel,
      ),
    ),
  );
}
```

```dart
class ChatActionCapabilityPolicy {
  List<ChatActionDefinition> resolve(ChatActionCapabilityContext context) {
    final actions = <ChatActionDefinition>[
      chatChooseImageAction,
      chatChooseFileAction,
      chatSendLocationAction,
      chatChooseCardAction,
    ];
    if (context.isMobile) {
      actions.insert(1, chatCaptureImageAction);
    }
    if (context.isGroup) {
      actions.add(chatGroupCallAction);
    } else {
      actions
        ..add(chatAudioCallAction)
        ..add(chatVideoCallAction);
    }
    return actions;
  }
}
```

- [ ] **Step 4: Handle `wk_chat_toolbar_mention` inside the shell by inserting `@` at the cursor**

```dart
Future<void> _handleToolbarTap(
  ChatToolBarMenu item,
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) async {
  switch (item.sid) {
    case 'wk_chat_toolbar_emoji':
      composerController.toggleFacePanel();
      break;
    case 'wk_chat_toolbar_more':
      composerController.toggleFunctionPanel();
      break;
    case 'wk_chat_toolbar_album':
      await _sendPickedContent(
        await ref.read(chatMediaActionServiceProvider).pickImage(context),
        composerController,
      );
      break;
    case 'wk_chat_toolbar_voice':
      final voiceService = _voiceService;
      final voiceState = voiceService?.recordingStateListenable.value;
      if (voiceState == null) {
        composerController.toggleVoiceInput();
        break;
      }
      if (_isVoiceSessionActive(voiceState)) {
        await _cancelVoiceRecording();
      }
      composerController.toggleVoiceInput();
      break;
    case 'wk_chat_toolbar_mention':
      final selection = _textController.selection;
      final offset = selection.isValid
          ? selection.baseOffset.clamp(0, _textController.text.length).toInt()
          : _textController.text.length;
      final nextText = _textController.text.replaceRange(offset, offset, '@');
      _applyComposerValue(
        TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: offset + 1),
        ),
        composerController,
        mentionsController,
      );
      break;
  }
  item.onChecked?.call(!item.isSelected);
}
```

- [ ] **Step 5: Update the more-panel parity expectation so rich text is absent**

```dart
testWidgets('more panel matches Android default function entries', (tester) async {
  await pumpChatPage(
    tester,
    channelId: 'u_function_panel',
    channelType: WKChannelType.personal,
    channelName: 'Function Panel',
  );
  await tester.pumpAndSettle();

  await tester.tap(_assetFinder(WKReferenceAssets.chatToolbarMore));
  await tester.pumpAndSettle();

  expect(find.text('图片'), findsOneWidget);
  expect(find.text('名片'), findsOneWidget);
  expect(find.text('位置'), findsOneWidget);
  expect(find.text('文件'), findsOneWidget);
  expect(find.text('富文本'), findsNothing);
});
```

- [ ] **Step 6: Run the slot and parity tests again**

Run: `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart test/modules/chat/chat_page_android_parity_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_toolbar_slot_assembly.dart lib/modules/chat/chat_action_capability_policy.dart lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_toolbar_slot_assembly_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: add android mention toolbar behavior"
```

## Task 3: Generate the Android Emoji Asset Catalog and Copy Assets into Flutter

**Files:**

- Create: `tool/generate_android_emoji_catalog.dart`
- Create: `lib/wukong_base/emoji/android_emoji_catalog.dart`
- Create: `lib/wukong_base/emoji/android_emoji_catalog.g.dart`
- Modify: `lib/wukong_base/emoji/emoji_exports.dart`
- Modify: `pubspec.yaml`
- Test: `test/wukong_base/emoji/android_emoji_catalog_test.dart`

- [ ] **Step 1: Add a failing catalog test that describes the generated source of truth**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

void main() {
  test('generated Android emoji catalog preserves groups, assets, and variants', () {
    expect(androidEmojiEntries.length, greaterThan(350));
    expect(androidEmojiCatalog.groupIds, <String>['0', '1', '2']);
    expect(
      androidEmojiCatalog.lookupById('0_0')?.assetPath,
      'assets/emoji/android/default/0_0.png',
    );
    expect(
      androidEmojiCatalog.lookupById('0_114_default')?.baseId,
      '0_114',
    );
  });
}
```

- [ ] **Step 2: Run the catalog test and verify it fails because the generated files do not exist yet**

Run: `flutter test test/wukong_base/emoji/android_emoji_catalog_test.dart`

Expected: FAIL with missing import/build errors until the catalog files are created.

- [ ] **Step 3: Define the hand-written catalog model and lookup API**

```dart
import 'package:flutter/foundation.dart';

part 'android_emoji_catalog.g.dart';

@immutable
class AndroidEmojiEntry {
  const AndroidEmojiEntry({
    required this.id,
    required this.groupId,
    required this.tag,
    required this.assetPath,
    this.baseId,
  });

  final String id;
  final String groupId;
  final String tag;
  final String assetPath;
  final String? baseId;
}

class AndroidEmojiCatalog {
  AndroidEmojiCatalog(List<AndroidEmojiEntry> entries)
      : entries = List<AndroidEmojiEntry>.unmodifiable(entries),
        _byId = <String, AndroidEmojiEntry>{
          for (final entry in entries) entry.id: entry,
        },
        _byTag = <String, AndroidEmojiEntry>{
          for (final entry in entries) entry.tag: entry,
        };

  final List<AndroidEmojiEntry> entries;
  final Map<String, AndroidEmojiEntry> _byId;
  final Map<String, AndroidEmojiEntry> _byTag;

  List<String> get groupIds => <String>['0', '1', '2'];

  AndroidEmojiEntry? lookupById(String id) => _byId[id];
  AndroidEmojiEntry? lookupByTag(String tag) => _byTag[tag];

  AndroidEmojiEntry? longestMatchAt(String text, int start) {
    AndroidEmojiEntry? best;
    for (final entry in entries) {
      if (!text.startsWith(entry.tag, start)) {
        continue;
      }
      if (best == null || entry.tag.length > best.tag.length) {
        best = entry;
      }
    }
    return best;
  }

  List<AndroidEmojiEntry> entriesForGroup(String groupId) {
    return entries
        .where((entry) => entry.groupId == groupId && !entry.id.contains('_color_'))
        .toList(growable: false);
  }
}

final AndroidEmojiCatalog androidEmojiCatalog =
    AndroidEmojiCatalog(androidEmojiEntries);
```

- [ ] **Step 4: Implement the generator that parses Android `emoji.xml`, copies PNGs, and emits `android_emoji_catalog.g.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as path;

final _emoticonPattern = RegExp(
  r'<Emoticon ID="([^"]+)" Tag="([^"]*)" File="([^"]+)"\\s*/>',
);

void main(List<String> args) {
  final androidEmojiRoot = Directory(
    args.isNotEmpty
        ? args.first
        : path.join(
            '..',
            'TangSengDaoDao',
            'TangSengDaoDaoAndroid-master',
            'wkbase',
            'src',
            'main',
            'assets',
            'emoji',
          ),
  );
  final flutterEmojiRoot = Directory(
    path.join('assets', 'emoji', 'android'),
  );
  final generatedFile = File(
    path.join(
      'lib',
      'wukong_base',
      'emoji',
      'android_emoji_catalog.g.dart',
    ),
  );

  final xmlFile = File(path.join(androidEmojiRoot.path, 'emoji.xml'));
  final xml = xmlFile.readAsStringSync();
  final entries = <Map<String, String>>[];

  for (final match in _emoticonPattern.allMatches(xml)) {
    final id = match.group(1)!;
    final tag = match.group(2)!;
    final file = match.group(3)!;
    final groupId = id.split('_').first;
    final baseId = _resolveBaseId(id);

    final sourceFile = File(path.join(androidEmojiRoot.path, 'default', file));
    final targetFile = File(path.join(flutterEmojiRoot.path, 'default', file));
    targetFile.parent.createSync(recursive: true);
    sourceFile.copySync(targetFile.path);

    entries.add(<String, String>{
      'id': id,
      'groupId': groupId,
      'tag': tag,
      'assetPath': path.join('assets', 'emoji', 'android', 'default', file).replaceAll('\\', '/'),
      'baseId': baseId ?? '',
    });
  }

  final buffer = StringBuffer()
    ..writeln("part of 'android_emoji_catalog.dart';")
    ..writeln()
    ..writeln('const List<AndroidEmojiEntry> androidEmojiEntries = <AndroidEmojiEntry>[');

  for (final entry in entries) {
    buffer
      ..writeln('  AndroidEmojiEntry(')
      ..writeln("    id: '${_escape(entry['id']!)}',")
      ..writeln("    groupId: '${_escape(entry['groupId']!)}',")
      ..writeln("    tag: '${_escape(entry['tag']!)}',")
      ..writeln("    assetPath: '${_escape(entry['assetPath']!)}',")
      ..writeln(
        entry['baseId']!.isEmpty
            ? '    baseId: null,'
            : "    baseId: '${_escape(entry['baseId']!)}',",
      )
      ..writeln('  ),');
  }

  buffer
    ..writeln('];')
    ..writeln();

  generatedFile
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
}

String? _resolveBaseId(String id) {
  if (id.endsWith('_default')) {
    return id.substring(0, id.length - '_default'.length);
  }
  final colorIndex = id.indexOf('_color_');
  if (colorIndex != -1) {
    return id.substring(0, colorIndex);
  }
  return null;
}

String _escape(String value) {
  return value
      .replaceAll(r'\\', r'\\\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n');
}
```

- [ ] **Step 5: Register the new asset directory and export the catalog**

```yaml
flutter:
  assets:
    - assets/images/
    - assets/emoji/
    - assets/emoji/android/
    - assets/icons/
    - assets/reference_ui/icons/
```

```dart
export 'android_emoji_catalog.dart';
export 'emoji_manager.dart';
export 'sticker_manager.dart';
export 'moon_util.dart';
```

- [ ] **Step 6: Run the generator to materialize `assets/emoji/android/default/*.png` and `android_emoji_catalog.g.dart`**

Run: `dart run tool/generate_android_emoji_catalog.dart ..\\TangSengDaoDao\\TangSengDaoDaoAndroid-master\\wkbase\\src\\main\\assets\\emoji`

Expected: the generator completes without errors, `assets/emoji/android/default/` contains the copied Android PNGs, and `lib/wukong_base/emoji/android_emoji_catalog.g.dart` is regenerated.

- [ ] **Step 7: Run the catalog test again**

Run: `flutter test test/wukong_base/emoji/android_emoji_catalog_test.dart`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add tool/generate_android_emoji_catalog.dart lib/wukong_base/emoji/android_emoji_catalog.dart lib/wukong_base/emoji/android_emoji_catalog.g.dart lib/wukong_base/emoji/emoji_exports.dart pubspec.yaml assets/emoji/android test/wukong_base/emoji/android_emoji_catalog_test.dart
git commit -m "feat: import android emoji catalog"
```

## Task 4: Rebuild EmojiManager and StickerManager on Top of the Android Catalog

**Files:**

- Modify: `lib/wukong_base/emoji/emoji_manager.dart`
- Modify: `lib/wukong_base/emoji/sticker_manager.dart`
- Test: `test/wukong_base/emoji/emoji_manager_test.dart`

- [ ] **Step 1: Add a failing manager test for Android-backed categories and recents**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/emoji/emoji_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('emoji manager exposes Android groups and persists recents by tag', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageUtils.init();

    final manager = EmojiManager.instance;
    manager.debugResetForTest();
    await manager.initialize();

    expect(manager.categories.map((item) => item.id), containsAll(<String>['0', '1', '2']));

    final tag = androidEmojiCatalog.lookupById('0_0')!.tag;
    manager.addToRecent(tag);

    expect(manager.recentEmojis.first, tag);
    expect(manager.search(tag), contains(tag));
  });
}
```

- [ ] **Step 2: Run the manager test and verify it fails**

Run: `flutter test test/wukong_base/emoji/emoji_manager_test.dart`

Expected: FAIL because the manager still serves the old hardcoded categories and has no test reset hook.

- [ ] **Step 3: Replace the hardcoded emoji defaults with catalog-derived data**

```dart
static final List<EmojiCategory> defaultCategories = <EmojiCategory>[
  for (final groupId in androidEmojiCatalog.groupIds)
    EmojiCategory(
      id: groupId,
      name: _categoryNameForGroup(groupId),
      icon: _categoryIconForGroup(groupId),
      emojis: androidEmojiCatalog
          .entriesForGroup(groupId)
          .map((entry) => entry.tag)
          .toList(growable: false),
    ),
];

static final List<EmojiPack> defaultPacks = <EmojiPack>[
  for (final groupId in androidEmojiCatalog.groupIds)
    EmojiPack(
      id: 'android_$groupId',
      name: _categoryNameForGroup(groupId),
      coverUrl: androidEmojiCatalog.entriesForGroup(groupId).first.assetPath,
      emojis: androidEmojiCatalog
          .entriesForGroup(groupId)
          .map((entry) => entry.tag)
          .toList(growable: false),
      isBuiltIn: true,
    ),
];

static String _categoryNameForGroup(String groupId) {
  switch (groupId) {
    case '0':
      return 'default';
    case '1':
      return 'nature';
    case '2':
      return 'symbols';
    default:
      return 'group_$groupId';
  }
}

static IconData _categoryIconForGroup(String groupId) {
  switch (groupId) {
    case '0':
      return Icons.sentiment_satisfied_alt;
    case '1':
      return Icons.pets;
    case '2':
      return Icons.favorite;
    default:
      return Icons.tag_faces;
  }
}
```

- [ ] **Step 4: Add a test reset hook and make sticker categories resolve local asset paths from the catalog**

```dart
@visibleForTesting
void debugResetForTest() {
  _initialized = false;
  _categories = <EmojiCategory>[];
  _packs.clear();
  _recentEmojis = <String>[];
}
```

```dart
StickerCategory _packToCategory(EmojiPack pack) {
  return StickerCategory(
    id: pack.id,
    name: pack.name,
    iconUrl: pack.coverUrl,
    isBuiltIn: pack.isBuiltIn,
    stickers: List<Sticker>.generate(pack.emojis.length, (index) {
      final tag = pack.emojis[index];
      final entry = androidEmojiCatalog.lookupByTag(tag);
      return Sticker(
        id: '${pack.id}_$index',
        name: entry?.id ?? '${pack.name} ${index + 1}',
        localPath: entry?.assetPath,
        url: null,
      );
    }),
  );
}
```

- [ ] **Step 5: Run the manager test again**

Run: `flutter test test/wukong_base/emoji/emoji_manager_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/wukong_base/emoji/emoji_manager.dart lib/wukong_base/emoji/sticker_manager.dart test/wukong_base/emoji/emoji_manager_test.dart
git commit -m "refactor: back emoji manager with android catalog"
```

## Task 5: Replace the Hardcoded Emoji Panel with an Asset-Backed Android Picker

**Files:**

- Create: `lib/modules/chat/widgets/chat_emoji_panel.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Test: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Replace the current emoji panel test with a failing asset-backed parity test**

```dart
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

testWidgets('emoji panel exposes Android asset cells and inserts the matched tag', (
  tester,
) async {
  await pumpChatPage(
    tester,
    channelId: 'u_emoji_panel',
    channelType: WKChannelType.personal,
    channelName: 'Emoji Panel',
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-toolbar-wk_chat_toolbar_emoji')),
  );
  await tester.pumpAndSettle();

  final firstEmoji = androidEmojiCatalog.lookupById('0_0')!;

  expect(
    find.byKey(ValueKey<String>('chat-emoji-item-${firstEmoji.id}')),
    findsOneWidget,
  );
  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == firstEmoji.assetPath,
    ),
    findsWidgets,
  );

  await tester.tap(
    find.byKey(ValueKey<String>('chat-emoji-item-${firstEmoji.id}')),
  );
  await tester.pumpAndSettle();

  final textField = tester.widget<TextField>(find.byType(TextField).first);
  expect(textField.controller?.text, contains(firstEmoji.tag));
});
```

- [ ] **Step 2: Run the parity test and verify it fails because the panel still uses `_defaultEmojiPalette`**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart --plain-name "emoji panel exposes Android asset cells and inserts the matched tag"`

Expected: FAIL because the current panel renders `Text` cells from `_defaultEmojiPalette`, not asset images keyed by Android IDs.

- [ ] **Step 3: Create `ChatEmojiPanel` with recent plus `0/1/2` Android tabs**

```dart
import 'package:flutter/material.dart';

import '../../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../../wukong_base/emoji/emoji_manager.dart';
import '../../../widgets/wk_colors.dart';

class ChatEmojiPanel extends StatefulWidget {
  const ChatEmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspaceTap,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspaceTap;

  @override
  State<ChatEmojiPanel> createState() => _ChatEmojiPanelState();
}

class _ChatEmojiPanelState extends State<ChatEmojiPanel> {
  late final Future<void> _initializeFuture = EmojiManager.instance.initialize();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        final tabs = _buildTabs();
        final activeEntries = tabs[_selectedIndex].$2;
        return Container(
          key: const ValueKey<String>('chat-emoji-panel'),
          width: double.infinity,
          color: WKColors.homeBg,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (var index = 0; index < tabs.length; index++) ...[
                    TextButton(
                      key: ValueKey<String>('chat-emoji-tab-${tabs[index].$1}'),
                      onPressed: () => setState(() => _selectedIndex = index),
                      child: Text(tabs[index].$1),
                    ),
                    if (index != tabs.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: activeEntries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final entry = activeEntries[index];
                    return InkWell(
                      key: ValueKey<String>('chat-emoji-item-${entry.id}'),
                      onTap: () {
                        EmojiManager.instance.addToRecent(entry.tag);
                        setState(() {});
                        widget.onEmojiSelected(entry.tag);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: WKColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(entry.assetPath, filterQuality: FilterQuality.high),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey<String>('chat-emoji-delete'),
                  onPressed: widget.onBackspaceTap,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<(String, List<AndroidEmojiEntry>)> _buildTabs() {
    final recent = EmojiManager.instance.recentEmojis
        .map(androidEmojiCatalog.lookupByTag)
        .whereType<AndroidEmojiEntry>()
        .toList(growable: false);

    return <(String, List<AndroidEmojiEntry>)>[
      ('recent', recent),
      for (final groupId in androidEmojiCatalog.groupIds)
        (groupId, androidEmojiCatalog.entriesForGroup(groupId)),
    ].where((tab) => tab.$1 != 'recent' || tab.$2.isNotEmpty).toList(growable: false);
  }
}
```

- [ ] **Step 4: Replace `_buildEmojiPanel` in the shell with the new widget**

```dart
Widget _buildEmojiPanel(
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) {
  return ChatEmojiPanel(
    onEmojiSelected: (tag) => _insertEmoji(
      tag,
      composerController,
      mentionsController,
    ),
    onBackspaceTap: () => _deletePreviousComposerCharacter(
      composerController,
      mentionsController,
    ),
  );
}
```

- [ ] **Step 5: Run the parity test again**

Run: `flutter test test/modules/chat/chat_page_android_parity_test.dart --plain-name "emoji panel exposes Android asset cells and inserts the matched tag"`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/modules/chat/widgets/chat_emoji_panel.dart lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: add android emoji picker panel"
```

## Task 6: Render Android Emoji Images Inline in Message Bubbles

**Files:**

- Create: `lib/widgets/wk_emoji_text.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Test: `test/widgets/wk_emoji_text_test.dart`
- Test: `test/modules/chat/message_bubble_experience_test.dart`

- [ ] **Step 1: Add a failing widget test for inline Android emoji rendering**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_emoji_text.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

void main() {
  testWidgets('WKEmojiText replaces Android emoji tags with inline asset images', (
    tester,
  ) async {
    final entry = androidEmojiCatalog.lookupById('0_0')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WKEmojiText(
            text: 'hello ${entry.tag} world',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );

    expect(find.byType(RichText), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == entry.assetPath,
      ),
      findsOneWidget,
    );
  });
}
```

```dart
testWidgets('text bubble renders Android emoji assets inline without losing the status badge', (
  tester,
) async {
  final entry = androidEmojiCatalog.lookupById('0_0')!;
  final message = WKMsg()
    ..fromUID = 'u_me'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('hello ${entry.tag}')
    ..status = WKSendMsgResult.sendSuccess
    ..wkMsgExtra = (WKMsgExtra()..readedCount = 1);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          model: ChatMessageMapper().map(message, currentUid: 'u_me'),
        ),
      ),
    ),
  );

  expect(
    find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == entry.assetPath,
    ),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('message-status-badge')),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run the emoji text tests and verify they fail**

Run: `flutter test test/widgets/wk_emoji_text_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: FAIL because `WKEmojiText` does not exist and `MessageBubble` still uses `SelectableText` directly.

- [ ] **Step 3: Implement `WKEmojiText` with longest-match tokenization against the Android catalog**

```dart
import 'package:flutter/material.dart';

import '../wukong_base/emoji/android_emoji_catalog.dart';

class WKEmojiText extends StatelessWidget {
  const WKEmojiText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  static bool containsAndroidEmoji(String text) {
    for (var index = 0; index < text.length; index++) {
      if (androidEmojiCatalog.longestMatchAt(text, index) != null) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: _buildSpans(),
      ),
    );
  }

  List<InlineSpan> _buildSpans() {
    final spans = <InlineSpan>[];
    final fontSize = style.fontSize ?? 16;
    var index = 0;

    while (index < text.length) {
      final match = androidEmojiCatalog.longestMatchAt(text, index);
      if (match != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image.asset(
              match.assetPath,
              width: fontSize * 1.2,
              height: fontSize * 1.2,
              filterQuality: FilterQuality.high,
            ),
          ),
        );
        index += match.tag.length;
        continue;
      }

      final nextPlainStart = _findNextEmojiStart(index);
      spans.add(TextSpan(text: text.substring(index, nextPlainStart), style: style));
      index = nextPlainStart;
    }

    return spans;
  }

  int _findNextEmojiStart(int start) {
    for (var index = start + 1; index <= text.length; index++) {
      if (index == text.length || androidEmojiCatalog.longestMatchAt(text, index) != null) {
        return index;
      }
    }
    return text.length;
  }
}
```

- [ ] **Step 4: Swap `MessageBubble._buildTextContent` to use `WKEmojiText` when the message contains Android emoji tags**

```dart
Widget _buildTextContent(String text) {
  final textStyle = TextStyle(
    color: isSelf ? WKColors.sendText : WKColors.receiveText,
    fontSize: 16.5,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
  final previewUrl = LinkPreviewService.extractFirstUrl(text);
  final textWidget = WKEmojiText.containsAndroidEmoji(text)
      ? SelectionArea(
          child: WKEmojiText(
            text: text,
            style: textStyle,
          ),
        )
      : SelectableText(text, style: textStyle);

  if (previewUrl == null) {
    return textWidget;
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      textWidget,
      const SizedBox(height: 8),
      _LinkPreviewCard(url: previewUrl, isSelf: isSelf),
    ],
  );
}
```

- [ ] **Step 5: Run the emoji text tests again**

Run: `flutter test test/widgets/wk_emoji_text_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/wk_emoji_text.dart lib/widgets/message_bubble.dart test/widgets/wk_emoji_text_test.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: render android emoji images in message bubbles"
```

## Task 7: Add the Android `text_to_emoji_sticker` Hook and Finish Rich-Text/Flame Parity

**Files:**

- Create: `lib/modules/chat/chat_text_sticker_conversion.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/wukong_base/endpoint/menu/endpoint_menu.dart`
- Modify: `test/modules/chat/chat_media_action_service_test.dart`
- Create: `test/modules/chat/chat_text_sticker_conversion_test.dart`
- Modify: `test/modules/chat/chat_page_android_parity_test.dart`

- [ ] **Step 1: Add failing unit and widget tests for the conversion hook and flame/rich-text behavior**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_text_sticker_conversion.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/send_text_menu.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';

void main() {
  test('text sticker conversion only fires for exact Android emoji tags without reply', () {
    final manager = EndpointManager.getInstance()..clear();
    SendTextMenu? captured;
    manager.setMethod(
      ChatMenuIDs.textToEmojiSticker,
      MenuCategories.chatAction,
      0,
      SimpleFunctionHandler(([param]) {
        captured = param as SendTextMenu;
        return true;
      }),
    );

    final converter = ChatTextStickerConversion(endpointManager: manager);
    final handled = converter.tryHandle(
      text: androidEmojiCatalog.lookupById('0_0')!.tag,
      hasReply: false,
      conversationContext: const <String, Object?>{'channelId': 'u_demo'},
    );

    expect(handled, isTrue);
    expect(captured?.text, androidEmojiCatalog.lookupById('0_0')!.tag);
  });
}
```

```dart
testWidgets('flame chats hide the rich-text button like Android', (tester) async {
  final channel = WKChannel('u_flame_rich_text', WKChannelType.personal)
    ..channelName = 'Flame Rich Text'
    ..flame = 1;
  WKIM.shared.channelManager.addOrUpdateChannel(channel);

  await pumpChatPage(
    tester,
    channelId: 'u_flame_rich_text',
    channelType: WKChannelType.personal,
    channelName: 'Flame Rich Text',
  );
  await tester.pumpAndSettle();

  expect(
    find.byKey(const ValueKey<String>('chat-compose-rich-text-button')),
    findsNothing,
  );
});
```

```dart
test('builds rich text content from the composed selection', () {
  final factory = ChatMediaContentFactory();

  final content = factory.buildRichTextContent(
    const ChatRichTextSelection(title: 'Plan', body: 'Ship the Android parity UI'),
  );

  expect(content, isA<WKRichTextContent>());
  expect(content.title, 'Plan');
  expect(content.body, 'Ship the Android parity UI');
});
```

- [ ] **Step 2: Run the tests and verify they fail**

Run: `flutter test test/modules/chat/chat_text_sticker_conversion_test.dart test/modules/chat/chat_media_action_service_test.dart test/modules/chat/chat_page_android_parity_test.dart`

Expected: FAIL because there is no `ChatTextStickerConversion`, no `ChatMenuIDs.textToEmojiSticker`, and the flame-mode rich-text behavior is not asserted in code yet.

- [ ] **Step 3: Add the endpoint ID and the conversion helper**

```dart
class ChatMenuIDs {
  static const String sendText = 'send_text';
  static const String sendImage = 'send_image';
  static const String sendVoice = 'send_voice';
  static const String sendVideo = 'send_video';
  static const String sendFile = 'send_file';
  static const String sendLocation = 'send_location';
  static const String sendCard = 'send_card';
  static const String textToEmojiSticker = 'text_to_emoji_sticker';
  // ...
}
```

```dart
import '../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/entity/send_text_menu.dart';
import '../../wukong_base/endpoint/menu/endpoint_menu.dart';

class ChatTextStickerConversion {
  ChatTextStickerConversion({EndpointManager? endpointManager})
      : _endpointManager = endpointManager ?? EndpointManager.getInstance();

  final EndpointManager _endpointManager;

  bool tryHandle({
    required String text,
    required bool hasReply,
    required dynamic conversationContext,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || hasReply) {
      return false;
    }
    if (androidEmojiCatalog.lookupByTag(trimmed) == null) {
      return false;
    }
    return _endpointManager.invoke(
          ChatMenuIDs.textToEmojiSticker,
          SendTextMenu(
            text: trimmed,
            conversationContext: conversationContext,
          ),
        ) ==
        true;
  }
}
```

- [ ] **Step 4: Call the conversion helper before sending plain text and keep the rich-text button hidden in flame mode**

```dart
late final ChatTextStickerConversion _textStickerConversion =
    ChatTextStickerConversion();

Future<void> _openRichTextComposer(
  ChatComposerController composerController,
) async {
  await _executeChatAction(ChatActionId.composeRichText, composerController);
}

Future<void> _handleSendPressed(
  ChatComposerController composerController,
  ChatMentionsController mentionsController,
) async {
  final payload = composerController.buildSubmissionPayload();
  if (payload.text.isEmpty) {
    return;
  }

  final handledByStickerHook = _textStickerConversion.tryHandle(
    text: payload.text,
    hasReply: payload.replyMessageId?.trim().isNotEmpty == true,
    conversationContext: <String, Object?>{
      'channelId': widget.session.channelId,
      'channelType': widget.session.channelType,
    },
  );
  if (handledByStickerHook) {
    composerController.markSubmitSucceeded();
    mentionsController.clear();
    ref
        .read(chatSceneControllerProvider(widget.session).notifier)
        .restoreNormal();
    return;
  }

  final content = WKTextContent(payload.text);
  final mentionedUids = _normalizedMentionedUids(
    ref.read(chatMentionsControllerProvider(widget.session)).mentionedUids,
  );
  if (mentionedUids.isNotEmpty) {
    content.mentionInfo = WKMentionInfo()..uids = mentionedUids;
  }

  // keep the existing edit/send logic below unchanged
}
```

- [ ] **Step 5: Keep the robot GIF path covered while verifying the relocated rich-text entry**

```dart
class _FakeChatMediaActionService implements ChatMediaActionService {
  const _FakeChatMediaActionService({required this.richTextContent});

  final WKRichTextContent richTextContent;

  @override
  Future<WKCardContent?> pickCard(BuildContext context) async => null;

  @override
  Future<WKFileContent?> pickFile(BuildContext context) async => null;

  @override
  Future<WKImageContent?> pickImage(BuildContext context) async => null;

  @override
  Future<WKLocationContent?> pickLocation(BuildContext context) async => null;

  @override
  Future<WKRichTextContent?> pickRichText(BuildContext context) async {
    return richTextContent;
  }
}

testWidgets('input-row rich text button sends WKRichTextContent', (tester) async {
  final gateway = _RecordingChatSceneGateway();
  final media = _FakeChatMediaActionService(
    richTextContent: WKRichTextContent(
      title: 'Plan',
      body: 'Android parity body',
    ),
  );

  await pumpChatPage(
    tester,
    channelId: 'u_rich_text_button',
    channelType: WKChannelType.personal,
    channelName: 'Rich Text Button',
    overrides: <Override>[
      chatSceneGatewayProvider.overrideWith((ref, _) => gateway),
      chatMediaActionServiceProvider.overrideWithValue(media),
    ],
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const ValueKey<String>('chat-compose-rich-text-button')),
  );
  await tester.pumpAndSettle();

  expect(gateway.sentContents.single, isA<WKRichTextContent>());
});
```

- [ ] **Step 6: Run the conversion, media, and parity tests again**

Run: `flutter test test/modules/chat/chat_text_sticker_conversion_test.dart test/modules/chat/chat_media_action_service_test.dart test/modules/chat/chat_page_android_parity_test.dart`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/modules/chat/chat_text_sticker_conversion.dart lib/modules/chat/chat_page_shell.dart lib/wukong_base/endpoint/menu/endpoint_menu.dart test/modules/chat/chat_text_sticker_conversion_test.dart test/modules/chat/chat_media_action_service_test.dart test/modules/chat/chat_page_android_parity_test.dart
git commit -m "feat: add android text sticker send hook"
```

## Task 8: Final Verification Sweep and Manual Parity Checklist

**Files:**

- Modify: the files from Tasks 1 through 7 only if a verification run exposes a regression
- Test: `test/wukong_base/emoji/android_emoji_catalog_test.dart`
- Test: `test/wukong_base/emoji/emoji_manager_test.dart`
- Test: `test/widgets/wk_emoji_text_test.dart`
- Test: `test/modules/chat/chat_toolbar_slot_assembly_test.dart`
- Test: `test/modules/chat/chat_page_android_parity_test.dart`
- Test: `test/modules/chat/message_bubble_experience_test.dart`
- Test: `test/modules/chat/chat_media_action_service_test.dart`
- Test: `test/modules/chat/chat_composer_controller_test.dart`
- Test: `test/modules/chat/chat_mentions_controller_test.dart`
- Test: `test/modules/chat/chat_text_sticker_conversion_test.dart`

- [ ] **Step 1: Regenerate the catalog one last time to ensure checked-in generated files match the Android source**

Run: `dart run tool/generate_android_emoji_catalog.dart ..\\TangSengDaoDao\\TangSengDaoDaoAndroid-master\\wkbase\\src\\main\\assets\\emoji`

Expected: generator exits cleanly and does not produce a diff if nothing changed.

- [ ] **Step 2: Run the targeted regression suite**

Run: `flutter test test/wukong_base/emoji/android_emoji_catalog_test.dart test/wukong_base/emoji/emoji_manager_test.dart test/widgets/wk_emoji_text_test.dart test/modules/chat/chat_toolbar_slot_assembly_test.dart test/modules/chat/chat_page_android_parity_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/chat_media_action_service_test.dart test/modules/chat/chat_composer_controller_test.dart test/modules/chat/chat_mentions_controller_test.dart test/modules/chat/chat_text_sticker_conversion_test.dart`

Expected: PASS.

- [ ] **Step 3: Execute the manual Android parity smoke checklist**

Run manually:

1. Personal chat: input row shows `TextField + rich text + send`, toolbar row shows `voice / emoji / album / more`.
2. Group chat: toolbar row adds the Android `@` button between `album` and `more`.
3. Flame chat: rich-text button is hidden while the flame affordance stays available.
4. Emoji panel: recent tab appears after one insertion, tabs `0`, `1`, and `2` show Android asset cells, and backspace deletes the previous grapheme.
5. Message bubbles: sent/received text messages render Android inline emoji images from historical content as well as new outgoing text.
6. Robot GIF flow: entering `@gif cat` still sends `WKGifContent`.
7. Text-to-sticker hook: exact emoji-only text can be intercepted by a registered `text_to_emoji_sticker` endpoint, but reply-mode text still falls back to `WKTextContent`.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml tool/generate_android_emoji_catalog.dart assets/emoji/android lib/modules/chat lib/widgets lib/wukong_base/emoji lib/wukong_base/endpoint/menu/endpoint_menu.dart test/wukong_base/emoji test/widgets/wk_emoji_text_test.dart test/modules/chat
git commit -m "feat: complete android chat page parity"
```
