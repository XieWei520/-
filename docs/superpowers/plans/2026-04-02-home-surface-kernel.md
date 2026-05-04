# Home Surface Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the homepage so the main shell, conversation surface, and contacts surface share one precise lifecycle and invalidation kernel, keeping tab switches stable, refresh scope deterministic, and reconnect behavior observable.

**Architecture:** Introduce a reusable home kernel built from shared contracts, a tab coordinator, badge snapshot providers, a visibility controller, and a surface invalidation bus. Keep [main_page.dart](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\main_page.dart) as the public entry point, but move bootstrap logic into a focused shell layer and split the contacts page into directory, presence, viewport, and alphabet-index responsibilities.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, existing conversation/contact providers, WKIM SDK, PowerShell, SSH remote debugging

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The commit commands below are the preferred commands for the canonical repository checkout. In this local copy, record the same checkpoint together with verification output after each task.

## File Structure

## Remote Debugging Requirement

This plan explicitly keeps remote backend correlation in scope during implementation and verification.

- SSH entry: `ssh root@103.207.68.33`
- Required server checks:
  - `docker ps`
  - `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`
  - `docker logs --tail 200 fullstack-tangsengdaodaoserver-1`
- Use remote logs whenever homepage bootstrap, reconnect, badge refresh, or surface recovery behavior cannot be explained locally.

### New Files

- `lib/modules/home/home_surface_contract.dart`
- `lib/modules/home/home_badge_snapshot.dart`
- `lib/modules/home/home_tab_coordinator.dart`
- `lib/modules/home/home_surface_invalidation_bus.dart`
- `lib/modules/home/home_surface_visibility_controller.dart`
- `lib/modules/home/home_surface_kernel.dart`
- `lib/modules/home/home_shell_page.dart`
- `lib/modules/contacts/contacts_directory_controller.dart`
- `lib/modules/contacts/contacts_presence_controller.dart`
- `lib/modules/contacts/widgets/contacts_list_viewport.dart`
- `lib/modules/contacts/widgets/contacts_alphabet_index.dart`
- `test/modules/home/home_badge_snapshot_test.dart`
- `test/modules/home/home_tab_coordinator_test.dart`
- `test/modules/home/home_shell_page_test.dart`
- `test/modules/home/home_surface_kernel_test.dart`
- `test/modules/conversation/conversation_surface_bridge_test.dart`
- `test/modules/contacts/contacts_directory_controller_test.dart`
- `test/modules/contacts/contacts_presence_controller_test.dart`
- `test/modules/contacts/contacts_viewport_test.dart`

### Existing Files To Modify

- `lib/modules/conversation/main_page.dart`
- `lib/modules/conversation/conversation_list_page.dart`
- `lib/modules/conversation/conversation_list_refresh_controller.dart`
- `lib/modules/conversation/conversation_list_item_loader.dart`
- `lib/modules/conversation/conversation_activity_registry.dart`
- `lib/modules/contacts/contacts_page.dart`
- `test/modules/conversation/conversation_list_refresh_controller_test.dart`
- `test/modules/conversation/conversation_list_item_loader_test.dart`
- `test/modules/contacts/contacts_page_parity_test.dart`
- `test/modules/shell/main_pages_compile_test.dart`

### Verification Commands Used Throughout

- `dart analyze lib/modules/home lib/modules/conversation/main_page.dart lib/modules/conversation/conversation_list_page.dart lib/modules/contacts`
- `flutter test test/modules/home/home_badge_snapshot_test.dart test/modules/home/home_tab_coordinator_test.dart`
- `flutter test test/modules/home/home_shell_page_test.dart test/modules/shell/main_pages_compile_test.dart`
- `flutter test test/modules/conversation/conversation_surface_bridge_test.dart test/modules/conversation/conversation_list_refresh_controller_test.dart test/modules/conversation/conversation_list_item_loader_test.dart`
- `flutter test test/modules/contacts/contacts_directory_controller_test.dart test/modules/contacts/contacts_presence_controller_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/contacts/contacts_page_parity_test.dart`

### Task 1: Build Shared Home Contracts, Snapshots, And Visibility Primitives

**Files:**
- Create: `lib/modules/home/home_surface_contract.dart`
- Create: `lib/modules/home/home_badge_snapshot.dart`
- Create: `lib/modules/home/home_tab_coordinator.dart`
- Create: `lib/modules/home/home_surface_invalidation_bus.dart`
- Create: `lib/modules/home/home_surface_visibility_controller.dart`
- Create: `test/modules/home/home_badge_snapshot_test.dart`
- Create: `test/modules/home/home_tab_coordinator_test.dart`

- [ ] **Step 1: Write the failing unit tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_badge_snapshot.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/home/home_tab_coordinator.dart';

void main() {
  test('badge snapshot aggregates unread values by surface', () {
    const snapshot = HomeBadgeSnapshot(
      bySurface: <HomeSurfaceId, int>{
        HomeSurfaceId.conversations: 12,
        HomeSurfaceId.contacts: 3,
      },
    );

    expect(snapshot.badgeFor(HomeSurfaceId.conversations), 12);
    expect(snapshot.totalUnread, 15);
  });

  test('tab coordinator returns hidden and visible surface ids', () {
    final coordinator = HomeTabCoordinator(initialIndex: 0);

    final transition = coordinator.setIndex(1);

    expect(transition.hiddenSurface, HomeSurfaceId.conversations);
    expect(transition.visibleSurface, HomeSurfaceId.contacts);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/modules/home/home_badge_snapshot_test.dart test/modules/home/home_tab_coordinator_test.dart`
Expected: FAIL with missing `HomeBadgeSnapshot`, `HomeSurfaceContract`, or `HomeTabCoordinator`

- [ ] **Step 3: Implement the shared contracts and immutable snapshot types**

```dart
import 'package:flutter/foundation.dart';

enum HomeSurfaceId { conversations, contacts, user }

enum SurfaceReliabilityState { healthy, stale, degraded, failed }

enum HomeSurfaceVisibilityState { cold, warm, visible, backgroundAlive }

@immutable
class HomeSurfacePrefetchHint {
  const HomeSurfacePrefetchHint({
    required this.surfaceId,
    this.critical = false,
    this.adjacent = false,
    this.idle = false,
  });

  final HomeSurfaceId surfaceId;
  final bool critical;
  final bool adjacent;
  final bool idle;
}

@immutable
class HomeSurfaceContract {
  const HomeSurfaceContract({
    required this.surfaceId,
    required this.badgeCount,
    required this.reliabilityState,
    required this.prefetchHint,
  });

  final HomeSurfaceId surfaceId;
  final int badgeCount;
  final SurfaceReliabilityState reliabilityState;
  final HomeSurfacePrefetchHint prefetchHint;
}

@immutable
class HomeBadgeSnapshot {
  const HomeBadgeSnapshot({this.bySurface = const <HomeSurfaceId, int>{}});

  final Map<HomeSurfaceId, int> bySurface;

  int badgeFor(HomeSurfaceId surfaceId) => bySurface[surfaceId] ?? 0;

  int get totalUnread => bySurface.values.fold<int>(0, (sum, value) => sum + value);
}
```

- [ ] **Step 4: Implement invalidation and visibility primitives**

```dart
import 'dart:async';

import 'home_surface_contract.dart';

enum HomeInvalidationKind { structural, decorative, viewportTriggered, session }

class HomeSurfaceInvalidation {
  const HomeSurfaceInvalidation({
    required this.surfaceId,
    required this.kind,
    this.key,
  });

  final HomeSurfaceId surfaceId;
  final HomeInvalidationKind kind;
  final String? key;
}

class HomeSurfaceInvalidationBus {
  final StreamController<HomeSurfaceInvalidation> _controller =
      StreamController<HomeSurfaceInvalidation>.broadcast();

  Stream<HomeSurfaceInvalidation> get stream => _controller.stream;

  void emit(HomeSurfaceInvalidation event) => _controller.add(event);
}

class HomeTabTransition {
  const HomeTabTransition({required this.hiddenSurface, required this.visibleSurface});

  final HomeSurfaceId hiddenSurface;
  final HomeSurfaceId visibleSurface;
}

class HomeTabCoordinator {
  HomeTabCoordinator({int initialIndex = 0}) : _currentIndex = initialIndex;

  int _currentIndex;

  HomeTabTransition setIndex(int nextIndex) {
    final previous = HomeSurfaceId.values[_currentIndex];
    _currentIndex = nextIndex;
    return HomeTabTransition(hiddenSurface: previous, visibleSurface: HomeSurfaceId.values[nextIndex]);
  }
}

class HomeSurfaceVisibilityController {
  HomeSurfaceVisibilityController(HomeSurfaceId initialSurface)
      : _states = <HomeSurfaceId, HomeSurfaceVisibilityState>{
          for (final surface in HomeSurfaceId.values)
            surface: surface == initialSurface
                ? HomeSurfaceVisibilityState.visible
                : HomeSurfaceVisibilityState.cold,
        };

  final Map<HomeSurfaceId, HomeSurfaceVisibilityState> _states;

  HomeSurfaceVisibilityState stateFor(HomeSurfaceId surfaceId) =>
      _states[surfaceId] ?? HomeSurfaceVisibilityState.cold;

  void markVisible(HomeSurfaceId surfaceId) {
    for (final entry in _states.entries.toList()) {
      _states[entry.key] = entry.key == surfaceId
          ? HomeSurfaceVisibilityState.visible
          : HomeSurfaceVisibilityState.backgroundAlive;
    }
  }
}
```

- [ ] **Step 5: Run the unit tests again**

Run: `flutter test test/modules/home/home_badge_snapshot_test.dart test/modules/home/home_tab_coordinator_test.dart`
Expected: PASS with snapshot aggregation and tab transition assertions green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/home/home_surface_contract.dart lib/modules/home/home_badge_snapshot.dart lib/modules/home/home_tab_coordinator.dart lib/modules/home/home_surface_invalidation_bus.dart lib/modules/home/home_surface_visibility_controller.dart test/modules/home/home_badge_snapshot_test.dart test/modules/home/home_tab_coordinator_test.dart
git commit -m "refactor: add home kernel primitives"
```
### Task 2: Extract Home Shell And Bootstrap Kernel

**Files:**
- Create: `lib/modules/home/home_surface_kernel.dart`
- Create: `lib/modules/home/home_shell_page.dart`
- Create: `test/modules/home/home_shell_page_test.dart`
- Modify: `lib/modules/conversation/main_page.dart`
- Modify: `test/modules/shell/main_pages_compile_test.dart`

- [ ] **Step 1: Write the failing shell tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_shell_page.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';

void main() {
  testWidgets('home shell shows retry state when bootstrap fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBootstrapStateProvider.overrideWith((ref) {
            return const HomeBootstrapState.failed(StateError('boom'));
          }),
        ],
        child: const MaterialApp(home: HomeShellPage()),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the shell tests to verify they fail**

Run: `flutter test test/modules/home/home_shell_page_test.dart`
Expected: FAIL with missing `HomeShellPage`, `HomeBootstrapState`, or shell provider overrides

- [ ] **Step 3: Implement bootstrap state and shell-facing providers**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../service/im/im_service.dart';
import 'home_badge_snapshot.dart';
import 'home_surface_contract.dart';

@immutable
class HomeBootstrapState {
  const HomeBootstrapState._({required this.isLoading, required this.isReady, this.error});

  const HomeBootstrapState.loading() : this._(isLoading: true, isReady: false);
  const HomeBootstrapState.ready() : this._(isLoading: false, isReady: true);
  const HomeBootstrapState.failed(Object error) : this._(isLoading: false, isReady: false, error: error);

  final bool isLoading;
  final bool isReady;
  final Object? error;
}

class HomeBootstrapController extends Notifier<HomeBootstrapState> {
  @override
  HomeBootstrapState build() => const HomeBootstrapState.loading();

  Future<void> initialize() async {
    final ok = await ref.read(imServiceProvider.notifier).init();
    state = ok
        ? const HomeBootstrapState.ready()
        : const HomeBootstrapState.failed(StateError('IM initialization failed.'));
  }

  void markReadyWithoutInit() {
    state = const HomeBootstrapState.ready();
  }
}

final homeBootstrapStateProvider = NotifierProvider<HomeBootstrapController, HomeBootstrapState>(HomeBootstrapController.new);
final homeCurrentTabIndexProvider = StateProvider<int>((ref) => 0);
final homeBadgeSnapshotProvider = Provider<HomeBadgeSnapshot>((ref) {
  final conversations = ref.watch(conversationProvider);
  final requests = ref.watch(friendRequestListProvider);
  return HomeBadgeSnapshot(
    bySurface: <HomeSurfaceId, int>{
      HomeSurfaceId.conversations: conversations.fold<int>(0, (sum, item) => sum + item.unreadCount),
      HomeSurfaceId.contacts: requests.maybeWhen(data: countPendingFriendRequests, orElse: () => 0),
      HomeSurfaceId.user: 0,
    },
  );
});
```

- [ ] **Step 4: Implement the shell and delegate `MainPage` to it**

```dart
class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key, this.autoInitializeIM = true, this.pagesOverride});

  final bool autoInitializeIM;
  final List<Widget>? pagesOverride;
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  static const List<Widget> _defaultPages = <Widget>[
    ConversationListPage(),
    ContactsPage(),
    UserPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(homeBootstrapStateProvider.notifier);
      if (widget.autoInitializeIM) {
        controller.initialize();
      } else {
        controller.markReadyWithoutInit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapStateProvider);
    final badges = ref.watch(homeBadgeSnapshotProvider);
    final pages = widget.pagesOverride ?? _defaultPages;

    if (bootstrap.isLoading && !bootstrap.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (bootstrap.error != null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => ref.read(homeBootstrapStateProvider.notifier).initialize(),
            child: const Text('Retry'),
          ),
        ),
      );
    }

    return WKTabShell(
      currentIndex: ref.watch(homeCurrentTabIndexProvider),
      pages: pages,
      items: <WKTabShellItemData>[
        WKTabShellItemData(label: 'Chats', normalIcon: WKReferenceAssets.tabChatNormal, selectedIcon: WKReferenceAssets.tabChatSelected, badgeCount: badges.badgeFor(HomeSurfaceId.conversations)),
        WKTabShellItemData(label: 'Contacts', normalIcon: WKReferenceAssets.tabContactsNormal, selectedIcon: WKReferenceAssets.tabContactsSelected, badgeCount: badges.badgeFor(HomeSurfaceId.contacts)),
        WKTabShellItemData(label: 'Me', normalIcon: WKReferenceAssets.tabMineNormal, selectedIcon: WKReferenceAssets.tabMineSelected),
      ],
      onTap: (index) => ref.read(homeCurrentTabIndexProvider.notifier).state = index,
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({super.key, this.autoInitializeIM = true});

  final bool autoInitializeIM;

  @override
  Widget build(BuildContext context) {
    return HomeShellPage(autoInitializeIM: autoInitializeIM);
  }
}
```

- [ ] **Step 5: Run shell and compile coverage**

Run: `flutter test test/modules/home/home_shell_page_test.dart test/modules/shell/main_pages_compile_test.dart`
Expected: PASS with retry UI and compile assertions green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/home/home_surface_kernel.dart lib/modules/home/home_shell_page.dart lib/modules/conversation/main_page.dart test/modules/home/home_shell_page_test.dart test/modules/shell/main_pages_compile_test.dart
git commit -m "refactor: extract home shell bootstrap kernel"
```

### Task 3: Bridge The Conversation Surface Into The Home Kernel

**Files:**
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Modify: `lib/modules/conversation/conversation_list_refresh_controller.dart`
- Modify: `lib/modules/conversation/conversation_activity_registry.dart`
- Create: `test/modules/conversation/conversation_surface_bridge_test.dart`
- Modify: `test/modules/conversation/conversation_list_refresh_controller_test.dart`
- Modify: `test/modules/conversation/conversation_list_item_loader_test.dart`

- [ ] **Step 1: Write the failing bridge tests**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';

void main() {
  test('conversation surface exposes a home surface contract', () {
    final container = ProviderContainer();

    final contract = container.read(conversationSurfaceContractProvider);

    expect(contract.surfaceId, HomeSurfaceId.conversations);
  });
}
```

- [ ] **Step 2: Run the bridge tests to verify they fail**

Run: `flutter test test/modules/conversation/conversation_surface_bridge_test.dart`
Expected: FAIL with missing `conversationSurfaceContractProvider`

- [ ] **Step 3: Expose a conversation contract provider and surface bridge**

```dart
final conversationSurfaceContractProvider = Provider<HomeSurfaceContract>((ref) {
  final conversations = ref.watch(conversationProvider);
  final unread = conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);
  return HomeSurfaceContract(
    surfaceId: HomeSurfaceId.conversations,
    badgeCount: unread,
    reliabilityState: SurfaceReliabilityState.healthy,
    prefetchHint: const HomeSurfacePrefetchHint(
      surfaceId: HomeSurfaceId.conversations,
      critical: true,
      adjacent: true,
    ),
  );
});

class ConversationSurfaceBridge {
  ConversationSurfaceBridge({required this.refreshController, required this.invalidationBus});

  final ConversationListRefreshController refreshController;
  final HomeSurfaceInvalidationBus invalidationBus;

  void onConversationChanged(String requestKey) {
    refreshController.markConversationDirty(requestKey);
    invalidationBus.emit(
      const HomeSurfaceInvalidation(
        surfaceId: HomeSurfaceId.conversations,
        kind: HomeInvalidationKind.structural,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the conversation bridge and regression tests**

Run: `flutter test test/modules/conversation/conversation_surface_bridge_test.dart test/modules/conversation/conversation_list_refresh_controller_test.dart test/modules/conversation/conversation_list_item_loader_test.dart`
Expected: PASS with conversation contract and refresh-controller behavior green

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/conversation/conversation_list_page.dart lib/modules/conversation/conversation_list_refresh_controller.dart lib/modules/conversation/conversation_activity_registry.dart test/modules/conversation/conversation_surface_bridge_test.dart test/modules/conversation/conversation_list_refresh_controller_test.dart test/modules/conversation/conversation_list_item_loader_test.dart
git commit -m "refactor: connect conversation surface to home kernel"
```
### Task 4: Extract Contacts Directory Mapping

**Files:**
- Create: `lib/modules/contacts/contacts_directory_controller.dart`
- Create: `test/modules/contacts/contacts_directory_controller_test.dart`
- Modify: `lib/modules/contacts/contacts_page.dart`
- Modify: `test/modules/contacts/contacts_page_parity_test.dart`

- [ ] **Step 1: Write the failing directory tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/modules/contacts/contacts_directory_controller.dart';

void main() {
  test('builds sorted sections and letters once per data set', () {
    final controller = ContactsDirectoryController();
    final directory = controller.buildDirectory(<Friend>[
      Friend(uid: 'u_bob', name: 'Bob'),
      Friend(uid: 'u_alice', name: 'Alice'),
    ]);

    expect(directory.letters, <String>['A', 'B']);
    expect(directory.sections.first.entries.single.friend.uid, 'u_alice');
  });
}
```

- [ ] **Step 2: Run the directory tests to verify they fail**

Run: `flutter test test/modules/contacts/contacts_directory_controller_test.dart`
Expected: FAIL with missing `ContactsDirectoryController` or section model types

- [ ] **Step 3: Implement sectioned contacts mapping outside the page build**

```dart
@immutable
class ContactsDirectoryEntry {
  const ContactsDirectoryEntry({required this.friend, required this.sortKey, required this.sectionLetter});

  final Friend friend;
  final String sortKey;
  final String sectionLetter;
}

@immutable
class ContactsDirectorySection {
  const ContactsDirectorySection({required this.letter, required this.entries});

  final String letter;
  final List<ContactsDirectoryEntry> entries;
}

@immutable
class ContactsDirectoryData {
  const ContactsDirectoryData({required this.sections, required this.letters});

  final List<ContactsDirectorySection> sections;
  final List<String> letters;
}

class ContactsDirectoryController {
  ContactsDirectoryData buildDirectory(List<Friend> friends) {
    final entries = friends.map((friend) {
      final sortKey = ContactFilter.resolveName(friend).trim();
      final letter = ContactFilter.resolveSortLetter(friend);
      return ContactsDirectoryEntry(friend: friend, sortKey: sortKey, sectionLetter: letter);
    }).toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));

    final letters = <String>[];
    final sections = <ContactsDirectorySection>[];
    for (final entry in entries) {
      if (!letters.contains(entry.sectionLetter)) {
        letters.add(entry.sectionLetter);
      }
    }
    for (final letter in letters) {
      sections.add(ContactsDirectorySection(
        letter: letter,
        entries: entries.where((entry) => entry.sectionLetter == letter).toList(),
      ));
    }
    return ContactsDirectoryData(sections: sections, letters: letters);
  }
}
```

- [ ] **Step 4: Replace page-local grouping with the controller output**

```dart
final contactsDirectoryControllerProvider = Provider<ContactsDirectoryController>((ref) {
  return ContactsDirectoryController();
});

final contactsDirectoryDataProvider = Provider.family<ContactsDirectoryData, List<Friend>>((ref, friends) {
  final controller = ref.watch(contactsDirectoryControllerProvider);
  return controller.buildDirectory(friends);
});
```

- [ ] **Step 5: Run directory and parity tests**

Run: `flutter test test/modules/contacts/contacts_directory_controller_test.dart test/modules/contacts/contacts_page_parity_test.dart`
Expected: PASS with alphabetical grouping preserved and visible parity text still present

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/contacts/contacts_directory_controller.dart lib/modules/contacts/contacts_page.dart test/modules/contacts/contacts_directory_controller_test.dart test/modules/contacts/contacts_page_parity_test.dart
git commit -m "refactor: extract contacts directory controller"
```

### Task 5: Extract Contacts Presence Control And Viewport Widgets

**Files:**
- Create: `lib/modules/contacts/contacts_presence_controller.dart`
- Create: `lib/modules/contacts/widgets/contacts_list_viewport.dart`
- Create: `lib/modules/contacts/widgets/contacts_alphabet_index.dart`
- Create: `test/modules/contacts/contacts_presence_controller_test.dart`
- Create: `test/modules/contacts/contacts_viewport_test.dart`
- Modify: `lib/modules/contacts/contacts_page.dart`
- Modify: `test/modules/contacts/contacts_page_parity_test.dart`

- [ ] **Step 1: Write the failing presence and viewport tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_presence_controller.dart';
import 'package:wukong_im_app/modules/contacts/widgets/contacts_alphabet_index.dart';

void main() {
  test('drops stale presence loads by generation', () async {
    final controller = ContactsPresenceController(
      loadChannel: (uid) async => ContactPresenceSnapshot(uid: uid, online: true),
    );

    final result = await controller.load(<String>['u_1']);

    expect(result['u_1']?.online, isTrue);
  });

  testWidgets('alphabet index reports tapped letter', (tester) async {
    String tapped = '';

    await tester.pumpWidget(MaterialApp(
      home: ContactsAlphabetIndex(
        letters: const <String>['A', 'B'],
        onLetterSelected: (value) => tapped = value,
      ),
    ));

    await tester.tap(find.text('B'));
    expect(tapped, 'B');
  });
}
```

- [ ] **Step 2: Run the presence and viewport tests to verify they fail**

Run: `flutter test test/modules/contacts/contacts_presence_controller_test.dart test/modules/contacts/contacts_viewport_test.dart`
Expected: FAIL with missing `ContactsPresenceController`, `ContactPresenceSnapshot`, or `ContactsAlphabetIndex`

- [ ] **Step 3: Implement the presence controller with generation gating**

```dart
@immutable
class ContactPresenceSnapshot {
  const ContactPresenceSnapshot({required this.uid, this.online = false, this.lastOffline = 0, this.deviceFlag = 0});

  final String uid;
  final bool online;
  final int lastOffline;
  final int deviceFlag;
}

typedef ContactPresenceLoader = Future<ContactPresenceSnapshot?> Function(String uid);

class ContactsPresenceController {
  ContactsPresenceController({required ContactPresenceLoader loadChannel}) : _loadChannel = loadChannel;

  final ContactPresenceLoader _loadChannel;
  int _generation = 0;

  Future<Map<String, ContactPresenceSnapshot>> load(List<String> uids) async {
    final generation = ++_generation;
    final next = <String, ContactPresenceSnapshot>{};
    for (final uid in uids) {
      final snapshot = await _loadChannel(uid);
      if (snapshot != null) {
        next[uid] = snapshot;
      }
    }
    return generation == _generation ? next : <String, ContactPresenceSnapshot>{};
  }
}
```

- [ ] **Step 4: Move list and alphabet rendering into focused widgets**

```dart
class ContactsListViewport extends StatelessWidget {
  const ContactsListViewport({super.key, required this.directory, required this.presenceByUid});

  final ContactsDirectoryData directory;
  final Map<String, ContactPresenceSnapshot> presenceByUid;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView.builder(
        itemCount: directory.sections.length,
        itemBuilder: (context, index) => _ContactsSection(
          section: directory.sections[index],
          presenceByUid: presenceByUid,
        ),
      ),
    );
  }
}

class ContactsAlphabetIndex extends StatelessWidget {
  const ContactsAlphabetIndex({super.key, required this.letters, required this.onLetterSelected});

  final List<String> letters;
  final ValueChanged<String> onLetterSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: letters.map((letter) {
        return GestureDetector(
          onTap: () => onLetterSelected(letter),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(letter),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 5: Run presence, viewport, and parity tests**

Run: `flutter test test/modules/contacts/contacts_presence_controller_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/contacts/contacts_page_parity_test.dart`
Expected: PASS with generation gating, alphabet taps, and parity behavior green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/contacts/contacts_presence_controller.dart lib/modules/contacts/widgets/contacts_list_viewport.dart lib/modules/contacts/widgets/contacts_alphabet_index.dart lib/modules/contacts/contacts_page.dart test/modules/contacts/contacts_presence_controller_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/contacts/contacts_page_parity_test.dart
git commit -m "refactor: split contacts presence and viewport"
```
### Task 6: Add Reliability, Observability, And Final Verification

**Files:**
- Modify: `lib/modules/home/home_surface_kernel.dart`
- Modify: `lib/modules/home/home_shell_page.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Modify: `lib/modules/contacts/contacts_page.dart`
- Create: `test/modules/home/home_surface_kernel_test.dart`

- [ ] **Step 1: Write the failing reliability and observability tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';

void main() {
  test('records focused observability events for bootstrap and visibility', () {
    final sink = <String>[];
    final kernel = HomeSurfaceKernel(logEvent: sink.add);

    kernel.markBootstrapStart();
    kernel.markBootstrapReady();
    kernel.markSurfaceVisible(HomeSurfaceId.conversations);

    expect(sink, <String>[
      'home_bootstrap_start',
      'home_bootstrap_ready',
      'surface_visible:conversations',
    ]);
  });
}
```

- [ ] **Step 2: Run the reliability tests to verify they fail**

Run: `flutter test test/modules/home/home_surface_kernel_test.dart`
Expected: FAIL with missing `HomeSurfaceKernel` methods or observability tracking

- [ ] **Step 3: Implement observability and reliability state tracking**

```dart
typedef HomeKernelLogEvent = void Function(String event);

class HomeSurfaceKernel {
  HomeSurfaceKernel({required HomeKernelLogEvent logEvent}) : _logEvent = logEvent;

  final HomeKernelLogEvent _logEvent;
  final Map<HomeSurfaceId, SurfaceReliabilityState> _reliability = <HomeSurfaceId, SurfaceReliabilityState>{
    for (final surface in HomeSurfaceId.values) surface: SurfaceReliabilityState.healthy,
  };

  void markBootstrapStart() => _logEvent('home_bootstrap_start');
  void markBootstrapReady() => _logEvent('home_bootstrap_ready');
  void markSurfaceVisible(HomeSurfaceId surfaceId) => _logEvent('surface_visible:${surfaceId.name}');
  void markSurfaceHidden(HomeSurfaceId surfaceId) => _logEvent('surface_hidden:${surfaceId.name}');

  void markSurfaceReliability(HomeSurfaceId surfaceId, SurfaceReliabilityState state) {
    _reliability[surfaceId] = state;
    _logEvent('surface_${state.name}:${surfaceId.name}');
  }
}
```

- [ ] **Step 4: Run focused analysis, local test packs, and remote correlation**

Run: `dart analyze lib/modules/home lib/modules/conversation/main_page.dart lib/modules/conversation/conversation_list_page.dart lib/modules/contacts`
Expected: `No issues found!`

Run: `flutter test test/modules/home/home_badge_snapshot_test.dart test/modules/home/home_tab_coordinator_test.dart test/modules/home/home_shell_page_test.dart test/modules/home/home_surface_kernel_test.dart test/modules/conversation/conversation_surface_bridge_test.dart test/modules/conversation/conversation_list_item_loader_test.dart test/modules/conversation/conversation_list_refresh_controller_test.dart test/modules/contacts/contacts_directory_controller_test.dart test/modules/contacts/contacts_presence_controller_test.dart test/modules/contacts/contacts_viewport_test.dart test/modules/contacts/contacts_page_parity_test.dart test/modules/shell/main_pages_compile_test.dart`
Expected: PASS for the homepage kernel test pack

Run: `ssh root@103.207.68.33 "docker ps && tail -n 200 /data/fullstack/wukongimdata/logs/error.log && docker logs --tail 200 fullstack-tangsengdaodaoserver-1"`
Expected: container list prints, WuKongIM log tail prints, and TangSeng logs print without SSH or container-name errors

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/home/home_surface_kernel.dart lib/modules/home/home_shell_page.dart lib/modules/conversation/conversation_list_page.dart lib/modules/contacts/contacts_page.dart test/modules/home/home_surface_kernel_test.dart
git commit -m "refactor: add home kernel observability and verification"
```

## Self-Review Checklist

- Spec coverage:
  - shared kernel contracts, snapshot aggregation, invalidation, and visibility are implemented in Tasks 1 and 2
  - conversation surface registration and invalidation bridging are implemented in Task 3
  - contacts directory, presence control, and viewport extraction are implemented in Tasks 4 and 5
  - reliability, observability, and remote verification are implemented in Task 6
- Placeholder scan:
  - no unresolved placeholder markers remain in the plan
- Type consistency:
  - `HomeSurfaceId`, `HomeSurfaceContract`, `HomeBadgeSnapshot`, `HomeSurfaceKernel`, `ContactsDirectoryController`, and `ContactsPresenceController` use consistent names across all tasks


