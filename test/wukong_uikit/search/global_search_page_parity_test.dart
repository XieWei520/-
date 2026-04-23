import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/wukong_uikit/search/global_search_page.dart';

void main() {
  testWidgets('compatibility global search import renders Android shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(
            _FakeGlobalSearchRepository(),
          ),
        ],
        child: const MaterialApp(home: GlobalSearchPage()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('global-search-inline-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('global-search-cancel')),
      findsOneWidget,
    );
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets(
    'compatibility import shows find-user row between group and message sections',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(
              _FakeGlobalSearchRepository(
                snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
                  'ali': <int, GlobalSearchSnapshot>{
                    1: const GlobalSearchSnapshot(
                      users: <SearchMemberHit>[
                        SearchMemberHit(uid: 'u_ali', displayName: 'Ali'),
                      ],
                      groups: <SearchMessageHit>[
                        SearchMessageHit(
                          channelId: 'g_ali',
                          channelType: 2,
                          messageSeq: 0,
                          orderSeq: 0,
                          timestamp: 0,
                          contentType: 0,
                          fromUid: '',
                          fromName: 'Ali Group',
                          previewText: 'group preview',
                          channelName: 'Ali Group',
                        ),
                      ],
                      messages: <SearchMessageHit>[
                        SearchMessageHit(
                          channelId: 'g_ali',
                          channelType: 2,
                          messageSeq: 88,
                          orderSeq: 8088,
                          timestamp: 1712123456,
                          contentType: 1,
                          fromUid: 'u_ali',
                          fromName: 'Ali',
                          previewText: 'ali hit',
                          channelName: 'Ali Group',
                        ),
                      ],
                    ),
                  },
                },
              ),
            ),
          ],
          child: const MaterialApp(home: GlobalSearchPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('global-search-field')),
        'ali',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(
        find.byKey(const ValueKey<String>('global-search-group-g_ali')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('global-search-find-user')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('global-search-message-88')),
        findsOneWidget,
      );

      final groupY = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('global-search-group-g_ali')),
          )
          .dy;
      final findUserY = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('global-search-find-user')),
          )
          .dy;
      final messageY = tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('global-search-message-88')),
          )
          .dy;

      expect(groupY < findUserY, isTrue);
      expect(findUserY < messageY, isTrue);
    },
  );
}

class _FakeGlobalSearchRepository implements SearchRepository {
  _FakeGlobalSearchRepository({
    this.snapshotsByKeyword = const <String, Map<int, GlobalSearchSnapshot>>{},
  });

  final Map<String, Map<int, GlobalSearchSnapshot>> snapshotsByKeyword;

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
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
