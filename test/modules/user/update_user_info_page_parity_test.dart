import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/user/update_user_info_page.dart';
import 'package:wukongimfluttersdk/common/options.dart' as wk;
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testUid =
      'update_user_info_page_test_${DateTime.now().microsecondsSinceEpoch}';
  late HttpClientAdapter originalAdapter;

  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: child);
  }

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
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  tearDownAll(() {
    WKDBHelper.shared.close();
  });

  testWidgets(
    'update user info page matches Android name editor shell and hides complete until changed',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const UpdateUserInfoPage(
            type: UserInfoUpdateType.name,
            initialValue: 'Alice',
          ),
        ),
      );

      expect(find.byType(WKSubPageScaffold), findsOneWidget);
      expect(find.byKey(const ValueKey('update_user_info_input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('update_user_info_complete_action')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('update_user_info_input')),
        'Alice 2',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('update_user_info_complete_action')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'update user info page matches Android 10-unit input limit for nickname',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const UpdateUserInfoPage(
            type: UserInfoUpdateType.name,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('update_user_info_input')),
        '12345678901',
      );
      await tester.pump();

      final editableText = tester.widget<EditableText>(find.byType(EditableText));
      expect(editableText.controller.text, '1234567890');
    },
  );

  testWidgets(
    'update user info page matches Android short number editor and saves sanitized result',
    (tester) async {
      String? savedValue;

      await tester.pumpWidget(
        wrapWithApp(
          UpdateUserInfoPage(
            type: UserInfoUpdateType.shortNo,
            initialValue: '1001',
            onSave: (value) async {
              savedValue = value;
            },
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('update_user_info_input')),
        '1001\n23',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('update_user_info_complete_action')),
        findsOneWidget,
      );
      expect(find.text('100123'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('update_user_info_complete_action')),
      );
      await tester.pumpAndSettle();

      expect(savedValue, '100123');
    },
  );

  testWidgets(
    'update user info page saves nickname through API and writes it back to current personal channel',
    (tester) async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final seededChannel = WKChannel(testUid, WKChannelType.personal)
        ..channelName = 'Old Name';
      WKIM.shared.channelManager.addOrUpdateChannel(seededChannel);

      await tester.pumpWidget(
        wrapWithApp(
          const UpdateUserInfoPage(
            type: UserInfoUpdateType.name,
            initialValue: 'Old Name',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('update_user_info_input')),
        'New Name',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('update_user_info_complete_action')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));

      final updatedChannel = await WKIM.shared.channelManager.getChannel(
        testUid,
        WKChannelType.personal,
      );

      expect(adapter.lastRequestOptions?.method, 'PUT');
      expect(adapter.lastRequestOptions?.path, '/v1/user/current');
      expect(adapter.lastRequestOptions?.data, containsPair('name', 'New Name'));
      expect(updatedChannel, isNotNull);
      expect(updatedChannel!.channelName, 'New Name');
    },
  );
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) : _payload = payload;

  final Map<String, dynamic> _payload;
  static const int statusCode = 200;
  RequestOptions? lastRequestOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    final bytes = utf8.encode(jsonEncode(_payload));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
