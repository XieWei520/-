# Phase 6B Chat-Scoped Search Mainline Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge the Flutter chat-scoped search mainline so Android runtime behavior inside a conversation matches the TangSengDaoDao Android reference for search entry, keyword results, image or file or link scoped search, and member-result navigation while preserving the Phase 6A shared locate foundation.

**Architecture:** This plan upgrades the existing `lib/modules/search/**` search kernel rather than replacing it. The mainline work is to turn keyword search into the same controller-owned paginated state machine already used by media and member search, rebuild the chat search entry shell to match Android interaction meaning, make keyword results visually and behaviorally closer to Android, and force every chat-scoped result tap through the explicit `SearchLocateResolver -> ChatLocateCoordinator` protocol introduced in Phase 6A.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, wukongimfluttersdk, existing `lib/modules/search/**` kernel, PowerShell, optional SSH verification against `root@103.207.68.33` when deployed behavior diverges from local evidence

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only the approved design in [2026-04-05-phase-6-search-convergence-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-05-phase-6-search-convergence-design.md), specifically `Child Plan B: Chat-Scoped Search Mainline Convergence`.

In scope:

- final chat search entry behavior inside a conversation
- keyword result convergence, including pagination and incremental failure semantics
- explicit shared-locate convergence for keyword, image, file, link, and member results
- regression coverage proving image and member parity work remains preserved while being absorbed into the shared locate protocol

Out of scope for this plan:

- reopening Phase 6A date-search logic or shared locate domain modeling already verified green
- global-search shaping or global message-result convergence from Phase 6C
- backend contract rewrites unless deployed verification proves a real server-side blocker
- non-search Phase 6 domains

## Current Code Reality To Preserve

The implementation must start from the current verified Phase 6A baseline:

- `lib/modules/search/application/chat_keyword_search_controller.dart` still performs debounce plus first-page fetch only, so keyword results lag behind the paged architecture already used by media and member search
- `lib/modules/search/presentation/chat_search_entry_page.dart` still renders a generic `AppBar(title: Text('Search Chat'))` shell instead of the Android inline search bar plus cancel-row contract
- `lib/modules/search/presentation/chat_search_results_page.dart` is still a thin `ListView` wrapper with no load-more footer or incremental-failure semantics
- `lib/modules/search/presentation/chat_search_collection_page.dart` and `lib/modules/search/presentation/chat_search_member_page.dart` already preserve image and member parity behaviors and must not be redesigned from scratch
- `lib/modules/search/data/search_locate_resolver.dart` and `lib/modules/search/application/chat_locate_coordinator.dart` already exist from Phase 6A, but the chat-scoped pages still lean on the old `buildOpenRequest(hit, ...)` wrapper instead of explicitly producing `ChatLocateIntent`
- `lib/modules/search/search_with_img_page.dart` and `lib/modules/search/search_with_member_page.dart` are compatibility wrappers and should remain valid for legacy entry points even if the main chat search page now routes directly to the mainline search pages
- Android `MessageRecordActivity`, `SearchMessageAdapter`, `SearchWithImgActivity`, and `SearchWithMemberActivity` define the visible behavior contract: inline search field plus cancel affordance, empty-keyword menu, paged result list, grouped image results, member results as paged message hits, and anchored 'show in chat' navigation

This plan must therefore tighten the mainline contract without destabilizing the already-finished scoped search behavior or reopening Phase 6A foundations.

## File Structure

### New Files

- `lib/modules/search/presentation/search_chat_navigation.dart`
  - Shared presentation helper that takes a normalized `ChatLocateIntent`, uses `ChatLocateCoordinator`, opens `ChatPage`, and surfaces explicit fallback feedback.
- `test/modules/search/chat_keyword_search_controller_test.dart`
  - Unit tests that lock keyword pagination, stale-request invalidation, incremental failure retention, and explicit retry semantics.
- `test/modules/search/chat_search_results_page_test.dart`
  - Widget tests that lock keyword result list pagination triggers, incremental failure footer behavior, and richer Android-style tile rendering.

### Existing Files To Modify

- `lib/modules/search/application/chat_keyword_search_controller.dart`
  - Upgrade from debounce-only first-page fetching to a paged controller-owned state machine aligned with `ChatMediaSearchController` and `ChatMemberSearchController`.
- `lib/modules/search/presentation/chat_search_entry_page.dart`
  - Replace the generic scaffold shell with Android-style inline search chrome, route empty-keyword menu entries directly to the converged scoped pages, and wire keyword hits through the explicit locate-intent flow.
- `lib/modules/search/presentation/chat_search_results_page.dart`
  - Add load-more notifications, footer rendering, retry affordance, and wire in the richer result tile contract.
- `lib/modules/search/presentation/chat_search_collection_page.dart`
  - Stop using the legacy coordinator convenience wrapper and route show-in-chat behavior through the explicit resolver plus shared navigation helper.
- `lib/modules/search/presentation/chat_search_member_page.dart`
  - Stop using the legacy coordinator convenience wrapper and route member result taps through the explicit resolver plus shared navigation helper.
- `lib/modules/search/presentation/widgets/search_message_tile.dart`
  - Replace the generic `ListTile` with an Android-closer message result tile that exposes stable keys for avatar, name, time, and content assertions.
- `lib/modules/search/presentation/widgets/search_menu_grid.dart`
  - Tighten grid spacing and stable keys so the entry page can reproduce the Android empty-keyword affordance more faithfully.
- `test/modules/search/chat_search_entry_page_test.dart`
  - Update entry tests for Android-style shell behavior, direct scoped-page routing, shared locate intent usage, and paged keyword result transitions.
- `test/modules/search/chat_search_collection_page_test.dart`
  - Add explicit locate-intent coverage for image or file or link 'show in chat' behavior.
- `test/modules/search/chat_search_member_page_test.dart`
  - Add explicit locate-intent coverage for member-result taps while keeping current incremental failure coverage intact.
- `test/modules/search/search_pages_compile_test.dart`
  - Keep compile coverage current after the direct mainline routing and new helper imports land.

## Verification Commands Used Throughout

- `flutter test test/modules/search/chat_keyword_search_controller_test.dart`
- `flutter test test/modules/search/chat_search_results_page_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart`
- `flutter test test/modules/search/chat_search_collection_page_test.dart`
- `flutter test test/modules/search/chat_search_member_page_test.dart`
- `flutter test test/modules/search/chat_search_date_page_test.dart test/modules/search/search_locate_resolver_test.dart test/modules/search/chat_locate_coordinator_test.dart test/modules/search/search_pages_compile_test.dart`
- `flutter analyze lib/modules/search/application/chat_keyword_search_controller.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_results_page.dart lib/modules/search/presentation/chat_search_collection_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/presentation/search_chat_navigation.dart lib/modules/search/presentation/widgets/search_message_tile.dart lib/modules/search/presentation/widgets/search_menu_grid.dart`

If local evidence passes but deployed behavior still diverges, run:

- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|message|order_seq|keyword'"`

### Task 1: Upgrade Keyword Search Into A Paged Controller-Owned State Machine

**Files:**
- Modify: `lib/modules/search/application/chat_keyword_search_controller.dart`
- Create: `test/modules/search/chat_keyword_search_controller_test.dart`

- [ ] **Step 1: Write the failing keyword-controller tests**

```dart
class _FakeKeywordRepository implements SearchRepository {
  _FakeKeywordRepository({
    this.pagesByKeyword = const <String, Map<int, List<SearchMessageHit>>>{},
    this.pendingByKeywordPage =
        const <String, Completer<List<SearchMessageHit>>>{},
    this.failingKeywordPages = const <String, Set<int>>{},
  });

  final Map<String, Map<int, List<SearchMessageHit>>> pagesByKeyword;
  final Map<String, Completer<List<SearchMessageHit>>> pendingByKeywordPage;
  final Map<String, Set<int>> failingKeywordPages;
  final List<({String keyword, int page})> calls = <({String keyword, int page})>[];

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async {
    calls.add((keyword: keyword, page: page));
    final pending = pendingByKeywordPage['$keyword:$page'];
    if (pending != null) {
      return pending.future;
    }
    if (failingKeywordPages[keyword]?.contains(page) == true) {
      throw Exception('keyword page $page failed');
    }
    return pagesByKeyword[keyword]?[page] ?? const <SearchMessageHit>[];
  }

  @override
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async => const <SearchDateMonthSection>[];

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async => const <SearchMediaItem>[];

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async => const <SearchMemberHit>[];

  @override
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async {
    return const GlobalSearchSnapshot();
  }
}

test('updateKeyword loads page 1 and loadMore appends page 2', () async {
  final repository = _FakeKeywordRepository(
    pagesByKeyword: <String, Map<int, List<SearchMessageHit>>>{
      'alpha': <int, List<SearchMessageHit>>{
        1: List<SearchMessageHit>.generate(20, (index) {
          final seq = 100 + index;
          return SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: seq,
            orderSeq: 70000 + seq,
            timestamp: 1712123456,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'alpha result $seq',
            channelName: 'Project Group',
          );
        }),
        2: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: 200,
            orderSeq: 70200,
            timestamp: 1712123556,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'alpha result 200',
            channelName: 'Project Group',
          ),
        ],
      },
    },
  );

  final controller = ChatKeywordSearchController(
    channelId: 'group-1',
    channelType: 2,
    repository: repository,
    debounce: Duration.zero,
  );

  controller.updateKeyword('alpha');
  await Future<void>.delayed(Duration.zero);

  expect(controller.state.items, hasLength(20));
  expect(controller.state.page, 2);
  expect(controller.state.hasMore, isTrue);

  await controller.loadMore();

  expect(controller.state.items, hasLength(21));
  expect(controller.state.page, 3);
  expect(controller.state.hasMore, isFalse);
});

test('stale first-page results do not replace a newer keyword', () async {
  final alphaPending = Completer<List<SearchMessageHit>>();
  final repository = _FakeKeywordRepository(
    pagesByKeyword: <String, Map<int, List<SearchMessageHit>>>{
      'beta': <int, List<SearchMessageHit>>{
        1: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: 300,
            orderSeq: 70300,
            timestamp: 1712123656,
            contentType: 1,
            fromUid: 'u_bob',
            fromName: 'Bob',
            previewText: 'beta result',
            channelName: 'Project Group',
          ),
        ],
      },
    },
    pendingByKeywordPage: <String, Completer<List<SearchMessageHit>>>{
      'alpha:1': alphaPending,
    },
  );

  final controller = ChatKeywordSearchController(
    channelId: 'group-1',
    channelType: 2,
    repository: repository,
    debounce: Duration.zero,
  );

  controller.updateKeyword('alpha');
  await Future<void>.delayed(Duration.zero);
  controller.updateKeyword('beta');
  await Future<void>.delayed(Duration.zero);
  alphaPending.complete(const <SearchMessageHit>[
    SearchMessageHit(
      channelId: 'group-1',
      channelType: 2,
      messageSeq: 301,
      orderSeq: 70301,
      timestamp: 1712123756,
      contentType: 1,
      fromUid: 'u_alex',
      fromName: 'Alex',
      previewText: 'stale alpha result',
      channelName: 'Project Group',
    ),
  ]);
  await Future<void>.delayed(Duration.zero);

  expect(controller.state.keyword, 'beta');
  expect(controller.state.items.single.previewText, 'beta result');
});

test('incremental failure keeps visible results until explicit retry', () async {
  final repository = _FakeKeywordRepository(
    pagesByKeyword: <String, Map<int, List<SearchMessageHit>>>{
      'alpha': <int, List<SearchMessageHit>>{
        1: List<SearchMessageHit>.generate(20, (index) {
          final seq = 400 + index;
          return SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: seq,
            orderSeq: 70400 + seq,
            timestamp: 1712123856,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'alpha result $seq',
            channelName: 'Project Group',
          );
        }),
      },
    },
    failingKeywordPages: const <String, Set<int>>{
      'alpha': <int>{2},
    },
  );

  final controller = ChatKeywordSearchController(
    channelId: 'group-1',
    channelType: 2,
    repository: repository,
    debounce: Duration.zero,
  );

  controller.updateKeyword('alpha');
  await Future<void>.delayed(Duration.zero);

  await controller.loadMore();
  final callsAfterFailure = repository.calls.length;

  expect(controller.state.items, hasLength(20));
  expect(controller.state.loadMoreError, isNotNull);

  await controller.loadMore();
  expect(repository.calls.length, callsAfterFailure);
});
```

- [ ] **Step 2: Run the keyword-controller test to verify it fails**

Run: `flutter test test/modules/search/chat_keyword_search_controller_test.dart`  
Expected: FAIL with missing `page`, `isLoadingMore`, `hasMore`, `loadMoreError`, `loadMore()`, or stale-request expectations that the current debounce-only controller cannot satisfy

- [ ] **Step 3: Implement paginated keyword state and explicit retry semantics**

```dart
// lib/modules/search/application/chat_keyword_search_controller.dart
@immutable
class ChatKeywordSearchState {
  const ChatKeywordSearchState({
    this.keyword = '',
    this.items = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final List<SearchMessageHit> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  bool get hasKeyword => keyword.trim().isNotEmpty;

  ChatKeywordSearchState copyWith({
    String? keyword,
    List<SearchMessageHit>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatKeywordSearchState(
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _errorSentinel)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }
}

const int _defaultPageSize = 20;

void updateKeyword(String value) {
  _debounceTimer?.cancel();
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    _requestVersion += 1;
    state = ChatKeywordSearchState(keyword: value);
    return;
  }

  final requestVersion = ++_requestVersion;
  state = ChatKeywordSearchState(
    keyword: value,
    isLoading: true,
    hasMore: true,
  );

  _debounceTimer = Timer(_debounceDuration, () {
    unawaited(
      _loadFirstPage(
        rawKeyword: value,
        trimmedKeyword: trimmed,
        requestVersion: requestVersion,
      ),
    );
  });
}

Future<void> _loadFirstPage({
  required String rawKeyword,
  required String trimmedKeyword,
  required int requestVersion,
}) async {
  try {
    final items = await _repository.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: trimmedKeyword,
      page: 1,
      limit: _defaultPageSize,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = ChatKeywordSearchState(
      keyword: rawKeyword,
      items: items,
      page: 2,
      isLoading: false,
      hasMore: items.length >= _defaultPageSize,
    );
  } catch (error) {
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = ChatKeywordSearchState(
      keyword: rawKeyword,
      isLoading: false,
      hasMore: false,
      error: error.toString(),
    );
  }
}

Future<void> loadMore({bool isRetry = false}) async {
  final trimmedKeyword = state.keyword.trim();
  if (trimmedKeyword.isEmpty ||
      state.isLoading ||
      state.isLoadingMore ||
      !state.hasMore) {
    return;
  }
  if (!isRetry && state.loadMoreError != null) {
    return;
  }

  final requestVersion = _requestVersion;
  state = state.copyWith(isLoadingMore: true, loadMoreError: null);

  try {
    final items = await _repository.searchMessages(
      channelId: channelId,
      channelType: channelType,
      keyword: trimmedKeyword,
      page: state.page,
      limit: _defaultPageSize,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      items: <SearchMessageHit>[...state.items, ...items],
      page: state.page + 1,
      isLoadingMore: false,
      hasMore: items.length >= _defaultPageSize,
      loadMoreError: null,
    );
  } catch (error) {
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      isLoadingMore: false,
      loadMoreError: error.toString(),
    );
  }
}

void retry() {
  updateKeyword(state.keyword);
}
```

- [ ] **Step 4: Run the keyword-controller test to verify it passes**

Run: `flutter test test/modules/search/chat_keyword_search_controller_test.dart`  
Expected: PASS with green coverage for first page, load more, stale-request invalidation, and incremental failure retention

- [ ] **Step 5: Checkpoint the keyword controller upgrade**

```bash
git add lib/modules/search/application/chat_keyword_search_controller.dart test/modules/search/chat_keyword_search_controller_test.dart
git commit -m "feat: paginate chat keyword search"
```

### Task 2: Rebuild The Chat Search Entry Shell To Match Android Interaction Meaning

**Files:**
- Modify: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Modify: `lib/modules/search/presentation/widgets/search_menu_grid.dart`
- Modify: `test/modules/search/chat_search_entry_page_test.dart`

- [ ] **Step 1: Write the failing entry-shell widget tests**

```dart
testWidgets('empty keyword shows Android-style search shell and scoped menu hint', (
  tester,
) async {
  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
      repository: _FakeSearchRepository(),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(AppBar), findsNothing);
  expect(find.byKey(const ValueKey<String>('chat-search-inline-shell')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('chat-search-cancel')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('chat-search-menu-hint')), findsOneWidget);
  expect(find.text('Search specified content'), findsOneWidget);
});

testWidgets('typing a keyword hides the scoped menu and shows the keyword result list', (
  tester,
) async {
  final repository = _FakeSearchRepository(
    resultsByKeyword: <String, List<SearchMessageHit>>{
      'keyword': const <SearchMessageHit>[
        SearchMessageHit(
          channelId: 'group-1',
          channelType: 2,
          messageSeq: 42,
          orderSeq: 77,
          timestamp: 1712123456,
          contentType: 1,
          fromUid: 'u_alex',
          fromName: 'Alex',
          previewText: 'keyword result',
          channelName: 'Project Group',
        ),
      ],
    },
  );

  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
      repository: repository,
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('chat-search-field')),
    'keyword',
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));

  expect(find.byKey(const ValueKey<String>('chat-search-menu-grid')), findsNothing);
  expect(find.byKey(const ValueKey<String>('chat-search-results-list')), findsOneWidget);
});

testWidgets('empty-keyword menu routes directly to converged scoped pages', (
  tester,
) async {
  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchEntryPage(
        channelId: 'group-1',
        channelType: 2,
        channelName: 'Project Group',
      ),
      repository: _FakeSearchRepository(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('chat-search-menu-image')));
  await tester.pumpAndSettle();
  final imagePage = tester.widget<ChatSearchCollectionPage>(
    find.byType(ChatSearchCollectionPage),
  );
  expect(imagePage.scope, SearchCollectionScope.image);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();

  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchEntryPage(
        channelId: 'group-1',
        channelType: 2,
        channelName: 'Project Group',
      ),
      repository: _FakeSearchRepository(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('chat-search-menu-member')));
  await tester.pumpAndSettle();
  expect(find.byType(ChatSearchMemberPage), findsOneWidget);
});
```

- [ ] **Step 2: Run the entry-page test to verify it fails**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`  
Expected: FAIL because the page still shows a generic `AppBar`, still routes image and member items through wrapper pages, and does not expose the Android-style inline shell keys

- [ ] **Step 3: Implement the Android-style entry shell and direct scoped-page routing**

```dart
// lib/modules/search/presentation/chat_search_entry_page.dart
return Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Row(
            key: const ValueKey<String>('chat-search-inline-shell'),
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    key: const ValueKey<String>('chat-search-field'),
                    controller: _textController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: controller.updateKeyword,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey<String>('chat-search-cancel'),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.hasKeyword
              ? _SearchResultsBody(
                  state: state,
                  onLoadMore: controller.loadMore,
                  onRetryInitial: controller.retry,
                  onRetryLoadMore: () => controller.loadMore(isRetry: true),
                  onTap: _openSearchResult,
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                  child: Column(
                    children: [
                      Text(
                        'Search specified content',
                        key: const ValueKey<String>('chat-search-menu-hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SearchMenuGrid(
                        entries: buildDefaultSearchMenuEntries(),
                        onTap: _handleMenuTap,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  ),
);

void _handleMenuTap(SearchMenuEntry entry) {
  final Widget page = switch (entry.kind) {
    SearchMenuKind.date => ChatSearchDatePage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
    ),
    SearchMenuKind.image => ChatSearchCollectionPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      scope: SearchCollectionScope.image,
    ),
    SearchMenuKind.file => ChatSearchCollectionPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      scope: SearchCollectionScope.file,
    ),
    SearchMenuKind.link => ChatSearchCollectionPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      scope: SearchCollectionScope.link,
    ),
    SearchMenuKind.member => ChatSearchMemberPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
    ),
  };

  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
```

```dart
// lib/modules/search/presentation/widgets/search_menu_grid.dart
return GridView.count(
  key: const ValueKey<String>('chat-search-menu-grid'),
  crossAxisCount: 3,
  mainAxisSpacing: 18,
  crossAxisSpacing: 18,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  childAspectRatio: 1.25,
  children: entries
      .map(
        (entry) => InkWell(
          key: ValueKey<String>(entry.key),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WKReferenceAssets.image(entry.iconAsset, width: 22, height: 22),
                const SizedBox(height: 8),
                Text(entry.title, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      )
      .toList(growable: false),
);
```

- [ ] **Step 4: Run the entry-page test to verify it passes**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`  
Expected: PASS with inline shell rendering, empty-keyword menu hint visibility, and direct routing to converged scoped pages

- [ ] **Step 5: Checkpoint the Android-style entry shell**

```bash
git add lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/widgets/search_menu_grid.dart test/modules/search/chat_search_entry_page_test.dart
git commit -m "feat: align chat search entry with android shell"
```

### Task 3: Add A Paged Keyword Results Surface And Android-Closer Result Tiles

**Files:**
- Modify: `lib/modules/search/presentation/chat_search_results_page.dart`
- Modify: `lib/modules/search/presentation/widgets/search_message_tile.dart`
- Modify: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Create: `test/modules/search/chat_search_results_page_test.dart`

- [ ] **Step 1: Write the failing keyword-results widget tests**

```dart
testWidgets('keyword result tile exposes avatar, name, time, and content keys', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChatSearchResultsPage(
        items: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: 42,
            orderSeq: 77,
            timestamp: 1712123456,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'keyword result',
            channelName: 'Project Group',
          ),
        ],
        onTap: (_) {},
      ),
    ),
  );

  expect(find.byKey(const ValueKey<String>('search-keyword-result-42')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('search-keyword-result-avatar-42')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('search-keyword-result-name-42')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('search-keyword-result-time-42')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('search-keyword-result-content-42')), findsOneWidget);
});

testWidgets('scrolling near the end triggers keyword load more and retry footer', (
  tester,
) async {
  var loadMoreCalls = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: ChatSearchResultsPage(
        items: List<SearchMessageHit>.generate(20, (index) {
          final seq = 100 + index;
          return SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: seq,
            orderSeq: 70000 + seq,
            timestamp: 1712123456,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'keyword result $seq',
            channelName: 'Project Group',
          );
        }),
        onTap: (_) {},
        onLoadMore: () {
          loadMoreCalls += 1;
        },
      ),
    ),
  );

  await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
  await tester.pump();

  expect(loadMoreCalls, greaterThanOrEqualTo(1));
});

testWidgets('load-more failure keeps visible items and offers retry', (tester) async {
  var retried = false;
  await tester.pumpWidget(
    MaterialApp(
      home: ChatSearchResultsPage(
        items: const <SearchMessageHit>[
          SearchMessageHit(
            channelId: 'group-1',
            channelType: 2,
            messageSeq: 42,
            orderSeq: 77,
            timestamp: 1712123456,
            contentType: 1,
            fromUid: 'u_alex',
            fromName: 'Alex',
            previewText: 'keyword result',
            channelName: 'Project Group',
          ),
        ],
        onTap: (_) {},
        loadMoreError: 'load more failed',
        onRetryLoadMore: () {
          retried = true;
        },
      ),
    ),
  );

  expect(find.byKey(const ValueKey<String>('search-keyword-result-42')), findsOneWidget);
  expect(find.text('Load more failed'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey<String>('chat-search-load-more-retry')));
  expect(retried, isTrue);
});
```

- [ ] **Step 2: Run the keyword-results test to verify it fails**

Run: `flutter test test/modules/search/chat_search_results_page_test.dart`  
Expected: FAIL because the current results page has no load-more API, no retry footer, and the current `SearchMessageTile` exposes none of the richer Android-style layout keys

- [ ] **Step 3: Implement the paged results list and richer tile contract**

```dart
// lib/modules/search/presentation/chat_search_results_page.dart
class ChatSearchResultsPage extends StatelessWidget {
  const ChatSearchResultsPage({
    super.key,
    required this.items,
    required this.onTap,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onLoadMore,
    this.onRetryLoadMore,
  });

  final List<SearchMessageHit> items;
  final ValueChanged<SearchMessageHit> onTap;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          onLoadMore?.call();
        }
        return false;
      },
      child: ListView.builder(
        key: const ValueKey<String>('chat-search-results-list'),
        itemCount: items.length + ((isLoadingMore || loadMoreError != null) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            if (isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Load more failed'),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey<String>('chat-search-load-more-retry'),
                      onPressed: onRetryLoadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final hit = items[index];
          return SearchMessageTile(
            hit: hit,
            onTap: () => onTap(hit),
          );
        },
      ),
    );
  }
}
```

```dart
// lib/modules/search/presentation/widgets/search_message_tile.dart
return InkWell(
  key: ValueKey<String>('search-keyword-result-${hit.messageSeq}'),
  onTap: onTap,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WKUserAvatar(
          key: ValueKey<String>('search-keyword-result-avatar-${hit.messageSeq}'),
          avatarUrl: null,
          name: title,
          size: 40,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      key: ValueKey<String>('search-keyword-result-name-${hit.messageSeq}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF999999),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTimestamp(hit.timestamp),
                    key: ValueKey<String>('search-keyword-result-time-${hit.messageSeq}'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF999999),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                hit.previewText,
                key: ValueKey<String>('search-keyword-result-content-${hit.messageSeq}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF313131),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
```

```dart
// lib/modules/search/presentation/chat_search_entry_page.dart
class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.state,
    required this.onTap,
    required this.onRetryInitial,
    required this.onLoadMore,
    required this.onRetryLoadMore,
  });

  final ChatKeywordSearchState state;
  final ValueChanged<SearchMessageHit> onTap;
  final VoidCallback onRetryInitial;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetryInitial, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return ChatSearchResultsPage(
      items: state.items,
      onTap: onTap,
      isLoadingMore: state.isLoadingMore,
      loadMoreError: state.loadMoreError,
      onLoadMore: onLoadMore,
      onRetryLoadMore: onRetryLoadMore,
    );
  }
}
```

- [ ] **Step 4: Run the keyword-results test to verify it passes**

Run: `flutter test test/modules/search/chat_search_results_page_test.dart`  
Expected: PASS with load-more notifications, retry footer coverage, and stable result tile keys

- [ ] **Step 5: Checkpoint the paged results surface**

```bash
git add lib/modules/search/presentation/chat_search_results_page.dart lib/modules/search/presentation/widgets/search_message_tile.dart lib/modules/search/presentation/chat_search_entry_page.dart test/modules/search/chat_search_results_page_test.dart
git commit -m "feat: converge keyword result list behavior"
```

### Task 4: Converge Keyword, Collection, And Member Result Taps Onto The Explicit Shared Locate Protocol

**Files:**
- Create: `lib/modules/search/presentation/search_chat_navigation.dart`
- Modify: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Modify: `lib/modules/search/presentation/chat_search_collection_page.dart`
- Modify: `lib/modules/search/presentation/chat_search_member_page.dart`
- Modify: `test/modules/search/chat_search_entry_page_test.dart`
- Modify: `test/modules/search/chat_search_collection_page_test.dart`
- Modify: `test/modules/search/chat_search_member_page_test.dart`
- Modify: `test/modules/search/search_pages_compile_test.dart`

- [ ] **Step 1: Write the failing shared-locate widget tests**

```dart
class _RecordingLocateResolver extends SearchLocateResolver {
  _RecordingLocateResolver({required this.intent});

  final ChatLocateIntent intent;
  final List<String> sources = <String>[];

  @override
  ChatLocateIntent fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    sources.add(source);
    return intent;
  }
}

class _RecordingLocateCoordinator extends ChatLocateCoordinator {
  _RecordingLocateCoordinator({required this.request})
      : super(
          resolveOrderSeq: ({
            required int messageSeq,
            required String channelId,
            required int channelType,
          }) async => 0,
        );

  final ChatOpenRequest request;
  final List<ChatLocateIntent> intents = <ChatLocateIntent>[];

  @override
  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    intents.add(intent);
    return request;
  }
}

testWidgets('keyword result tap uses SearchLocateResolver source chat-keyword-search', (
  tester,
) async {
  final resolver = _RecordingLocateResolver(
    intent: const ChatLocateIntent(
      channelId: 'group-1',
      channelType: 2,
      orderSeq: 8801,
      source: 'chat-keyword-search',
      channelName: 'Project Group',
    ),
  );
  final coordinator = _RecordingLocateCoordinator(
    request: const ChatOpenRequest(
      channelId: 'group-1',
      channelType: 2,
      orderSeq: 8801,
      highlightKeyword: 'keyword',
      source: 'chat-keyword-search',
      channelName: 'Project Group',
    ),
  );

  await tester.pumpWidget(
    wrapWithApp(
      const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
      repository: _FakeSearchRepository(
        resultsByKeyword: <String, List<SearchMessageHit>>{
          'keyword': const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'group-1',
              channelType: 2,
              messageSeq: 42,
              orderSeq: 0,
              timestamp: 1712123456,
              contentType: 1,
              fromUid: 'u_alex',
              fromName: 'Alex',
              previewText: 'keyword result',
              channelName: 'Project Group',
            ),
          ],
        },
      ),
      locateResolver: resolver,
      coordinator: coordinator,
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('chat-search-field')),
    'keyword',
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
  await tester.tap(find.byKey(const ValueKey<String>('search-keyword-result-42')));
  await tester.pumpAndSettle();

  expect(resolver.sources.single, 'chat-keyword-search');
  expect(coordinator.intents.single.source, 'chat-keyword-search');
  final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
  expect(shell.initialAroundOrderSeq, 8801);
});

testWidgets('file show-in-chat uses explicit locate intent source chat-collection-search', (
  tester,
) async {
  final resolver = _RecordingLocateResolver(
    intent: const ChatLocateIntent(
      channelId: 'g1001',
      channelType: 2,
      orderSeq: 9901,
      source: 'chat-collection-search',
      channelName: 'Design',
    ),
  );
  final coordinator = _RecordingLocateCoordinator(
    request: const ChatOpenRequest(
      channelId: 'g1001',
      channelType: 2,
      orderSeq: 9901,
      highlightKeyword: '',
      source: 'chat-collection-search',
      channelName: 'Design',
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FakeScopedRepository()),
        searchLocateResolverProvider.overrideWithValue(resolver),
        chatLocateCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MaterialApp(
        home: ChatSearchCollectionPage(
          channelId: 'g1001',
          channelType: 2,
          scope: SearchCollectionScope.file,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('search-collection-item-33')));
  await tester.pumpAndSettle();

  expect(resolver.sources.single, 'chat-collection-search');
  expect(coordinator.intents.single.source, 'chat-collection-search');
});

testWidgets('member result tap uses explicit locate intent source chat-member-search', (
  tester,
) async {
  final resolver = _RecordingLocateResolver(
    intent: const ChatLocateIntent(
      channelId: 'g1001',
      channelType: 2,
      orderSeq: 44000,
      source: 'chat-member-search',
      channelName: 'Design',
    ),
  );
  final coordinator = _RecordingLocateCoordinator(
    request: const ChatOpenRequest(
      channelId: 'g1001',
      channelType: 2,
      orderSeq: 44000,
      highlightKeyword: '',
      source: 'chat-member-search',
      channelName: 'Design',
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FakeScopedRepository()),
        searchLocateResolverProvider.overrideWithValue(resolver),
        chatLocateCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MaterialApp(
        home: ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('search-member-u_alice')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('search-member-result-44')));
  await tester.pumpAndSettle();

  expect(resolver.sources.single, 'chat-member-search');
  expect(coordinator.intents.single.source, 'chat-member-search');
});
```

- [ ] **Step 2: Run the shared-locate widget tests to verify they fail**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`  
Expected: FAIL because the current pages still lean on `ChatLocateCoordinator.buildOpenRequest(hit, ...)`, do not override `searchLocateResolverProvider`, and do not share one presentation helper for the final chat-open path

- [ ] **Step 3: Implement explicit locate-intent resolution and shared navigation helper**

```dart
// lib/modules/search/presentation/search_chat_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';

import '../application/search_providers.dart';
import '../domain/search_models.dart';

Future<void> openSearchIntentInChat(
  BuildContext context,
  WidgetRef ref, {
  required ChatLocateIntent intent,
  String? fallbackChannelName,
}) async {
  final request = await ref
      .read(chatLocateCoordinatorProvider)
      .buildOpenRequestFromIntent(intent);

  if (!context.mounted) {
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChatPage(
        channelId: request.channelId,
        channelType: request.channelType,
        channelName: request.channelName ?? fallbackChannelName,
        initialAroundOrderSeq: request.orderSeq,
      ),
    ),
  );

  final feedbackMessage = request.feedbackMessage;
  if (feedbackMessage == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(feedbackMessage)),
  );
}
```

```dart
// lib/modules/search/presentation/chat_search_entry_page.dart
Future<void> _openSearchResult(SearchMessageHit hit) async {
  final resolver = ref.read(searchLocateResolverProvider);
  final intent = resolver.fromSearchHit(
    hit,
    highlightKeyword: _textController.text.trim(),
    source: 'chat-keyword-search',
  );
  await openSearchIntentInChat(
    context,
    ref,
    intent: intent,
    fallbackChannelName: widget.channelName,
  );
}
```

```dart
// lib/modules/search/presentation/chat_search_collection_page.dart
Future<void> _showInChat(
  BuildContext context,
  WidgetRef ref,
  SearchMediaItem item,
) async {
  final resolver = ref.read(searchLocateResolverProvider);
  final intent = resolver.fromSearchHit(
    item.hit,
    highlightKeyword: '',
    source: 'chat-collection-search',
  );
  await openSearchIntentInChat(
    context,
    ref,
    intent: intent,
    fallbackChannelName: channelName,
  );
}
```

```dart
// lib/modules/search/presentation/chat_search_member_page.dart
Future<void> _openResult(
  BuildContext context,
  WidgetRef ref,
  SearchMessageHit hit,
) async {
  final resolver = ref.read(searchLocateResolverProvider);
  final intent = resolver.fromSearchHit(
    hit,
    highlightKeyword: '',
    source: 'chat-member-search',
  );
  await openSearchIntentInChat(
    context,
    ref,
    intent: intent,
    fallbackChannelName: channelName,
  );
}
```

- [ ] **Step 4: Run the shared-locate widget tests to verify they pass**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`  
Expected: PASS with explicit resolver usage, stable source markers, and converged chat-open behavior across keyword, collection, and member results

- [ ] **Step 5: Checkpoint the chat-scoped locate convergence**

```bash
git add lib/modules/search/presentation/search_chat_navigation.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_collection_page.dart lib/modules/search/presentation/chat_search_member_page.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/search_pages_compile_test.dart
git commit -m "feat: unify chat scoped search navigation"
```

### Task 5: Run Phase 6B Regression, Analysis, And Remote Mismatch Triage

**Files:**
- No additional code changes expected if earlier tasks are correct

**Execution Note (2026-04-05):** Steps 1-4 were rerun locally and passed. Step 5 was not needed because no deployed mismatch remained after fresh local verification. Step 6 is recorded as a local evidence checkpoint because this workspace still has no `.git` metadata.

- [x] **Step 1: Run the Phase 6B controller and results suites**

Run: `flutter test test/modules/search/chat_keyword_search_controller_test.dart test/modules/search/chat_search_results_page_test.dart`  
Expected: PASS with green coverage for paged keyword search state and the keyword results surface

- [x] **Step 2: Run the chat-scoped search widget regression suites**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart`  
Expected: PASS, proving Android-style shell behavior and explicit locate convergence across the scoped pages

- [x] **Step 3: Run the shared-foundation compatibility suites**

Run: `flutter test test/modules/search/chat_search_date_page_test.dart test/modules/search/search_locate_resolver_test.dart test/modules/search/chat_locate_coordinator_test.dart test/modules/search/search_pages_compile_test.dart`  
Expected: PASS, proving Phase 6B did not destabilize the Phase 6A locate foundation or page compile coverage

- [x] **Step 4: Run static analysis on the touched search files**

Run: `flutter analyze lib/modules/search/application/chat_keyword_search_controller.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/presentation/chat_search_results_page.dart lib/modules/search/presentation/chat_search_collection_page.dart lib/modules/search/presentation/chat_search_member_page.dart lib/modules/search/presentation/search_chat_navigation.dart lib/modules/search/presentation/widgets/search_message_tile.dart lib/modules/search/presentation/widgets/search_menu_grid.dart`  
Expected: `No issues found!`

- [x] **Step 5: If deployed behavior still diverges, collect remote search evidence**

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|message|order_seq|keyword'"`  
Expected: enough runtime evidence to decide whether any remaining mismatch is local UI wiring, local locate resolution, or a deployed search-service issue

- [x] **Step 6: Checkpoint the verified Phase 6B finish line**

```bash
git add lib/modules/search test/modules/search
git commit -m "feat: complete phase 6b chat scoped search convergence"
```
