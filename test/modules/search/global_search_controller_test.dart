import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/global_search_controller.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';

void main() {
  test(
    'updateKeyword loads page 1 and loadMore appends messages only',
    () async {
      final repository = _FakeGlobalRepository(
        snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
          'alpha': <int, GlobalSearchSnapshot>{
            1: GlobalSearchSnapshot(
              users: const <SearchMemberHit>[
                SearchMemberHit(
                  uid: 'u_alex',
                  displayName: 'Alex',
                  avatarUrl: 'https://example.com/alex.png',
                ),
              ],
              groups: const <SearchMessageHit>[
                SearchMessageHit(
                  channelId: 'group-1',
                  channelType: 2,
                  messageSeq: 0,
                  orderSeq: 0,
                  timestamp: 0,
                  contentType: 0,
                  fromUid: '',
                  fromName: 'Project Group',
                  previewText: 'Project Group',
                  channelName: 'Project Group',
                ),
              ],
              messages: List<SearchMessageHit>.generate(20, (index) {
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
            ),
            2: const GlobalSearchSnapshot(
              messages: <SearchMessageHit>[
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
            ),
          },
        },
      );

      final controller = GlobalSearchController(
        repository: repository,
        debounce: Duration.zero,
      );

      controller.updateKeyword('alpha');
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
    },
  );

  test('stale first-page results do not replace a newer keyword', () async {
    final alphaPending = Completer<GlobalSearchSnapshot>();
    final repository = _FakeGlobalRepository(
      snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
        'beta': const <int, GlobalSearchSnapshot>{
          1: GlobalSearchSnapshot(
            users: <SearchMemberHit>[
              SearchMemberHit(uid: 'u_beta', displayName: 'Beta'),
            ],
            groups: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'group-beta',
                channelType: 2,
                messageSeq: 0,
                orderSeq: 0,
                timestamp: 0,
                contentType: 0,
                fromUid: '',
                fromName: 'Beta Group',
                previewText: 'Beta Group',
                channelName: 'Beta Group',
              ),
            ],
            messages: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'group-beta',
                channelType: 2,
                messageSeq: 300,
                orderSeq: 70300,
                timestamp: 1712123656,
                contentType: 1,
                fromUid: 'u_beta',
                fromName: 'Beta',
                previewText: 'beta result',
                channelName: 'Beta Group',
              ),
            ],
          ),
        },
      },
      pendingByKeywordPage: <String, Completer<GlobalSearchSnapshot>>{
        'alpha:1': alphaPending,
      },
    );

    final controller = GlobalSearchController(
      repository: repository,
      debounce: Duration.zero,
    );

    controller.updateKeyword('alpha');
    await Future<void>.delayed(Duration.zero);
    controller.updateKeyword('beta');
    await Future<void>.delayed(Duration.zero);

    alphaPending.complete(
      const GlobalSearchSnapshot(
        messages: <SearchMessageHit>[
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
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.keyword, 'beta');
    expect(controller.state.users.single.uid, 'u_beta');
    expect(controller.state.messages.single.previewText, 'beta result');
  });

  test('incremental load-more failure requires explicit retry', () async {
    final repository = _FakeGlobalRepository(
      snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
        'alpha': <int, GlobalSearchSnapshot>{
          1: GlobalSearchSnapshot(
            users: const <SearchMemberHit>[
              SearchMemberHit(uid: 'u_alpha', displayName: 'Alpha'),
            ],
            groups: const <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'group-alpha',
                channelType: 2,
                messageSeq: 0,
                orderSeq: 0,
                timestamp: 0,
                contentType: 0,
                fromUid: '',
                fromName: 'Alpha Group',
                previewText: 'Alpha Group',
                channelName: 'Alpha Group',
              ),
            ],
            messages: List<SearchMessageHit>.generate(20, (index) {
              final seq = 400 + index;
              return SearchMessageHit(
                channelId: 'group-alpha',
                channelType: 2,
                messageSeq: seq,
                orderSeq: 70400 + seq,
                timestamp: 1712123856,
                contentType: 1,
                fromUid: 'u_alpha',
                fromName: 'Alpha',
                previewText: 'alpha result $seq',
                channelName: 'Alpha Group',
              );
            }),
          ),
          2: const GlobalSearchSnapshot(
            messages: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'group-alpha',
                channelType: 2,
                messageSeq: 500,
                orderSeq: 70500,
                timestamp: 1712123956,
                contentType: 1,
                fromUid: 'u_alpha',
                fromName: 'Alpha',
                previewText: 'alpha result 500',
                channelName: 'Alpha Group',
              ),
            ],
          ),
        },
      },
      failingKeywordPages: <String, Set<int>>{
        'alpha': <int>{2},
      },
    );

    final controller = GlobalSearchController(
      repository: repository,
      debounce: Duration.zero,
    );

    controller.updateKeyword('alpha');
    await Future<void>.delayed(Duration.zero);

    await controller.loadMore();
    final callsAfterFailure = repository.calls.length;

    expect(controller.state.messages, hasLength(20));
    expect(controller.state.loadMoreError, isNotNull);

    await controller.loadMore();
    expect(repository.calls.length, callsAfterFailure);

    repository.failingKeywordPages['alpha']?.remove(2);
    await controller.loadMore(isRetry: true);

    expect(repository.calls.length, callsAfterFailure + 1);
    expect(controller.state.messages, hasLength(21));
    expect(controller.state.loadMoreError, isNull);
  });
}

class _FakeGlobalRepository implements SearchRepository {
  _FakeGlobalRepository({
    this.snapshotsByKeyword = const <String, Map<int, GlobalSearchSnapshot>>{},
    this.pendingByKeywordPage =
        const <String, Completer<GlobalSearchSnapshot>>{},
    this.failingKeywordPages = const <String, Set<int>>{},
  });

  final Map<String, Map<int, GlobalSearchSnapshot>> snapshotsByKeyword;
  final Map<String, Completer<GlobalSearchSnapshot>> pendingByKeywordPage;
  final Map<String, Set<int>> failingKeywordPages;
  final List<({String keyword, int page})> calls =
      <({String keyword, int page})>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
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
      throw Exception('global page $page failed');
    }
    return snapshotsByKeyword[keyword]?[page] ?? const GlobalSearchSnapshot();
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
  Future<List<SearchMessageHit>> searchMessages({
    required String channelId,
    required int channelType,
    required String keyword,
    required int page,
    required int limit,
  }) async => const <SearchMessageHit>[];

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
