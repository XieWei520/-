import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  Future<void> pumpChatPage(
    WidgetTester tester, {
    required String channelId,
    required int channelType,
    required _ChatFlameRoutingAdapter adapter,
  }) async {
    await StorageUtils.setUid('u_self');
    ApiClient.instance.dio.httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
        ],
        child: MaterialApp(
          home: ChatPage(
            channelId: channelId,
            channelType: channelType,
            channelName: 'Flame Parity',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'personal flame button opens Android-aligned panel and updates user setting endpoint',
    (tester) async {
      final adapter = _ChatFlameRoutingAdapter.personal(
        channelId: 'u_flame_personal_phase6',
        userPayload: const <String, dynamic>{
          'uid': 'u_flame_personal_phase6',
          'name': 'Alice',
          'flame': 1,
          'flame_second': 20,
        },
      );

      await pumpChatPage(
        tester,
        channelId: 'u_flame_personal_phase6',
        channelType: WKChannelType.personal,
        adapter: adapter,
      );

      expect(
        find.byKey(const ValueKey<String>('chat-flame-toggle-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-flame-toggle-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('chat-flame-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-flame-enabled-switch')),
        findsOneWidget,
      );
      expect(find.textContaining('20秒'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('chat-flame-enabled-switch')),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requestCount(
          'PUT',
          '${ApiConfig.userInfo}/u_flame_personal_phase6/setting',
        ),
        1,
      );
      expect(adapter.lastRequestOptions?.data, containsPair('flame', 0));
    },
  );

  testWidgets('group flame panel updates ttl through group setting endpoint', (
    tester,
  ) async {
    final adapter = _ChatFlameRoutingAdapter.group(
      channelId: 'g_flame_group_phase6',
      groupPayload: const <String, dynamic>{
        'group_no': 'g_flame_group_phase6',
        'name': 'Flame Group',
        'save': 1,
        'flame': 1,
        'flame_second': 60,
      },
    );

    await pumpChatPage(
      tester,
      channelId: 'g_flame_group_phase6',
      channelType: WKChannelType.group,
      adapter: adapter,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('chat-flame-toggle-button')),
    );
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('chat-flame-duration-slider')),
    );
    slider.onChanged?.call(6);
    await tester.pump();
    slider.onChangeEnd?.call(6);
    await tester.pumpAndSettle();

    expect(
      adapter.requestCount(
        'PUT',
        '${ApiConfig.groups}/g_flame_group_phase6${ApiConfig.groupSetting}',
      ),
      1,
    );
    expect(adapter.lastRequestOptions?.data, containsPair('flame_second', 180));
    expect(find.textContaining('3分钟'), findsOneWidget);
  });
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}

class _ChatFlameRoutingAdapter implements HttpClientAdapter {
  _ChatFlameRoutingAdapter._({
    required this.channelId,
    required this.channelType,
    this.userPayload,
    this.groupPayload,
  });

  factory _ChatFlameRoutingAdapter.personal({
    required String channelId,
    required Map<String, dynamic> userPayload,
  }) {
    return _ChatFlameRoutingAdapter._(
      channelId: channelId,
      channelType: WKChannelType.personal,
      userPayload: userPayload,
    );
  }

  factory _ChatFlameRoutingAdapter.group({
    required String channelId,
    required Map<String, dynamic> groupPayload,
  }) {
    return _ChatFlameRoutingAdapter._(
      channelId: channelId,
      channelType: WKChannelType.group,
      groupPayload: groupPayload,
    );
  }

  final String channelId;
  final int channelType;
  final Map<String, dynamic>? userPayload;
  final Map<String, dynamic>? groupPayload;
  final List<RequestOptions> requests = <RequestOptions>[];
  RequestOptions? lastRequestOptions;

  int requestCount(String method, String path) {
    final normalizedMethod = method.toUpperCase();
    return requests.where((request) {
      return request.method.toUpperCase() == normalizedMethod &&
          request.uri.path == path;
    }).length;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    lastRequestOptions = options;
    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (channelType == WKChannelType.personal &&
        method == 'GET' &&
        path == '${ApiConfig.userInfo}/$channelId') {
      return _jsonResponse(userPayload ?? const <String, dynamic>{});
    }
    if (channelType == WKChannelType.personal &&
        method == 'PUT' &&
        path == '${ApiConfig.userInfo}/$channelId/setting') {
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (channelType == WKChannelType.group &&
        method == 'GET' &&
        path == '${ApiConfig.groups}/$channelId') {
      return _jsonResponse(<String, dynamic>{
        'code': 0,
        'data': groupPayload ?? const <String, dynamic>{},
      });
    }
    if (channelType == WKChannelType.group &&
        method == 'PUT' &&
        path == '${ApiConfig.groups}/$channelId${ApiConfig.groupSetting}') {
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }

    return _jsonResponse(const <String, dynamic>{'code': 0});
  }

  ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
