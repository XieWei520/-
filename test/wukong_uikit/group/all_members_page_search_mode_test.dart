import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/wukong_uikit/group/all_members_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';

void main() {
  Widget _wrapWithApp(Widget child) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
      ],
      child: MaterialApp(home: child),
    );
  }

  GroupMember _member({
    required String uid,
    required String name,
  }) {
    return GroupMember(groupNo: 'group_demo', uid: uid, name: name, role: 0);
  }

  testWidgets('searchMessage mode uses Android title behavior', (tester) async {
    await tester.pumpWidget(
      _wrapWithApp(
        AllMembersPage(
          channelId: 'group_demo',
          channelType: 2,
          channelName: 'Project Group',
          searchMessage: true,
          autoLoad: false,
          initialMembers: [_member(uid: 'u_alice', name: 'Alice')],
        ),
      ),
    );

    expect(find.text('Search by group members'), findsOneWidget);
  });

  testWidgets(
    'searchMessage mode opens existing member-search results instead of user detail',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          AllMembersPage(
            channelId: 'group_demo',
            channelType: 2,
            channelName: 'Project Group',
            searchMessage: true,
            autoLoad: false,
            initialMembers: [_member(uid: 'u_alice', name: 'Alice')],
          ),
        ),
      );

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('search-member-results-page-u_alice'),
        ),
        findsOneWidget,
      );
      expect(find.byType(UserDetailPage), findsNothing);
    },
  );

  testWidgets('default mode still opens UserDetailPage on member tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithApp(
        AllMembersPage(
          channelId: 'group_demo',
          channelType: 2,
          autoLoad: false,
          initialMembers: [_member(uid: 'u_alice', name: 'Alice')],
        ),
      ),
    );

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byType(UserDetailPage), findsOneWidget);
  });
}

class _FakeSearchRepository implements SearchRepository {
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
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
  Future<List<SearchMessageHit>> searchMessagesByMember({
    required String channelId,
    required int channelType,
    required String memberUid,
    required String keyword,
    required int page,
    required int limit,
  }) async {
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
        channelName: 'Project Group',
      ),
    ];
  }
}
