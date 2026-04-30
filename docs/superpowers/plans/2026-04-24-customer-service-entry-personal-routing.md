# Customer Service Entry Personal Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route the customer-service entry to a normal personal chat when the server resolves a real customer-service account UID, while preserving the legacy placeholder fallback on `WKChannelType.customerService`.

**Architecture:** The fix stays entirely in the Flutter client. `ContactsPage` already resolves customer-service accounts through `/v1/user/customerservices`; the only runtime change is selecting `WKChannelType.personal` for resolved real-account routes and keeping `WKChannelType.customerService` only for the placeholder `customer_service` fallback. Regression coverage is added in the existing contacts parity test file so both branches stay locked.

**Tech Stack:** Flutter, Dart, flutter_test, Riverpod, Dio, WKIM SDK

---

## File Structure And Ownership

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\contacts_page.dart`
  Responsibility: decide which channel type to use when opening the customer-service entry
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`
  Responsibility: verify resolved account routing uses `WKChannelType.personal` and legacy fallback keeps `WKChannelType.customerService`

## Task 1: Lock The Routing Behavior With Failing Tests

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`

- [ ] **Step 1: Write the failing resolved-account routing test**

Add this test near the existing customer-service entry tests in `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`:

```dart
  testWidgets(
    'contacts page opens resolved customer-service account as personal chat',
    (tester) async {
      final adapter = _RecordingJsonAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'cs_001', 'name': '售后客服'},
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      String? openedChannelId;
      int? openedChannelType;
      String? openedChannelName;

      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            onOpenResolvedCustomerService: (_) {},
            onOpenContactChat: null,
          ),
        ),
      );

      final state = tester.state<_ContactsPageState>(find.byType(ContactsPage));
      state._openCustomerServiceChat = ({
        required String channelId,
        required String channelName,
        CustomerServiceAccount? resolvedService,
      }) {
        openedChannelId = channelId;
        openedChannelType = resolvedService == null
            ? WKChannelType.customerService
            : WKChannelType.personal;
        openedChannelName = channelName;
      };

      await tester.tap(
        find.byKey(const ValueKey('contacts-header-customer_service')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(adapter.lastRequestOptions?.path, '/v1/user/customerservices');
      expect(openedChannelId, 'cs_001');
      expect(openedChannelType, WKChannelType.personal);
      expect(openedChannelName, '售后客服');
    },
  );
```

- [ ] **Step 2: Replace the above test with a public-behavior version that does not mutate private state**

Use this final failing test instead, still in `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`:

```dart
  testWidgets(
    'contacts page resolves customer-service account using direct personal routing semantics',
    (tester) async {
      final adapter = _RecordingJsonAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'cs_001', 'name': '售后客服'},
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      CustomerServiceAccount? openedService;

      await tester.pumpWidget(
        wrapWithApp(
          ContactsPage(
            friendsStateOverride: const AsyncValue.data(<Friend>[]),
            requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            onOpenResolvedCustomerService: (service) {
              openedService = service;
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('contacts-header-customer_service')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(adapter.lastRequestOptions?.path, '/v1/user/customerservices');
      expect(openedService?.uid, 'cs_001');
      expect(openedService?.name, '售后客服');
    },
  );
```

Then add the actual route-type assertions by introducing a local route capture helper test directly below it:

```dart
  testWidgets(
    'contacts page pushes resolved customer-service account as personal chat route',
    (tester) async {
      final adapter = _RecordingJsonAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{'uid': 'cs_001', 'name': '售后客服'},
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      late _RecordingNavigatorObserver observer;

      observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              return _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'u_self', name: 'Self', vipLevel: 1),
                ),
              );
            }),
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            home: ContactsPage(
              friendsStateOverride: const AsyncValue.data(<Friend>[]),
              requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('contacts-header-customer_service')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final chatPage = observer.lastPushedChatPage;
      expect(chatPage, isNotNull);
      expect(chatPage!.channelId, 'cs_001');
      expect(chatPage.channelType, WKChannelType.personal);
      expect(chatPage.channelName, '售后客服');
    },
  );
```

- [ ] **Step 3: Write the failing legacy fallback routing test**

Add this test in the same file:

```dart
  testWidgets(
    'contacts page keeps legacy placeholder customer-service route on fallback',
    (tester) async {
      ApiClient.instance.dio.httpClientAdapter = _FailingJsonAdapter();
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              return _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'u_self', name: 'Self', vipLevel: 1),
                ),
              );
            }),
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
          ],
          child: MaterialApp(
            navigatorObservers: [observer],
            home: ContactsPage(
              friendsStateOverride: const AsyncValue.data(<Friend>[]),
              requestsStateOverride: const AsyncValue.data(<FriendRequest>[]),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('contacts-header-customer_service')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final chatPage = observer.lastPushedChatPage;
      expect(chatPage, isNotNull);
      expect(chatPage!.channelId, 'customer_service');
      expect(chatPage.channelType, WKChannelType.customerService);
      expect(chatPage.channelName, '客服');
    },
  );
```

- [ ] **Step 4: Add the failing test helpers**

Add these helper classes at the bottom of `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`:

```dart
class _FailingJsonAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      error: 'network failed',
      type: DioExceptionType.unknown,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  ChatPage? lastPushedChatPage;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final settings = route.settings;
    final arguments = settings.arguments;
    if (route is MaterialPageRoute && route.builder != null) {
      final built = route.builder(route.navigator!.context);
      if (built is ChatPage) {
        lastPushedChatPage = built;
      }
    } else if (arguments is ChatPage) {
      lastPushedChatPage = arguments;
    }
    super.didPush(route, previousRoute);
  }
}
```

- [ ] **Step 5: Run the targeted contacts parity tests to verify they fail**

Run:

```powershell
flutter test test\modules\contacts\contacts_page_parity_test.dart
```

Expected:

- FAIL because the resolved-customer-service route still pushes
  `WKChannelType.customerService`
- the legacy fallback test may already pass

- [ ] **Step 6: Commit only the failing-test scaffolding if the repo convention requires it**

Run:

```powershell
git diff -- test\modules\contacts\contacts_page_parity_test.dart
```

Expected:

- Shows only the new routing regression tests and helpers
- Do not commit yet if the repo convention prefers red-green within one commit

## Task 2: Implement The Minimal Routing Fix

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\contacts_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`

- [ ] **Step 1: Implement the route-type resolver in the customer-service entry**

In `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\contacts_page.dart`,
replace `_openCustomerServiceChat` with this implementation:

```dart
  void _openCustomerServiceChat({
    required String channelId,
    required String channelName,
    CustomerServiceAccount? resolvedService,
  }) {
    final service =
        resolvedService ??
        CustomerServiceAccount(uid: channelId, name: channelName);
    final onOpenResolvedCustomerService = widget.onOpenResolvedCustomerService;
    if (onOpenResolvedCustomerService != null) {
      onOpenResolvedCustomerService(service);
      return;
    }

    final normalizedChannelId = channelId.trim();
    final isLegacyPlaceholder = normalizedChannelId == 'customer_service';
    final resolvedChannelType = isLegacyPlaceholder
        ? WKChannelType.customerService
        : WKChannelType.personal;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: normalizedChannelId,
          channelType: resolvedChannelType,
          channelName: channelName,
        ),
      ),
    );
  }
```

- [ ] **Step 2: Keep the legacy fallback explicit**

In the same file, keep `_openLegacyCustomerService()` in this form:

```dart
  void _openLegacyCustomerService() {
    _openCustomerServiceChat(
      channelId: 'customer_service',
      channelName: '客服',
      resolvedService: const CustomerServiceAccount(
        uid: 'customer_service',
        name: '客服',
      ),
    );
  }
```

Do not remove the legacy placeholder fallback.

- [ ] **Step 3: Fix the test helper to capture pushed chat pages safely**

If the first helper version is brittle, update `_RecordingNavigatorObserver` in
`C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`
to this exact version:

```dart
class _RecordingNavigatorObserver extends NavigatorObserver {
  ChatPage? lastPushedChatPage;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final widget = route.settings is MaterialPageRoute
        ? null
        : null;
    super.didPush(route, previousRoute);
  }
}
```

Then replace it with a simpler route capture by wrapping `Navigator.onGenerateRoute`
if needed. The preferred final helper is:

```dart
class _ChatRouteCaptureApp extends StatelessWidget {
  const _ChatRouteCaptureApp({
    required this.home,
    required this.onOpenChat,
  });

  final Widget home;
  final void Function(ChatPage page) onOpenChat;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: (settings) {
        final builder = settings is MaterialPageRoute ? settings.builder : null;
        if (builder != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              final child = builder(context);
              if (child is ChatPage) {
                onOpenChat(child);
              }
              return child;
            },
          );
        }
        return MaterialPageRoute(builder: (_) => home);
      },
      home: home,
    );
  }
}
```

Use the smallest helper that actually works with the existing test harness.

- [ ] **Step 4: Run the targeted contacts parity tests to verify they pass**

Run:

```powershell
flutter test test\modules\contacts\contacts_page_parity_test.dart
```

Expected:

- PASS
- the resolved route now opens `WKChannelType.personal`
- the legacy fallback still opens `WKChannelType.customerService`

- [ ] **Step 5: Run a narrow static analysis pass on the changed file**

Run:

```powershell
dart analyze lib\modules\contacts\contacts_page.dart test\modules\contacts\contacts_page_parity_test.dart
```

Expected:

- No analyzer errors for the changed files

- [ ] **Step 6: Commit only the routing fix and tests**

Run:

```powershell
git add -- lib\modules\contacts\contacts_page.dart test\modules\contacts\contacts_page_parity_test.dart
git commit -m "fix: route resolved customer service chats as personal conversations"
```

Expected:

- Creates one commit containing only the customer-service entry route fix and
  regression tests

## Self-Review

- Spec coverage:
  - resolved real customer-service account opens as `personal`: covered in Task 1 and Task 2
  - legacy `customer_service` fallback remains on `customerService`: covered in Task 1 and Task 2
  - no server contract changes: preserved by limiting file scope to Flutter entry routing and tests
- Placeholder scan:
  - no `TODO`, `TBD`, or deferred implementation markers remain
- Type consistency:
  - route decision uses existing `ChatPage`, `CustomerServiceAccount`, `WKChannelType.personal`, and `WKChannelType.customerService`
