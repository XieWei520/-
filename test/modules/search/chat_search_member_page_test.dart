import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/search/application/chat_locate_coordinator.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/data/search_locate_resolver.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_member_page.dart';
import 'package:wukong_im_app/modules/search/search_with_member_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await StorageUtils.setUid('u_self');
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  Widget wrapWithApp(
    Widget child, {
    required SearchRepository repository,
    SearchLocateResolver? searchLocateResolver,
    ChatLocateCoordinator? chatLocateCoordinator,
  }) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
        if (searchLocateResolver != null)
          searchLocateResolverProvider.overrideWithValue(searchLocateResolver),
        if (chatLocateCoordinator != null)
          chatLocateCoordinatorProvider.overrideWithValue(
            chatLocateCoordinator,
          ),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
      ],
      child: MaterialApp(locale: const Locale('en'), home: child),
    );
  }

  testWidgets('member page opens a dedicated member-results route', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
        repository: _FakeScopedRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-member-u_alice')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('search-member-u_alice')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-member-results-page-u_alice')),
      findsOneWidget,
    );
    expect(find.text('member result'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('search-member-result-avatar-u_alice')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('search-member-result-name-44')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('search-member-result-time-44')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('search-member-result-content-44')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-member-u_alice')),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping a member result resolves locate intent with chat-member-search and opens chat',
    (tester) async {
      final resolver = _RecordingLocateResolver(
        intent: const ChatLocateIntent(
          channelId: 'resolved-member-channel',
          channelType: 2,
          messageSeq: 44,
          orderSeq: 12345,
          source: 'resolved-member-intent',
          channelName: 'Resolved Member Room',
        ),
      );
      final coordinator = _RecordingLocateCoordinator(
        request: const ChatOpenRequest(
          channelId: 'resolved-member-channel',
          channelType: 2,
          orderSeq: 12345,
          highlightKeyword: '',
          source: 'resolved-member-intent',
          channelName: 'Resolved Member Room',
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
          repository: _FakeScopedRepository(),
          searchLocateResolver: resolver,
          chatLocateCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-member-u_alice')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-member-result-44')),
      );
      await tester.pumpAndSettle();

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, 12345);
      expect(shell.channelName, 'Resolved Member Room');
      expect(resolver.sources, <String>['chat-member-search']);
      expect(resolver.highlightKeywords, <String>['']);
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.source, 'resolved-member-intent');
    },
  );

  testWidgets(
    'member results page does not flash no-results before loading starts',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchMemberResultsPage(
            channelId: 'g1001',
            channelType: 2,
            member: SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
          ),
          repository: _FakeDelayedMemberResultsRepository(),
        ),
      );

      expect(find.text('暂无结果'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'search with member wrapper routes directly to the existing member-results owner',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const SearchWithMemberPage(
            channelId: 'g1001',
            channelType: 2,
            member: SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
          ),
          repository: _FakeScopedRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('search-member-results-page-u_alice'),
        ),
        findsOneWidget,
      );
      expect(find.text('member result'), findsOneWidget);
    },
  );

  testWidgets(
    'member load-more failure keeps items visible and offers explicit retry',
    (tester) async {
      final repository = _FakeMemberIncrementalFailureRepository();
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-member-u_alice')),
      );
      await tester.pumpAndSettle();

      final resultsList = find.byKey(
        const ValueKey<String>('chat-member-search-results-list'),
      );
      final resultsScrollable = find.descendant(
        of: resultsList,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('search-member-result-119')),
        200,
        scrollable: resultsScrollable,
      );
      expect(
        find.byKey(const ValueKey<String>('search-member-result-119')),
        findsOneWidget,
      );

      await tester.drag(resultsScrollable, const Offset(0, -1200));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, greaterThanOrEqualTo(1));
      expect(
        find.byKey(const ValueKey<String>('search-member-result-119')),
        findsOneWidget,
      );
      expect(find.text('加载更多失败'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('chat-member-search-load-more-retry'),
        ),
        findsOneWidget,
      );

      final attemptsBeforeRetry = repository.loadMoreAttempts;
      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-member-search-load-more-retry'),
        ),
      );
      await tester.pump();

      expect(repository.loadMoreAttempts, greaterThan(attemptsBeforeRetry));
    },
  );

  testWidgets(
    'member load-more failure waits for explicit retry before retrying',
    (tester) async {
      final repository = _FakeMemberIncrementalFailureRepository();
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchMemberPage(channelId: 'g1001', channelType: 2),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-member-u_alice')),
      );
      await tester.pumpAndSettle();

      final resultsList = find.byKey(
        const ValueKey<String>('chat-member-search-results-list'),
      );
      final resultsScrollable = find.descendant(
        of: resultsList,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('search-member-result-119')),
        200,
        scrollable: resultsScrollable,
      );

      await tester.drag(resultsScrollable, const Offset(0, -1200));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('加载更多失败'), findsOneWidget);

      final attemptsAfterFailure = repository.loadMoreAttempts;
      await tester.drag(resultsScrollable, const Offset(0, -120));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat-member-search-load-more-retry'),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure + 1);
    },
  );
}

class _FakeScopedRepository implements SearchRepository {
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
    return const <SearchMemberHit>[
      SearchMemberHit(uid: 'u_alice', displayName: 'Alice'),
      SearchMemberHit(uid: 'u_bob', displayName: 'Bob'),
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
    return <SearchMessageHit>[
      SearchMessageHit(
        channelId: channelId,
        channelType: channelType,
        messageSeq: 44,
        orderSeq: 44000,
        timestamp: 1710000000,
        contentType: 1,
        fromUid: memberUid,
        fromName: memberUid == 'u_alice' ? 'Alice' : 'Bob',
        previewText: 'member result',
        channelName: 'Design',
      ),
    ];
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _FakeMemberIncrementalFailureRepository implements SearchRepository {
  int loadMoreAttempts = 0;

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
      return List<SearchMessageHit>.generate(20, (index) {
        final seq = 100 + index;
        return SearchMessageHit(
          channelId: channelId,
          channelType: channelType,
          messageSeq: seq,
          orderSeq: 90000 + seq,
          timestamp: 1710000000,
          contentType: 1,
          fromUid: memberUid,
          fromName: 'Alice',
          previewText: 'member result $seq',
          channelName: 'Design',
        );
      });
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _FakeDelayedMemberResultsRepository implements SearchRepository {
  final Completer<List<SearchMessageHit>> _pendingResults =
      Completer<List<SearchMessageHit>>();

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
    return _pendingResults.future;
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _RecordingLocateResolver extends SearchLocateResolver {
  _RecordingLocateResolver({required this.intent});

  final ChatLocateIntent intent;
  final List<String> sources = <String>[];
  final List<String> highlightKeywords = <String>[];

  @override
  ChatLocateIntent fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    sources.add(source);
    highlightKeywords.add(highlightKeyword);
    return intent;
  }
}

class _RecordingLocateCoordinator extends ChatLocateCoordinator {
  _RecordingLocateCoordinator({required this.request})
    : super(resolveOrderSeq: _unusedResolveOrderSeq);

  final ChatOpenRequest request;
  final List<ChatLocateIntent> intents = <ChatLocateIntent>[];

  @override
  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    intents.add(intent);
    return request;
  }

  static Future<int> _unusedResolveOrderSeq({
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    return 0;
  }
}

class _ImmediateSuccessAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}
