import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_date_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_member_page.dart';
import 'package:wukong_im_app/modules/search/presentation/search_chat_navigation.dart';
import 'package:wukong_im_app/modules/search/presentation/global_search_page.dart';
import 'package:wukong_im_app/wukong_uikit/search/global_search_page.dart'
    as legacy_search;

void main() {
  testWidgets('new search pages compile inside ProviderScope', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatSearchEntryPage(channelId: 'g1001', channelType: 2),
        ),
      ),
    );

    expect(find.byType(ChatSearchEntryPage), findsOneWidget);
    expect(openChatFromLocateIntent, isA<Function>());
    expect(
      const ChatSearchDatePage(channelId: 'g1001', channelType: 2),
      isA<Widget>(),
    );
    expect(
      const ChatSearchCollectionPage(
        channelId: 'g1001',
        channelType: 2,
        scope: SearchCollectionScope.image,
      ),
      isA<Widget>(),
    );
    expect(
      const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
      isA<Widget>(),
    );
    expect(const GlobalSearchPage(), isA<Widget>());
  });

  testWidgets(
    'legacy global search import still resolves the compatibility page',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(
              _CompileSearchRepository(),
            ),
          ],
          child: const MaterialApp(home: legacy_search.GlobalSearchPage()),
        ),
      );

      expect(find.byType(legacy_search.GlobalSearchPage), findsOneWidget);
    },
  );
}

class _CompileSearchRepository implements SearchRepository {
  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
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
