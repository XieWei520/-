# Android Image And Member Search Parity Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the Flutter Android image-search and member-search surfaces so they behave like the TangSengDaoDao Android reference, close the remaining scoped-search interaction gaps, and become a clean handoff point before `Phase 3`.

**Architecture:** This plan does not reopen the full search rebuild. It builds directly on the new `lib/modules/search/**` kernel that already exists, tightens data shaping in the repository, upgrades paged-state error handling in the current Riverpod controllers, and preserves stable public entry paths through compatibility wrappers. Android product semantics stay primary; the Flutter implementation is allowed to exceed the reference only where it improves resilience or debuggability without changing the visible flow.

**Tech Stack:** Flutter, flutter_riverpod, existing WKIM Flutter SDK, dio, flutter_test, PowerShell, SSH

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Parent Plan Boundary

This is a focused child plan under [2026-04-03-search-parity-rebuild.md](C:/Users/COLORFUL/Desktop/WuKongIM/wukong_im_app/docs/superpowers/plans/2026-04-03-search-parity-rebuild.md).

It intentionally executes only the search slice the user chose to prioritize before `Phase 3`:

- Android image search parity
- Android member search parity
- scoped-search entry regression coverage
- deployed-backend validation for the repaired real search chain

Out of scope for this child plan:

- date search
- global search convergence
- authentication and device-login alignment (`Phase 3`)
- unrelated chat action parity outside image/member search

## Android Reference Anchors

The implementation in this plan is pinned to the Android surfaces below:

- `wkuikit/src/main/java/com/chat/uikit/chat/search/image/SearchWithImgActivity.java`
  - year-month section grouping
  - image preview actions
  - forward / favorite / show-in-chat behavior
  - load-more pagination
- `wkuikit/src/main/java/com/chat/uikit/chat/search/member/SearchWithMemberActivity.java`
  - member-scoped message results
  - anchored show-in-chat behavior
  - load-more pagination
- `wkuikit/src/main/java/com/chat/uikit/chat/search/MessageRecordActivity.kt`
  - entry-page menu flow into scoped image/member search

## File Structure

### New Files

- `lib/modules/search/search_with_member_page.dart`
  - Compatibility wrapper so member search has a stable public surface just like `SearchWithImgPage`.

### Existing Files To Modify

- `lib/modules/search/data/search_repository_impl.dart`
  - Normalize image result section keys to Android month grouping and prefer existing local image paths before remote URLs.
- `lib/modules/search/application/chat_media_search_controller.dart`
  - Split first-load errors from incremental pagination errors.
- `lib/modules/search/presentation/chat_search_collection_page.dart`
  - Surface incremental-load retry affordances without discarding existing image results.
- `lib/modules/search/application/chat_member_search_controller.dart`
  - Split first-load errors from incremental pagination errors for member results.
- `lib/modules/search/presentation/chat_search_member_page.dart`
  - Surface incremental-load retry affordances while preserving visible member results.
- `lib/modules/search/presentation/chat_search_entry_page.dart`
  - Route image/member menu taps through compatibility wrappers instead of directly binding callers to internal pages.
- `lib/modules/search/search_exports.dart`
  - Export the new member wrapper.
- `test/modules/search/search_repository_test.dart`
  - Cover month grouping and local-path preference.
- `test/modules/search/chat_search_collection_page_test.dart`
  - Cover incremental-load failure behavior on the image surface.
- `test/modules/search/chat_search_member_page_test.dart`
  - Cover incremental-load failure behavior on the member-results surface.
- `test/modules/search/chat_search_entry_page_test.dart`
  - Cover wrapper-based entry routing and channel-name forwarding.

## Remote Debugging Requirement

This plan must use the repaired live backend when local tests and real behavior disagree.

- SSH entry: `ssh root@103.207.68.33`
- Minimum remote checks after the client work lands:
  - `docker logs --tail 120 fullstack-tangsengdaoserver-1`
  - `docker logs --tail 120 fullstack-wukongim-1`
- Use server inspection if:
  - image search unexpectedly returns empty on a conversation that has image history
  - member search returns messages from the wrong sender
  - `/v1/search/global` starts returning plugin or forward-path errors again

## Verification Commands Used Throughout

- `dart analyze lib/modules/search`
- `flutter test test/modules/search/search_repository_test.dart`
- `flutter test test/modules/search/chat_search_collection_page_test.dart`
- `flutter test test/modules/search/chat_search_member_page_test.dart`
- `flutter test test/modules/search/chat_search_entry_page_test.dart`
- `ssh root@103.207.68.33 "docker logs --tail 120 fullstack-tangsengdaoserver-1 && docker logs --tail 120 fullstack-wukongim-1"`

### Task 1: Normalize Image Search Repository Shaping

**Files:**
- Modify: `lib/modules/search/data/search_repository_impl.dart`
- Test: `test/modules/search/search_repository_test.dart`

- [ ] **Step 1: Write the failing repository test for month grouping and local-path preference**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/data/search_api_gateway.dart';
import 'package:wukong_im_app/modules/search/data/search_local_timeline_data_source.dart';
import 'package:wukong_im_app/modules/search/data/search_remote_data_source.dart';
import 'package:wukong_im_app/modules/search/data/search_repository_impl.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('SearchRepositoryImpl', () {
    late _FakeSearchApiGateway gateway;
    late SearchRepositoryImpl repository;

    setUp(() {
      gateway = _FakeSearchApiGateway();
      repository = SearchRepositoryImpl(
        remoteDataSource: SearchRemoteDataSource(apiGateway: gateway),
        localTimelineDataSource: _FakeSearchLocalTimelineDataSource(),
        now: () => DateTime(2026, 3, 10),
      );
    });

    test('searchCollection groups image results by month and prefers local path', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}search_image.png',
      )..writeAsStringSync('image');
      addTearDown(() {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      });

      gateway.imageResults = <Map<String, dynamic>>[
        <String, dynamic>{
          'channel_id': 'group-1',
          'channel_type': WKChannelType.group,
          'message_seq': 21,
          'timestamp': 1712123456,
          'content_type': WkMessageContentType.image,
          'from_uid': 'u1',
          'from_name': 'Alex',
          'content': '[image]',
          'image_url': 'https://cdn.example.com/image.png',
          'local_path': tempFile.path,
          'channel_name': 'Project Group',
        },
      ];

      final items = await repository.searchCollection(
        channelId: 'group-1',
        channelType: WKChannelType.group,
        scope: SearchCollectionScope.image,
        page: 1,
        limit: 20,
      );

      expect(items, hasLength(1));
      expect(items.first.sectionKey, '2024-04');
      expect(items.first.mediaUrl, tempFile.path);
    });
  });
}
```

- [ ] **Step 2: Run the repository test to verify it fails**

Run: `flutter test test/modules/search/search_repository_test.dart`
Expected: FAIL because the current implementation returns day-level section keys like `2024-04-03` and ignores `local_path`

- [ ] **Step 3: Implement Android-style month grouping and local image fallback**

```dart
// lib/modules/search/data/search_repository_impl.dart
import 'dart:io';

import 'package:wukongimfluttersdk/type/const.dart';

import '../domain/search_models.dart';
import '../domain/search_repository.dart';
import 'search_local_timeline_data_source.dart';
import 'search_remote_data_source.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({
    required SearchRemoteDataSource remoteDataSource,
    required SearchLocalTimelineDataSource localTimelineDataSource,
    DateTime Function()? now,
  }) : _remoteDataSource = remoteDataSource,
       _localTimelineDataSource = localTimelineDataSource,
       _now = now ?? DateTime.now;

  final SearchRemoteDataSource _remoteDataSource;
  final SearchLocalTimelineDataSource _localTimelineDataSource;
  final DateTime Function() _now;

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit < 1 ? 20 : limit;
    final items = switch (scope) {
      SearchCollectionScope.image => await _remoteDataSource.searchImages(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
      SearchCollectionScope.file => await _remoteDataSource.searchFiles(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
      SearchCollectionScope.link => await _remoteDataSource.searchLinks(
        channelId: channelId,
        channelType: channelType,
        page: safePage,
        limit: safeLimit,
      ),
    };

    return items
        .map(
          (item) => SearchMediaItem(
            hit: _mapMessageHit(item),
            scope: scope,
            sectionKey: _buildSectionKey(_readInt(item, 'timestamp')),
            mediaUrl: _resolveMediaUrl(scope, item),
            fileName: _readOptionalString(item, 'file_name'),
            linkUrl: _resolveLinkUrl(scope, item),
          ),
        )
        .toList(growable: false);
  }

  String _buildSectionKey(int timestamp) {
    if (timestamp <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
      isUtc: true,
    ).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String? _resolveMediaUrl(
    SearchCollectionScope scope,
    Map<String, dynamic> item,
  ) {
    if (scope == SearchCollectionScope.image) {
      final localPath =
          _readOptionalString(item, 'local_path') ??
          _readOptionalString(item, 'localPath');
      if (localPath != null && File(localPath).existsSync()) {
        return localPath;
      }
      return _readOptionalString(item, 'image_url') ??
          _readOptionalString(item, 'url');
    }
    if (scope == SearchCollectionScope.file) {
      return _readOptionalString(item, 'url');
    }
    return null;
  }
}
```

- [ ] **Step 4: Re-run analysis and the repository test**

Run: `dart analyze lib/modules/search/data/search_repository_impl.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/search_repository_test.dart`
Expected: PASS with the new month-grouping and local-path test green

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/data/search_repository_impl.dart test/modules/search/search_repository_test.dart
git commit -m "fix: align image search repository grouping with android"
```

### Task 2: Preserve Image Results During Incremental Failures

**Files:**
- Modify: `lib/modules/search/application/chat_media_search_controller.dart`
- Modify: `lib/modules/search/presentation/chat_search_collection_page.dart`
- Test: `test/modules/search/chat_search_collection_page_test.dart`

- [ ] **Step 1: Write the failing widget test for incremental-load retry UI**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';

void main() {
  Widget wrapWithApp(Widget child, {required SearchRepository repository}) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('load-more failure keeps image results visible and shows retry affordance', (
    tester,
  ) async {
    final repository = _PagedCollectionRepository();

    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchCollectionPage(
          channelId: 'g1001',
          channelType: 2,
          scope: SearchCollectionScope.image,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-collection-section-2026-04')),
      findsOneWidget,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-collection-item-33')),
      findsOneWidget,
    );
    expect(find.text('Load more failed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.loadMoreAttempts, 2);
  });
}

class _PagedCollectionRepository implements SearchRepository {
  int loadMoreAttempts = 0;

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    if (page == 1) {
      return <SearchMediaItem>[
        SearchMediaItem(
          hit: const SearchMessageHit(
            channelId: 'g1001',
            channelType: 2,
            messageSeq: 33,
            orderSeq: 33000,
            timestamp: 1710000000,
            contentType: 2,
            fromUid: 'u_alice',
            fromName: 'Alice',
            previewText: '[image]',
            channelName: 'Design',
          ),
          scope: scope,
          sectionKey: '2026-04',
          mediaUrl: 'https://cdn.example.com/image.png',
        ),
      ];
    }

    loadMoreAttempts += 1;
    throw Exception('Load more failed');
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
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchDateMonthSection>[];
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
```

- [ ] **Step 2: Run the collection-page test to verify it fails**

Run: `flutter test test/modules/search/chat_search_collection_page_test.dart`
Expected: FAIL because the current page silently drops incremental errors when items are already visible

- [ ] **Step 3: Add incremental-error state and retry UI without discarding current items**

```dart
// lib/modules/search/application/chat_media_search_controller.dart
@immutable
class ChatMediaSearchState {
  const ChatMediaSearchState({
    this.items = const <SearchMediaItem>[],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final List<SearchMediaItem> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  ChatMediaSearchState copyWith({
    List<SearchMediaItem>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatMediaSearchState(
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

Future<void> refresh() async {
  state = state.copyWith(
    items: const <SearchMediaItem>[],
    page: 1,
    isLoading: true,
    isLoadingMore: false,
    hasMore: true,
    error: null,
    loadMoreError: null,
  );
  // existing body unchanged
}

Future<void> loadMore() async {
  if (state.isLoading || state.isLoadingMore || !state.hasMore) {
    return;
  }

  state = state.copyWith(isLoadingMore: true, loadMoreError: null);
  try {
    final items = await _repository.searchCollection(
      channelId: channelId,
      channelType: channelType,
      scope: scope,
      page: state.page,
      limit: _defaultPageSize,
    );
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      items: <SearchMediaItem>[...state.items, ...items],
      page: state.page + 1,
      isLoadingMore: false,
      hasMore: items.length >= _defaultPageSize,
      loadMoreError: null,
    );
  } catch (error) {
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isLoadingMore: false,
      loadMoreError: error.toString(),
    );
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_collection_page.dart
Widget _buildLoadMoreFooter(ChatMediaSearchState state, ChatMediaSearchController controller) {
  if (state.isLoadingMore) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
  if (state.loadMoreError == null) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Load more failed'),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey<String>('search-collection-load-more-retry'),
            onPressed: controller.loadMore,
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

// Use _buildLoadMoreFooter in both ListView and CustomScrollView branches.
```

- [ ] **Step 4: Re-run analysis and the collection-page test**

Run: `dart analyze lib/modules/search/application/chat_media_search_controller.dart lib/modules/search/presentation/chat_search_collection_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/chat_search_collection_page_test.dart`
Expected: PASS with the incremental-load retry coverage green

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/application/chat_media_search_controller.dart lib/modules/search/presentation/chat_search_collection_page.dart test/modules/search/chat_search_collection_page_test.dart
git commit -m "fix: preserve image search results during incremental failures"
```

### Task 3: Preserve Member Results During Incremental Failures

**Files:**
- Modify: `lib/modules/search/application/chat_member_search_controller.dart`
- Modify: `lib/modules/search/presentation/chat_search_member_page.dart`
- Test: `test/modules/search/chat_search_member_page_test.dart`

- [ ] **Step 1: Write the failing widget test for member-result retry UI**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_member_page.dart';

void main() {
  Widget wrapWithApp(Widget child, {required SearchRepository repository}) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('member results keep visible items and show retry when load more fails', (
    tester,
  ) async {
    final repository = _PagedMemberRepository();

    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('search-member-u_alice')));
    await tester.pumpAndSettle();

    expect(find.text('member result'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey<String>('chat-member-search-results-list')),
      const Offset(0, -1000),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('member result'), findsOneWidget);
    expect(find.text('Load more failed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-member-search-load-more-retry')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-member-search-load-more-retry')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.loadMoreAttempts, 2);
  });
}

class _PagedMemberRepository implements SearchRepository {
  int loadMoreAttempts = 0;

  @override
  Future<List<SearchMemberHit>> loadMembers({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchMemberHit>[
      SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
    ];
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
    if (page == 1) {
      return <SearchMessageHit>[
        SearchMessageHit(
          channelId: channelId,
          channelType: channelType,
          messageSeq: 44,
          orderSeq: 44000,
          timestamp: 1710000000,
          contentType: 1,
          fromUid: memberUid,
          fromName: 'Alice',
          previewText: 'member result',
          channelName: 'Design',
        ),
      ];
    }

    loadMoreAttempts += 1;
    throw Exception('Load more failed');
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
  Future<List<SearchDateMonthSection>> loadDateCalendar({
    required String channelId,
    required int channelType,
  }) async {
    return const <SearchDateMonthSection>[];
  }

  @override
  Future<GlobalSearchSnapshot> searchGlobal(String keyword) async {
    return const GlobalSearchSnapshot();
  }
}
```

- [ ] **Step 2: Run the member-page test to verify it fails**

Run: `flutter test test/modules/search/chat_search_member_page_test.dart`
Expected: FAIL because the current member-results page does not expose incremental-failure retry UI once page 1 content is already visible

- [ ] **Step 3: Split member first-load and load-more errors**

```dart
// lib/modules/search/application/chat_member_search_controller.dart
@immutable
class ChatMemberSearchState {
  const ChatMemberSearchState({
    this.members = const <SearchMemberHit>[],
    this.selectedMember,
    this.results = const <SearchMessageHit>[],
    this.page = 1,
    this.isLoadingMembers = false,
    this.isLoadingResults = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loadMoreError,
  });

  final List<SearchMemberHit> members;
  final SearchMemberHit? selectedMember;
  final List<SearchMessageHit> results;
  final int page;
  final bool isLoadingMembers;
  final bool isLoadingResults;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? loadMoreError;

  ChatMemberSearchState copyWith({
    List<SearchMemberHit>? members,
    Object? selectedMember = _memberSentinel,
    List<SearchMessageHit>? results,
    int? page,
    bool? isLoadingMembers,
    bool? isLoadingResults,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _errorSentinel,
    Object? loadMoreError = _errorSentinel,
  }) {
    return ChatMemberSearchState(
      members: members ?? this.members,
      selectedMember: identical(selectedMember, _memberSentinel)
          ? this.selectedMember
          : selectedMember as SearchMemberHit?,
      results: results ?? this.results,
      page: page ?? this.page,
      isLoadingMembers: isLoadingMembers ?? this.isLoadingMembers,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _errorSentinel) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _errorSentinel)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }
}

Future<void> openMember(SearchMemberHit member) async {
  final requestVersion = ++_requestVersion;
  state = state.copyWith(
    selectedMember: member,
    results: const <SearchMessageHit>[],
    page: 1,
    isLoadingResults: true,
    isLoadingMore: false,
    hasMore: true,
    error: null,
    loadMoreError: null,
  );
  // existing body unchanged
}

Future<void> loadMoreResults() async {
  final member = state.selectedMember;
  if (member == null ||
      state.isLoadingResults ||
      state.isLoadingMore ||
      !state.hasMore) {
    return;
  }

  final requestVersion = _requestVersion;
  state = state.copyWith(isLoadingMore: true, loadMoreError: null);
  try {
    final results = await _repository.searchMessagesByMember(
      channelId: channelId,
      channelType: channelType,
      memberUid: member.uid,
      keyword: '',
      page: state.page,
      limit: _defaultPageSize,
    );
    if (!mounted || requestVersion != _requestVersion) {
      return;
    }
    state = state.copyWith(
      results: <SearchMessageHit>[...state.results, ...results],
      page: state.page + 1,
      isLoadingMore: false,
      hasMore: results.length >= _defaultPageSize,
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
```

```dart
// lib/modules/search/presentation/chat_search_member_page.dart
class _MemberResultsBody extends StatelessWidget {
  const _MemberResultsBody({
    required this.member,
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTapResult,
  });

  final SearchMemberHit member;
  final ChatMemberSearchState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<SearchMessageHit> onTapResult;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingResults && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        key: const ValueKey<String>('chat-member-search-results-list'),
        itemCount: state.results.length + 1,
        itemBuilder: (context, index) {
          if (index < state.results.length) {
            final hit = state.results[index];
            return SearchMemberResultTile(
              member: member,
              hit: hit,
              onTap: () => onTapResult(hit),
            );
          }
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.loadMoreError != null) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Load more failed'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'chat-member-search-load-more-retry',
                      ),
                      onPressed: onLoadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Re-run analysis and the member-page test**

Run: `dart analyze lib/modules/search/application/chat_member_search_controller.dart lib/modules/search/presentation/chat_search_member_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/chat_search_member_page_test.dart`
Expected: PASS with the member-result retry coverage green

- [ ] **Step 5: Checkpoint**

```bash
git add lib/modules/search/application/chat_member_search_controller.dart lib/modules/search/presentation/chat_search_member_page.dart test/modules/search/chat_search_member_page_test.dart
git commit -m "fix: preserve member search results during incremental failures"
```

### Task 4: Route Entry Through Stable Image And Member Wrappers

**Files:**
- Create: `lib/modules/search/search_with_member_page.dart`
- Modify: `lib/modules/search/presentation/chat_search_entry_page.dart`
- Modify: `lib/modules/search/search_exports.dart`
- Test: `test/modules/search/chat_search_entry_page_test.dart`

- [ ] **Step 1: Write the failing entry-route regression tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/modules/search/search_with_img_page.dart';
import 'package:wukong_im_app/modules/search/search_with_member_page.dart';

void main() {
  Widget wrapWithApp(Widget child, {required SearchRepository repository}) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('image menu routes through SearchWithImgPage and preserves channel name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchEntryPage(
          channelId: 'group-1',
          channelType: 2,
          channelName: 'Design',
        ),
        repository: _FakeSearchRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-menu-image')),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<SearchWithImgPage>(find.byType(SearchWithImgPage));
    expect(page.channelId, 'group-1');
    expect(page.channelType, 2);
    expect(page.channelName, 'Design');
  });

  testWidgets('member menu routes through SearchWithMemberPage and preserves channel name', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchEntryPage(
          channelId: 'group-1',
          channelType: 2,
          channelName: 'Design',
        ),
        repository: _FakeSearchRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-menu-member')),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<SearchWithMemberPage>(
      find.byType(SearchWithMemberPage),
    );
    expect(page.channelId, 'group-1');
    expect(page.channelType, 2);
    expect(page.channelName, 'Design');
  });
}
```

- [ ] **Step 2: Run the entry-page test to verify it fails**

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`
Expected: FAIL because the current entry page pushes internal implementation pages directly and there is no `SearchWithMemberPage`

- [ ] **Step 3: Add the member wrapper and route image/member entry taps through compatibility surfaces**

```dart
// lib/modules/search/search_with_member_page.dart
import 'package:flutter/material.dart';

import 'presentation/chat_search_member_page.dart';

class SearchWithMemberPage extends StatelessWidget {
  const SearchWithMemberPage({
    super.key,
    required this.channelId,
    this.channelType = 2,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return ChatSearchMemberPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
```

```dart
// lib/modules/search/presentation/chat_search_entry_page.dart
import '../search_with_img_page.dart';
import '../search_with_member_page.dart';

void _handleMenuTap(SearchMenuEntry entry) {
  final Widget page = switch (entry.kind) {
    SearchMenuKind.date => ChatSearchDatePage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
    ),
    SearchMenuKind.image => SearchWithImgPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
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
    SearchMenuKind.member => SearchWithMemberPage(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
    ),
  };

  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );
}
```

```dart
// lib/modules/search/search_exports.dart
export 'presentation/chat_search_collection_page.dart';
export 'presentation/chat_search_date_page.dart';
export 'presentation/chat_search_entry_page.dart';
export 'presentation/global_search_page.dart';
export 'presentation/chat_search_member_page.dart';
export 'presentation/chat_search_results_page.dart';
export 'search_with_date_page.dart';
export 'search_with_img_page.dart';
export 'search_with_member_page.dart';
```

- [ ] **Step 4: Re-run analysis and the entry regression test**

Run: `dart analyze lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/search_with_member_page.dart lib/modules/search/search_exports.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/chat_search_entry_page_test.dart`
Expected: PASS with wrapper-based routing coverage green

- [ ] **Step 5: Run the final local and remote verification sweep**

Run: `dart analyze lib/modules/search`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/search/search_repository_test.dart test/modules/search/chat_search_collection_page_test.dart test/modules/search/chat_search_member_page_test.dart test/modules/search/chat_search_entry_page_test.dart`
Expected: PASS with all image/member scoped-search tests green

Run: `ssh root@103.207.68.33 "docker logs --tail 120 fullstack-tangsengdaoserver-1 && docker logs --tail 120 fullstack-wukongim-1"`
Expected: no fresh `/v1/search/global` plugin or forward-path errors after the local smoke pass

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/search/search_with_member_page.dart lib/modules/search/presentation/chat_search_entry_page.dart lib/modules/search/search_exports.dart test/modules/search/chat_search_entry_page_test.dart
git commit -m "refactor: route scoped image and member search through stable wrappers"
```

## Self-Review Checklist

- Spec coverage:
  - Android image month grouping and image URL resolution are covered by Task 1
  - image incremental-load parity and retry behavior are covered by Task 2
  - member-result incremental-load parity and retry behavior are covered by Task 3
  - entry-path compatibility and wrapper-based routing are covered by Task 4
  - deployed-backend regression checks are covered by Task 4 final verification
- Placeholder scan:
  - no placeholder markers or deferred implementation notes remain
  - every code-changing step contains explicit code or exact commands
- Type consistency:
  - `SearchMediaItem`, `ChatMediaSearchState`, `ChatMemberSearchState`, `SearchWithImgPage`, and `SearchWithMemberPage` use one stable naming scheme throughout the plan

## Expected Outcome

After this plan is implemented:

- image search groups results by Android-style year-month sections instead of per-day buckets
- image search prefers local image files when they exist, matching Android's preview behavior
- image search and member search no longer hide incremental failures behind silent stalls
- the scoped-search entry page routes through stable compatibility surfaces instead of binding callers to internal implementation pages
- the search subsystem reaches a clean "image/member parity closed" state, which is the right handoff point before entering `Phase 3`

