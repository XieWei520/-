# Phase 6C Global Search Convergence And Final Regression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge Flutter global search so Android behavior on Android matches the TangSengDaoDao reference for global search shell, message-level result shaping, anchored message navigation, and final search-regression closure.

**Architecture:** This plan removes the remaining legacy global-search drift by moving global search fully onto the `lib/modules/search/**` mainline, replacing direct `SearchApi` map handling with repository-backed domain models and a controller-owned paged state machine, then forcing global message taps through the same `SearchLocateResolver -> ChatLocateCoordinator` protocol already used by Phase 6A and 6B. The page stays Android-faithful at the interaction layer while exceeding the reference in state isolation, testability, and failure handling.

**Tech Stack:** Flutter, flutter_riverpod, flutter_test, Material widgets, wukongimfluttersdk, existing `lib/modules/search/**` search kernel, PowerShell, optional SSH verification against `root@103.207.68.33`

---

**Workspace Note:** This working copy still does not contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Spec Boundary

This plan implements only `Child Plan C: Global Search Convergence And Final Regression` from [2026-04-05-phase-6-search-convergence-design.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/specs/2026-04-05-phase-6-search-convergence-design.md).

In scope:

- global search result shaping cleanup
- message-level global results instead of channel-summarized pseudo results
- shared locate convergence for global message taps
- final search regression coverage across Phase 6A, 6B, and 6C
- remote verification hooks for deployed mismatch triage

Out of scope:

- reopening chat-scoped Phase 6B UX that already passed
- reopening date-search local aggregation from Phase 6A
- non-search product surfaces
- backend rewrites unless deployed verification proves an actual contract bug

## Current Code Reality To Preserve

The implementation must start from the current verified Phase 6B baseline:

- `lib/modules/search/application/global_search_controller.dart` is still a thin direct `SearchApi` wrapper that returns `Map<String, dynamic>` instead of repository-owned domain state
- `lib/modules/search/presentation/global_search_page.dart` is still a large local-state page that owns fetching, result shaping, direct `ChatPage` navigation, and the legacy `SearchMessageResultsPage`
- `lib/service/api/search_api.dart` currently summarizes global message hits by channel, which diverges from Android `remote/GlobalActivity.kt`, where every visible global message row is already a message-bearing hit with message-level anchoring semantics
- the shared locate pipeline from Phase 6A and 6B already exists and must be reused rather than bypassed
- entry points in `lib/modules/conversation/conversation_list_page.dart` and `lib/modules/contacts/contacts_page.dart` already mount `GlobalSearchPage` and must remain stable
- compatibility export `lib/wukong_uikit/search/global_search_page.dart` must keep resolving to the converged page

## Android Contract Anchors

The visible contract for global search is the Android remote global-search flow:

- `wkuikit/src/main/java/com/chat/uikit/search/remote/GlobalActivity.kt`
  - inline search shell plus cancel
  - page 1 loads friends, groups, search-user row, and first message page
  - later pages load message rows only
  - tapping a message row resolves an anchor and opens chat directly
- `wkuikit/src/main/java/com/chat/uikit/search/remote/GlobalAdapter.kt`
  - deterministic section ordering
  - message rows render channel avatar/title, time, and preview text or file text

## File Structure

### New Files

- `test/modules/search/global_search_controller_test.dart`
  - unit tests for the paged global-search controller state machine, stale-request invalidation, incremental failure handling, and message-only pagination semantics
- `test/modules/search/global_search_page_test.dart`
  - widget tests for Android-style global shell behavior, deterministic section rendering, message-tap locate convergence, and load-more footer behavior
- `lib/modules/search/presentation/widgets/global_search_channel_tile.dart`
  - focused user and group row widget matching the Android row meaning while keeping `global_search_page.dart` smaller
- `lib/modules/search/presentation/widgets/global_search_message_tile.dart`
  - focused global message row widget that renders conversation title, timestamp, preview, and stable test keys
- `lib/modules/search/presentation/widgets/global_search_find_user_row.dart`
  - dedicated “find user” row widget with stable keys and Android-faithful layout

### Existing Files To Modify

- `lib/service/api/search_api.dart`
- `lib/modules/search/data/search_api_gateway.dart`
- `lib/modules/search/data/search_remote_data_source.dart`
- `lib/modules/search/domain/search_repository.dart`
- `lib/modules/search/data/search_repository_impl.dart`
- `lib/modules/search/application/global_search_controller.dart`
- `lib/modules/search/application/search_providers.dart`
- `lib/modules/search/presentation/global_search_page.dart`
- `test/modules/search/search_repository_test.dart`
- `test/modules/search/search_pages_compile_test.dart`
- `test/wukong_uikit/search/global_search_page_parity_test.dart`

## Verification Commands Used Throughout

- `flutter test test/modules/search/search_repository_test.dart test/modules/search/global_search_controller_test.dart`
- `flutter test test/modules/search/global_search_page_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart`
- `flutter test test/modules/search/chat_date_calendar_controller_test.dart test/modules/search/chat_keyword_search_controller_test.dart test/modules/search/chat_locate_coordinator_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_date_page_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_image_forward_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/chat_search_results_page_test.dart test/modules/search/search_locate_resolver_test.dart test/modules/search/search_models_test.dart test/modules/search/search_pages_compile_test.dart`
- `flutter analyze lib/modules/search/application/global_search_controller.dart lib/modules/search/presentation/global_search_page.dart lib/modules/search/presentation/widgets/global_search_channel_tile.dart lib/modules/search/presentation/widgets/global_search_message_tile.dart lib/modules/search/presentation/widgets/global_search_find_user_row.dart lib/modules/search/data/search_repository_impl.dart lib/modules/search/data/search_remote_data_source.dart lib/modules/search/data/search_api_gateway.dart lib/modules/search/domain/search_repository.dart lib/service/api/search_api.dart`

If local evidence passes but deployed behavior still diverges, run:

- `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|global|message_seq|order_seq|keyword'"`

### Task 1: Repair The Global Search Data Contract So Message Identity Survives Pagination

**Files:**
- Modify: `lib/service/api/search_api.dart`
- Modify: `lib/modules/search/data/search_api_gateway.dart`
- Modify: `lib/modules/search/data/search_remote_data_source.dart`
- Modify: `lib/modules/search/domain/search_repository.dart`
- Modify: `lib/modules/search/data/search_repository_impl.dart`
- Modify: `test/modules/search/search_repository_test.dart`

- [x] **Step 1: Write the failing repository tests for paged global search**

```dart
test('searchGlobal page 1 preserves message identity and page 2 requests messages only', () async {
  gateway.globalResultByOnlyMessagePage = <String, Map<String, dynamic>>{
    '0:1': <String, dynamic>{
      'friends': <Map<String, dynamic>>[
        <String, dynamic>{'uid': 'u_alice', 'name': 'Alice', 'avatar': 'https://cdn.example.com/alice.png'},
      ],
      'groups': <Map<String, dynamic>>[
        <String, dynamic>{'group_no': 'g1001', 'name': 'Design Group', 'avatar': 'https://cdn.example.com/group.png'},
      ],
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'message_seq': 41,
          'order_seq': 9041,
          'channel_id': 'g1001',
          'channel_type': WKChannelType.group,
          'timestamp': 1712123401,
          'from_uid': 'u_alice',
          'from_name': 'Alice',
          'channel_name': 'Design Group',
          'payload': <String, dynamic>{'type': WkMessageContentType.text, 'content': 'launch checklist'},
        },
      ],
    },
    '1:2': <String, dynamic>{
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{
          'message_seq': 42,
          'order_seq': 9042,
          'channel_id': 'g1001',
          'channel_type': WKChannelType.group,
          'timestamp': 1712123501,
          'from_uid': 'u_bob',
          'from_name': 'Bob',
          'channel_name': 'Design Group',
          'payload': <String, dynamic>{'type': WkMessageContentType.file, 'name': 'roadmap.pdf'},
        },
      ],
    },
  };

  final first = await repository.searchGlobal(keyword: 'launch', page: 1, limit: 20);
  final second = await repository.searchGlobal(keyword: 'launch', page: 2, limit: 20);

  expect(gateway.globalCalls, <({bool messagesOnly, int page, int limit, String keyword})>[
    (messagesOnly: false, page: 1, limit: 20, keyword: 'launch'),
    (messagesOnly: true, page: 2, limit: 20, keyword: 'launch'),
  ]);
  expect(first.users.single.uid, 'u_alice');
  expect(first.groups.single.channelId, 'g1001');
  expect(first.messages.single.messageSeq, 41);
  expect(first.messages.single.orderSeq, 9041);
  expect(first.messages.single.previewText, 'launch checklist');
  expect(second.users, isEmpty);
  expect(second.groups, isEmpty);
  expect(second.messages.single.messageSeq, 42);
  expect(second.messages.single.orderSeq, 9042);
  expect(second.messages.single.previewText, '[文件] roadmap.pdf');
});
```

- [x] **Step 2: Run the repository test to verify it fails**

Run: `flutter test test/modules/search/search_repository_test.dart`
Expected: FAIL because the current global-search path does not accept page-aware requests and still collapses messages by channel summary

- [x] **Step 3: Implement the paged global-search contract**

```dart
// lib/modules/search/domain/search_repository.dart
Future<GlobalSearchSnapshot> searchGlobal({
  required String keyword,
  required int page,
  required int limit,
});
```

```dart
// lib/modules/search/data/search_api_gateway.dart
Future<Map<String, dynamic>> globalSearch({
  required String keyword,
  required bool messagesOnly,
  required int page,
  required int limit,
});
```

```dart
// lib/service/api/search_api.dart
Future<Map<String, dynamic>> globalSearchPage({
  required String keyword,
  required int page,
  int limit = 20,
  bool messagesOnly = false,
}) async {
  final response = await _searchGlobal(
    keyword: keyword.trim(),
    onlyMessage: messagesOnly ? 1 : 0,
    page: page,
    limit: limit,
  );
  return <String, dynamic>{
    'users': messagesOnly ? const <Map<String, dynamic>>[] : _normalizeUsers(response['friends']),
    'groups': messagesOnly ? const <Map<String, dynamic>>[] : _normalizeGroups(response['groups']),
    'messages': _normalizeMessages(response['messages']),
  };
}
```

```dart
// lib/modules/search/data/search_repository_impl.dart
@override
Future<GlobalSearchSnapshot> searchGlobal({
  required String keyword,
  required int page,
  required int limit,
}) async {
  final payload = await _remoteDataSource.globalSearch(
    keyword: keyword,
    messagesOnly: page > 1,
    page: page < 1 ? 1 : page,
    limit: limit < 1 ? 20 : limit,
  );
  return GlobalSearchSnapshot(
    users: _readList(payload, 'users').map(_mapGlobalUser).toList(growable: false),
    groups: _readList(payload, 'groups').map(_mapGlobalGroup).toList(growable: false),
    messages: _readList(payload, 'messages').map(_mapMessageHit).toList(growable: false),
  );
}
```

- [x] **Step 4: Run the repository test to verify it passes**

Run: `flutter test test/modules/search/search_repository_test.dart`
Expected: PASS with page-aware message identity preserved across global search

- [x] **Step 5: Checkpoint the global-search data-contract repair**

```bash
git add lib/service/api/search_api.dart lib/modules/search/data/search_api_gateway.dart lib/modules/search/data/search_remote_data_source.dart lib/modules/search/domain/search_repository.dart lib/modules/search/data/search_repository_impl.dart test/modules/search/search_repository_test.dart
git commit -m "feat: normalize paged global search results"
```

### Task 2: Replace The Legacy Global Search Wrapper With A Paged Controller-Owned State Machine

**Files:**
- Modify: `lib/modules/search/application/global_search_controller.dart`
- Modify: `lib/modules/search/application/search_providers.dart`
- Create: `test/modules/search/global_search_controller_test.dart`

- [x] **Step 1: Write the failing controller tests**

```dart
test('updateKeyword loads page 1 and loadMore appends page 2 messages only', () async {
  final repository = _FakeGlobalSearchRepository(
    snapshotsByKeywordPage: <String, Map<int, GlobalSearchSnapshot>>{
      'launch': <int, GlobalSearchSnapshot>{
        1: GlobalSearchSnapshot(
          users: const <SearchMemberHit>[
            SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
          ],
          groups: const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 0,
              orderSeq: 0,
              timestamp: 0,
              contentType: 0,
              fromUid: '',
              fromName: 'Design Group',
              previewText: 'Design Group',
              channelName: 'Design Group',
            ),
          ],
          messages: List<SearchMessageHit>.generate(20, (index) {
            return SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 100 + index,
              orderSeq: 9100 + index,
              timestamp: 1712123400 + index,
              contentType: 1,
              fromUid: 'u_alice',
              fromName: 'Alice',
              previewText: 'launch item $index',
              channelName: 'Design Group',
            );
          }),
        ),
        2: const GlobalSearchSnapshot(
          messages: <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 121,
              orderSeq: 9121,
              timestamp: 1712123600,
              contentType: 1,
              fromUid: 'u_bob',
              fromName: 'Bob',
              previewText: 'launch item 21',
              channelName: 'Design Group',
            ),
          ],
        ),
      },
    },
  );

  final controller = GlobalSearchController(
    repository: repository,
    debounce: Duration.zero,
  );

  controller.updateKeyword('launch');
  await Future<void>.delayed(Duration.zero);

  expect(controller.state.users, hasLength(1));
  expect(controller.state.groups, hasLength(1));
  expect(controller.state.messages, hasLength(20));
  expect(controller.state.page, 2);
  expect(controller.state.hasMore, isTrue);

  await controller.loadMore();

  expect(controller.state.users, hasLength(1));
  expect(controller.state.groups, hasLength(1));
  expect(controller.state.messages, hasLength(21));
  expect(controller.state.page, 3);
  expect(controller.state.hasMore, isFalse);
});
```

```dart
test('incremental failure keeps visible global messages until explicit retry', () async {
  final repository = _FakeGlobalSearchRepository(
    snapshotsByKeywordPage: <String, Map<int, GlobalSearchSnapshot>>{
      'launch': <int, GlobalSearchSnapshot>{
        1: GlobalSearchSnapshot(
          messages: List<SearchMessageHit>.generate(20, (index) {
            return SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: index + 1,
              orderSeq: index + 1,
              timestamp: 1712123000 + index,
              contentType: 1,
              fromUid: 'u1',
              fromName: 'Alice',
              previewText: 'launch $index',
              channelName: 'Design Group',
            );
          }),
        ),
      },
    },
    failingKeywordPages: const <String, Set<int>>{
      'launch': <int>{2},
    },
  );

  final controller = GlobalSearchController(
    repository: repository,
    debounce: Duration.zero,
  );

  controller.updateKeyword('launch');
  await Future<void>.delayed(Duration.zero);

  await controller.loadMore();
  final callsAfterFailure = repository.calls.length;

  expect(controller.state.messages, hasLength(20));
  expect(controller.state.loadMoreError, isNotNull);

  await controller.loadMore();
  expect(repository.calls.length, callsAfterFailure);
});
```

- [x] **Step 2: Run the controller test to verify it fails**

Run: `flutter test test/modules/search/global_search_controller_test.dart`
Expected: FAIL because the current controller is not a paged state machine and is not wired through repository-owned state

- [x] **Step 3: Implement the paged global-search controller**

```dart
@immutable
class GlobalSearchState {
  const GlobalSearchState({
    this.keyword = '',
    this.users = const <SearchMemberHit>[],
    this.groups = const <SearchMessageHit>[],
    this.messages = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final List<SearchMemberHit> users;
  final List<SearchMessageHit> groups;
  final List<SearchMessageHit> messages;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  GlobalSearchState copyWith({
    String? keyword,
    List<SearchMemberHit>? users,
    List<SearchMessageHit>? groups,
    List<SearchMessageHit>? messages,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
    Object? loadMoreError = _sentinel,
  }) {
    return GlobalSearchState(
      keyword: keyword ?? this.keyword,
      users: users ?? this.users,
      groups: groups ?? this.groups,
      messages: messages ?? this.messages,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _sentinel) ? this.loadMoreError : loadMoreError as String?,
    );
  }
}
```

```dart
final globalSearchControllerProvider =
    StateNotifierProvider.autoDispose<GlobalSearchController, GlobalSearchState>((ref) {
  return GlobalSearchController(repository: ref.watch(searchRepositoryProvider));
});

class GlobalSearchController extends StateNotifier<GlobalSearchState> {
  GlobalSearchController({
    required SearchRepository repository,
    Duration debounce = const Duration(milliseconds: 250),
  }) : _repository = repository,
       _debounce = debounce,
       super(const GlobalSearchState());

  final SearchRepository _repository;
  final Duration _debounce;
  Timer? _debounceTimer;
  int _requestVersion = 0;

  void updateKeyword(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _requestVersion += 1;
      state = GlobalSearchState(keyword: value);
      return;
    }
    state = GlobalSearchState(keyword: value, isLoading: true, hasMore: true);
    final requestVersion = ++_requestVersion;
    _debounceTimer = Timer(_debounce, () {
      unawaited(_loadFirstPage(rawKeyword: value, keyword: trimmed, requestVersion: requestVersion));
    });
  }

  Future<void> loadMore({bool isRetry = false}) async {
    if (state.keyword.trim().isEmpty || state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    if (!isRetry && state.loadMoreError != null) {
      return;
    }
    final requestVersion = _requestVersion;
    state = state.copyWith(isLoadingMore: true, loadMoreError: null);
    final snapshot = await _repository.searchGlobal(
      keyword: state.keyword.trim(),
      page: state.page,
      limit: 20,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      messages: <SearchMessageHit>[...state.messages, ...snapshot.messages],
      page: state.page + 1,
      isLoadingMore: false,
      hasMore: snapshot.messages.length >= 20,
    );
  }

  Future<void> _loadFirstPage({
    required String rawKeyword,
    required String keyword,
    required int requestVersion,
  }) async {
    final snapshot = await _repository.searchGlobal(
      keyword: keyword,
      page: 1,
      limit: 20,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = GlobalSearchState(
      keyword: rawKeyword,
      users: snapshot.users,
      groups: snapshot.groups,
      messages: snapshot.messages,
      page: 2,
      isLoading: false,
      hasMore: snapshot.messages.length >= 20,
    );
  }

  void retry() => updateKeyword(state.keyword);
}
```

- [x] **Step 4: Run the controller test to verify it passes**

Run: `flutter test test/modules/search/global_search_controller_test.dart`
Expected: PASS with repository-backed paging, stale-request invalidation, and incremental failure retention

- [x] **Step 5: Checkpoint the global-search state machine**

```bash
git add lib/modules/search/application/global_search_controller.dart lib/modules/search/application/search_providers.dart test/modules/search/global_search_controller_test.dart
git commit -m "feat: add paged global search controller"
```

### Task 3: Rebuild The Global Search Page Around Shared Locate Navigation And Android Result Meaning

**Files:**
- Modify: `lib/modules/search/presentation/global_search_page.dart`
- Create: `lib/modules/search/presentation/widgets/global_search_channel_tile.dart`
- Create: `lib/modules/search/presentation/widgets/global_search_message_tile.dart`
- Create: `lib/modules/search/presentation/widgets/global_search_find_user_row.dart`
- Create: `test/modules/search/global_search_page_test.dart`
- Modify: `test/wukong_uikit/search/global_search_page_parity_test.dart`
- Modify: `test/modules/search/search_pages_compile_test.dart`

- [x] **Step 1: Write the failing widget tests**

```dart
testWidgets('global message tap resolves locate intent source global-search and opens chat', (tester) async {
  final repository = _FakeGlobalSearchRepository(
    snapshotsByKeywordPage: <String, Map<int, GlobalSearchSnapshot>>{
      'launch': <int, GlobalSearchSnapshot>{
        1: const GlobalSearchSnapshot(
          messages: <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'g1001',
              channelType: 2,
              messageSeq: 41,
              orderSeq: 9041,
              timestamp: 1712123401,
              contentType: 1,
              fromUid: 'u_alice',
              fromName: 'Alice',
              previewText: 'launch checklist',
              channelName: 'Design Group',
            ),
          ],
        ),
      },
    },
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
        searchLocateResolverProvider.overrideWithValue(resolver),
        chatLocateCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MaterialApp(home: GlobalSearchPage()),
    ),
  );
  await tester.enterText(find.byKey(const ValueKey<String>('global-search-field')), 'launch');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 260));
  await tester.tap(find.byKey(const ValueKey<String>('global-search-message-41')));
  await tester.pumpAndSettle();

  final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
  expect(shell.initialAroundOrderSeq, 9041);
});
```

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
  Future<ChatOpenRequest> buildOpenRequestFromIntent(ChatLocateIntent intent) async {
    intents.add(intent);
    return request;
  }
}

class _StubGlobalSearchController extends GlobalSearchController {
  _StubGlobalSearchController(this.seed)
      : super(repository: _NoopSearchRepository(), debounce: Duration.zero) {
    state = seed;
  }

  final GlobalSearchState seed;
}

class _NoopSearchRepository implements SearchRepository {
  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async => const GlobalSearchSnapshot();

  @override
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

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
}
```

```dart
testWidgets('global page renders Android section order and load-more retry footer', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        globalSearchControllerProvider.overrideWith((ref) => _StubGlobalSearchController(
          const GlobalSearchState(
            keyword: 'launch',
            users: <SearchMemberHit>[SearchMemberHit(uid: 'u_alice', displayName: 'Alice')],
            groups: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'g1001',
                channelType: 2,
                messageSeq: 0,
                orderSeq: 0,
                timestamp: 0,
                contentType: 0,
                fromUid: '',
                fromName: 'Design Group',
                previewText: 'Design Group',
                channelName: 'Design Group',
              ),
            ],
            messages: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'g1001',
                channelType: 2,
                messageSeq: 41,
                orderSeq: 9041,
                timestamp: 1712123401,
                contentType: 1,
                fromUid: 'u_alice',
                fromName: 'Alice',
                previewText: 'launch checklist',
                channelName: 'Design Group',
              ),
            ],
            hasMore: true,
            loadMoreError: 'boom',
          ),
        )),
      ],
      child: const MaterialApp(home: GlobalSearchPage()),
    ),
  );

  expect(find.byKey(const ValueKey<String>('global-search-user-u_alice')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('global-search-group-g1001')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('global-search-find-user')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('global-search-message-41')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('global-search-load-more-retry')), findsOneWidget);
});
```

- [x] **Step 2: Run the widget tests to verify they fail**

Run: `flutter test test/modules/search/global_search_page_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart`
Expected: FAIL because the current page does not use the controller provider, still performs direct chat navigation, and still routes multi-hit messages through the legacy secondary result page

- [x] **Step 3: Implement the converged global-search page**

```dart
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({
    super.key,
    this.initialQuery,
    this.onOpenSearchUser,
  });

  final String? initialQuery;
  final ValueChanged<String>? onOpenSearchUser;
}
```

```dart
Future<void> _openMessageHit(SearchMessageHit hit) async {
  final resolver = ref.read(searchLocateResolverProvider);
  final intent = resolver.fromSearchHit(
    hit,
    highlightKeyword: _searchController.text.trim(),
    source: 'global-search',
  );
  await openChatFromLocateIntent(
    context: context,
    ref: ref,
    intent: intent,
    fallbackChannelName: hit.channelName,
  );
}
```

```dart
class GlobalSearchMessageTile extends StatelessWidget {
  const GlobalSearchMessageTile({
    super.key,
    required this.hit,
    required this.onTap,
  });

  final SearchMessageHit hit;
  final VoidCallback onTap;
}
```

- [x] **Step 4: Run the widget tests to verify they pass**

Run: `flutter test test/modules/search/global_search_page_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart`
Expected: PASS with Android-style shell behavior, deterministic sections, direct locate-based message opening, and compatibility-export coverage still green

- [x] **Step 5: Checkpoint the global-search UI convergence**

```bash
git add lib/modules/search/presentation/global_search_page.dart lib/modules/search/presentation/widgets/global_search_channel_tile.dart lib/modules/search/presentation/widgets/global_search_message_tile.dart lib/modules/search/presentation/widgets/global_search_find_user_row.dart test/modules/search/global_search_page_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart test/modules/search/search_pages_compile_test.dart
git commit -m "feat: converge global search navigation"
```

### Task 4: Run Final Phase 6 Search Regression, Analysis, And Remote Mismatch Triage

**Files:**
- No additional code changes expected if earlier tasks are correct

- [x] **Step 1: Run the repository and global-controller suites**

Run: `flutter test test/modules/search/search_repository_test.dart test/modules/search/global_search_controller_test.dart`
Expected: PASS with global-search data-contract and controller-state coverage green

- [x] **Step 2: Run the global-search widget and compatibility suites**

Run: `flutter test test/modules/search/global_search_page_test.dart test/wukong_uikit/search/global_search_page_parity_test.dart`
Expected: PASS with direct locate-message navigation and compatibility-export behavior preserved

- [x] **Step 3: Run the full Phase 6 search regression suites**

Run: `flutter test test/modules/search/chat_date_calendar_controller_test.dart test/modules/search/chat_keyword_search_controller_test.dart test/modules/search/chat_locate_coordinator_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_date_page_test.dart test/modules/search/chat_search_entry_page_test.dart test/modules/search/chat_search_image_forward_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/chat_search_results_page_test.dart test/modules/search/search_locate_resolver_test.dart test/modules/search/search_models_test.dart test/modules/search/search_pages_compile_test.dart`
Expected: PASS, proving Phase 6C did not regress the already-green Phase 6A and 6B mainline

- [x] **Step 4: Run static analysis on the touched search files**

Run: `flutter analyze lib/modules/search/application/global_search_controller.dart lib/modules/search/presentation/global_search_page.dart lib/modules/search/presentation/widgets/global_search_channel_tile.dart lib/modules/search/presentation/widgets/global_search_message_tile.dart lib/modules/search/presentation/widgets/global_search_find_user_row.dart lib/modules/search/data/search_repository_impl.dart lib/modules/search/data/search_remote_data_source.dart lib/modules/search/data/search_api_gateway.dart lib/modules/search/domain/search_repository.dart lib/service/api/search_api.dart`
Expected: `No issues found!`

- [x] **Step 5: If deployed behavior still diverges, collect remote global-search evidence**

Run: `ssh root@103.207.68.33 "docker logs --tail 200 fullstack-tangsengdaodaoserver-1 | grep -E 'search|global|message_seq|order_seq|keyword'"`
Expected: enough runtime evidence to decide whether any remaining mismatch is local locate wiring, endpoint payload shape, or deployed search-service data
Note: not needed in this run because fresh local repository/controller/widget regression plus targeted `flutter analyze` all passed, so no deployed mismatch signal remained to triage via SSH.

- [ ] **Step 6: Checkpoint the verified Phase 6C finish line**

```bash
git add lib/modules/search lib/service/api/search_api.dart test/modules/search test/wukong_uikit/search/global_search_page_parity_test.dart
git commit -m "feat: complete phase 6c global search convergence"
```
Note: not executed in this workspace because this local copy still has no `.git` metadata; perform this checkpoint in the canonical repository checkout.

## Self-Review

- Spec coverage: this plan maps the approved 6C scope into data-contract repair, controller convergence, presentation and locate convergence, then final regression and remote verification
- Placeholder scan: placeholder-like comments were removed during self-review so each execution step now names concrete files, expectations, and verification commands
- Type consistency: the plan uses one page-aware `searchGlobal` contract, one `GlobalSearchState`, and one `global-search` locate source marker throughout
