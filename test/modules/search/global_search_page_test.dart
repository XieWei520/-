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
import 'package:wukong_im_app/modules/search/presentation/global_search_page.dart';
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

  Widget wrapWithApp({
    required Widget child,
    required SearchRepository repository,
    SearchLocateResolver? searchLocateResolver,
    ChatLocateCoordinator? coordinator,
  }) {
    return ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(repository),
        if (searchLocateResolver != null)
          searchLocateResolverProvider.overrideWithValue(searchLocateResolver),
        if (coordinator != null)
          chatLocateCoordinatorProvider.overrideWithValue(coordinator),
        messageListProvider.overrideWith(
          (ref, session) =>
              _EmptyMessageListNotifier(session.channelId, session.channelType),
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets(
    'global search keeps Android shell and deterministic section order',
    (tester) async {
      final repository = _FakeGlobalSearchRepository(
        snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
          'alpha': <int, GlobalSearchSnapshot>{
            1: const GlobalSearchSnapshot(
              users: <SearchMemberHit>[
                SearchMemberHit(uid: 'u_alpha', displayName: 'Alpha User'),
              ],
              groups: <SearchMessageHit>[
                SearchMessageHit(
                  channelId: 'g_alpha',
                  channelType: 2,
                  messageSeq: 0,
                  orderSeq: 0,
                  timestamp: 0,
                  contentType: 0,
                  fromUid: '',
                  fromName: 'Alpha Group',
                  previewText: 'group preview',
                  channelName: 'Alpha Group',
                ),
              ],
              messages: <SearchMessageHit>[
                SearchMessageHit(
                  channelId: 'g_alpha',
                  channelType: 2,
                  messageSeq: 101,
                  orderSeq: 8101,
                  timestamp: 1712123456,
                  contentType: 1,
                  fromUid: 'u_alpha',
                  fromName: 'Alpha User',
                  previewText: 'alpha keyword hit',
                  channelName: 'Alpha Group',
                ),
              ],
            ),
          },
        },
      );

      await tester.pumpWidget(
        wrapWithApp(child: const GlobalSearchPage(), repository: repository),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('global-search-inline-shell')),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('global-search-field')),
        'alpha',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      final userFinder = find.byKey(
        const ValueKey<String>('global-search-user-u_alpha'),
      );
      final groupFinder = find.byKey(
        const ValueKey<String>('global-search-group-g_alpha'),
      );
      final findUserFinder = find.byKey(
        const ValueKey<String>('global-search-find-user'),
      );
      final messageFinder = find.byKey(
        const ValueKey<String>('global-search-message-101'),
      );

      expect(userFinder, findsOneWidget);
      expect(groupFinder, findsOneWidget);
      expect(findUserFinder, findsOneWidget);
      expect(messageFinder, findsOneWidget);

      final userTop = tester.getTopLeft(userFinder).dy;
      final groupTop = tester.getTopLeft(groupFinder).dy;
      final findUserTop = tester.getTopLeft(findUserFinder).dy;
      final messageTop = tester.getTopLeft(messageFinder).dy;

      expect(userTop < groupTop, isTrue);
      expect(groupTop < findUserTop, isTrue);
      expect(findUserTop < messageTop, isTrue);
    },
  );

  testWidgets(
    'tapping a global message uses locate resolver and shared chat opener',
    (tester) async {
      final repository = _FakeGlobalSearchRepository(
        snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
          'keyword': <int, GlobalSearchSnapshot>{
            1: const GlobalSearchSnapshot(
              messages: <SearchMessageHit>[
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
            ),
          },
        },
      );
      final resolver = _RecordingLocateResolver(
        intent: const ChatLocateIntent(
          channelId: 'resolved-channel',
          channelType: 2,
          messageSeq: 42,
          orderSeq: 8801,
          source: 'resolved-global-intent',
          channelName: 'Resolved Room',
        ),
      );
      final coordinator = _RecordingLocateCoordinator(
        request: const ChatOpenRequest(
          channelId: 'resolved-channel',
          channelType: 2,
          orderSeq: 8801,
          highlightKeyword: 'keyword',
          source: 'resolved-global-intent',
          channelName: 'Resolved Room',
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          child: const GlobalSearchPage(),
          repository: repository,
          searchLocateResolver: resolver,
          coordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('global-search-field')),
        'keyword',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      await tester.tap(
        find.byKey(const ValueKey<String>('global-search-message-42')),
      );
      await tester.pumpAndSettle();

      expect(resolver.sources, <String>['global-search']);
      expect(resolver.highlightKeywords, <String>['keyword']);
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.source, 'resolved-global-intent');

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, 8801);
      expect(shell.channelName, 'Resolved Room');
    },
  );

  testWidgets(
    'tapping an aggregated global message opens the channel result page',
    (tester) async {
      final repository = _FakeGlobalSearchRepository(
        snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
          'launch': <int, GlobalSearchSnapshot>{
            1: const GlobalSearchSnapshot(
              messages: <SearchMessageHit>[
                SearchMessageHit(
                  channelId: 'group-1',
                  channelType: 2,
                  messageSeq: 0,
                  orderSeq: 0,
                  timestamp: 0,
                  contentType: 0,
                  fromUid: '',
                  fromName: '',
                  previewText: 'launch',
                  channelName: 'Project Group',
                  matchCount: 3,
                ),
              ],
            ),
          },
        },
        channelMessagesByKey: <String, List<SearchMessageHit>>{
          'launch:group-1:2:1:100': const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'group-1',
              channelType: 2,
              messageSeq: 41,
              orderSeq: 8041,
              timestamp: 1712123456,
              contentType: 1,
              fromUid: 'u_alex',
              fromName: 'Alex',
              previewText: 'launch checklist',
              channelName: 'Project Group',
            ),
            SearchMessageHit(
              channelId: 'group-1',
              channelType: 2,
              messageSeq: 42,
              orderSeq: 8042,
              timestamp: 1712123556,
              contentType: 1,
              fromUid: 'u_blair',
              fromName: 'Blair',
              previewText: 'launch decision',
              channelName: 'Project Group',
            ),
          ],
        },
      );

      await tester.pumpWidget(
        wrapWithApp(child: const GlobalSearchPage(), repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('global-search-field')),
        'launch',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(find.text('3 related records'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('global-search-message-2_group-1_0')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Project Group'), findsWidgets);
      expect(
        repository.channelMessageCalls,
        contains(
          (
            keyword: 'launch',
            channelId: 'group-1',
            channelType: 2,
            page: 1,
            limit: 100,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-41')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-42')),
        findsOneWidget,
      );
      expect(find.byType(ChatPageShell), findsNothing);
    },
  );

  testWidgets('global message row prefers channel title over sender name', (
    tester,
  ) async {
    final repository = _FakeGlobalSearchRepository(
      snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
        'design': <int, GlobalSearchSnapshot>{
          1: const GlobalSearchSnapshot(
            messages: <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'g_design',
                channelType: 2,
                messageSeq: 501,
                orderSeq: 8501,
                timestamp: 1712123456,
                contentType: 1,
                fromUid: 'u_alice',
                fromName: 'Alice',
                previewText: 'roadmap update',
                channelName: 'Design Group',
              ),
            ],
          ),
        },
      },
    );

    await tester.pumpWidget(
      wrapWithApp(child: const GlobalSearchPage(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('global-search-field')),
      'design',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    final messageRow = find.byKey(
      const ValueKey<String>('global-search-message-501'),
    );
    expect(messageRow, findsOneWidget);
    expect(
      find.descendant(of: messageRow, matching: find.text('Design Group')),
      findsOneWidget,
    );
    expect(find.descendant(of: messageRow, matching: find.text('Alice')), findsNothing);
  });

  testWidgets(
    'global search load-more failure footer requires explicit retry',
    (tester) async {
      final repository = _FakeGlobalSearchRepository(
        snapshotsByKeyword: <String, Map<int, GlobalSearchSnapshot>>{
          'alpha': <int, GlobalSearchSnapshot>{
            1: GlobalSearchSnapshot(
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
                  messageSeq: 999,
                  orderSeq: 70999,
                  timestamp: 1712123956,
                  contentType: 1,
                  fromUid: 'u_alpha',
                  fromName: 'Alpha',
                  previewText: 'alpha result 999',
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

      await tester.pumpWidget(
        wrapWithApp(child: const GlobalSearchPage(), repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('global-search-field')),
        'alpha',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      await tester.drag(
        find.byKey(const ValueKey<String>('global-search-results-list')),
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();

      expect(
        repository.calls.where(
          (call) => call.keyword == 'alpha' && call.page == 2,
        ),
        hasLength(1),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('global-search-load-more-retry')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('global-search-results-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('global-search-load-more-retry')),
        findsOneWidget,
      );

      await tester.drag(
        find.byKey(const ValueKey<String>('global-search-results-list')),
        const Offset(0, -1800),
      );
      await tester.pump();

      expect(
        repository.calls.where(
          (call) => call.keyword == 'alpha' && call.page == 2,
        ),
        hasLength(1),
      );

      repository.failingKeywordPages['alpha']?.remove(2);
      await tester.tap(
        find.byKey(const ValueKey<String>('global-search-load-more-retry')),
      );
      await tester.pumpAndSettle();

      expect(
        repository.calls.where(
          (call) => call.keyword == 'alpha' && call.page == 2,
        ),
        hasLength(2),
      );
      expect(find.text('alpha result 999'), findsOneWidget);
    },
  );
}

class _FakeGlobalSearchRepository implements SearchRepository {
  _FakeGlobalSearchRepository({
    this.snapshotsByKeyword = const <String, Map<int, GlobalSearchSnapshot>>{},
    this.failingKeywordPages = const <String, Set<int>>{},
    this.channelMessagesByKey =
        const <String, List<SearchMessageHit>>{},
  });

  final Map<String, Map<int, GlobalSearchSnapshot>> snapshotsByKeyword;
  final Map<String, Set<int>> failingKeywordPages;
  final Map<String, List<SearchMessageHit>> channelMessagesByKey;
  final List<({String keyword, int page})> calls =
      <({String keyword, int page})>[];
  final List<
    ({
      String keyword,
      String channelId,
      int channelType,
      int page,
      int limit,
    })
  > channelMessageCalls =
      <({
        String keyword,
        String channelId,
        int channelType,
        int page,
        int limit,
      })>[];

  @override
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    calls.add((keyword: keyword, page: page));
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
  }) async {
    channelMessageCalls.add(
      (
        keyword: keyword,
        channelId: channelId,
        channelType: channelType,
        page: page,
        limit: limit,
      ),
    );
    return channelMessagesByKey['$keyword:$channelId:$channelType:$page:$limit'] ??
        const <SearchMessageHit>[];
  }

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
