# Web IM B UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved Web B UI for WuKong IM: warm social visual language, desktop Web workbench navigation, polished login/conversation/chat/call/contact/user surfaces, without changing IM protocol or non-Web navigation behavior.

**Architecture:** Add small Web-specific presentation primitives and use them from existing Flutter widgets. Keep business logic in current providers/controllers; only add display parameters and a Web conversation workspace wrapper where desktop Web needs list + chat side by side. Preserve current mobile Web and native platform behavior by gating desktop layout through breakpoints and Web platform checks.

**Tech Stack:** Flutter, Riverpod, existing WuKong IM SDK models/providers, Flutter widget tests, Flutter Web release build.

---

## Execution Notes

- The current workspace is dirty. Do not run `git add` or `git commit` in this shared workspace unless the user explicitly asks. Commit commands in this plan are checkpoint guidance for an isolated branch or worktree.
- Use `apply_patch` for manual edits.
- Keep Chinese strings from existing copy constants when possible. When adding new Chinese text, use Unicode escapes only in Dart files that already show encoding damage in PowerShell output.
- Keep all IM behavior untouched: message send/revoke/reaction, avatar identity resolution, call signaling, cache/pagination, password guard, and search anchors.

## File Structure

- Create `lib/widgets/wk_web_ui_tokens.dart`: Web B palette, breakpoints, panel helpers, page frame helpers.
- Modify `lib/widgets/wk_colors.dart`: add stable Web B aliases while preserving legacy aliases.
- Modify `lib/widgets/wk_theme.dart`: align app-level Material colors with the warmer palette.
- Modify `lib/widgets/wk_tab_shell.dart`: add desktop Web rail layout with bottom-tab fallback.
- Modify `lib/modules/home/home_shell_page.dart`: use the Web conversation workspace for the conversation tab and keep connection banner behavior.
- Create `lib/modules/conversation/web_conversation_workspace.dart`: desktop Web list + chat workbench shell.
- Modify `lib/modules/conversation/conversation_list_page.dart`: allow embedded list mode, selected conversation, and custom open handler.
- Modify `lib/widgets/wk_conversation_item.dart`: add Web visual style and selected state.
- Modify `lib/modules/auth/presentation/widgets/auth_experience_tokens.dart`: replace dark login palette with approved warm B tokens.
- Modify `lib/modules/auth/presentation/widgets/auth_stage_background.dart`: remove decorative glow bubbles and use a quiet app background.
- Modify `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart`: tighten radius and desktop split proportions for the warm login panel.
- Modify `lib/modules/chat/chat_page_shell.dart`: use warm Web header/background/composer flags while preserving chat logic.
- Modify `lib/modules/chat/widgets/chat_composer.dart`: add warm Web composer shell.
- Modify `lib/widgets/message_bubble.dart`: add warm Web message bubble style without changing content mapping.
- Modify `lib/modules/chat/widgets/chat_message_action_sheet.dart` and `lib/modules/chat/widgets/chat_reaction_picker_popup.dart`: warm popup surfaces.
- Modify `lib/modules/video_call/call_notification.dart` and `lib/modules/video_call/widgets/chat_calling_participants_bar.dart`: warm call overlays and in-chat call state.
- Modify `lib/modules/contacts/contacts_page.dart` and `lib/modules/user/user_page.dart`: Web panel framing and warm list styling.
- Add/update widget tests under `test/widgets/`, `test/modules/home/`, `test/modules/conversation/`, `test/modules/auth/`, `test/modules/chat/`, `test/modules/video_call/`, `test/modules/contacts/`, and `test/modules/user/`.

---

### Task 1: Web B Tokens And Shared Frame

**Files:**
- Create: `lib/widgets/wk_web_ui_tokens.dart`
- Modify: `lib/widgets/wk_colors.dart`
- Modify: `lib/widgets/wk_theme.dart`
- Test: `test/widgets/wk_web_ui_tokens_test.dart`

- [ ] **Step 1: Write failing token tests**

Create `test/widgets/wk_web_ui_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  test('Web B palette exposes approved warm social colors', () {
    expect(WKWebColors.pageWarm, const Color(0xFFFFFAF5));
    expect(WKWebColors.action, const Color(0xFFF97316));
    expect(WKWebColors.online, const Color(0xFF0D9488));
    expect(WKWebColors.textPrimary, const Color(0xFF172033));
    expect(WKColors.webPageWarm, WKWebColors.pageWarm);
  });

  test('Web breakpoints match the approved responsive contract', () {
    expect(WKWebBreakpoints.mobileMax, 719);
    expect(WKWebBreakpoints.tabletMin, 720);
    expect(WKWebBreakpoints.desktopMin, 1024);
    expect(WKWebBreakpoints.wideMin, 1280);
    expect(WKWebBreakpoints.useDesktopWorkbench(1023), isFalse);
    expect(WKWebBreakpoints.useDesktopWorkbench(1024), isTrue);
    expect(WKWebBreakpoints.showRightContext(1279), isFalse);
    expect(WKWebBreakpoints.showRightContext(1280), isTrue);
  });

  testWidgets('WKWebPanel paints warm border and stable radius', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WKWebPanel(
            key: ValueKey<String>('sample-web-panel'),
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('sample-web-panel')),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, WKWebColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(WKWebRadius.panel));
    expect(decoration.border, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/widgets/wk_web_ui_tokens_test.dart
```

Expected: fails because `wk_web_ui_tokens.dart`, `WKColors.webPageWarm`, and related symbols do not exist.

- [ ] **Step 3: Add shared Web token file**

Create `lib/widgets/wk_web_ui_tokens.dart`:

```dart
import 'package:flutter/material.dart';

import 'wk_design_tokens.dart';

class WKWebBreakpoints {
  WKWebBreakpoints._();

  static const double mobileMax = 719;
  static const double tabletMin = 720;
  static const double desktopMin = 1024;
  static const double wideMin = 1280;

  static bool useDesktopWorkbench(double width) => width >= desktopMin;
  static bool showRightContext(double width) => width >= wideMin;
}

class WKWebColors {
  WKWebColors._();

  static const Color pageWarm = Color(0xFFFFFAF5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFFF7ED);
  static const Color borderWarm = Color(0xFFFED7AA);
  static const Color action = Color(0xFFF97316);
  static const Color actionHover = Color(0xFFEA580C);
  static const Color actionSoft = Color(0xFFFFEDD5);
  static const Color online = Color(0xFF0D9488);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color overlayScrim = Color(0x33000000);
  static const Color shadow = Color(0x17172433);
}

class WKWebRadius {
  WKWebRadius._();

  static const double control = WKRadius.sm;
  static const double panel = 10;
  static const double avatar = 12;
}

class WKWebSizes {
  WKWebSizes._();

  static const double railWidth = 64;
  static const double conversationListWidth = 336;
  static const double conversationListMinWidth = 300;
  static const double chatRightContextWidth = 280;
  static const double conversationRowHeight = 76;
  static const double composerMinHeight = 72;
}

class WKWebPanel extends StatelessWidget {
  const WKWebPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color = WKWebColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(WKWebRadius.panel),
        border: Border.all(color: WKWebColors.borderWarm),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: WKWebColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Add Web aliases to existing color tokens**

In `lib/widgets/wk_colors.dart`, add these constants after the current neutral colors:

```dart
  // Web B warm social theme
  static const Color webPageWarm = Color(0xFFFFFAF5);
  static const Color webSurfaceSoft = Color(0xFFFFF7ED);
  static const Color webBorderWarm = Color(0xFFFED7AA);
  static const Color webAction = Color(0xFFF97316);
  static const Color webActionSoft = Color(0xFFFFEDD5);
  static const Color webOnline = Color(0xFF0D9488);
  static const Color webTextPrimary = Color(0xFF172033);
  static const Color webTextSecondary = Color(0xFF64748B);
```

Do not change legacy aliases yet; later tasks opt into Web colors explicitly.

- [ ] **Step 5: Warm the global theme without breaking legacy aliases**

In `lib/widgets/wk_theme.dart`, import the new token file:

```dart
import 'wk_web_ui_tokens.dart';
```

Change `colorScheme.primary`, `primaryColor`, button foregrounds, progress indicator, and text button foreground from `WKColors.brand500` to `WKWebColors.action`. Keep existing background aliases in place.

Use this exact pattern for the color scheme primary fields:

```dart
      primary: WKWebColors.action,
      onPrimary: WKColors.white,
      primaryContainer: WKWebColors.actionSoft,
      onPrimaryContainer: WKWebColors.textPrimary,
```

- [ ] **Step 6: Run token tests**

Run:

```powershell
flutter test test/widgets/wk_web_ui_tokens_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Checkpoint**

In an isolated branch only:

```powershell
git add lib/widgets/wk_web_ui_tokens.dart lib/widgets/wk_colors.dart lib/widgets/wk_theme.dart test/widgets/wk_web_ui_tokens_test.dart
git commit -m "feat(web): add warm IM design tokens"
```

---

### Task 2: Desktop Web Rail Shell

**Files:**
- Modify: `lib/widgets/wk_tab_shell.dart`
- Modify: `lib/modules/home/home_shell_page.dart`
- Test: `test/widgets/wk_tab_shell_web_test.dart`
- Test: `test/modules/home/home_shell_page_test.dart`

- [ ] **Step 1: Write failing rail tests**

Create `test/widgets/wk_tab_shell_web_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_tab_shell.dart';

void main() {
  final items = <WKTabShellItemData>[
    const WKTabShellItemData(label: '聊天', normalIcon: '', selectedIcon: ''),
    const WKTabShellItemData(label: '通讯录', normalIcon: '', selectedIcon: ''),
    const WKTabShellItemData(label: '我的', normalIcon: '', selectedIcon: ''),
  ];

  testWidgets('desktop Web rail replaces bottom tabs when forced', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 1,
            items: items,
            pages: const <Widget>[
              Text('chat page'),
              Text('contacts page'),
              Text('mine page'),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('wk_tab_shell_bottom_bar')), findsNothing);
    expect(find.text('contacts page'), findsOneWidget);
    expect(find.byTooltip('通讯录'), findsOneWidget);
  });

  testWidgets('bottom tabs remain available when desktop rail is not used', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WKTabShell(
          currentIndex: 0,
          items: items,
          pages: const <Widget>[
            Text('chat page'),
            Text('contacts page'),
            Text('mine page'),
          ],
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('wk_tab_shell_bottom_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/widgets/wk_tab_shell_web_test.dart
```

Expected: fails because `forceDesktopRailForTesting` and Web rail keys do not exist.

- [ ] **Step 3: Add responsive rail support to `WKTabShell`**

In `lib/widgets/wk_tab_shell.dart`, import:

```dart
import 'package:flutter/foundation.dart';
import 'wk_web_ui_tokens.dart';
```

Add this constructor field:

```dart
  final bool forceDesktopRailForTesting;
```

Default it in the constructor:

```dart
    this.forceDesktopRailForTesting = false,
```

Wrap the current `Scaffold` body in a `LayoutBuilder`. Use this decision:

```dart
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopRail =
            forceDesktopRailForTesting ||
            (kIsWeb && WKWebBreakpoints.useDesktopWorkbench(constraints.maxWidth));
        if (useDesktopRail) {
          return _buildDesktopRailShell(context);
        }
        return _buildBottomTabShell(context);
      },
    );
```

Move the current Scaffold into `_buildBottomTabShell` and add this key to the bottom bar `Container`:

```dart
        key: const ValueKey<String>('wk_tab_shell_bottom_bar'),
```

Add `_buildDesktopRailShell`:

```dart
  Widget _buildDesktopRailShell(BuildContext context) {
    return Scaffold(
      key: key ?? const ValueKey<String>('wk_tab_shell'),
      backgroundColor: WKWebColors.pageWarm,
      body: Row(
        children: [
          Container(
            key: const ValueKey<String>('wk_tab_shell_web_rail'),
            width: WKWebSizes.railWidth,
            color: WKWebColors.surface,
            padding: const EdgeInsets.symmetric(vertical: WKSpace.sm),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: WKWebColors.action,
                    borderRadius: BorderRadius.circular(WKWebRadius.control),
                  ),
                  child: const Text(
                    'WK',
                    style: TextStyle(
                      fontFamily: WKFontFamily.title,
                      color: WKColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: WKSpace.lg),
                for (var index = 0; index < items.length; index++)
                  _WKWebRailItem(
                    data: items[index],
                    selected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: WKWebColors.borderWarm),
          Expanded(
            key: const ValueKey<String>('wk_tab_shell_web_page_host'),
            child: IndexedStack(index: currentIndex, children: pages),
          ),
        ],
      ),
    );
  }
```

Add `_WKWebRailItem` below `_WKTabBarItem`. Use `Tooltip`, `Semantics`, `InkWell`, a stable `48 x 48` hit target, `WKReferenceAssets.image` when icon assets are available, and `Icons.chat_bubble_outline_rounded` as fallback when asset paths are empty in tests.

- [ ] **Step 4: Keep connection banner on top of the new shell**

In `lib/modules/home/home_shell_page.dart`, leave the existing `Stack(children: [shell, Positioned(...)])` logic intact. Update the banner style only if it overlaps rail:

```dart
left: 0,
right: 0,
```

Keep the existing key `home-im-connection-banner`.

- [ ] **Step 5: Run rail and home shell tests**

Run:

```powershell
flutter test test/widgets/wk_tab_shell_web_test.dart test/modules/home/home_shell_page_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Checkpoint**

In an isolated branch only:

```powershell
git add lib/widgets/wk_tab_shell.dart lib/modules/home/home_shell_page.dart test/widgets/wk_tab_shell_web_test.dart test/modules/home/home_shell_page_test.dart
git commit -m "feat(web): add desktop navigation rail"
```

---

### Task 3: Web Conversation Workspace

**Files:**
- Create: `lib/modules/conversation/web_conversation_workspace.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Modify: `lib/modules/home/home_shell_page.dart`
- Test: `test/modules/conversation/web_conversation_workspace_test.dart`
- Test: `test/modules/conversation/conversation_list_page_test.dart`

- [ ] **Step 1: Write workspace shell tests**

Create `test/modules/conversation/web_conversation_workspace_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/web_conversation_workspace.dart';

void main() {
  testWidgets('desktop workspace shows list and empty chat pane side by side', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 720,
          child: WebConversationWorkspaceScaffold(
            listPane: const Text('list pane'),
            chatPane: const Text('select a conversation'),
            showRightContext: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('web-conversation-workspace')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('web-conversation-list-pane')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('web-conversation-chat-pane')), findsOneWidget);
    expect(find.text('list pane'), findsOneWidget);
    expect(find.text('select a conversation'), findsOneWidget);
  });

  testWidgets('wide workspace can display the right context pane', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebConversationWorkspaceScaffold(
          listPane: Text('list'),
          chatPane: Text('chat'),
          rightContextPane: Text('context'),
          showRightContext: true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('web-conversation-right-pane')), findsOneWidget);
    expect(find.text('context'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected: fails because `web_conversation_workspace.dart` does not exist.

- [ ] **Step 3: Add the workspace scaffold**

Create `lib/modules/conversation/web_conversation_workspace.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';

import '../../data/models/chat_session.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../chat/chat_page.dart';
import 'conversation_list_page.dart';

class WebConversationWorkspaceSelection {
  const WebConversationWorkspaceSelection({
    required this.session,
    this.channelName,
    this.channelCategory,
    this.initialVipLevel = 0,
  });

  final ChatSession session;
  final String? channelName;
  final String? channelCategory;
  final int initialVipLevel;

  String get key => '${session.channelId}:${session.channelType}';
}

class WebConversationWorkspace extends StatefulWidget {
  const WebConversationWorkspace({super.key});

  @override
  State<WebConversationWorkspace> createState() => _WebConversationWorkspaceState();
}

class _WebConversationWorkspaceState extends State<WebConversationWorkspace> {
  WebConversationWorkspaceSelection? _selection;

  void _openConversation(
    WKUIConversationMsg conversation,
    ConversationPreferredInfo? preferredInfo,
    WKConversationItemData displayData,
  ) {
    final displayTitle = displayData.title.trim();
    setState(() {
      _selection = WebConversationWorkspaceSelection(
        session: ChatSession(
          channelId: conversation.channelID,
          channelType: conversation.channelType,
        ),
        channelName: preferredInfo?.title ??
            (displayTitle.isEmpty || displayTitle == conversation.channelID
                ? null
                : displayTitle),
        channelCategory: preferredInfo?.category ?? displayData.category,
        initialVipLevel: displayData.vipLevel,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!WKWebBreakpoints.useDesktopWorkbench(constraints.maxWidth)) {
          return const ConversationListPage();
        }
        final selection = _selection;
        return WebConversationWorkspaceScaffold(
          showRightContext: WKWebBreakpoints.showRightContext(constraints.maxWidth),
          listPane: ConversationListPage(
            embedded: true,
            selectedConversationKey: selection?.key,
            onOpenConversation: _openConversation,
          ),
          chatPane: selection == null
              ? const _EmptyConversationPane()
              : ChatPage(
                  key: ValueKey<String>('web-chat-${selection.key}'),
                  channelId: selection.session.channelId,
                  channelType: selection.session.channelType,
                  channelName: selection.channelName,
                  channelCategory: selection.channelCategory,
                  initialVipLevel: selection.initialVipLevel,
                ),
          rightContextPane: const _ConversationContextPanel(),
        );
      },
    );
  }
}

class WebConversationWorkspaceScaffold extends StatelessWidget {
  const WebConversationWorkspaceScaffold({
    super.key,
    required this.listPane,
    required this.chatPane,
    this.rightContextPane,
    this.showRightContext = false,
  });

  final Widget listPane;
  final Widget chatPane;
  final Widget? rightContextPane;
  final bool showRightContext;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('web-conversation-workspace'),
      color: WKWebColors.pageWarm,
      child: Row(
        children: [
          SizedBox(
            key: const ValueKey<String>('web-conversation-list-pane'),
            width: WKWebSizes.conversationListWidth,
            child: listPane,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: WKWebColors.borderWarm),
          Expanded(
            key: const ValueKey<String>('web-conversation-chat-pane'),
            child: chatPane,
          ),
          if (showRightContext && rightContextPane != null) ...[
            const VerticalDivider(width: 1, thickness: 1, color: WKWebColors.borderWarm),
            SizedBox(
              key: const ValueKey<String>('web-conversation-right-pane'),
              width: WKWebSizes.chatRightContextWidth,
              child: rightContextPane,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyConversationPane extends StatelessWidget {
  const _EmptyConversationPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WKWebPanel(
        padding: const EdgeInsets.all(WKSpace.xl),
        child: Text(
          '选择一个会话开始聊天',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: WKWebColors.textSecondary,
              ),
        ),
      ),
    );
  }
}

class _ConversationContextPanel extends StatelessWidget {
  const _ConversationContextPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKWebColors.surface,
      padding: const EdgeInsets.all(WKSpace.md),
      child: Text(
        '会话信息',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: WKWebColors.textPrimary,
            ),
      ),
    );
  }
}
```

- [ ] **Step 4: Make `ConversationListPage` embeddable**

In `lib/modules/conversation/conversation_list_page.dart`, add a public typedef near `ConversationListPage`:

```dart
typedef ConversationOpenHandler =
    void Function(
      WKUIConversationMsg conversation,
      ConversationPreferredInfo? preferredInfo,
      WKConversationItemData displayData,
    );
```

Change the constructor:

```dart
  const ConversationListPage({
    super.key,
    this.embedded = false,
    this.selectedConversationKey,
    this.onOpenConversation,
  });

  final bool embedded;
  final String? selectedConversationKey;
  final ConversationOpenHandler? onOpenConversation;
```

Add a public key helper:

```dart
String conversationKeyFor(WKUIConversationMsg conversation) {
  return '${conversation.channelID}:${conversation.channelType}';
}
```

Keep the private `_conversationKey` by delegating to this helper if existing tests depend on private behavior:

```dart
String _conversationKey(WKUIConversationMsg conversation) {
  return conversationKeyFor(conversation);
}
```

In the `build` method, use `widget.embedded` for background and chrome:

```dart
    final content = Column(
      children: [
        _ConversationListHeader(...),
        Expanded(...),
      ],
    );

    if (widget.embedded) {
      return Material(
        key: const ValueKey<String>('conversation-list-embedded'),
        color: WKWebColors.surface,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: WKColors.homeBg,
      body: content,
    );
```

In the tile `onTap`, before pushing a route, add:

```dart
                            if (widget.onOpenConversation != null) {
                              widget.onOpenConversation!(
                                conversation,
                                preferredInfo,
                                displayData,
                              );
                              return;
                            }
```

Pass the selected key and Web visual style into `_ConversationTile`:

```dart
                          webSelected:
                              widget.selectedConversationKey == conversationKey,
                          webStyle: widget.embedded,
```

Add these fields to `_ConversationTile` and pass them into `WKConversationItem`.

- [ ] **Step 5: Use workspace from the home shell**

In `lib/modules/home/home_shell_page.dart`, import:

```dart
import '../conversation/web_conversation_workspace.dart';
```

Change `_defaultPages` first entry:

```dart
  static const List<Widget> _defaultPages = <Widget>[
    WebConversationWorkspace(),
    ContactsPage(),
    UserPage(),
  ];
```

The workspace falls back to `ConversationListPage` below desktop width.

- [ ] **Step 6: Run workspace tests**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart test/modules/home/home_shell_page_test.dart
```

Expected: tests pass and existing home shell tests still find `WKTabShell`.

- [ ] **Step 7: Checkpoint**

In an isolated branch only:

```powershell
git add lib/modules/conversation/web_conversation_workspace.dart lib/modules/conversation/conversation_list_page.dart lib/modules/home/home_shell_page.dart test/modules/conversation/web_conversation_workspace_test.dart test/modules/home/home_shell_page_test.dart
git commit -m "feat(web): add conversation workspace"
```

---

### Task 4: Warm Conversation List And Tiles

**Files:**
- Modify: `lib/widgets/wk_conversation_item.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Test: `test/widgets/wk_conversation_item_parity_test.dart`

- [ ] **Step 1: Add failing tile style tests**

Append to `test/widgets/wk_conversation_item_parity_test.dart`:

```dart
  testWidgets('conversation item supports warm Web selected state', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const WKConversationItem(
          webStyle: true,
          selected: true,
          data: WKConversationItemData(
            channelId: 'u_web',
            channelType: 1,
            title: 'Web Alice',
            lastMsgContent: 'hello from web',
            unreadCount: 3,
          ),
        ),
      ),
    );

    final shell = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey<String>('wk-conversation-item-web-shell')),
    );
    final decoration = shell.decoration! as BoxDecoration;
    expect(decoration.color, WKWebColors.actionSoft);
    expect(tester.getSize(find.byKey(const ValueKey<String>('wk-conversation-item-hitbox'))).height, 76);
  });
```

Add this import:

```dart
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/widgets/wk_conversation_item_parity_test.dart
```

Expected: fails because `webStyle`, `selected`, and keys do not exist.

- [ ] **Step 3: Add optional Web presentation flags**

In `lib/widgets/wk_conversation_item.dart`, import:

```dart
import 'wk_web_ui_tokens.dart';
```

Add fields to `WKConversationItem`:

```dart
  final bool webStyle;
  final bool selected;
```

Default them in the constructor:

```dart
    this.webStyle = false,
    this.selected = false,
```

Replace the current top-level `Material` child container with:

```dart
    final effectiveRowBackground = webStyle
        ? (selected ? WKWebColors.actionSoft : WKWebColors.surface)
        : rowBackground;
    final effectivePadding = webStyle
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 15, vertical: 5);
    final hitbox = Container(
      key: const ValueKey<String>('wk-conversation-item-hitbox'),
      height: webStyle ? WKWebSizes.conversationRowHeight : null,
      padding: effectivePadding,
      child: Row(...),
    );

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        key: webStyle ? const ValueKey<String>('wk-conversation-item-web-shell') : null,
        duration: const Duration(milliseconds: 160),
        margin: webStyle
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: effectiveRowBackground,
          borderRadius: BorderRadius.circular(webStyle ? WKWebRadius.control : 0),
          border: webStyle
              ? Border.all(
                  color: selected ? WKWebColors.action : Colors.transparent,
                )
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(webStyle ? WKWebRadius.control : 0),
          highlightColor: webStyle
              ? WKWebColors.actionSoft.withValues(alpha: 0.6)
              : WKColors.screenBgSelected,
          splashColor: webStyle
              ? WKWebColors.actionSoft.withValues(alpha: 0.4)
              : WKColors.screenBgSelected,
          child: hitbox,
        ),
      ),
    );
```

Move the existing `Row(...)` content into `hitbox`. Keep all existing title, tags, emoji preview, unread count, and status logic unchanged.

- [ ] **Step 4: Pass Web style from embedded conversation list**

In `_ConversationTile` inside `conversation_list_page.dart`, pass:

```dart
      webStyle: webStyle,
      selected: webSelected,
```

where `webStyle` and `webSelected` are the fields added in Task 3.

- [ ] **Step 5: Run conversation item tests**

Run:

```powershell
flutter test test/widgets/wk_conversation_item_parity_test.dart test/modules/conversation/conversation_list_item_loader_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Checkpoint**

In an isolated branch only:

```powershell
git add lib/widgets/wk_conversation_item.dart lib/modules/conversation/conversation_list_page.dart test/widgets/wk_conversation_item_parity_test.dart
git commit -m "feat(web): warm conversation list items"
```

---

### Task 5: Warm Login Surface

**Files:**
- Modify: `lib/modules/auth/presentation/widgets/auth_experience_tokens.dart`
- Modify: `lib/modules/auth/presentation/widgets/auth_stage_background.dart`
- Modify: `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart`
- Test: `test/modules/auth/auth_login_page_test.dart`

- [ ] **Step 1: Add failing login style test**

Append to `test/modules/auth/auth_login_page_test.dart`:

```dart
  testWidgets('login page uses warm Web B stage colors', (tester) async {
    await pumpLoginPage(tester);

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('wk_login_background')),
    );
    final decoration = background.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFFAF5));

    final stageShell = tester.widget<Container>(
      find.byKey(const ValueKey<String>('auth-stage-shell')),
    );
    final shellDecoration = stageShell.decoration! as BoxDecoration;
    expect(shellDecoration.borderRadius, BorderRadius.circular(10));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/modules/auth/auth_login_page_test.dart
```

Expected: fails because current login uses dark stage colors and large radii.

- [ ] **Step 3: Replace dark auth tokens with warm B tokens**

In `auth_experience_tokens.dart`, update these constants:

```dart
  static const double panelBorderRadius = 10;
  static const double brandPanelBorderRadius = 10;
  static const double stageShellRadius = 10;

  static const Color stageBackgroundTop = Color(0xFFFFFAF5);
  static const Color stageBackgroundBottom = Color(0xFFFFFAF5);
  static const Color stageShellTop = Color(0xFFFFFFFF);
  static const Color stageShellBottom = Color(0xFFFFFFFF);
  static const Color stageShellBorder = Color(0xFFFED7AA);
  static const List<BoxShadow> stageShellShadow = [
    BoxShadow(color: Color(0x17172433), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const Color panelBackground = Color(0xFFFFFFFF);
  static const Color panelBorder = Color(0xFFFED7AA);
  static const Color panelInk = Color(0xFF172033);
  static const Color panelMuted = Color(0xFF64748B);

  static const Color brandPanelBackground = Color(0xFFFFF7ED);
  static const Color brandPanelOverlay = Color(0xFFFFEDD5);
  static const Color brandInk = Color(0xFF172033);
  static const Color brandMuted = Color(0xFF64748B);
  static const Color brandAccent = Color(0xFFF97316);
  static const Color brandAccentStrong = Color(0xFFEA580C);
  static const Color brandChipBackground = Color(0xFFFFEDD5);
  static const Color brandChipBorder = Color(0xFFFED7AA);
```

Update input and status colors to match the same palette:

```dart
  static const Color inputFill = Color(0xFFFFF7ED);
  static const Color inputHint = Color(0xFF94A3B8);
  static const Color inputText = Color(0xFF172033);
  static const Color inputBorder = Color(0xFFFED7AA);
  static const Color inputBorderFocus = Color(0xFFF97316);
  static const Color inputFillDisabled = Color(0xFFFFEDD5);
```

- [ ] **Step 4: Remove decorative glow bubbles from auth background**

Replace `AuthStageBackground.build` body with:

```dart
    return RepaintBoundary(
      child: DecoratedBox(
        key: backgroundKey,
        decoration: const BoxDecoration(
          color: AuthExperienceTokens.stageBackgroundBottom,
        ),
      ),
    );
```

Delete `_GlowBubble` and `_MessagePlate` classes from `auth_stage_background.dart`.

- [ ] **Step 5: Tighten the auth shell**

In `auth_page_scaffold.dart`, keep the existing layout but change stage shell decoration from gradient to color:

```dart
      decoration: BoxDecoration(
        color: AuthExperienceTokens.stageShellTop,
        borderRadius: BorderRadius.circular(AuthExperienceTokens.stageShellRadius),
        border: Border.all(color: AuthExperienceTokens.stageShellBorder),
        boxShadow: AuthExperienceTokens.stageShellShadow,
      ),
```

For `_buildBrandPanel`, use a plain warm surface:

```dart
      decoration: BoxDecoration(
        color: AuthExperienceTokens.brandPanelBackground,
        border: Border(
          right: BorderSide(color: AuthExperienceTokens.stageShellBorder),
        ),
      ),
```

- [ ] **Step 6: Run auth tests**

Run:

```powershell
flutter test test/modules/auth/auth_login_page_test.dart test/modules/auth/auth_page_scaffold_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Checkpoint**

In an isolated branch only:

```powershell
git add lib/modules/auth/presentation/widgets/auth_experience_tokens.dart lib/modules/auth/presentation/widgets/auth_stage_background.dart lib/modules/auth/presentation/widgets/auth_page_scaffold.dart test/modules/auth/auth_login_page_test.dart
git commit -m "feat(web): warm login experience"
```

---

### Task 6: Warm Chat Header, Bubbles, Composer, And Popups

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/widgets/chat_composer.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Modify: `lib/modules/chat/widgets/chat_message_action_sheet.dart`
- Modify: `lib/modules/chat/widgets/chat_reaction_picker_popup.dart`
- Test: `test/modules/chat/chat_page_scene_flow_test.dart`
- Test: `test/modules/chat/message_bubble_experience_test.dart`
- Test: `test/modules/chat/chat_message_action_sheet_test.dart`

- [ ] **Step 1: Add failing composer style test**

In the existing chat composer test file if present, or create `test/modules/chat/chat_composer_web_style_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_composer.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  testWidgets('chat composer supports warm Web shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            webStyle: true,
            inputRow: SizedBox(height: 20),
            toolbarRow: SizedBox(height: 20),
            panel: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-composer-shell')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, WKWebColors.surface);
    expect(decoration.border!.top.color, WKWebColors.borderWarm);
  });
}
```

- [ ] **Step 2: Add failing bubble style test**

Append to `test/modules/chat/message_bubble_experience_test.dart`:

```dart
    testWidgets('warm Web text bubble uses approved outgoing color', (tester) async {
      final message = WKMsg()
        ..fromUID = 'u_me'
        ..channelType = WKChannelType.personal
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello warm web')
        ..status = WKSendMsgResult.sendSuccess;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              webStyle: true,
              model: ChatMessageMapper().map(message, currentUid: 'u_me'),
            ),
          ),
        ),
      );

      final body = tester.widget<Container>(
        find.byKey(const ValueKey<String>('message-bubble-body')),
      );
      final decoration = body.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFEDD5));
    });
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```powershell
flutter test test/modules/chat/chat_composer_web_style_test.dart test/modules/chat/message_bubble_experience_test.dart
```

Expected: fails because `webStyle` flags and warm styles do not exist.

- [ ] **Step 4: Add warm shell to `ChatComposer`**

In `chat_composer.dart`, import:

```dart
import '../../../widgets/wk_web_ui_tokens.dart';
```

Add field:

```dart
  final bool webStyle;
```

Default it:

```dart
    this.webStyle = false,
```

Give the `DecoratedBox` a key and conditional decoration:

```dart
        key: const ValueKey<String>('chat-composer-shell'),
        decoration: BoxDecoration(
          color: webStyle ? WKWebColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: webStyle ? WKWebColors.borderWarm : WKColors.layoutColorSelected,
              width: 1,
            ),
          ),
          boxShadow: webStyle
              ? const <BoxShadow>[
                  BoxShadow(
                    color: WKWebColors.shadow,
                    blurRadius: 14,
                    offset: Offset(0, -4),
                  ),
                ]
              : null,
        ),
```

- [ ] **Step 5: Add warm bubble style to `MessageBubble`**

In `message_bubble.dart`, import:

```dart
import 'wk_web_ui_tokens.dart';
```

Add field:

```dart
  final bool webStyle;
```

Default it:

```dart
    this.webStyle = false,
```

In `_bubbleDecoration`, use the warm palette when `webStyle` is true:

```dart
    if (webStyle && _isTextLikeContent(contentType)) {
      return BoxDecoration(
        color: isSelf ? WKWebColors.actionSoft : WKWebColors.surface,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
        border: Border.all(
          color: isSelf ? WKWebColors.borderWarm : const Color(0xFFFFEDD5),
        ),
      );
    }
```

If `_isTextLikeContent` does not exist, add:

```dart
  bool _isTextLikeContent(int contentType) {
    return contentType == WkMessageContentType.text ||
        contentType == WkMessageContentType.unknown ||
        contentType == MsgContentType.robotCard;
  }
```

Keep image/video/gif/file/card layout limits unchanged.

- [ ] **Step 6: Pass Web style from `ChatPageShell`**

In `chat_page_shell.dart`, compute:

```dart
    final useWarmWebStyle = PlatformUtils.isWeb;
```

Use it for:

```dart
        backgroundColor: useWarmWebStyle ? WKWebColors.pageWarm : WKColors.homeBg,
```

Pass `webStyle: useWarmWebStyle` to `ChatComposer` and `MessageBubble`.

For the app bar, use warm colors when `useWarmWebStyle`:

```dart
          backgroundColor: useWarmWebStyle ? WKWebColors.surface : WKColors.homeBg,
```

- [ ] **Step 7: Warm message action surfaces**

In `chat_message_action_sheet.dart` and `chat_reaction_picker_popup.dart`, import `wk_web_ui_tokens.dart` and replace outer surface colors/borders with:

```dart
BoxDecoration(
  color: WKWebColors.surface,
  borderRadius: BorderRadius.circular(WKWebRadius.panel),
  border: Border.all(color: WKWebColors.borderWarm),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: WKWebColors.shadow, blurRadius: 20, offset: Offset(0, 10)),
  ],
)
```

Do not change action ordering or reaction emoji values.

- [ ] **Step 8: Run chat tests**

Run:

```powershell
flutter test test/modules/chat/chat_composer_web_style_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/chat/chat_message_action_sheet_test.dart test/modules/chat/chat_page_scene_flow_test.dart
```

Expected: all tests pass, including previous emoji/reaction expectations.

- [ ] **Step 9: Checkpoint**

In an isolated branch only:

```powershell
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_composer.dart lib/widgets/message_bubble.dart lib/modules/chat/widgets/chat_message_action_sheet.dart lib/modules/chat/widgets/chat_reaction_picker_popup.dart test/modules/chat/chat_composer_web_style_test.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat(web): warm chat surfaces"
```

---

### Task 7: Warm Call Overlay And In-Chat Call State

**Files:**
- Modify: `lib/modules/video_call/call_notification.dart`
- Modify: `lib/modules/video_call/widgets/chat_calling_participants_bar.dart`
- Test: `test/modules/video_call/call_notification_test.dart`
- Test: `test/modules/video_call/call_conversation_record_service_test.dart`

- [ ] **Step 1: Write failing call overlay test**

Create `test/modules/video_call/call_notification_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/call_notification.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  testWidgets('incoming call overlay uses warm Web surface and stable action keys', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) {
                return Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () {
                        CallNotificationOverlay.instance.showIncomingCall(
                          overlayState: Overlay.of(context),
                          data: CallNotificationData(
                            channelId: 'u_peer',
                            channelName: 'Alice',
                            type: CallNotificationType.incoming,
                            callType: 1,
                          ),
                          onAccept: () {},
                          onReject: () {},
                        );
                      },
                      child: const Text('show'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump();

    final card = tester.widget<Container>(
      find.byKey(const ValueKey<String>('call-notification-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, WKWebColors.surface);
    expect(find.byKey(const ValueKey<String>('call-notification-reject')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('call-notification-accept')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
flutter test test/modules/video_call/call_notification_test.dart
```

Expected: fails because keys and warm styles do not exist.

- [ ] **Step 3: Warm the notification overlay**

In `call_notification.dart`, import:

```dart
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_web_ui_tokens.dart';
```

In `_IncomingCallWidget`, replace `CircleAvatar` with:

```dart
WKAvatar(
  url: widget.data.avatar,
  name: widget.data.channelName,
  size: 48,
)
```

Give the main card container:

```dart
key: const ValueKey<String>('call-notification-card'),
decoration: BoxDecoration(
  color: WKWebColors.surface,
  borderRadius: BorderRadius.circular(WKWebRadius.panel),
  border: Border.all(color: WKWebColors.borderWarm),
  boxShadow: const <BoxShadow>[
    BoxShadow(color: WKWebColors.shadow, blurRadius: 24, offset: Offset(0, 10)),
  ],
),
```

Set reject and accept buttons:

```dart
key: const ValueKey<String>('call-notification-reject'),
```

and:

```dart
key: const ValueKey<String>('call-notification-accept'),
```

Use `WKWebColors.danger` for reject and `WKWebColors.online` for accept.

Apply the same card decoration to `_OutgoingCallWidget`, with key:

```dart
key: const ValueKey<String>('call-outgoing-notification-card'),
```

- [ ] **Step 4: Warm in-chat calling bar**

In `chat_calling_participants_bar.dart`, import `wk_web_ui_tokens.dart` and change the decoration to:

```dart
      decoration: const BoxDecoration(
        color: WKWebColors.surfaceSoft,
        border: Border(
          top: BorderSide(color: WKWebColors.borderWarm),
          bottom: BorderSide(color: WKWebColors.borderWarm),
        ),
      ),
```

Use `WKWebColors.online` for the call icon.

- [ ] **Step 5: Run call tests**

Run:

```powershell
flutter test test/modules/video_call/call_notification_test.dart test/modules/video_call/call_conversation_record_service_test.dart test/modules/video_call/call_session_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Checkpoint**

In an isolated branch only:

```powershell
git add lib/modules/video_call/call_notification.dart lib/modules/video_call/widgets/chat_calling_participants_bar.dart test/modules/video_call/call_notification_test.dart
git commit -m "feat(web): warm call overlays"
```

---

### Task 8: Contacts And User Web Panels

**Files:**
- Modify: `lib/modules/contacts/contacts_page.dart`
- Modify: `lib/modules/user/user_page.dart`
- Test: `test/modules/contacts/contacts_page_parity_test.dart`
- Test: `test/modules/user/user_page_parity_test.dart`

- [ ] **Step 1: Add failing contacts/user Web frame tests**

Append to `test/modules/contacts/contacts_page_parity_test.dart`:

```dart
  testWidgets('contacts page can render inside warm Web frame', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ContactsPage(forceWebFrameForTesting: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('contacts-web-frame')), findsOneWidget);
  });
```

Append to `test/modules/user/user_page_parity_test.dart`:

```dart
  testWidgets('user page can render inside warm Web frame', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserPage(forceWebFrameForTesting: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('user-web-frame')), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```powershell
flutter test test/modules/contacts/contacts_page_parity_test.dart test/modules/user/user_page_parity_test.dart
```

Expected: fails because testing flags and frame keys do not exist.

- [ ] **Step 3: Add Web frame flag to `ContactsPage`**

In `contacts_page.dart`, add constructor field:

```dart
  final bool forceWebFrameForTesting;
```

Default it:

```dart
    this.forceWebFrameForTesting = false,
```

At the end of `build`, create the existing body as `content`. Wrap it when forced or desktop Web:

```dart
    final useWebFrame = widget.forceWebFrameForTesting ||
        (kIsWeb && MediaQuery.sizeOf(context).width >= WKWebBreakpoints.desktopMin);

    if (!useWebFrame) {
      return content;
    }

    return Scaffold(
      key: const ValueKey<String>('contacts-web-frame'),
      backgroundColor: WKWebColors.pageWarm,
      body: Padding(
        padding: const EdgeInsets.all(WKSpace.md),
        child: WKWebPanel(child: content.body ?? const SizedBox.shrink()),
      ),
    );
```

If the current code returns a `Scaffold` directly, refactor it into:

```dart
    final body = Column(...);
    final content = Scaffold(backgroundColor: WKColors.homeBg, body: body);
```

Keep all existing provider logic, menus, presence, and navigation handlers.

- [ ] **Step 4: Add Web frame flag to `UserPage`**

In `user_page.dart`, add constructor:

```dart
  const UserPage({
    super.key,
    this.forceWebFrameForTesting = false,
  });

  final bool forceWebFrameForTesting;
```

Wrap the existing list body when forced or desktop Web with:

```dart
    final useWebFrame = widget.forceWebFrameForTesting ||
        (kIsWeb && MediaQuery.sizeOf(context).width >= WKWebBreakpoints.desktopMin);
```

When `useWebFrame`, return:

```dart
    return Scaffold(
      key: const ValueKey<String>('user-web-frame'),
      backgroundColor: WKWebColors.pageWarm,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: WKWebPanel(
            margin: const EdgeInsets.all(WKSpace.md),
            child: body,
          ),
        ),
      ),
    );
```

Preserve every existing menu entry and navigation callback.

- [ ] **Step 5: Run contacts/user tests**

Run:

```powershell
flutter test test/modules/contacts/contacts_page_parity_test.dart test/modules/user/user_page_parity_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Checkpoint**

In an isolated branch only:

```powershell
git add lib/modules/contacts/contacts_page.dart lib/modules/user/user_page.dart test/modules/contacts/contacts_page_parity_test.dart test/modules/user/user_page_parity_test.dart
git commit -m "feat(web): frame contacts and user pages"
```

---

### Task 9: Full Regression And Web Visual Verification

**Files:**
- No product files
- Optional docs update: `docs/2026-04-30-web-b-ui-verification-report.md`

- [ ] **Step 1: Run focused widget tests**

Run:

```powershell
flutter test test/widgets/wk_web_ui_tokens_test.dart test/widgets/wk_tab_shell_web_test.dart test/widgets/wk_conversation_item_parity_test.dart
```

Expected: all tests pass.

- [ ] **Step 2: Run Web UI flow tests**

Run:

```powershell
flutter test test/modules/home/home_shell_page_test.dart test/modules/conversation/web_conversation_workspace_test.dart test/modules/auth/auth_login_page_test.dart test/modules/chat/chat_composer_web_style_test.dart test/modules/chat/message_bubble_experience_test.dart test/modules/video_call/call_notification_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Run bugfix regression tests from the previous repair**

Run:

```powershell
flutter test test/web_entrypoint_cache_cleanup_test.dart test/wukong_base/emoji/android_emoji_catalog_test.dart test/wukong_base/msg/reaction_manager_test.dart test/modules/chat/chat_scene_gateway_test.dart test/data/providers/conversation_provider_test.dart test/modules/video_call/call_conversation_record_service_test.dart test/modules/video_call/call_session_service_test.dart test/modules/chat/message_bubble_experience_test.dart
```

Expected: all tests pass. This confirms emoji, reactions, revoke refresh, call records, and avatar behavior did not regress.

- [ ] **Step 4: Run analyzer on changed files**

Run:

```powershell
flutter analyze lib/widgets/wk_web_ui_tokens.dart lib/widgets/wk_colors.dart lib/widgets/wk_theme.dart lib/widgets/wk_tab_shell.dart lib/modules/home/home_shell_page.dart lib/modules/conversation/web_conversation_workspace.dart lib/modules/conversation/conversation_list_page.dart lib/widgets/wk_conversation_item.dart lib/modules/auth/presentation/widgets/auth_experience_tokens.dart lib/modules/auth/presentation/widgets/auth_stage_background.dart lib/modules/auth/presentation/widgets/auth_page_scaffold.dart lib/modules/chat/chat_page_shell.dart lib/modules/chat/widgets/chat_composer.dart lib/widgets/message_bubble.dart lib/modules/video_call/call_notification.dart lib/modules/video_call/widgets/chat_calling_participants_bar.dart lib/modules/contacts/contacts_page.dart lib/modules/user/user_page.dart
```

Expected: analyzer exits with code 0.

- [ ] **Step 5: Build Web release**

Run:

```powershell
flutter build web --release
```

Expected: build succeeds and `build\web` is produced.

- [ ] **Step 6: Browser visual check**

Start or reuse a local Web server for `build\web`, then capture:

```powershell
python -m http.server 8088 --directory build\web
```

Use browser automation or manual inspection for:

- `1440 x 900`: rail visible, conversation list visible, chat pane visible, no overlap.
- `375 x 812`: bottom tabs visible, single-column conversation flow, composer not clipped.
- Login page: warm background, centered panel, no dark decorative glow bubbles.
- Chat page: emoji and reaction text render as emoji, no `xx`.
- Call overlay: incoming/outgoing cards use warm surface and visible accept/reject buttons.

- [ ] **Step 7: Record verification**

If the user wants a written report, create `docs/2026-04-30-web-b-ui-verification-report.md` with:

```markdown
# Web B UI Verification Report

Date: 2026-04-30

## Commands

- flutter test ...
- flutter analyze ...
- flutter build web --release

## Screens Checked

- Desktop 1440 x 900
- Mobile Web 375 x 812

## Regression Coverage

- Emoji fallback
- Message revoke refresh
- Reaction rendering
- Call record and overlay
- Avatar identity stability
```

- [ ] **Step 8: Final checkpoint**

In an isolated branch only:

```powershell
git status --short
git add docs/2026-04-30-web-b-ui-verification-report.md
git commit -m "test(web): verify warm IM UI"
```

Only run the `git add` and `git commit` lines if the report file was created and the user asked for commits.

---

## Self-Review

- Spec coverage: tokens, desktop Web workbench, login, conversation list, chat surface, reaction/action popups, call overlay, contacts, user page, accessibility-friendly tooltips/keys, responsive breakpoints, regression checks.
- Scope control: no IM protocol, message storage, call signaling, push, or non-Web navigation rewrite.
- Test coverage: each visual slice starts with widget tests, then focused regression tests and Web release build.
- Risk control: tasks isolate presentation primitives before high-risk chat edits; `ChatPage` password guard remains in the embedded workspace; existing providers/controllers remain owners of business behavior.
