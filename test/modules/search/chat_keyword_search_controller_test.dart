import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/chat_keyword_search_controller.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';

void main() {
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

  test(
    'incremental failure keeps visible results until explicit retry',
    () async {
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
    },
  );
}

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
  final List<({String keyword, int page})> calls =
      <({String keyword, int page})>[];

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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}
