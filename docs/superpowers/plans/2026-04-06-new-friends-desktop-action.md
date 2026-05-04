# New Friends Desktop Action Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the actionable approval control for pending friend requests on the desktop `NewFriendsPage`, then verify the full desktop accept-and-refresh flow end to end.

**Architecture:** Keep the current `NewFriendsPage` data flow and provider behavior intact, but replace the fragile action rendering on the row with a deterministic custom action widget that renders consistently on Windows desktop. Lock the regression down with widget tests that prove a pending request shows an approval control and an approved request shows the processed label.

**Tech Stack:** Flutter, Riverpod, flutter_test

---

### Task 1: Capture the Regression With Widget Tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\contacts\new_friends_page_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('renders approve action for pending request', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendListProvider.overrideWith(
          () => _FakeFriendListNotifier(const AsyncValue.data(<Friend>[])),
        ),
      ],
      child: const MaterialApp(
        home: NewFriendsPage(
          initialRequests: <FriendRequest>[
            FriendRequest(
              id: 1,
              fromUid: 'pending-user',
              fromName: 'pending-user',
              status: 0,
              token: 'pending-token',
            ),
          ],
        ),
      ),
    ),
  );

  expect(find.text('通过验证'), findsOneWidget);
});

testWidgets('renders processed label for accepted request', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendListProvider.overrideWith(
          () => _FakeFriendListNotifier(const AsyncValue.data(<Friend>[])),
        ),
      ],
      child: const MaterialApp(
        home: NewFriendsPage(
          initialRequests: <FriendRequest>[
            FriendRequest(
              id: 2,
              fromUid: 'accepted-user',
              fromName: 'accepted-user',
              status: 1,
            ),
          ],
        ),
      ),
    ),
  );

  expect(find.text('已通过'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/modules/contacts/new_friends_page_test.dart`
Expected: FAIL on the pending-request action assertion.

- [ ] **Step 3: Add minimal test scaffolding**

```dart
class _FakeFriendListNotifier extends FriendListNotifier {
  _FakeFriendListNotifier(AsyncValue<List<Friend>> value) : super() {
    state = value;
  }

  @override
  Future<void> loadFriends() async {}
}
```

- [ ] **Step 4: Re-run the test and confirm only the action rendering is failing**

Run: `flutter test test/modules/contacts/new_friends_page_test.dart`
Expected: still FAIL, now specifically on the missing pending action UI.

### Task 2: Make Desktop Action Rendering Deterministic

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\contacts\new_friends_page.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\contacts\new_friends_page_test.dart`

- [ ] **Step 1: Replace the row action control with a custom action widget**

```dart
Widget _buildAction() {
  if (isProcessed) {
    return Text(
      strings.processed,
      style: const TextStyle(
        fontFamily: WKFontFamily.primary,
        fontSize: 14,
        color: WKColors.color999,
      ),
    );
  }

  final enabled = onApprove != null;
  return Semantics(
    button: true,
    enabled: enabled,
    label: isHandling ? strings.processing : strings.approve,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onApprove,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: enabled ? WKColors.brand500 : WKColors.brand300,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            isHandling ? strings.processing : strings.approve,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              color: WKColors.white,
            ),
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Use the custom action widget inside `_NewFriendRow`**

```dart
const SizedBox(width: 10),
_buildAction(),
```

- [ ] **Step 3: Run the focused widget test**

Run: `flutter test test/modules/contacts/new_friends_page_test.dart`
Expected: PASS

### Task 3: Verify No Contact-Flow Regressions

**Files:**
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\contacts\new_friends_page_test.dart`
- Test: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\service\im\im_service_test.dart`

- [ ] **Step 1: Run the contact-page regression test set**

Run: `flutter test test/modules/contacts/new_friends_page_test.dart`
Expected: PASS

- [ ] **Step 2: Re-run the IM side-effect regression test**

Run: `flutter test test/service/im/im_service_test.dart`
Expected: PASS

### Task 4: Re-run the Live Desktop Acceptance Flow

**Files:**
- Runtime only

- [ ] **Step 1: Relaunch the Windows app with the corrected PC token**

Run: `flutter run -d windows`
Expected: app reaches the message list without `Retry`.

- [ ] **Step 2: Open `通讯录 -> 新朋友` and confirm the approval control is visible**

Expected: pending request for `autotest_c_1775463925` shows `通过验证`.

- [ ] **Step 3: Click `通过验证` and wait for request handling to finish**

Expected: request row changes to `已通过` or disappears after reload.

- [ ] **Step 4: Return to the contacts list and verify the new contact appears without manual refresh**

Expected: `autotest_c_1775463925` is present in the contacts list.

- [ ] **Step 5: Confirm backend state**

Run: `curl`/`Invoke-RestMethod` against `/v1/friend/apply` and `/v1/friend/sync`
Expected: request no longer pending and friend sync includes the new contact.
