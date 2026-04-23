import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/favorites/favorite_record.dart';
import 'package:wukong_im_app/modules/favorites/favorites_page.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({FavoritesPage? page}) {
    return MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: page ?? const FavoritesPage(),
    );
  }

  test(
    'favorite record title falls back to sender_uid when sender_name is missing',
    () {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'fallback-1',
        'sender_name': '',
        'sender_uid': 'sender-uid-1',
        'uid': 'legacy-uid-ignored',
        'content': 'payload',
        'content_type': 1,
        'created_at': '2026-04-01T08:00:00Z',
      });

      expect(record.title, 'sender-uid-1');
    },
  );

  test(
    'favorite record hasTrustedLocateRoute stays false without message_seq and order_seq',
    () {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'route-1',
        'sender_name': 'Alice',
        'content': 'payload',
        'content_type': 1,
        'created_at': '2026-04-01T08:00:00Z',
        'channel_id': 'group-1',
        'channel_type': 2,
      });

      expect(record.hasTrustedLocateRoute, isFalse);
    },
  );

  testWidgets('first page loads from CollectionApi.getList', (tester) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        _AdapterResponse(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              _favoritePayload(
                id: '1001',
                senderName: 'Alice',
                content: 'Roadmap',
              ),
            ],
          },
        ),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('收藏'), findsAtLeastNWidgets(1));
    expect(find.text('搜索收藏'), findsOneWidget);
    expect(adapter.listCallCount, 1);
    expect(adapter.searchCallCount, 0);
    expect(
      find.byKey(const ValueKey<String>('favorites-row-1001')),
      findsOneWidget,
    );
    expect(find.text('Roadmap'), findsOneWidget);
  });

  testWidgets('keyword search uses CollectionApi.search', (tester) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        _AdapterResponse(payload: const <String, dynamic>{'data': <dynamic>[]}),
      ],
      searchResponsesByKeyword: <String, _AdapterResponse>{
        'road': _AdapterResponse(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              _favoritePayload(
                id: '2002',
                senderName: 'Bob',
                content: 'Search hit',
              ),
            ],
          },
        ),
      },
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('favorites-search-box')),
      'road',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(adapter.searchKeywords, <String>['road']);
    expect(
      find.byKey(const ValueKey<String>('favorites-row-2002')),
      findsOneWidget,
    );
    expect(find.text('Search hit'), findsOneWidget);
  });

  testWidgets(
    'deleting an item calls CollectionApi.delete and removes the row from UI',
    (tester) async {
      final adapter = _FavoritesApiAdapter(
        listResponses: <_AdapterResponse>[
          _AdapterResponse(
            payload: <String, dynamic>{
              'data': <Map<String, dynamic>>[
                _favoritePayload(
                  id: '3003',
                  senderName: 'Carol',
                  content: 'Will delete',
                ),
              ],
            },
          ),
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('favorites-row-3003')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('favorites-delete-3003')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('favorites-delete-confirm')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(adapter.deletedIds, <String>['3003']);
      expect(
        find.byKey(const ValueKey<String>('favorites-row-3003')),
        findsNothing,
      );
    },
  );

  testWidgets('empty state renders when the list is empty', (tester) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        _AdapterResponse(payload: const <String, dynamic>{'data': <dynamic>[]}),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('favorites-empty-state')),
      findsOneWidget,
    );
    expect(find.text('暂无收藏'), findsOneWidget);
  });

  testWidgets('load failure renders a retry state', (tester) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        const _AdapterResponse(statusCode: 500, payload: <String, dynamic>{}),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('favorites-error-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('favorites-retry-button')),
      findsOneWidget,
    );
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('retry recovers from initial load failure to success', (
    tester,
  ) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        const _AdapterResponse(statusCode: 500, payload: <String, dynamic>{}),
        _AdapterResponse(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              _favoritePayload(
                id: '4004',
                senderName: 'Dora',
                content: 'Retry success',
              ),
            ],
          },
        ),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('favorites-error-state')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('favorites-retry-button')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(adapter.listCallCount, 2);
    expect(
      find.byKey(const ValueKey<String>('favorites-row-4004')),
      findsOneWidget,
    );
  });

  testWidgets('pull-to-refresh recovers from empty state to loaded items', (
    tester,
  ) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        _AdapterResponse(payload: const <String, dynamic>{'data': <dynamic>[]}),
        _AdapterResponse(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              _favoritePayload(
                id: '5005',
                senderName: 'Eve',
                content: 'Refreshed item',
              ),
            ],
          },
        ),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('favorites-empty-state')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('favorites-empty-scroll')),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(adapter.listCallCount, 2);
    expect(
      find.byKey(const ValueKey<String>('favorites-row-5005')),
      findsOneWidget,
    );
  });

  testWidgets('tapping an openable favorite delegates to the injected opener', (
    tester,
  ) async {
    final adapter = _FavoritesApiAdapter(
      listResponses: <_AdapterResponse>[
        _AdapterResponse(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              _favoritePayload(
                id: '9009',
                senderName: 'Frank',
                contentType: 5,
                content: <String, dynamic>{
                  'name': '合同.pdf',
                  'url': 'https://example.com/files/contract.pdf',
                },
              ),
            ],
          },
        ),
      ],
    );
    ApiClient.instance.dio.httpClientAdapter = adapter;
    final openedIds = <String>[];

    await tester.pumpWidget(
      buildApp(
        page: FavoritesPage(
          onOpenRecord: (record) async {
            openedIds.add(record.id);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('favorites-row-9009')));
    await tester.pump();

    expect(openedIds, <String>['9009']);
  });

  testWidgets(
    'favorites empty state renders inside the settings-family shell',
    (tester) async {
      final adapter = _FavoritesApiAdapter(
        listResponses: <_AdapterResponse>[
          _AdapterResponse(
            payload: const <String, dynamic>{'data': <dynamic>[]},
          ),
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScaffold), findsOneWidget);
      expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const ValueKey<String>('favorites-empty-state')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'favorites retry state renders inside the settings-family shell',
    (tester) async {
      final adapter = _FavoritesApiAdapter(
        listResponses: <_AdapterResponse>[
          const _AdapterResponse(statusCode: 500, payload: <String, dynamic>{}),
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScaffold), findsOneWidget);
      expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const ValueKey<String>('favorites-error-state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('favorites-retry-button')),
        findsOneWidget,
      );
    },
  );
}

Map<String, dynamic> _favoritePayload({
  required String id,
  required String senderName,
  required Object content,
  int contentType = 1,
}) {
  return <String, dynamic>{
    'id': id,
    'sender_name': senderName,
    'content': content,
    'content_type': contentType,
    'created_at': '2026-04-01T08:00:00Z',
    'channel_id': 'group-1',
    'channel_type': 2,
  };
}

class _FavoritesApiAdapter implements HttpClientAdapter {
  _FavoritesApiAdapter({
    List<_AdapterResponse>? listResponses,
    Map<String, _AdapterResponse>? searchResponsesByKeyword,
  }) : _listResponses = listResponses ?? <_AdapterResponse>[],
       _searchResponsesByKeyword =
           searchResponsesByKeyword ?? const <String, _AdapterResponse>{};

  final List<_AdapterResponse> _listResponses;
  final Map<String, _AdapterResponse> _searchResponsesByKeyword;

  int listCallCount = 0;
  int searchCallCount = 0;
  final List<String> searchKeywords = <String>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final method = options.method.toUpperCase();

    if (path == ApiConfig.favorites && method == 'GET') {
      listCallCount += 1;
      final response = _listResponses.isNotEmpty
          ? _listResponses.removeAt(0)
          : const _AdapterResponse(
              payload: <String, dynamic>{'data': <dynamic>[]},
            );
      return _toResponseBody(response);
    }

    if (path == '${ApiConfig.favorites}/search' && method == 'POST') {
      searchCallCount += 1;
      final body = options.data;
      final keyword = body is Map ? (body['keyword']?.toString() ?? '') : '';
      searchKeywords.add(keyword);
      final response =
          _searchResponsesByKeyword[keyword] ??
          const _AdapterResponse(
            payload: <String, dynamic>{'data': <dynamic>[]},
          );
      return _toResponseBody(response);
    }

    if (path.startsWith('${ApiConfig.favorite}/') && method == 'DELETE') {
      final id = path.split('/').last;
      deletedIds.add(id);
      return _toResponseBody(
        const _AdapterResponse(payload: <String, dynamic>{}),
      );
    }

    return _toResponseBody(
      const _AdapterResponse(statusCode: 404, payload: <String, dynamic>{}),
    );
  }

  ResponseBody _toResponseBody(_AdapterResponse response) {
    return ResponseBody.fromString(
      jsonEncode(response.payload),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  const _AdapterResponse({this.statusCode = 200, required this.payload});

  final int statusCode;
  final Object payload;
}
