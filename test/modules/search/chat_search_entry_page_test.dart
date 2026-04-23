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
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_date_page.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/all_members_page.dart';
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
    'empty keyword shows Android-style search shell and scoped menu hint',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
          repository: _FakeSearchRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-search-inline-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-menu-hint')),
        findsOneWidget,
      );
      expect(find.text('Search specified content'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chat-search-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-menu-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-menu-date')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-results-list')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'typing a keyword hides the scoped menu and shows the keyword result list',
    (tester) async {
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

      expect(
        find.byKey(const ValueKey<String>('chat-search-menu-grid')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-results-list')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'starting a new keyword search hides stale results and shows loading',
    (tester) async {
      final betaResults = Completer<List<SearchMessageHit>>();
      final repository = _FakeSearchRepository(
        resultsByKeyword: <String, List<SearchMessageHit>>{
          'alpha': const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'group-1',
              channelType: 2,
              messageSeq: 41,
              orderSeq: 71,
              timestamp: 1712123455,
              contentType: 1,
              fromUid: 'u_alex',
              fromName: 'Alex',
              previewText: 'alpha result',
              channelName: 'Project Group',
            ),
          ],
        },
        pendingResultsByKeyword: <String, Completer<List<SearchMessageHit>>>{
          'beta': betaResults,
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
        'alpha',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(find.text('alpha result'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('chat-search-field')),
        'beta',
      );
      await tester.pump();

      expect(find.text('alpha result'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chat-search-results-list')),
        findsNothing,
      );

      betaResults.complete(const <SearchMessageHit>[]);
    },
  );

  testWidgets(
    'tapping a keyword result resolves locate intent via resolver and opens chat with coordinator request',
    (tester) async {
      final repository = _FakeSearchRepository(
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
      );
      final resolver = _RecordingLocateResolver(
        intent: const ChatLocateIntent(
          channelId: 'resolved-channel',
          channelType: 2,
          messageSeq: 42,
          orderSeq: 8801,
          source: 'resolved-keyword-intent',
          channelName: 'Resolved Room',
        ),
      );
      final coordinator = _RecordingLocateCoordinator(
        request: const ChatOpenRequest(
          channelId: 'resolved-channel',
          channelType: 2,
          orderSeq: 8801,
          locateMessageSeq: 42,
          highlightKeyword: 'keyword',
          source: 'resolved-keyword-intent',
          channelName: 'Resolved Room',
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
          repository: repository,
          searchLocateResolver: resolver,
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

      await tester.tap(find.text('keyword result'));
      await tester.pumpAndSettle();

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, 8801);
      expect(shell.initialLocateMessageSeq, 42);
      expect(shell.channelName, 'Resolved Room');
      expect(resolver.sources, <String>['chat-keyword-search']);
      expect(resolver.highlightKeywords, <String>['keyword']);
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.source, 'resolved-keyword-intent');
    },
  );

  testWidgets('locate fallback shows feedback instead of failing silently', (
    tester,
  ) async {
    final repository = _FakeSearchRepository(
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
    );
    final coordinator = ChatLocateCoordinator(
      resolveOrderSeq:
          ({
            required int messageSeq,
            required String channelId,
            required int channelType,
          }) async {
            throw StateError('locate failed');
          },
    );

    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
        repository: repository,
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

    await tester.tap(find.text('keyword result'));
    await tester.pumpAndSettle();

    final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
    expect(shell.initialAroundOrderSeq, isNull);
    expect(
      find.text(
        'Unable to locate the exact message. Opened the conversation instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping the date menu entry opens the scoped date search page', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchEntryPage(channelId: 'group-1', channelType: 2),
        repository: _FakeSearchRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-menu-date')),
    );
    await tester.pumpAndSettle();

    final page = tester.widget<ChatSearchDatePage>(
      find.byType(ChatSearchDatePage),
    );
    expect(page.channelId, 'group-1');
    expect(page.channelType, 2);
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

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-menu-image')),
    );
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

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-menu-member')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AllMembersPage), findsOneWidget);
    final memberPicker = tester.widget<AllMembersPage>(
      find.byType(AllMembersPage),
    );
    expect(memberPicker.searchMessage, isTrue);
    expect(memberPicker.channelId, 'group-1');
    expect(memberPicker.channelType, 2);
    expect(memberPicker.channelName, 'Project Group');
  });

  testWidgets(
    'tapping file and link menu entries open the matching collection scope page',
    (tester) async {
      Future<void> expectCollectionRoute({
        required String menuKey,
        required SearchCollectionScope expectedScope,
      }) async {
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

        await tester.tap(find.byKey(ValueKey<String>(menuKey)));
        await tester.pumpAndSettle();

        final page = tester.widget<ChatSearchCollectionPage>(
          find.byType(ChatSearchCollectionPage),
        );
        expect(page.channelId, 'group-1');
        expect(page.channelType, 2);
        expect(page.channelName, 'Project Group');
        expect(page.scope, expectedScope);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }

      await expectCollectionRoute(
        menuKey: 'chat-search-menu-file',
        expectedScope: SearchCollectionScope.file,
      );
      await expectCollectionRoute(
        menuKey: 'chat-search-menu-link',
        expectedScope: SearchCollectionScope.link,
      );
    },
  );
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({
    Map<String, List<SearchMessageHit>>? resultsByKeyword,
    Map<String, Completer<List<SearchMessageHit>>>? pendingResultsByKeyword,
  }) : _resultsByKeyword =
           resultsByKeyword ?? const <String, List<SearchMessageHit>>{},
       _pendingResultsByKeyword =
           pendingResultsByKeyword ??
           const <String, Completer<List<SearchMessageHit>>>{};

  final Map<String, List<SearchMessageHit>> _resultsByKeyword;
  final Map<String, Completer<List<SearchMessageHit>>> _pendingResultsByKeyword;

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
    final pending = _pendingResultsByKeyword[keyword];
    if (pending != null) {
      return pending.future;
    }
    return _resultsByKeyword[keyword] ?? const <SearchMessageHit>[];
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
