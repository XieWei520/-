import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/modules/search/application/chat_locate_coordinator.dart';
import 'package:wukong_im_app/modules/search/application/search_providers.dart';
import 'package:wukong_im_app/modules/search/data/search_locate_resolver.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/domain/search_repository.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_collection_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';
import 'package:wukong_im_app/wukong_base/views/image_viewer.dart';
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

  testWidgets('image collection page renders grouped sections', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        const ChatSearchCollectionPage(
          channelId: 'g1001',
          channelType: 2,
          scope: SearchCollectionScope.image,
        ),
        repository: _FakeScopedRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-collection-section-2026-04')),
      findsOneWidget,
    );
  });

  testWidgets(
    'local image paths render with file-image branch instead of network thumbnails',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
          ),
          repository: _FakeLocalImageRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CachedMediaImage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is FileImage,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'network image collection thumbnails use shared media cache with decode bounds',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
          ),
          repository: _FakeScopedRepository(),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImage = tester.widget<CachedMediaImage>(
        find.byType(CachedMediaImage),
      );

      expect(cachedImage.imageUrl, 'https://cdn.example.com/image.png');
      expect(cachedImage.cacheKey, cachedImage.imageUrl);
      expect(cachedImage.fit, BoxFit.cover);
      expect(cachedImage.maxWidth, isNotNull);
      expect(cachedImage.maxHeight, isNotNull);
      expect(cachedImage.maxWidth, greaterThan(0));
      expect(cachedImage.maxHeight, greaterThan(0));
    },
  );

  testWidgets(
    'image collection keeps the month header pinned while scrolling',
    (tester) async {
      final items = List<SearchMediaItem>.generate(24, (index) {
        return SearchMediaItem(
          hit: SearchMessageHit(
            channelId: 'g1001',
            channelType: 2,
            messageSeq: 100 + index,
            orderSeq: 33000 + index,
            timestamp: 1710000000,
            contentType: 2,
            fromUid: 'u_alice',
            fromName: 'Alice',
            previewText: '[image]',
            channelName: 'Design',
          ),
          scope: SearchCollectionScope.image,
          sectionKey: '2026-04',
          mediaUrl: 'https://cdn.example.com/image_$index.png',
        );
      });

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
          ),
          repository: _FakeScopedRepository(collectionItems: items),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('search-collection-section-2026-04')),
        findsOneWidget,
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
      await tester.pumpAndSettle();

      final headerTop = tester.getTopLeft(
        find.byKey(const ValueKey<String>('search-collection-section-2026-04')),
      );
      expect(headerTop.dy, greaterThanOrEqualTo(0));
    },
  );

  testWidgets(
    'tapping a file item resolves locate intent with chat-collection-search and opens chat',
    (tester) async {
      final resolver = _RecordingLocateResolver(
        intent: const ChatLocateIntent(
          channelId: 'resolved-file-channel',
          channelType: 2,
          messageSeq: 33,
          orderSeq: 9988,
          source: 'resolved-collection-intent',
          channelName: 'Resolved Collection Room',
        ),
      );
      final coordinator = _RecordingLocateCoordinator(
        request: const ChatOpenRequest(
          channelId: 'resolved-file-channel',
          channelType: 2,
          orderSeq: 9988,
          highlightKeyword: '',
          source: 'resolved-collection-intent',
          channelName: 'Resolved Collection Room',
        ),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            channelName: 'Design',
            scope: SearchCollectionScope.file,
          ),
          repository: _FakeScopedRepository(),
          searchLocateResolver: resolver,
          chatLocateCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-item-33')),
      );
      await tester.pumpAndSettle();

      final shell = tester.widget<ChatPageShell>(find.byType(ChatPageShell));
      expect(shell.initialAroundOrderSeq, 9988);
      expect(shell.channelName, 'Resolved Collection Room');
      expect(resolver.sources, <String>['chat-collection-search']);
      expect(resolver.highlightKeywords, <String>['']);
      expect(coordinator.intents, hasLength(1));
      expect(coordinator.intents.single.source, 'resolved-collection-intent');
    },
  );

  testWidgets('tapping an image opens preview with Android-style actions', (
    tester,
  ) async {
    var favoriteCount = 0;
    var showInChatCount = 0;

    await tester.pumpWidget(
      wrapWithApp(
        ChatSearchCollectionPage(
          channelId: 'g1001',
          channelType: 2,
          scope: SearchCollectionScope.image,
          onFavoriteItem: (_) async {
            favoriteCount += 1;
          },
          onShowItemInChat: (_) async {
            showInChatCount += 1;
          },
        ),
        repository: _FakeScopedRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('search-collection-item-33')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('image-viewer-action-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('image-viewer-action-favorite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('image-viewer-action-show-in-chat')),
      findsOneWidget,
    );
    expect(favoriteCount, 0);
    expect(showInChatCount, 0);

    await tester.tap(
      find.byKey(const ValueKey<String>('image-viewer-action-favorite')),
    );
    await tester.pumpAndSettle();
    expect(favoriteCount, 1);
    expect(showInChatCount, 0);

    await tester.tap(
      find.byKey(const ValueKey<String>('image-viewer-action-show-in-chat')),
    );
    await tester.pumpAndSettle();
    expect(showInChatCount, 1);
  });

  testWidgets(
    'image preview shows scan QR action when parse_qr_code endpoint is registered',
    (tester) async {
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);
      endpointManager.setMethod(
        ChatMenuIDs.parseQrCode,
        '',
        0,
        AsyncFunctionHandler(([dynamic _]) async => null),
      );

      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
          ),
          repository: _FakeScopedRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-item-33')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('image-viewer-action-scan-qrcode')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping an image item without usable mediaUrl falls back to show-in-chat',
    (tester) async {
      final openedInChat = <int>[];
      await tester.pumpWidget(
        wrapWithApp(
          ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
            onShowItemInChat: (item) async {
              openedInChat.add(item.hit.messageSeq);
            },
          ),
          repository: _FakeMixedPreviewRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-item-33')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewer), findsNothing);
      expect(openedInChat, <int>[33]);
    },
  );

  testWidgets(
    'preview actions stay aligned with filtered previewable image items',
    (tester) async {
      final openedInChat = <int>[];
      await tester.pumpWidget(
        wrapWithApp(
          ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.image,
            onShowItemInChat: (item) async {
              openedInChat.add(item.hit.messageSeq);
            },
          ),
          repository: _FakeMixedPreviewRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-item-44')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewer), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('image-viewer-action-show-in-chat')),
      );
      await tester.pumpAndSettle();

      expect(openedInChat, <int>[44]);
    },
  );

  testWidgets('long pressing an image shows Android quick actions', (
    tester,
  ) async {
    var forwardCount = 0;
    var showInChatCount = 0;

    await tester.pumpWidget(
      wrapWithApp(
        ChatSearchCollectionPage(
          channelId: 'g1001',
          channelType: 2,
          scope: SearchCollectionScope.image,
          onForwardItem: (_) async {
            forwardCount += 1;
          },
          onShowItemInChat: (_) async {
            showInChatCount += 1;
          },
        ),
        repository: _FakeScopedRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey<String>('search-collection-item-33')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('search-image-quick-action-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('search-image-quick-action-show-in-chat'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('search-image-quick-action-forward')),
    );
    await tester.pumpAndSettle();
    expect(forwardCount, 1);
    expect(showInChatCount, 0);

    await tester.longPress(
      find.byKey(const ValueKey<String>('search-collection-item-33')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('search-image-quick-action-show-in-chat'),
      ),
    );
    await tester.pumpAndSettle();
    expect(showInChatCount, 1);
  });

  testWidgets('image load-more failure keeps items visible and offers retry', (
    tester,
  ) async {
    final repository = _FakeIncrementalFailureRepository();
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('search-collection-item-119')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('search-collection-item-119')),
      findsOneWidget,
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.loadMoreAttempts, greaterThanOrEqualTo(1));
    expect(
      find.byKey(const ValueKey<String>('search-collection-item-119')),
      findsOneWidget,
    );
    expect(find.text('加载更多失败'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
      findsOneWidget,
    );

    final attemptsBeforeRetry = repository.loadMoreAttempts;
    await tester.tap(
      find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
    );
    await tester.pump();

    expect(repository.loadMoreAttempts, greaterThan(attemptsBeforeRetry));
  });

  testWidgets(
    'image load-more failure waits for explicit retry before retrying',
    (tester) async {
      final repository = _FakeIncrementalFailureRepository();
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('search-collection-item-119')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('加载更多失败'), findsOneWidget);

      final attemptsAfterFailure = repository.loadMoreAttempts;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure);

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure + 1);
    },
  );

  testWidgets(
    'file load-more failure keeps items visible and uses shared retry footer',
    (tester) async {
      final repository = _FakeIncrementalFailureRepository();
      await tester.pumpWidget(
        wrapWithApp(
          const ChatSearchCollectionPage(
            channelId: 'g1001',
            channelType: 2,
            scope: SearchCollectionScope.file,
          ),
          repository: repository,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('search-collection-section-2026-04')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('search-collection-item-119')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey<String>('search-collection-item-119')),
        findsOneWidget,
      );

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('search-collection-item-119')),
        findsOneWidget,
      );
      expect(find.text('加载更多失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
        findsOneWidget,
      );

      final attemptsAfterFailure = repository.loadMoreAttempts;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure);

      await tester.tap(
        find.byKey(const ValueKey<String>('search-collection-load-more-retry')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.loadMoreAttempts, attemptsAfterFailure + 1);
    },
  );
}

class _FakeScopedRepository implements SearchRepository {
  _FakeScopedRepository({List<SearchMediaItem>? collectionItems})
    : _collectionItems = collectionItems;

  final List<SearchMediaItem>? _collectionItems;

  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    if (_collectionItems != null) {
      return _collectionItems;
    }
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _FakeLocalImageRepository implements SearchRepository {
  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
    return <SearchMediaItem>[
      SearchMediaItem(
        hit: const SearchMessageHit(
          channelId: 'g1001',
          channelType: 2,
          messageSeq: 88,
          orderSeq: 88000,
          timestamp: 1710000000,
          contentType: 2,
          fromUid: 'u_alice',
          fromName: 'Alice',
          previewText: '[image]',
          channelName: 'Design',
        ),
        scope: SearchCollectionScope.image,
        sectionKey: '2026-04',
        mediaUrl: r'C:\local\search_image_88.png',
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _FakeMixedPreviewRepository implements SearchRepository {
  @override
  Future<List<SearchMediaItem>> searchCollection({
    required String channelId,
    required int channelType,
    required SearchCollectionScope scope,
    required int page,
    required int limit,
  }) async {
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
        scope: SearchCollectionScope.image,
        sectionKey: '2026-04',
        mediaUrl: '',
      ),
      SearchMediaItem(
        hit: const SearchMessageHit(
          channelId: 'g1001',
          channelType: 2,
          messageSeq: 44,
          orderSeq: 44000,
          timestamp: 1710000001,
          contentType: 2,
          fromUid: 'u_bob',
          fromName: 'Bob',
          previewText: '[image]',
          channelName: 'Design',
        ),
        scope: SearchCollectionScope.image,
        sectionKey: '2026-04',
        mediaUrl: 'https://cdn.example.com/image_44.png',
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
  Future<GlobalSearchSnapshot> searchGlobal({
    required String keyword,
    required int page,
    required int limit,
  }) async {
    return const GlobalSearchSnapshot();
  }
}

class _FakeIncrementalFailureRepository implements SearchRepository {
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
      return List<SearchMediaItem>.generate(20, (index) {
        final seq = 100 + index;
        return SearchMediaItem(
          hit: SearchMessageHit(
            channelId: channelId,
            channelType: channelType,
            messageSeq: seq,
            orderSeq: 70000 + seq,
            timestamp: 1710000000,
            contentType: 2,
            fromUid: 'u_alice',
            fromName: 'Alice',
            previewText: '[image]',
            channelName: 'Design',
          ),
          scope: scope,
          sectionKey: '2026-04',
          mediaUrl: scope == SearchCollectionScope.image
              ? 'https://cdn.example.com/image_$seq.png'
              : null,
          fileName: scope == SearchCollectionScope.file
              ? 'file_$seq.pdf'
              : null,
          linkUrl: scope == SearchCollectionScope.link
              ? 'https://example.com/$seq'
              : null,
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
