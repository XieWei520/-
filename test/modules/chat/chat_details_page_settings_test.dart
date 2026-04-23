import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/chat/chat_details_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/setting/chat_background_settings_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'chat_details_page_settings_${DateTime.now().microsecondsSinceEpoch}';
  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await StorageUtils.setUid(testUid);
    WKIM.shared.options = wk.Options.newDefault(testUid, 'token');
    await WKDBHelper.shared.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    await StorageUtils.setUid(testUid);
    await _clearImTables();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  tearDownAll(() {
    WKDBHelper.shared.close();
  });

  testWidgets(
    'personal chat details renders chat password switch and auto-delete state from server values',
    (tester) async {
      final adapter = _ChatDetailsRoutingAdapter(
        channelId: 'u_target',
        initialChatPwdOn: 1,
        initialAutoDeleteSeconds: 86400,
      );

      await _pumpChatDetailsPage(
        tester,
        adapter: adapter,
        channelId: 'u_target',
      );

      expect(
        find.byKey(const ValueKey<String>('chat_detail_chat_pwd_switch')),
        findsOneWidget,
      );
      expect(_switchValue(tester, 'chat_detail_chat_pwd_switch'), isTrue);
      expect(
        find.byKey(
          const ValueKey<String>('chat_detail_message_auto_delete_cell'),
        ),
        findsOneWidget,
      );
      expect(_cellValue(tester, 'chat_detail_message_auto_delete_cell'), '1天');
    },
  );

  testWidgets(
    'personal chat details updates chat password switch and auto-delete cache through confirmed routes',
    (tester) async {
      final adapter = _ChatDetailsRoutingAdapter(
        channelId: 'u_target',
        initialChatPwdOn: 0,
        initialAutoDeleteSeconds: 0,
      );

      await _pumpChatDetailsPage(
        tester,
        adapter: adapter,
        channelId: 'u_target',
      );

      await _tapSwitch(tester, 'chat_detail_chat_pwd_switch');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));

      expect(adapter.requestCount('PUT', adapter.userSettingPath), 1);
      expect(
        adapter.lastUserSettingRequestData,
        containsPair('chat_pwd_on', 1),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('chat_detail_message_auto_delete_cell'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('channel_auto_delete_option_86400')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));

      expect(adapter.requestCount('POST', adapter.autoDeletePath), 1);
      expect(
        adapter.lastAutoDeleteRequestData,
        containsPair('msg_auto_delete', 86400),
      );

      final channel = await WKIM.shared.channelManager.getChannel(
        'u_target',
        WKChannelType.personal,
      );
      expect(channel, isNotNull);
      expect(channel!.remoteExtraMap['chat_pwd_on'], 1);
      expect(channel.remoteExtraMap['msg_auto_delete'], 86400);
      expect(channel.localExtra['chat_pwd_on'], 1);
      expect(channel.localExtra['msg_auto_delete'], 86400);
    },
  );

  testWidgets(
    'personal chat details opens the channel-scoped chat background settings page',
    (tester) async {
      final adapter = _ChatDetailsRoutingAdapter(
        channelId: 'u_target',
        initialChatPwdOn: 0,
        initialAutoDeleteSeconds: 0,
      );

      await _pumpChatDetailsPage(
        tester,
        adapter: adapter,
        channelId: 'u_target',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('chat_detail_chat_background_cell')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatBackgroundSettingsPage), findsOneWidget);
    },
  );
}

Future<void> _pumpChatDetailsPage(
  WidgetTester tester, {
  required _ChatDetailsRoutingAdapter adapter,
  required String channelId,
}) async {
  ApiClient.instance.dio.httpClientAdapter = adapter;

  final seededChannel = WKChannel(channelId, WKChannelType.personal)
    ..channelName = 'Seeded User'
    ..remoteExtraMap = <String, dynamic>{}
    ..localExtra = <String, dynamic>{};
  WKIM.shared.channelManager.addOrUpdateChannel(seededChannel);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
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
        home: ChatDetailsPage(
          channelId: channelId,
          channelType: WKChannelType.personal,
          channelName: 'Seeded User',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 11));
}

Future<void> _tapSwitch(WidgetTester tester, String key) async {
  final container = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(container);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: container,
      matching: find.byKey(const ValueKey('wk_android_switch')),
    ),
  );
}

bool _switchValue(WidgetTester tester, String key) {
  return tester
      .widget<WKSettingsSwitchCell>(find.byKey(ValueKey<String>(key)))
      .value;
}

String? _cellValue(WidgetTester tester, String key) {
  return tester.widget<WKSettingsCell>(find.byKey(ValueKey<String>(key))).value;
}

Future<void> _clearImTables() async {
  final db = WKDBHelper.shared.getDB();
  if (db == null) {
    return;
  }

  await db.delete(WKDBConst.tableMessage);
  await db.delete(WKDBConst.tableMessageExtra);
  await db.delete(WKDBConst.tableConversation);
  await db.delete(WKDBConst.tableConversationExtra);
  await db.delete(WKDBConst.tableChannel);
}

class _ChatDetailsRoutingAdapter implements HttpClientAdapter {
  _ChatDetailsRoutingAdapter({
    required this.channelId,
    required int initialChatPwdOn,
    required int initialAutoDeleteSeconds,
  }) : _chatPwdOn = initialChatPwdOn,
       _autoDeleteSeconds = initialAutoDeleteSeconds;

  final String channelId;
  int _chatPwdOn;
  int _autoDeleteSeconds;
  final List<RequestOptions> requests = <RequestOptions>[];

  String get userPath => '${ApiConfig.userInfo}/$channelId';
  String get channelPath => '/v1/channels/$channelId/1';
  String get userSettingPath => '$userPath/setting';
  String get autoDeletePath => '$channelPath/message/autodelete';

  Map<String, dynamic>? lastUserSettingRequestData;
  Map<String, dynamic>? lastAutoDeleteRequestData;

  int requestCount(String method, String path) {
    final expectedMethod = method.toUpperCase();
    return requests.where((request) {
      return request.method.toUpperCase() == expectedMethod &&
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
    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'GET' && path == userPath) {
      return _jsonResponse(<String, dynamic>{
        'uid': channelId,
        'name': 'Target User',
        'chat_pwd_on': _chatPwdOn,
      });
    }
    if (method == 'GET' && path == channelPath) {
      return _jsonResponse(<String, dynamic>{
        'channel': <String, dynamic>{
          'channel_id': channelId,
          'channel_type': 1,
        },
        'name': 'Target User',
        'extra': <String, dynamic>{'msg_auto_delete': _autoDeleteSeconds},
      });
    }
    if (method == 'PUT' && path == userSettingPath) {
      final payload = _asMap(options.data);
      _chatPwdOn = (payload['chat_pwd_on'] as num?)?.toInt() ?? _chatPwdOn;
      lastUserSettingRequestData = payload;
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == autoDeletePath) {
      final payload = _asMap(options.data);
      _autoDeleteSeconds =
          (payload['msg_auto_delete'] as num?)?.toInt() ?? _autoDeleteSeconds;
      lastAutoDeleteRequestData = payload;
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }

    return _jsonResponse(<String, dynamic>{
      'code': 404,
      'msg': 'Unhandled request: $method $path',
    }, statusCode: 404);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
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
