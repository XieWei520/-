# Flutter VIP Stage 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Flutter-side VIP awareness, passive expiry handling, VIP badge/UI entry points, and non-VIP access interception for add-friend and create-group flows.

**Architecture:** Keep `authProvider.userInfo` as the single source of truth for the current logged-in user's VIP state. Reuse the existing IM CMD dispatch path in `IMService` for `vip_expired`, and add a small shared VIP presentation/guard layer so the UI, dialogs, and route interception stay consistent across pages.

**Tech Stack:** Flutter, Riverpod, existing `IMService`, Material routing, widget tests, model/unit tests.

---

## File Structure

**Create**
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_guard.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_badge.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_management_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\vip\vip_guard_test.dart`

**Modify**
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\user.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\user\user_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\my_info_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_detail_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\search\add_friends_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\search\mail_list_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\create_group_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\new_friends_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\saved_groups_page.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\friend_model_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\providers\auth_provider_session_refresh_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\service\im\im_service_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\user_page_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\my_info_page_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\user_detail_page_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\search\add_friends_page_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\search\mail_list_page_parity_test.dart`
- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\contacts\create_group_page_parity_test.dart`

## Task 1: User Model And Shared VIP Utilities

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_guard.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_badge.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\user.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\friend_model_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\vip\vip_guard_test.dart`

- [ ] **Step 1: Add model-level failing tests for `vip_level` parse/copy**

```dart
test('parses vip level from user payload', () {
  final user = UserInfo.fromJson({'uid': 'vip_user', 'vip_level': 1});

  expect(user.vipLevel, 1);
  expect(user.isVip, isTrue);
});

test('copyWith can downgrade vip level', () {
  final user = UserInfo(uid: 'vip_user', vipLevel: 1);

  final downgraded = user.copyWith(vipLevel: 0);

  expect(downgraded.vipLevel, 0);
  expect(downgraded.isVip, isFalse);
});
```

- [ ] **Step 2: Run model test to verify it fails**

Run: `flutter test test/data/models/friend_model_test.dart`
Expected: FAIL because `vipLevel` and `isVip` do not exist yet.

- [ ] **Step 3: Implement `vip_level` parsing/storage and shared VIP helpers**

```dart
class UserInfo {
  final int vipLevel;

  bool get isVip => vipLevel == 1;

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      uid: json['uid']?.toString() ?? '',
      vipLevel: _parseInt(json['vip_level']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'vip_level': vipLevel,
    };
  }

  UserInfo copyWith({
    int? vipLevel,
  }) {
    return UserInfo(
      uid: uid,
      vipLevel: vipLevel ?? this.vipLevel,
    );
  }
}
```

```dart
const String vipCustomerServiceUid = 'system_kefu';
const String vipRequiredMessage = '该功能仅限商家可用，请联系管理员';

bool isVipUser(UserInfo? user) => (user?.vipLevel ?? 0) == 1;
```

- [ ] **Step 4: Add a small badge widget test surface**

```dart
testWidgets('vip badge renders label when enabled', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: VipBadge(label: 'VIP/商家')),
    ),
  );

  expect(find.text('VIP/商家'), findsOneWidget);
});
```

- [ ] **Step 5: Run the focused tests**

Run: `flutter test test/data/models/friend_model_test.dart test/modules/vip/vip_guard_test.dart`
Expected: PASS.

## Task 2: IM CMD Expiry Handling Through Existing Auth State

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\service\im\im_service_test.dart`

- [ ] **Step 1: Add failing tests for VIP expiry detection and downgrade**

```dart
test('resolveImCommandSideEffects ignores vip_expired side effects', () {
  expect(resolveImCommandSideEffects('vip_expired'), isEmpty);
});

test('service can downgrade current user from vip_expired command', () async {
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith((ref) => _SeededAuthNotifier(ref, vipLevel: 1)),
    ],
  );
  addTearDown(container.dispose);

  final service = IMService(
    readProvider: container.read,
  );

  await (service as dynamic).handleVipExpiredForTesting();

  expect(container.read(authProvider).userInfo?.vipLevel, 0);
});
```

- [ ] **Step 2: Run IM service test to verify it fails**

Run: `flutter test test/service/im/im_service_test.dart`
Expected: FAIL because the helper or downgrade path does not exist yet.

- [ ] **Step 3: Wire `vip_expired` into `_handleCmd` via the existing command path**

```dart
void _handleCmd(WKCMD cmd) {
  if (cmd.cmd.trim() == 'vip_expired') {
    _downgradeCurrentVipUser();
  }

  final effects = resolveImCommandSideEffects(cmd.cmd);
  ...
}

void _downgradeCurrentVipUser() {
  final read = _readProvider;
  if (read == null) {
    return;
  }
  final authNotifier = read(authProvider.notifier);
  final current = read(authProvider).userInfo;
  if (current == null || current.vipLevel == 0) {
    return;
  }
  authNotifier.updateCurrentUser(current.copyWith(vipLevel: 0));
}
```

- [ ] **Step 4: Expose only the minimal test hook if direct callback invocation is needed**

```dart
@visibleForTesting
void handleVipExpiredForTesting() {
  _downgradeCurrentVipUser();
}
```

- [ ] **Step 5: Re-run the focused IM tests**

Run: `flutter test test/service/im/im_service_test.dart`
Expected: PASS.

## Task 3: VIP Badge, Profile Entry, And Management Placeholder Page

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_management_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\user\user_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\my_info_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_detail_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\user_page_parity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\my_info_page_parity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\user\user_detail_page_parity_test.dart`

- [ ] **Step 1: Add failing widget tests for VIP badge and management entry**

```dart
testWidgets('user page shows management entry for vip user', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _seededAuthNotifier(vipLevel: 1)),
      ],
      child: const MaterialApp(home: UserPage()),
    ),
  );

  expect(find.text('管理系统'), findsOneWidget);
  expect(find.text('VIP/商家'), findsOneWidget);
});
```

- [ ] **Step 2: Run user/profile widget tests to verify they fail**

Run: `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/my_info_page_parity_test.dart test/modules/user/user_detail_page_parity_test.dart`
Expected: FAIL because the badge and placeholder route do not exist yet.

- [ ] **Step 3: Implement the placeholder page and inject VIP visuals**

```dart
class VipManagementPage extends StatelessWidget {
  const VipManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const WKSubPageScaffold(
      title: '管理系统',
      body: Center(child: Text('管理系统功能建设中')),
    );
  }
}
```

```dart
if ((userInfo?.vipLevel ?? 0) == 1)
  _UserMenuItem(
    sid: 'vip_management',
    iconAsset: '',
    title: '管理系统',
    onTap: () => _pushPage(const VipManagementPage()),
  ),
```

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(name),
    if (isVip) const SizedBox(width: 8),
    if (isVip) const VipBadge(label: 'VIP/商家'),
  ],
)
```

- [ ] **Step 4: Re-run the targeted user/profile widget tests**

Run: `flutter test test/modules/user/user_page_parity_test.dart test/modules/user/my_info_page_parity_test.dart test/modules/user/user_detail_page_parity_test.dart`
Expected: PASS.

## Task 4: Add-Friend / Create-Group VIP Guard And Customer-Service Routing

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\vip\vip_guard.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\search\add_friends_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\search\mail_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_detail_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\create_group_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\contacts_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\new_friends_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\saved_groups_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\search\add_friends_page_parity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\search\mail_list_page_parity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\contacts\create_group_page_parity_test.dart`

- [ ] **Step 1: Add failing tests for non-VIP interception**

```dart
testWidgets('search user apply is blocked for non vip', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _seededAuthNotifier(vipLevel: 0)),
      ],
      child: MaterialApp(
        home: SearchUserPage(
          onSearchUsers: (_) async => [User(uid: 'u_alice', name: 'Alice')],
          onLoadLocalChannel: (_, __) async => null,
        ),
      ),
    ),
  );

  await tester.enterText(find.byType(TextField), 'alice');
  await tester.tap(find.byKey(const ValueKey('search-user-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('申请'));
  await tester.pumpAndSettle();

  expect(find.text('该功能仅限商家可用，请联系管理员'), findsOneWidget);
  expect(find.text('联系管理员'), findsOneWidget);
});
```

- [ ] **Step 2: Run add-friend/create-group widget tests to verify failure**

Run: `flutter test test/wukong_uikit/search/add_friends_page_parity_test.dart test/wukong_uikit/search/mail_list_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart`
Expected: FAIL because the guard is not implemented.

- [ ] **Step 3: Implement a reusable guard dialog and customer-service jump**

```dart
Future<bool> guardVipFeature(
  BuildContext context, {
  required WidgetRef ref,
  required String feature,
}) async {
  final user = ref.read(authProvider).userInfo;
  if (isVipUser(user)) {
    return true;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('提示'),
      content: const Text(vipRequiredMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('联系管理员'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatPage(
          channelId: vipCustomerServiceUid,
          channelType: WKChannelType.personal,
          channelName: '管理员',
        ),
      ),
    );
  }
  return false;
}
```

- [ ] **Step 4: Apply the guard at both route-entry and action-submit layers**

```dart
Future<void> _openAddFriendPage() async {
  final allowed = await guardVipFeature(context, ref: ref, feature: 'add_friend');
  if (!allowed || !mounted) {
    return;
  }
  await Navigator.of(context).push(...);
}
```

```dart
Future<void> _applyUser(User user) async {
  final allowed = await guardVipFeature(context, ref: ref, feature: 'add_friend');
  if (!allowed) {
    return;
  }
  await FriendApi.instance.addFriend(...);
}
```

```dart
Future<void> _submit() async {
  final allowed = await guardVipFeature(context, ref: ref, feature: 'create_group');
  if (!allowed) {
    return;
  }
  ...
}
```

- [ ] **Step 5: Re-run the focused guard tests**

Run: `flutter test test/wukong_uikit/search/add_friends_page_parity_test.dart test/wukong_uikit/search/mail_list_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart`
Expected: PASS.

## Task 5: Full Focused Verification

**Files:**
- Review all files changed in Tasks 1-4.

- [ ] **Step 1: Run the Stage 3 focused test batch**

Run: `flutter test test/data/models/friend_model_test.dart test/data/providers/auth_provider_session_refresh_test.dart test/service/im/im_service_test.dart test/modules/user/user_page_parity_test.dart test/modules/user/my_info_page_parity_test.dart test/modules/user/user_detail_page_parity_test.dart test/wukong_uikit/search/add_friends_page_parity_test.dart test/wukong_uikit/search/mail_list_page_parity_test.dart test/modules/contacts/create_group_page_parity_test.dart test/modules/vip/vip_guard_test.dart`
Expected: PASS with zero failures.

- [ ] **Step 2: Run a compile/build-oriented smoke suite**

Run: `flutter test test/modules/profile/profile_pages_compile_test.dart test/modules/settings/settings_pages_compile_test.dart test/modules/shell/main_pages_compile_test.dart`
Expected: PASS.

- [ ] **Step 3: Run a wider static sanity check**

Run: `flutter analyze`
Expected: exit code 0. If the repository has unrelated pre-existing warnings, record the exact output instead of claiming a clean analyze run.

- [ ] **Step 4: Manual checklist**

Run through:
- Login as VIP user and confirm “我的”页出现“管理系统”入口。
- Simulate `vip_expired` and confirm badge、入口、拦截状态同步降级。
- Login as non-VIP and confirm添加好友/发起群聊被拦截，点击“联系管理员”进入 `system_kefu` 单聊。

## Self-Review Checklist

- Spec coverage:
  - `vip_level` parsing/storage covered in Task 1.
  - `vip_expired` CMD downgrade covered in Task 2.
  - badge + management entry + placeholder page covered in Task 3.
  - add-friend/create-group interception + `system_kefu` routing covered in Task 4.
- Placeholder scan:
  - No TODO/TBD markers remain in this plan.
- Type consistency:
  - Use `vipLevel`, `isVipUser`, `vipRequiredMessage`, and `vipCustomerServiceUid` consistently across tasks.
