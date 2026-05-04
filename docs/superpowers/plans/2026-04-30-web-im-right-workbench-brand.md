# Web IM Right Workbench Brand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the ambiguous desktop Web `WK` rail brand with the approved `信息平权` brand mark and turn the sparse right panel into a useful `会话工作台`.

**Architecture:** Keep the change presentation-only. Add one focused desktop rail brand widget inside `WKTabShell`, and replace the current private right-context placeholder with a reusable `ConversationWorkbenchPanel` that can render selected-conversation context and safe empty states. Reuse existing Web B tokens and existing conversation selection data; do not change IM protocol, message send logic, search internals, or call signaling.

**Tech Stack:** Flutter, Dart, Flutter widget tests, existing `WKWebColors` / `WKWebSizes` / `WKWebRadius` tokens.

---

## Execution Notes

- The workspace currently contains many unrelated dirty files. Do not stage broad paths. Use only the exact files listed in each task.
- The product code already has `lib/widgets/wk_tab_shell.dart`, `lib/modules/conversation/web_conversation_workspace.dart`, `test/widgets/wk_tab_shell_web_test.dart`, and `test/modules/conversation/web_conversation_workspace_test.dart`.
- Keep Chinese strings as UTF-8 Dart source strings. Do not convert product copy into mojibake or escaped placeholder strings.
- Do not create fake business data. The right panel may show safe empty states such as `暂无群公告`, `暂无最近图片`, and `暂无最近文件`.
- Do not modify message send, revoke, reply, forward, reaction, notification, call, cache, or routing logic.

## File Structure

- Modify `test/widgets/wk_tab_shell_web_test.dart`
  - Adds a focused regression test for the desktop Web brand mark.
- Modify `lib/widgets/wk_tab_shell.dart`
  - Adds `_WKWebBrandMark`, a focused widget that renders `信息\n平权`, removes visible `WK`, and keeps tooltip/semantics.
- Modify `test/modules/conversation/web_conversation_workspace_test.dart`
  - Adds tests for the approved right workbench title and sections.
- Modify `lib/modules/conversation/web_conversation_workspace.dart`
  - Adds public `ConversationWorkbenchPanel`.
  - Wires `WebConversationWorkspace` to pass the current selection into the right panel.
  - Removes the old single-title `_ConversationContextPanel`.
- Optional verification only, no product changes:
  - Run focused widget tests and analyze the changed files.

---

### Task 1: Desktop Web Rail Brand Mark

**Files:**
- Modify: `test/widgets/wk_tab_shell_web_test.dart`
- Modify: `lib/widgets/wk_tab_shell.dart`

- [ ] **Step 1: Add the failing brand regression test**

Append this test inside the existing `void main()` in `test/widgets/wk_tab_shell_web_test.dart`, after the current desktop rail test:

```dart
  testWidgets('desktop Web rail uses 信息平权 brand mark without explanatory copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 0,
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

    expect(
      find.byKey(const ValueKey<String>('wk_tab_shell_brand_mark')),
      findsOneWidget,
    );
    expect(find.text('信息\n平权'), findsOneWidget);
    expect(find.text('WK'), findsNothing);
    expect(find.text('品牌入口'), findsNothing);
    expect(find.byTooltip('信息平权'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/widgets/wk_tab_shell_web_test.dart
```

Expected result: the new test fails because the desktop rail still renders visible `WK` and does not have key `wk_tab_shell_brand_mark`.

- [ ] **Step 3: Replace the inline `WK` container with a brand widget**

In `lib/widgets/wk_tab_shell.dart`, locate `_buildDesktopRailShell`. Replace the current first `Container` in the rail `Column` that renders the visible `WK` text with:

```dart
                const _WKWebBrandMark(),
```

The rail `Column` should start like this after the replacement:

```dart
            child: Column(
              children: [
                const _WKWebBrandMark(),
                const SizedBox(height: WKSpace.lg),
                for (var index = 0; index < items.length; index++)
                  _WKWebRailItem(
                    data: items[index],
                    selected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
              ],
            ),
```

- [ ] **Step 4: Add `_WKWebBrandMark`**

In `lib/widgets/wk_tab_shell.dart`, add this class between `WKTabShell` and `_WKTabBarItem`:

```dart
class _WKWebBrandMark extends StatelessWidget {
  const _WKWebBrandMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '信息平权',
      child: Semantics(
        button: true,
        label: '信息平权',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(WKWebRadius.control),
            child: Container(
              key: const ValueKey<String>('wk_tab_shell_brand_mark'),
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: WKWebColors.action,
                borderRadius: BorderRadius.circular(WKWebRadius.control),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: WKWebColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                '信息\n平权',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: WKFontFamily.title,
                  color: WKColors.white,
                  fontSize: 12,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the rail test and verify it passes**

Run:

```powershell
flutter test test/widgets/wk_tab_shell_web_test.dart
```

Expected result: all tests in `test/widgets/wk_tab_shell_web_test.dart` pass.

- [ ] **Step 6: Commit Task 1 only**

Run:

```powershell
git add test/widgets/wk_tab_shell_web_test.dart lib/widgets/wk_tab_shell.dart
git commit -m "feat(web): show information equality brand mark"
```

Expected result: a commit is created containing only the rail brand test and implementation.

---

### Task 2: Conversation Workbench Panel Tests

**Files:**
- Modify: `test/modules/conversation/web_conversation_workspace_test.dart`
- Modify: `lib/modules/conversation/web_conversation_workspace.dart`

- [ ] **Step 1: Add failing tests for the approved right panel**

Append these tests inside the existing `void main()` in `test/modules/conversation/web_conversation_workspace_test.dart`:

```dart
  testWidgets('conversation workbench shows approved title and sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: ConversationWorkbenchPanel(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('conversation-workbench-panel')),
      findsOneWidget,
    );
    expect(find.text('会话工作台'), findsOneWidget);
    expect(find.text('成员'), findsOneWidget);
    expect(find.text('置顶 / 公告'), findsOneWidget);
    expect(find.text('文件与图片'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('会话信息'), findsNothing);
  });

  testWidgets('conversation workbench uses selected conversation display name', (
    tester,
  ) async {
    const selection = WebConversationWorkspaceSelection(
      session: ChatSession(channelId: 'group_1', channelType: 2),
      channelName: 'test1、平权客服、LD',
      channelCategory: 'group',
      initialVipLevel: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: ConversationWorkbenchPanel(selection: selection),
        ),
      ),
    );

    expect(find.text('test1、平权客服、LD'), findsOneWidget);
    expect(find.text('group'), findsOneWidget);
  });
```

Also add this import at the top of `test/modules/conversation/web_conversation_workspace_test.dart`:

```dart
import 'package:wukong_im_app/data/models/chat_session.dart';
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected result: fails because `ConversationWorkbenchPanel` does not exist.

- [ ] **Step 3: Add `ConversationWorkbenchPanel` and helpers**

In `lib/modules/conversation/web_conversation_workspace.dart`, replace the private `_ConversationContextPanel` class with the following code:

```dart
class ConversationWorkbenchPanel extends StatelessWidget {
  const ConversationWorkbenchPanel({
    super.key,
    this.selection,
  });

  final WebConversationWorkspaceSelection? selection;

  String get _displayName {
    final name = selection?.channelName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final id = selection?.session.channelId.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return '选择会话后显示详情';
  }

  String get _avatarText {
    final value = _displayName.trim();
    if (value.isEmpty || value == '选择会话后显示详情') {
      return '会';
    }
    return value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('conversation-workbench-panel'),
      color: WKWebColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: WKSpace.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: WKWebColors.borderWarm),
              ),
            ),
            child: Text(
              '会话工作台',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: WKWebColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(WKSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WorkbenchSection(
                    key: const ValueKey<String>(
                      'conversation-workbench-members-section',
                    ),
                    title: '成员',
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: WKWebColors.actionSoft,
                            borderRadius: BorderRadius.circular(
                              WKWebRadius.avatar,
                            ),
                          ),
                          child: Text(
                            _avatarText,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.title,
                              color: WKWebColors.action,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: WKSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: WKFontFamily.primary,
                                  color: WKWebColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selection == null ? '暂无选中会话' : '当前会话',
                                style: const TextStyle(
                                  fontFamily: WKFontFamily.primary,
                                  color: WKWebColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _WorkbenchSection(
                    key: const ValueKey<String>(
                      'conversation-workbench-status-section',
                    ),
                    title: '置顶 / 公告',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkbenchPill(
                          text: selection?.channelCategory ?? '暂无会话状态',
                        ),
                        const SizedBox(height: WKSpace.xs),
                        const _WorkbenchPill(text: '暂无群公告'),
                      ],
                    ),
                  ),
                  const _WorkbenchSection(
                    key: ValueKey<String>(
                      'conversation-workbench-files-section',
                    ),
                    title: '文件与图片',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkbenchFileEntry(text: '暂无最近图片'),
                        SizedBox(height: WKSpace.xs),
                        _WorkbenchFileEntry(text: '暂无最近文件'),
                      ],
                    ),
                  ),
                  const _WorkbenchSection(
                    key: ValueKey<String>(
                      'conversation-workbench-actions-section',
                    ),
                    title: '快捷操作',
                    child: Wrap(
                      spacing: WKSpace.xs,
                      runSpacing: WKSpace.xs,
                      children: [
                        _WorkbenchActionChip(label: '查找'),
                        _WorkbenchActionChip(label: '置顶'),
                        _WorkbenchActionChip(label: '免打扰'),
                        _WorkbenchActionChip(label: '设置'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchSection extends StatelessWidget {
  const _WorkbenchSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              color: WKWebColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          child,
        ],
      ),
    );
  }
}

class _WorkbenchPill extends StatelessWidget {
  const _WorkbenchPill({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: 32,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      decoration: BoxDecoration(
        color: WKWebColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.pill),
        border: Border.all(color: WKWebColors.borderWarm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _WorkbenchFileEntry extends StatelessWidget {
  const _WorkbenchFileEntry({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      minHeight: 46,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      decoration: BoxDecoration(
        color: WKWebColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
        border: Border.all(color: WKWebColors.borderWarm),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WorkbenchActionChip extends StatelessWidget {
  const _WorkbenchActionChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: WKSpace.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WKWebColors.actionSoft,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          color: WKWebColors.action,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests and verify they pass**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected result: the newly added workbench tests pass, and the existing workspace tests still pass.

- [ ] **Step 5: Commit Task 2 only**

Run:

```powershell
git add test/modules/conversation/web_conversation_workspace_test.dart lib/modules/conversation/web_conversation_workspace.dart
git commit -m "feat(web): add conversation workbench panel"
```

Expected result: a commit is created containing only the workbench panel tests and implementation.

---

### Task 3: Wire the Workbench Into the Desktop Workspace

**Files:**
- Modify: `lib/modules/conversation/web_conversation_workspace.dart`
- Modify: `test/modules/conversation/web_conversation_workspace_test.dart`

- [ ] **Step 1: Add a scaffold integration test**

Append this test inside `void main()` in `test/modules/conversation/web_conversation_workspace_test.dart`:

```dart
  testWidgets('wide workspace can display the approved workbench panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WebConversationWorkspaceScaffold(
          listPane: Text('list'),
          chatPane: Text('chat'),
          rightContextPane: ConversationWorkbenchPanel(),
          showRightContext: true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('web-conversation-right-pane')),
      findsOneWidget,
    );
    expect(find.text('会话工作台'), findsOneWidget);
    expect(find.text('会话信息'), findsNothing);
  });
```

- [ ] **Step 2: Run the test and verify current behavior**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected result: this test passes after Task 2, but the product workspace still needs wiring so selected conversation data flows into the panel.

- [ ] **Step 3: Pass the current selection to the workbench panel**

In `lib/modules/conversation/web_conversation_workspace.dart`, locate the `WebConversationWorkspaceScaffold` call in `_WebConversationWorkspaceState.build`. Replace:

```dart
          rightContextPane: const _ConversationContextPanel(),
```

with:

```dart
          rightContextPane: ConversationWorkbenchPanel(selection: selection),
```

After the replacement, the `WebConversationWorkspaceScaffold` call should end like this:

```dart
        return WebConversationWorkspaceScaffold(
          showRightContext: WKWebBreakpoints.showRightContext(viewportWidth),
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
          rightContextPane: ConversationWorkbenchPanel(selection: selection),
        );
```

- [ ] **Step 4: Run the focused conversation workspace tests**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected result: all tests in the file pass.

- [ ] **Step 5: Commit Task 3 only**

Run:

```powershell
git add lib/modules/conversation/web_conversation_workspace.dart test/modules/conversation/web_conversation_workspace_test.dart
git commit -m "feat(web): wire conversation workbench context"
```

Expected result: a commit is created containing only the wiring and test update.

---

### Task 4: Focused Verification

**Files:**
- No product files

- [ ] **Step 1: Run the focused widget tests**

Run:

```powershell
flutter test test/widgets/wk_tab_shell_web_test.dart test/modules/conversation/web_conversation_workspace_test.dart
```

Expected result: both test files pass.

- [ ] **Step 2: Run regression tests for adjacent workspace behavior**

Run:

```powershell
flutter test test/modules/home/home_shell_page_test.dart test/modules/conversation/conversation_list_page_test.dart
```

Expected result: both test files pass. This confirms the home shell and conversation list still render with the desktop Web workspace changes.

- [ ] **Step 3: Analyze changed production files**

Run:

```powershell
flutter analyze lib/widgets/wk_tab_shell.dart lib/modules/conversation/web_conversation_workspace.dart
```

Expected result: analyzer exits with code 0 and reports no new issues for the changed files.

- [ ] **Step 4: Optional desktop Web visual check**

Run a Web build or existing dev server and inspect a desktop-width chat screen:

```powershell
flutter build web --release
python -m http.server 8088 --directory build\web
```

Expected visual result at 1440px wide:

- Left rail shows `信息平权` in the top brand block.
- No visible `WK` appears in the rail brand block.
- No visible `品牌入口` copy appears under the brand.
- Right panel title is `会话工作台`.
- Right panel contains `成员`, `置顶 / 公告`, `文件与图片`, and `快捷操作`.
- Chat content remains readable and is not squeezed below usable width.

- [ ] **Step 5: Final status check**

Run:

```powershell
git status --short
```

Expected result: only intentional changes from the implementation remain. If commits from Tasks 1 through 3 were created, there should be no unstaged changes in the four edited files.

---

## Self-Review

- Spec coverage:
  - `信息平权` brand mark: Task 1.
  - No visible `WK` or `品牌入口`: Task 1 test and implementation.
  - Right panel title `会话工作台`: Task 2.
  - Sections `成员`, `置顶 / 公告`, `文件与图片`, `快捷操作`: Task 2.
  - Selected conversation display name flows into right panel: Task 2 and Task 3.
  - Width behavior remains controlled by existing `showRightContext`: Task 3 keeps existing scaffold behavior.
  - IM business behavior untouched: all tasks are presentation widgets and tests only.
- Placeholder scan: no placeholder implementation steps remain.
- Type consistency:
  - `ConversationWorkbenchPanel` is public so tests can import it directly.
  - `WebConversationWorkspaceSelection` and `ChatSession` signatures match the current source.
  - Test keys match implementation keys exactly.
