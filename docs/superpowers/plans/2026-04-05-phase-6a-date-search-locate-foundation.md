# Phase 6A Date Search And Shared Locate Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge Flutter date search and shared chat-location foundations so Android date-search behavior on Android matches the TangSengDaoDao reference while keeping the newer Flutter search kernel as the only authoritative implementation.

**Architecture:** This plan does not rebuild search from scratch. It upgrades the existing `lib/modules/search/**` mainline by making `ChatLocateIntent` flexible enough for both message-hit and date-calendar entry points, adds a thin `SearchLocateResolver` that normalizes page intent without duplicating navigation logic, makes `ChatLocateCoordinator` intent-first with compatibility wrappers for existing callers, and routes `ChatSearchDatePage` through that pipeline. Date-page selection state stays controller-owned so the Flutter page preserves Android's selected-day semantics when the user returns from chat.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, sqflite-backed local timeline aggregation, wukongimfluttersdk, PowerShell, optional SSH verification when deployed behavior diverges from local evidence

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only the approved design in [2026-04-05-phase-6-search-convergence-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-05-phase-6-search-convergence-design.md), specifically `Child Plan A: Date Search And Shared Locate Foundation`.

In scope:

- flexible `ChatLocateIntent` domain modeling for message-hit and date-search entry points
- new `SearchLocateResolver` as the thin normalization layer required by the Phase 6 design
- intent-first `ChatLocateCoordinator` with compatibility for existing `SearchMessageHit` callers
- Android-faithful date-search month and day behavior, including selected-day persistence and shared locate navigation
- targeted regression coverage to prove `chat_search_entry`, `chat_search_collection`, `chat_search_member`, and compile smoke tests still work without reopening those completed pages

Out of scope for this plan:

- final chat-search-entry convergence beyond keeping existing callers compatible
- image-search or member-search redesign already completed in prior phases
- global-search shaping and global message-result convergence
- backend contract rewrites unless verification shows a real deployed mismatch
- non-search Phase 6 domains

## Current Code Reality To Preserve

The implementation must start from the current search kernel rather than old assumptions:

- `lib/modules/search/application/chat_locate_coordinator.dart` already exists, but only accepts `SearchMessageHit`
- `lib/modules/search/presentation/chat_search_date_page.dart` still opens `ChatPage` directly from `SearchDateCell.anchorOrderSeq`
- `lib/modules/search/application/search_providers.dart` already exposes `chatLocateCoordinatorProvider`
- `lib/modules/search/data/search_local_timeline_data_source.dart` already builds month sections with `messageCount`, `anchorOrderSeq`, `isToday`, and `isSelected`
- Android `SearchWithDateActivity` and `DateChildAdapter` do not show a numeric badge; they express day state through enabled color, orange selected fill, and the `Today` marker

This plan must therefore unify navigation and selection semantics without inventing a second search flow or a non-Android date-cell badge design.

## File Structure

### New Files

- `lib/modules/search/data/search_locate_resolver.dart`
  - Thin normalization layer that converts search-domain payloads into `ChatLocateIntent` without owning navigation.
- `test/modules/search/search_locate_resolver_test.dart`
  - Unit tests that lock normalized resolver output for search hits and date cells.
- `test/modules/search/chat_date_calendar_controller_test.dart`
  - Controller tests that lock Android-style selected-day transitions without touching page rendering.

### Existing Files To Modify

- `lib/modules/search/domain/search_models.dart`
  - Make `ChatLocateIntent` flexible enough for both search hits and date cells, and add date-cell helpers needed for controller-side selection updates.
- `lib/modules/search/application/search_providers.dart`
  - Register `SearchLocateResolver` and keep provider wiring explicit.
- `lib/modules/search/application/chat_locate_coordinator.dart`
  - Add intent-first open-request building while preserving the current `SearchMessageHit` wrapper used by existing pages.
- `lib/modules/search/application/chat_date_calendar_controller.dart`
  - Keep selected-day state in controller-owned sections and expose a narrow `selectCell` API.
- `lib/modules/search/presentation/chat_search_date_page.dart`
  - Stop direct ad hoc `ChatPage` opening and use resolver plus coordinator for all day taps.
- `lib/modules/search/presentation/widgets/search_date_calendar.dart`
  - Preserve Android day styling and add stable keys needed for selected-day and fallback-feedback widget assertions.
- `test/modules/search/search_models_test.dart`
  - Lock new `ChatLocateIntent` factories and `SearchDateCell` state helpers.
- `test/modules/search/chat_locate_coordinator_test.dart`
  - Lock intent-first locate behavior, compatibility wrappers, and explicit fallback semantics.
- `test/modules/search/chat_search_date_page_test.dart`
  - Lock shared-locate navigation, selected-day persistence, and fallback snackbar behavior.

## Verification Commands Used Throughout

- `flutter test test/modules/search/search_models_test.dart`
- `flutter test test/modules/search/search_locate_resolver_test.dart`
- `flutter test test/modules/search/chat_locate_coordinator_test.dart`
- `flutter test test/modules/search/chat_date_calendar_controller_test.dart`
- `flutter test test/modules/search/chat_search_date_page_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/search_pages_compile_test.dart`
- `flutter analyze lib/modules/search/domain/search_models.dart lib/modules/search/data/search_locate_resolver.dart lib/modules/search/application/chat_locate_coordinator.dart lib/modules/search/application/chat_date_calendar_controller.dart lib/modules/search/application/search_providers.dart lib/modules/search/presentation/chat_search_date_page.dart lib/modules/search/presentation/widgets/search_date_calendar.dart`

If local behavior passes but deployed Android-style navigation still diverges, run:

- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|message|order_seq'"`

### Task 1: Extend Search Domain Models For Shared Locate And Date Selection

**Files:**
- Modify: `lib/modules/search/domain/search_models.dart`
- Modify: `test/modules/search/search_models_test.dart`

- [ ] **Step 1: Write the failing domain-model tests**

```dart
test('ChatLocateIntent factories normalize search hits and date cells', () {
  const hit = SearchMessageHit(
    channelId: 'group-1',
    channelType: 2,
    messageSeq: 77,
    orderSeq: 9901,
    timestamp: 1712123456,
    contentType: 1,
    fromUid: 'u-alex',
    fromName: 'Alex',
    previewText: 'keyword appears here',
    channelName: 'Project Group',
  );
  const cell = SearchDateCell(
    year: 2026,
    month: 4,
    day: 3,
    messageCount: 8,
    anchorOrderSeq: 8000,
    isToday: false,
    isSelected: false,
  );

  final fromHit = ChatLocateIntent.fromSearchHit(
    hit,
    highlightKeyword: 'keyword',
    source: 'chat-keyword-search',
  );
  final fromDate = ChatLocateIntent.fromDateCell(
    cell: cell,
    channelId: 'group-1',
    channelType: 2,
    channelName: 'Project Group',
    source: 'search-date',
  );

  expect(fromHit.messageSeq, 77);
  expect(fromHit.orderSeq, 9901);
  expect(fromHit.highlightKeyword, 'keyword');
  expect(fromHit.source, 'chat-keyword-search');

  expect(fromDate.messageSeq, isNull);
  expect(fromDate.orderSeq, 8000);
  expect(fromDate.highlightKeyword, '');
  expect(fromDate.source, 'search-date');
  expect(fromDate.channelName, 'Project Group');
});

test('SearchDateCell copyWith and dayKey support selected-day updates', () {
  const cell = SearchDateCell(
    year: 2026,
    month: 4,
    day: 3,
    messageCount: 8,
    anchorOrderSeq: 8000,
    isToday: true,
    isSelected: true,
  );

  final changed = cell.copyWith(isSelected: false);

  expect(cell.dayKey, '2026-04-03');
  expect(changed.dayKey, '2026-04-03');
  expect(changed.isSelected, isFalse);
  expect(changed.anchorOrderSeq, 8000);
  expect(changed.messageCount, 8);
});
```

- [ ] **Step 2: Run the domain-model test to verify it fails**

Run: `flutter test test/modules/search/search_models_test.dart`  
Expected: FAIL with missing `ChatLocateIntent.fromSearchHit`, missing `ChatLocateIntent.fromDateCell`, missing `SearchDateCell.copyWith`, or missing `SearchDateCell.dayKey`

- [ ] **Step 3: Implement the flexible locate intent and date-cell helpers**

```dart
// lib/modules/search/domain/search_models.dart
@immutable
class SearchDateCell {
  const SearchDateCell({
    required this.year,
    required this.month,
    required this.day,
    required this.messageCount,
    required this.anchorOrderSeq,
    required this.isToday,
    required this.isSelected,
    this.isPlaceholder = false,
    this.weekdayOffset = 0,
  });

  String get dayKey =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  SearchDateCell copyWith({
    int? year,
    int? month,
    int? day,
    int? messageCount,
    int? anchorOrderSeq,
    bool? isToday,
    bool? isSelected,
    bool? isPlaceholder,
    int? weekdayOffset,
  }) {
    return SearchDateCell(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      messageCount: messageCount ?? this.messageCount,
      anchorOrderSeq: anchorOrderSeq ?? this.anchorOrderSeq,
      isToday: isToday ?? this.isToday,
      isSelected: isSelected ?? this.isSelected,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      weekdayOffset: weekdayOffset ?? this.weekdayOffset,
    );
  }
}

@immutable
class ChatLocateIntent {
  const ChatLocateIntent({
    required this.channelId,
    required this.channelType,
    required this.source,
    this.messageSeq,
    this.orderSeq,
    this.highlightKeyword = '',
    this.channelName,
  });

  factory ChatLocateIntent.fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    return ChatLocateIntent(
      channelId: hit.channelId,
      channelType: hit.channelType,
      messageSeq: hit.messageSeq,
      orderSeq: hit.orderSeq > 0 ? hit.orderSeq : null,
      highlightKeyword: highlightKeyword,
      source: source,
      channelName: hit.channelName,
    );
  }

  factory ChatLocateIntent.fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    required String source,
    String? channelName,
  }) {
    return ChatLocateIntent(
      channelId: channelId,
      channelType: channelType,
      orderSeq: cell.anchorOrderSeq > 0 ? cell.anchorOrderSeq : null,
      highlightKeyword: '',
      source: source,
      channelName: channelName,
    );
  }

  final String channelId;
  final int channelType;
  final int? messageSeq;
  final int? orderSeq;
  final String highlightKeyword;
  final String source;
  final String? channelName;
}
```

- [ ] **Step 4: Run the domain-model test to verify it passes**

Run: `flutter test test/modules/search/search_models_test.dart`  
Expected: PASS with the new factories and date-cell helpers covered

- [ ] **Step 5: Checkpoint the model changes**

```bash
git add lib/modules/search/domain/search_models.dart test/modules/search/search_models_test.dart
git commit -m "feat: normalize search locate intent models"
```

### Task 2: Add The Thin SearchLocateResolver And Provider Wiring

**Files:**
- Create: `lib/modules/search/data/search_locate_resolver.dart`
- Modify: `lib/modules/search/application/search_providers.dart`
- Create: `test/modules/search/search_locate_resolver_test.dart`

- [ ] **Step 1: Write the failing resolver test**

```dart
test('SearchLocateResolver converts search hits and date cells into locate intents', () {
  const resolver = SearchLocateResolver();
  const hit = SearchMessageHit(
    channelId: 'group-1',
    channelType: 2,
    messageSeq: 77,
    orderSeq: 0,
    timestamp: 1712123456,
    contentType: 1,
    fromUid: 'u-alex',
    fromName: 'Alex',
    previewText: 'keyword appears here',
    channelName: 'Project Group',
  );
  const cell = SearchDateCell(
    year: 2026,
    month: 4,
    day: 3,
    messageCount: 8,
    anchorOrderSeq: 8000,
    isToday: false,
    isSelected: false,
  );

  final searchIntent = resolver.fromSearchHit(
    hit,
    highlightKeyword: 'keyword',
    source: 'chat-member-search',
  );
  final dateIntent = resolver.fromDateCell(
    cell: cell,
    channelId: 'group-1',
    channelType: 2,
    channelName: 'Project Group',
    source: 'search-date',
  );

  expect(searchIntent.messageSeq, 77);
  expect(searchIntent.orderSeq, isNull);
  expect(searchIntent.highlightKeyword, 'keyword');
  expect(dateIntent.messageSeq, isNull);
  expect(dateIntent.orderSeq, 8000);
  expect(dateIntent.channelName, 'Project Group');
});
```

- [ ] **Step 2: Run the resolver test to verify it fails**

Run: `flutter test test/modules/search/search_locate_resolver_test.dart`  
Expected: FAIL with missing `SearchLocateResolver` or missing `searchLocateResolverProvider`

- [ ] **Step 3: Implement the resolver and provider**

```dart
// lib/modules/search/data/search_locate_resolver.dart
import '../domain/search_models.dart';

class SearchLocateResolver {
  const SearchLocateResolver();

  ChatLocateIntent fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    return ChatLocateIntent.fromSearchHit(
      hit,
      highlightKeyword: highlightKeyword,
      source: source,
    );
  }

  ChatLocateIntent fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    required String source,
    String? channelName,
  }) {
    return ChatLocateIntent.fromDateCell(
      cell: cell,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      source: source,
    );
  }
```

```dart
// lib/modules/search/application/search_providers.dart
import '../data/search_locate_resolver.dart';

final searchLocateResolverProvider = Provider<SearchLocateResolver>(
  (ref) => const SearchLocateResolver(),
);
```

- [ ] **Step 4: Run the resolver test to verify it passes**

Run: `flutter test test/modules/search/search_locate_resolver_test.dart`  
Expected: PASS with explicit coverage for search-hit and date-cell normalization

- [ ] **Step 5: Checkpoint the resolver layer**

```bash
git add lib/modules/search/data/search_locate_resolver.dart lib/modules/search/application/search_providers.dart test/modules/search/search_locate_resolver_test.dart
git commit -m "feat: add search locate resolver"
```

### Task 3: Make ChatLocateCoordinator Intent-First Without Breaking Existing Search Pages

**Files:**
- Modify: `lib/modules/search/application/chat_locate_coordinator.dart`
- Modify: `test/modules/search/chat_locate_coordinator_test.dart`

- [ ] **Step 1: Write the failing coordinator tests**

```dart
test('ChatLocateCoordinator uses existing orderSeq from ChatLocateIntent without extra lookup', () async {
  var resolveCalls = 0;
  final coordinator = ChatLocateCoordinator(
    resolveOrderSeq: ({
      required int messageSeq,
      required String channelId,
      required int channelType,
    }) async {
      resolveCalls += 1;
      return 0;
    },
  );

  const intent = ChatLocateIntent(
    channelId: 'group-1',
    channelType: 2,
    orderSeq: 8000,
    source: 'search-date',
    channelName: 'Project Group',
  );

  final request = await coordinator.buildOpenRequestFromIntent(intent);

  expect(request.orderSeq, 8000);
  expect(request.feedbackMessage, isNull);
  expect(resolveCalls, 0);
});

test('ChatLocateCoordinator resolves orderSeq from messageSeq when the intent has no anchor', () async {
  final coordinator = ChatLocateCoordinator(
    resolveOrderSeq: ({
      required int messageSeq,
      required String channelId,
      required int channelType,
    }) async {
      expect(messageSeq, 77);
      expect(channelId, 'group-1');
      expect(channelType, 2);
      return 9901;
    },
  );

  const intent = ChatLocateIntent(
    channelId: 'group-1',
    channelType: 2,
    messageSeq: 77,
    highlightKeyword: 'keyword',
    source: 'chat-keyword-search',
    channelName: 'Project Group',
  );

  final request = await coordinator.buildOpenRequestFromIntent(intent);

  expect(request.orderSeq, 9901);
  expect(request.highlightKeyword, 'keyword');
});

test('ChatLocateCoordinator falls back to opening the conversation when the intent cannot resolve an anchor', () async {
  final coordinator = ChatLocateCoordinator(
    resolveOrderSeq: ({
      required int messageSeq,
      required String channelId,
      required int channelType,
    }) async => 0,
  );

  const intent = ChatLocateIntent(
    channelId: 'group-1',
    channelType: 2,
    source: 'search-date',
    channelName: 'Project Group',
  );

  final request = await coordinator.buildOpenRequestFromIntent(intent);

  expect(request.orderSeq, isNull);
  expect(
    request.feedbackMessage,
    'Unable to locate the exact message. Opened the conversation instead.',
  );
});
```

- [ ] **Step 2: Run the coordinator test to verify it fails**

Run: `flutter test test/modules/search/chat_locate_coordinator_test.dart`  
Expected: FAIL with missing `buildOpenRequestFromIntent` and old `ChatLocateIntent` shape assumptions

- [ ] **Step 3: Implement the intent-first coordinator while preserving the wrapper**

```dart
// lib/modules/search/application/chat_locate_coordinator.dart
const String _locateFallbackMessage =
    'Unable to locate the exact message. Opened the conversation instead.';

class ChatLocateCoordinator {
  const ChatLocateCoordinator({required this.resolveOrderSeq});

  final ResolveOrderSeq resolveOrderSeq;

  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    final directOrderSeq = intent.orderSeq;
    if (directOrderSeq != null && directOrderSeq > 0) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: directOrderSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
      );
    }

    final messageSeq = intent.messageSeq;
    if (messageSeq == null || messageSeq <= 0) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: null,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: _locateFallbackMessage,
      );
    }

    try {
      final orderSeq = await resolveOrderSeq(
        messageSeq: messageSeq,
        channelId: intent.channelId,
        channelType: intent.channelType,
      );
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: orderSeq > 0 ? orderSeq : null,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: orderSeq > 0 ? null : _locateFallbackMessage,
      );
    } catch (_) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: null,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: _locateFallbackMessage,
      );
    }
  }

  Future<ChatOpenRequest> buildOpenRequest(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    return buildOpenRequestFromIntent(
      ChatLocateIntent.fromSearchHit(
        hit,
        highlightKeyword: highlightKeyword,
        source: source,
      ),
    );
  }
```

- [ ] **Step 4: Run the coordinator test to verify it passes**

Run: `flutter test test/modules/search/chat_locate_coordinator_test.dart`  
Expected: PASS with explicit coverage for direct anchor use, message-seq resolution, and fallback behavior

- [ ] **Step 5: Checkpoint the coordinator changes**

```bash
git add lib/modules/search/application/chat_locate_coordinator.dart test/modules/search/chat_locate_coordinator_test.dart
git commit -m "feat: make search locate coordinator intent-first"
```

### Task 4: Preserve Android Selected-Day Semantics In The Date Controller

**Files:**
- Modify: `lib/modules/search/application/chat_date_calendar_controller.dart`
- Create: `test/modules/search/chat_date_calendar_controller_test.dart`

- [ ] **Step 1: Write the failing controller test**

```dart
class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository({required this.sections});

  final List<SearchDateMonthSection> sections;

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    return sections;
  }

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const <SearchMessageHit>[];
  }

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    return const <SearchMediaItem>[];
  }

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchMemberHit>[];
  }

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const <SearchMessageHit>[];
  }

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async {
    return const GlobalSearchSnapshot();
  }
}

test('selectCell moves the selected state from today to the tapped active day', () async {
  final controller = ChatDateCalendarController(
    channelId: 'group-1',
    channelType: 2,
    repository: _FakeSearchRepository(
      sections: const <SearchDateMonthSection>[
        SearchDateMonthSection(
          year: 2026,
          month: 4,
          cells: <SearchDateCell>[
            SearchDateCell(
              year: 2026,
              month: 4,
              day: 3,
              messageCount: 8,
              anchorOrderSeq: 8000,
              isToday: false,
              isSelected: false,
            ),
            SearchDateCell(
              year: 2026,
              month: 4,
              day: 5,
              messageCount: 3,
              anchorOrderSeq: 8005,
              isToday: true,
              isSelected: true,
            ),
          ],
        ),
      ],
    ),
  );

  await controller.load();
  controller.selectCell(
    controller.state.sections.single.cells.firstWhere(
      (cell) => !cell.isPlaceholder && cell.day == 3,
    ),
  );

  final selectedCells = controller.state.sections
      .expand((section) => section.cells)
      .where((cell) => !cell.isPlaceholder && cell.isSelected)
      .toList(growable: false);

  expect(selectedCells, hasLength(1));
  expect(selectedCells.single.dayKey, '2026-04-03');
});
```

- [ ] **Step 2: Run the controller test to verify it fails**

Run: `flutter test test/modules/search/chat_date_calendar_controller_test.dart`  
Expected: FAIL with missing `selectCell` or unchanged selected-day state

- [ ] **Step 3: Implement controller-owned selected-day updates**

```dart
// lib/modules/search/application/chat_date_calendar_controller.dart
void selectCell(SearchDateCell cell) {
    if (cell.isPlaceholder || !cell.canOpen) {
      return;
    }
    final selectedDayKey = cell.dayKey;
    state = state.copyWith(
      sections: _markSelectedDay(
        sections: state.sections,
        selectedDayKey: selectedDayKey,
      ),
    );
  }

  List<SearchDateMonthSection> _markSelectedDay({
    required List<SearchDateMonthSection> sections,
    required String selectedDayKey,
  }) {
    return List<SearchDateMonthSection>.unmodifiable(
      sections.map((section) {
        return SearchDateMonthSection(
          year: section.year,
          month: section.month,
          cells: List<SearchDateCell>.unmodifiable(
            section.cells.map((cell) {
              if (cell.isPlaceholder) {
                return cell;
              }
              return cell.copyWith(isSelected: cell.dayKey == selectedDayKey);
            }),
          ),
        );
      }),
    );
  }
```

- [ ] **Step 4: Run the controller test to verify it passes**

Run: `flutter test test/modules/search/chat_date_calendar_controller_test.dart`  
Expected: PASS with a single selected active day after `selectCell`

- [ ] **Step 5: Checkpoint the controller behavior**

```bash
git add lib/modules/search/application/chat_date_calendar_controller.dart test/modules/search/chat_date_calendar_controller_test.dart
git commit -m "feat: preserve date search selected day state"
```

### Task 5: Route Date Search Through The Shared Locate Pipeline

**Files:**
- Modify: `lib/modules/search/presentation/chat_search_date_page.dart`
- Modify: `lib/modules/search/presentation/widgets/search_date_calendar.dart`
- Modify: `test/modules/search/chat_search_date_page_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
Widget wrapWithApp(
  Widget child, {
  required SearchRepository repository,
  SearchLocateResolver? locateResolver,
  ChatLocateCoordinator? locateCoordinator,
}) {
  return ProviderScope(
    overrides: [
      searchRepositoryProvider.overrideWithValue(repository),
      if (locateResolver != null)
        searchLocateResolverProvider.overrideWithValue(locateResolver),
      if (locateCoordinator != null)
        chatLocateCoordinatorProvider.overrideWithValue(locateCoordinator),
      messageListProvider.overrideWith(
        (ref, session) =>
            _EmptyMessageListNotifier(session.channelId, session.channelType),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      home: child,
    ),
  );
}

typedef _DateCellIntentFactory = ChatLocateIntent Function({
  required SearchDateCell cell,
  required String channelId,
  required int channelType,
  required String source,
  String? channelName,
});

class _FakeSearchLocateResolver extends SearchLocateResolver {
  _FakeSearchLocateResolver({required this.onFromDateCell});

  final _DateCellIntentFactory onFromDateCell;

  @override
  ChatLocateIntent fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    required String source,
    String? channelName,
  }) {
    return onFromDateCell(
      cell: cell,
      channelId: channelId,
      channelType: channelType,
      source: source,
      channelName: channelName,
    );
  }
}

class _FakeChatLocateCoordinator extends ChatLocateCoordinator {
  _FakeChatLocateCoordinator({required this.request})
      : super(
          resolveOrderSeq: ({
            required int messageSeq,
            required String channelId,
            required int channelType,
          }) async => 0,
        );

  final ChatOpenRequest request;
  final List<ChatLocateIntent> intentLog = <ChatLocateIntent>[];

  @override
  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    intentLog.add(intent);
    return request;
  }
}

testWidgets('tapping a navigable day routes through the locate pipeline and opens chat with the resolved anchor', (tester) async {
  final resolver = _FakeSearchLocateResolver(
    onFromDateCell: ({
      required SearchDateCell cell,
      required String channelId,
      required int channelType,
      required String source,
      String? channelName,
    }) {
      expect(cell.dayKey, '2026-04-03');
      expect(channelId, 'group-1');
      expect(channelType, 2);
      expect(source, 'search-date');
      return const ChatLocateIntent(
        channelId: 'group-1',
        channelType: 2,
        orderSeq: 8000,
        source: 'search-date',
        channelName: 'Project Group',
      );
    },
  );
  final coordinator = _FakeChatLocateCoordinator(
    request: const ChatOpenRequest(
      channelId: 'group-1',
      channelType: 2,
      orderSeq: 8000,
      highlightKeyword: '',
      source: 'search-date',
      channelName: 'Project Group',
    ),
  );

  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchDatePage(
        channelId: 'group-1',
        channelType: 2,
        channelName: 'Project Group',
      ),
      repository: _FakeDateRepository(
        sections: const <SearchDateMonthSection>[
          SearchDateMonthSection(
            year: 2026,
            month: 4,
            cells: <SearchDateCell>[
              SearchDateCell(
                year: 2026,
                month: 4,
                day: 3,
                messageCount: 8,
                anchorOrderSeq: 8000,
                isToday: false,
                isSelected: false,
              ),
            ],
          ),
        ],
      ),
      locateResolver: resolver,
      locateCoordinator: coordinator,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')));
  await tester.pumpAndSettle();

  final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
  expect(shell.initialAroundOrderSeq, 8000);
  expect(coordinator.intentLog.single.source, 'search-date');
});

testWidgets('tapping a date cell keeps the tapped day selected after returning from chat', (tester) async {
  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
      repository: _FakeDateRepository(
        sections: const <SearchDateMonthSection>[
          SearchDateMonthSection(
            year: 2026,
            month: 4,
            cells: <SearchDateCell>[
              SearchDateCell(
                year: 2026,
                month: 4,
                day: 3,
                messageCount: 8,
                anchorOrderSeq: 8000,
                isToday: false,
                isSelected: false,
              ),
              SearchDateCell(
                year: 2026,
                month: 4,
                day: 5,
                messageCount: 3,
                anchorOrderSeq: 8005,
                isToday: true,
                isSelected: true,
              ),
            ],
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')));
  await tester.pumpAndSettle();
  await tester.pageBack();
  await tester.pumpAndSettle();

  final selectedChip = tester.widget<Container>(
    find.byKey(const ValueKey<String>('search-date-day-chip-2026-04-03')),
  );
  expect((selectedChip.decoration! as BoxDecoration).color, const Color(0xFFF65835));
});

testWidgets('fallback locate request still opens the conversation root and shows feedback', (tester) async {
  final coordinator = _FakeChatLocateCoordinator(
    request: const ChatOpenRequest(
      channelId: 'group-1',
      channelType: 2,
      orderSeq: null,
      highlightKeyword: '',
      source: 'search-date',
      feedbackMessage: 'Unable to locate the exact message. Opened the conversation instead.',
    ),
  );

  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchDatePage(channelId: 'group-1', channelType: 2),
      repository: _FakeDateRepository(
        sections: const <SearchDateMonthSection>[
          SearchDateMonthSection(
            year: 2026,
            month: 4,
            cells: <SearchDateCell>[
              SearchDateCell(
                year: 2026,
                month: 4,
                day: 3,
                messageCount: 8,
                anchorOrderSeq: 8000,
                isToday: false,
                isSelected: false,
              ),
            ],
          ),
        ],
      ),
      locateCoordinator: coordinator,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('search-date-cell-2026-04-03')));
  await tester.pump();
  await tester.pumpAndSettle();

  expect(find.byType(ChatPageShell), findsOneWidget);
  expect(find.text('Unable to locate the exact message. Opened the conversation instead.'), findsOneWidget);
});
```

- [ ] **Step 2: Run the date-page test to verify it fails**

Run: `flutter test test/modules/search/chat_search_date_page_test.dart`  
Expected: FAIL because the page still opens `ChatPage` directly, does not update selected-day state on tap, and does not surface locate fallback feedback

- [ ] **Step 3: Implement the shared locate navigation and stable widget keys**

```dart
// lib/modules/search/presentation/chat_search_date_page.dart
import 'dart:async';

import '../application/search_providers.dart';

Future<void> _openDayCell(SearchDateCell cell) async {
  if (!cell.canOpen) {
    return;
  }

  ref.read(chatDateCalendarControllerProvider(_target).notifier).selectCell(cell);

  final resolver = ref.read(searchLocateResolverProvider);
  final coordinator = ref.read(chatLocateCoordinatorProvider);
  final intent = resolver.fromDateCell(
    cell: cell,
    channelId: widget.channelId,
    channelType: widget.channelType,
    channelName: widget.channelName,
    source: 'search-date',
  );
  final request = await coordinator.buildOpenRequestFromIntent(intent);
  if (!mounted) {
    return;
  }

  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: request.channelId,
          channelType: request.channelType,
          channelName: request.channelName ?? widget.channelName,
          initialAroundOrderSeq: request.orderSeq,
        ),
      ),
    ),
  );

  final feedbackMessage = request.feedbackMessage;
  if (feedbackMessage == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(feedbackMessage)),
  );
}
```

```dart
// lib/modules/search/presentation/widgets/search_date_calendar.dart
Container(
  key: ValueKey<String>('search-date-day-chip-$dayKey'),
  width: 30,
  height: 30,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: isSelected ? palette.accent : Colors.transparent,
    borderRadius: BorderRadius.circular(15),
  ),
  child: Text(
    dayLabel,
    key: ValueKey<String>('search-date-day-label-$dayKey'),
    style: TextStyle(
      color: isSelected
          ? Colors.white
          : canOpen
          ? palette.primaryText
          : palette.secondaryText,
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
    ),
  ),
),
Text(
  cell.isToday ? strings.today : ' ',
  key: ValueKey<String>('search-date-today-$dayKey'),
  style: TextStyle(
    color: cell.isToday ? palette.accent : Colors.transparent,
    fontSize: 12,
  ),
),
```

- [ ] **Step 4: Run the date-page test to verify it passes**

Run: `flutter test test/modules/search/chat_search_date_page_test.dart`  
Expected: PASS with resolver or coordinator usage, selected-day persistence, and snackbar fallback coverage

- [ ] **Step 5: Checkpoint the date-page convergence**

```bash
git add lib/modules/search/presentation/chat_search_date_page.dart lib/modules/search/presentation/widgets/search_date_calendar.dart test/modules/search/chat_search_date_page_test.dart
git commit -m "feat: converge date search onto shared locate pipeline"
```

### Task 6: Run Child Plan A Compatibility And Final Regression

**Files:**
- No additional code changes expected if earlier tasks are correct

- [ ] **Step 1: Run the targeted Child Plan A unit and widget suite**

Run: `flutter test test/modules/search/search_models_test.dart test/modules/search/search_locate_resolver_test.dart test/modules/search/chat_locate_coordinator_test.dart test/modules/search/chat_date_calendar_controller_test.dart test/modules/search/chat_search_date_page_test.dart`  
Expected: PASS with all locate and date-search foundations green

- [ ] **Step 2: Run compatibility coverage for unchanged search pages**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/search_pages_compile_test.dart`  
Expected: PASS, proving the compatibility wrapper kept existing callers stable

- [ ] **Step 3: Run static analysis on the touched search files**

Run: `flutter analyze lib/modules/search/domain/search_models.dart lib/modules/search/data/search_locate_resolver.dart lib/modules/search/application/chat_locate_coordinator.dart lib/modules/search/application/chat_date_calendar_controller.dart lib/modules/search/application/search_providers.dart lib/modules/search/presentation/chat_search_date_page.dart lib/modules/search/presentation/widgets/search_date_calendar.dart`  
Expected: `No issues found!`

- [ ] **Step 4: If local evidence and deployed behavior disagree, collect remote verification evidence**

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|message|order_seq'"`  
Expected: enough runtime evidence to decide whether any remaining mismatch is local navigation wiring or a deployed service issue

- [ ] **Step 5: Checkpoint the verified Child Plan A finish line**

```bash
git add lib/modules/search test/modules/search
git commit -m "feat: complete phase 6a date search locate foundation"
```
