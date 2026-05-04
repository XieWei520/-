# Contacts Strings Resource Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a lightweight contacts-domain strings resource layer and route the contacts surfaces in scope through it so the Flutter app stays strictly aligned with Android default wording.

**Architecture:** Add a pure-Dart `ContactsStrings` resource object plus a resolver in the contacts module, then migrate contacts slot assembly and contacts pages to read from that single source of truth. Keep the change scoped to the contacts domain and avoid introducing app-wide localization infrastructure or behavior changes.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, existing contacts widgets/pages, pure Dart resource objects

---

## File Structure

## Execution Notes

- This workspace snapshot does not currently contain `.git` metadata.
- If the plan is executed inside this snapshot, treat commit steps as logical checkpoints and skip the `git commit` command itself.
- If the plan is executed inside a git worktree, use the commit messages exactly as written.

### New files

- `lib/modules/contacts/contacts_strings.dart`: contacts-domain strings model, default Simplified Chinese values, and locale-ready resolver
- `test/modules/contacts/contacts_strings_test.dart`: unit tests for default resolved values and future locale-safe fallback behavior

### Existing files to modify

- `lib/modules/contacts/contacts_slot_assembly.dart`: replace hardcoded default header labels with resource-layer values
- `lib/modules/contacts/contacts_page.dart`: replace contacts-domain page labels, menus, dialog labels, and legacy page strings with resource-layer values
- `lib/modules/contacts/new_friends_page.dart`: replace new-friends page strings with resource-layer values
- `lib/modules/contacts/create_group_page.dart`: replace create-group page strings with resource-layer values
- `lib/modules/contacts/widgets/contacts_list_viewport.dart`: replace empty-state and count labels with resource-layer values
- `test/modules/contacts/contacts_slot_assembly_test.dart`: lock slot output to resource-layer default labels
- `test/modules/contacts/contacts_page_parity_test.dart`: lock Android header labels and contacts page labels
- `test/modules/contacts/new_friends_page_parity_test.dart`: keep Android-aligned new-friends labels under the new resource layer
- `test/modules/contacts/create_group_page_parity_test.dart`: keep Android-aligned create-group labels under the new resource layer
- `test/modules/contacts/contacts_viewport_test.dart`: keep empty-state label assertions green after migration

### Verification commands used throughout

- `flutter test test/modules/contacts/contacts_strings_test.dart`
- `flutter test test/modules/contacts/contacts_slot_assembly_test.dart`
- `flutter test test/modules/contacts/contacts_page_parity_test.dart`
- `flutter test test/modules/contacts/new_friends_page_parity_test.dart`
- `flutter test test/modules/contacts/create_group_page_parity_test.dart`
- `flutter test test/modules/contacts/contacts_viewport_test.dart`
- `flutter analyze lib/modules/contacts test/modules/contacts`

### Task 1: Build The Contacts Strings Resource Layer

**Files:**
- Create: `lib/modules/contacts/contacts_strings.dart`
- Create: `test/modules/contacts/contacts_strings_test.dart`

- [ ] **Step 1: Write the failing resource-layer tests**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_strings.dart';

void main() {
  test('resolveContactsStrings returns Android-aligned Simplified Chinese defaults', () {
    final strings = resolveContactsStrings();

    expect(strings.newFriends, '新朋友');
    expect(strings.savedGroups, '保存的群聊');
    expect(strings.contactsTitle, '通讯录');
    expect(strings.newFriendsTitle, '新朋友');
    expect(strings.selectContactsTitle, '选择联系人');
    expect(strings.confirmWithCount(2), '确定(2)');
    expect(strings.contactsCount(5), '5位联系人');
  });

  test('resolveContactsStrings falls back to Simplified Chinese for unsupported locales', () {
    final strings = resolveContactsStrings(locale: const Locale('en'));

    expect(strings.newFriends, '新朋友');
    expect(strings.savedGroups, '保存的群聊');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/modules/contacts/contacts_strings_test.dart`
Expected: FAIL with missing `contacts_strings.dart`, missing `ContactsStrings`, or missing `resolveContactsStrings`

- [ ] **Step 3: Add the resource object and resolver**

```dart
import 'package:flutter/widgets.dart';

class ContactsStrings {
  const ContactsStrings({
    required this.newFriends,
    required this.savedGroups,
    required this.contactsTitle,
    required this.contactsLoading,
    required this.contactsLoadFailed,
    required this.setRemark,
    required this.sendMessage,
    required this.remarkDialogTitle,
    required this.remarkDialogHint,
    required this.cancel,
    required this.save,
    required this.newFriendsTitle,
    required this.newFriendsLoading,
    required this.newFriendsLoadFailed,
    required this.newFriendsEmpty,
    required this.newFriendsEmptyHint,
    required this.requestAddFriend,
    required this.approve,
    required this.processing,
    required this.processed,
    required this.delete,
    required this.selectContactsTitle,
    required this.searchPlaceholder,
    required this.confirm,
    required this.createGroupFailedPrefix,
    required this.contactsEmpty,
    required this.contactsEmptyHint,
  });

  final String newFriends;
  final String savedGroups;
  final String contactsTitle;
  final String contactsLoading;
  final String contactsLoadFailed;
  final String setRemark;
  final String sendMessage;
  final String remarkDialogTitle;
  final String remarkDialogHint;
  final String cancel;
  final String save;
  final String newFriendsTitle;
  final String newFriendsLoading;
  final String newFriendsLoadFailed;
  final String newFriendsEmpty;
  final String newFriendsEmptyHint;
  final String requestAddFriend;
  final String approve;
  final String processing;
  final String processed;
  final String delete;
  final String selectContactsTitle;
  final String searchPlaceholder;
  final String confirm;
  final String createGroupFailedPrefix;
  final String contactsEmpty;
  final String contactsEmptyHint;

  String confirmWithCount(int count) => '$confirm($count)';
  String contactsCount(int count) => '${count}位联系人';
  String createGroupFailed(Object error) => '$createGroupFailedPrefix: $error';
  String contactsLoadFailedMessage(Object error) => '$contactsLoadFailed: $error';
}

const ContactsStrings _zhHansContactsStrings = ContactsStrings(
  newFriends: '新朋友',
  savedGroups: '保存的群聊',
  contactsTitle: '通讯录',
  contactsLoading: '加载通讯录中...',
  contactsLoadFailed: '通讯录加载失败',
  setRemark: '设置备注',
  sendMessage: '发消息',
  remarkDialogTitle: '设置备注',
  remarkDialogHint: '输入备注',
  cancel: '取消',
  save: '保存',
  newFriendsTitle: '新朋友',
  newFriendsLoading: '加载申请中...',
  newFriendsLoadFailed: '加载失败',
  newFriendsEmpty: '暂无新的好友申请',
  newFriendsEmptyHint: '新的请求会集中出现在这里。',
  requestAddFriend: '请求加好友',
  approve: '通过验证',
  processing: '处理中',
  processed: '已通过',
  delete: '删除',
  selectContactsTitle: '选择联系人',
  searchPlaceholder: '搜索',
  confirm: '确定',
  createGroupFailedPrefix: '创建群聊失败',
  contactsEmpty: '暂无联系人',
  contactsEmptyHint: '添加好友后会显示在这里。',
);

ContactsStrings resolveContactsStrings({Locale? locale}) {
  final languageCode = locale?.languageCode.toLowerCase();
  switch (languageCode) {
    case 'zh':
      return _zhHansContactsStrings;
    default:
      return _zhHansContactsStrings;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/modules/contacts/contacts_strings_test.dart`
Expected: PASS with both default-value assertions green

- [ ] **Step 5: Commit**

```bash
git add lib/modules/contacts/contacts_strings.dart test/modules/contacts/contacts_strings_test.dart
git commit -m "refactor: add contacts strings resource layer"
```

### Task 2: Route Header Slots And Contacts Page Through The Resource Layer

**Files:**
- Modify: `lib/modules/contacts/contacts_slot_assembly.dart`
- Modify: `lib/modules/contacts/contacts_page.dart`
- Modify: `test/modules/contacts/contacts_slot_assembly_test.dart`
- Modify: `test/modules/contacts/contacts_page_parity_test.dart`

- [ ] **Step 1: Write the failing slot and parity assertions**

```dart
test('contacts installer exposes Android header rows with localized labels', () {
  final registry = SlotRegistry();

  final items = resolveContactsHeaderMenus(
    registry,
    const ContactsHeaderSlotContext(pendingRequestCount: 9),
    openNewFriendsPage: () {},
    openSavedGroupsPage: () {},
  );

  expect(items.map((item) => item.text).toList(), <String>['新朋友', '保存的群聊']);
  expect(items.first.badgeNum, 9);
});
```

```dart
testWidgets('contacts page uses Android default header entries', (tester) async {
  await tester.pumpWidget(
    wrapWithApp(
      ContactsPage(
        friendsStateOverride: const AsyncValue.data(<Friend>[]),
        requestsStateOverride: AsyncValue.data([
          FriendRequest(id: 1, fromUid: 'u_1', status: 0),
          FriendRequest(id: 2, fromUid: 'u_2', status: 0),
        ]),
      ),
    ),
  );

  expect(find.text('新朋友'), findsOneWidget);
  expect(find.text('保存的群聊'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify they fail for the right reason**

Run: `flutter test test/modules/contacts/contacts_slot_assembly_test.dart test/modules/contacts/contacts_page_parity_test.dart`
Expected: FAIL because slot assembly still returns `New friends` / `Saved groups`, or because `contacts_page.dart` still hardcodes page-level strings outside the new resource layer

- [ ] **Step 3: Replace slot-assembly hardcoded labels**

```dart
import 'contacts_strings.dart';

void ensureContactsHeaderSlots(SlotRegistry registry) {
  final strings = resolveContactsStrings();
  if (!registry.containsId(contactsHeaderSlot, 'contacts.friend')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.friend',
        priority: 100,
        build: (context) => ContactsMenu(
          sid: 'friend',
          imgResource: WKReferenceAssets.newFriend,
          text: strings.newFriends,
          badgeNum: context.pendingRequestCount,
        ),
      ),
    );
  }
  if (!registry.containsId(contactsHeaderSlot, 'contacts.group')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.group',
        priority: 90,
        build: (_) => ContactsMenu(
          sid: 'group',
          imgResource: WKReferenceAssets.savedGroups,
          text: strings.savedGroups,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace contacts page strings that belong to the contacts domain**

```dart
@override
Widget build(BuildContext context) {
  final strings = resolveContactsStrings();
  final AsyncValue<List<Friend>> friendsState =
      widget.friendsStateOverride ?? ref.watch(friendListProvider);

  return Scaffold(
    backgroundColor: WKColors.homeBg,
    body: Column(
      children: [
        _buildHeader(strings),
        Expanded(
          child: friendsState.when(
            loading: () => WKLoadingView(message: strings.contactsLoading),
            error: (error, _) => WKErrorView(
              message: strings.contactsLoadFailed,
              subMessage: error.toString(),
              onRetry: () => ref.read(friendListProvider.notifier).refresh(),
            ),
            data: (friends) {
              final directory = _resolveDirectory(friends, directoryController);
              final entries = directory.sections
                  .expand((section) => section.entries)
                  .toList(growable: false);
              _syncContactPresence(entries);
              final header = _ContactsHeaderSection(
                headerMenus: resolvedHeaderMenus,
              );

              return ContactsListViewport(
                scrollController: _scrollController,
                header: header,
                directory: directory,
                contactPresenceByUid: widget.contactPresenceOverrides ?? const {},
                currentTimestampSeconds: currentTimestampSeconds,
                onTapEntry: (entry) => _openUserDetail(entry.friend.uid),
                onLongPressEntry: (entry) => _showContactMenu(entry.friend),
              );
            },
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Update the remark dialog and legacy page to read the shared resource object**

```dart
Widget _buildHeader(ContactsStrings strings) {
  return WKMainTopBar(
    title: Text(strings.contactsTitle),
    actions: [
      WKTopBarActionButton(
        tooltip: strings.searchPlaceholder,
        padding: const EdgeInsets.only(right: 29),
        onTap: _openGlobalSearch,
        child: WKReferenceAssets.image(
          WKReferenceAssets.search,
          width: 18,
          height: 18,
          tint: WKColors.popupText,
        ),
      ),
    ],
  );
}

Future<void> _showContactMenu(Friend friend) async {
  final strings = resolveContactsStrings();
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }

  final action = await showMenu<_ContactMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      overlay.size.width / 2,
      overlay.size.height / 3,
      overlay.size.width / 2,
      overlay.size.height / 3,
    ),
    items: [
      PopupMenuItem<_ContactMenuAction>(
        value: _ContactMenuAction.remark,
        child: Text(strings.setRemark),
      ),
      PopupMenuItem<_ContactMenuAction>(
        value: _ContactMenuAction.chat,
        child: Text(strings.sendMessage),
      ),
    ],
  );
}

final strings = resolveContactsStrings();
final remark = await showDialog<String>(
  context: context,
  builder: (dialogContext) {
    return AlertDialog(
      title: Text(strings.remarkDialogTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 20,
        decoration: InputDecoration(hintText: strings.remarkDialogHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(strings.save),
        ),
      ],
    );
  },
);
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/modules/contacts/contacts_slot_assembly_test.dart test/modules/contacts/contacts_page_parity_test.dart`
Expected: PASS with Android-aligned header labels and unchanged badge/callback behavior

- [ ] **Step 7: Commit**

```bash
git add lib/modules/contacts/contacts_slot_assembly.dart lib/modules/contacts/contacts_page.dart test/modules/contacts/contacts_slot_assembly_test.dart test/modules/contacts/contacts_page_parity_test.dart
git commit -m "refactor: route contacts header strings through resource layer"
```

### Task 3: Route New Friends, Create Group, And Viewport Strings Through The Resource Layer

**Files:**
- Modify: `lib/modules/contacts/new_friends_page.dart`
- Modify: `lib/modules/contacts/create_group_page.dart`
- Modify: `lib/modules/contacts/widgets/contacts_list_viewport.dart`
- Modify: `test/modules/contacts/new_friends_page_parity_test.dart`
- Modify: `test/modules/contacts/create_group_page_parity_test.dart`
- Modify: `test/modules/contacts/contacts_viewport_test.dart`

- [ ] **Step 1: Write the failing UI assertions for migrated strings**

```dart
testWidgets('new friends page matches Android row actions and status style', (tester) async {
  await tester.pumpWidget(
    wrapWithApp(
      NewFriendsPage(
        initialRequests: [buildPendingRequest(), buildAcceptedRequest()],
      ),
    ),
  );

  expect(find.text('新朋友'), findsOneWidget);
  expect(find.text('通过验证'), findsOneWidget);
  expect(find.text('已通过'), findsOneWidget);
});
```

```dart
testWidgets('create group page uses Android choose-contacts shell', (tester) async {
  List<Friend> buildFriends() => [
    Friend(uid: 'u_alice', name: 'Alice'),
    Friend(uid: 'u_bob', name: 'Bob'),
  ];

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: CreateGroupPage(initialFriends: buildFriends()),
      ),
    ),
  );

  expect(find.text('选择联系人'), findsOneWidget);
  expect(find.text('搜索'), findsOneWidget);
});
```

```dart
testWidgets('contacts list viewport shows empty state and repaint boundary', (tester) async {
  final directory = ContactsDirectoryData(
    sections: const [],
    letters: const [],
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ContactsListViewport(
        header: const Text('Header'),
        directory: directory,
        contactPresenceByUid: const <String, ContactPresenceState>{},
        currentTimestampSeconds: 0,
        onTapEntry: (_) {},
        onLongPressEntry: (_) {},
      ),
    ),
  );

  expect(find.text('暂无联系人'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify they fail if the pages still hardcode strings**

Run: `flutter test test/modules/contacts/new_friends_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart test/modules/contacts/contacts_viewport_test.dart`
Expected: FAIL if any touched file still uses contacts-domain hardcoded labels instead of the shared resource layer

- [ ] **Step 3: Replace new-friends page labels with `ContactsStrings`**

```dart
@override
Widget build(BuildContext context) {
  final strings = resolveContactsStrings();
  final AsyncValue<List<FriendRequest>> requestsState =
      widget.initialRequests != null
      ? AsyncValue<List<FriendRequest>>.data(widget.initialRequests!)
      : ref.watch(friendRequestListProvider);

  return WKSubPageScaffold(
    title: strings.newFriendsTitle,
    body: requestsState.when(
      loading: () => WKLoadingView(message: strings.newFriendsLoading),
      error: (error, _) => WKErrorView(
        message: strings.newFriendsLoadFailed,
        subMessage: error.toString(),
        onRetry: () => ref.read(friendRequestListProvider.notifier).refresh(),
      ),
      data: _buildContent,
    ),
  );
}

final subtitle = (request.extra ?? '').trim().isEmpty
    ? strings.requestAddFriend
    : request.extra!.trim();
```

- [ ] **Step 4: Replace create-group page labels with `ContactsStrings`**

```dart
@override
Widget build(BuildContext context) {
  final strings = resolveContactsStrings();
  final AsyncValue<List<Friend>> friendsState = widget.initialFriends != null
      ? AsyncValue<List<Friend>>.data(widget.initialFriends!)
      : ref.watch(friendListProvider);

  return WKSubPageScaffold(
    title: strings.selectContactsTitle,
    trailing: _selectedUids.isEmpty
        ? const SizedBox(key: ValueKey('empty-action'))
        : WKSubPageAction(
            key: ValueKey('submit-${_selectedUids.length}'),
            text: strings.confirmWithCount(_selectedUids.length),
            onTap: _submit,
          ),
    body: friendsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(strings.contactsLoadFailedMessage(error), textAlign: TextAlign.center),
        ),
      ),
      data: _buildContent,
    ),
  );
}

decoration: InputDecoration(
  border: InputBorder.none,
  hintText: strings.searchPlaceholder,
  hintStyle: const TextStyle(fontSize: 14, color: WKColors.color999),
  isCollapsed: true,
  contentPadding: const EdgeInsets.symmetric(vertical: 10),
),
```

- [ ] **Step 5: Replace contacts viewport empty-state and count labels**

```dart
@override
Widget build(BuildContext context) {
  final strings = resolveContactsStrings();
  final entries = directory.sections
      .expand((section) => section.entries)
      .toList(growable: false);

  return RepaintBoundary(
    key: const ValueKey('contacts-list-viewport-repaint'),
    child: ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        header,
        if (entries.isEmpty) ...[
          const SizedBox(height: 120),
          WKEmptyView(
            icon: Icons.people_outline_rounded,
            message: strings.contactsEmpty,
            subMessage: strings.contactsEmptyHint,
          ),
        ] else ...[
          Container(
            color: WKColors.homeBg,
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            child: Text(
              strings.contactsCount(entries.length),
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 16,
                color: WKColors.colorDark,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/modules/contacts/new_friends_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart test/modules/contacts/contacts_viewport_test.dart`
Expected: PASS with unchanged Android wording and interaction behavior

- [ ] **Step 7: Commit**

```bash
git add lib/modules/contacts/new_friends_page.dart lib/modules/contacts/create_group_page.dart lib/modules/contacts/widgets/contacts_list_viewport.dart test/modules/contacts/new_friends_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart test/modules/contacts/contacts_viewport_test.dart
git commit -m "refactor: migrate contacts pages to shared strings"
```

### Task 4: Verify The Contacts Strings Refactor End-To-End

**Files:**
- Verify only

- [ ] **Step 1: Run the focused contacts strings suite**

Run: `flutter test test/modules/contacts/contacts_strings_test.dart test/modules/contacts/contacts_slot_assembly_test.dart test/modules/contacts/contacts_page_parity_test.dart test/modules/contacts/new_friends_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart test/modules/contacts/contacts_viewport_test.dart`
Expected: PASS with Android-aligned labels and contacts-domain regressions covered

- [ ] **Step 2: Run the broader contacts suite**

Run: `flutter test test/modules/contacts`
Expected: PASS with no regressions in directory, presence, filter, or viewport behavior

- [ ] **Step 3: Run analyzer on touched contacts files**

Run: `flutter analyze lib/modules/contacts test/modules/contacts`
Expected: `No issues found!`

- [ ] **Step 4: Perform a manual smoke check on the desktop build**

Run: `flutter run -d windows`
Expected:
- contacts top title shows `通讯录`
- default contacts header entries show `新朋友` and `保存的群聊`
- new friends page title and actions still show Android wording
- create group page title, search field, and confirm button still show Android wording
- no navigation or badge behavior changes

- [ ] **Step 5: Record the final checkpoint**

```bash
git add lib/modules/contacts test/modules/contacts docs/superpowers/specs/2026-04-05-contacts-strings-resource-layer-design.md docs/superpowers/plans/2026-04-05-contacts-strings-resource-layer.md
git commit -m "refactor: align contacts strings through shared resource layer"
```
