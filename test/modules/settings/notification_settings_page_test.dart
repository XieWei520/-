import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/notification_channel_settings_bridge.dart';
import 'package:wukong_im_app/modules/settings/notification_settings_page.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  setUp(() {
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets(
    'notification settings route message and rtc entries through distinct bridge targets',
    (tester) async {
      final bridge = _RecordingNotificationBridge();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: const <Locale>[
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NotificationSettingsPage(notificationBridge: bridge),
        ),
      );
      await tester.pumpAndSettle();

      final messageSettingsFinder = find.text(
        'Open New Message Notification Settings',
      );
      await tester.scrollUntilVisible(
        messageSettingsFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(messageSettingsFinder);
      await tester.pumpAndSettle();
      final rtcSettingsFinder = find.text(
        'Open Call Invitation Notification Settings',
      );
      await tester.scrollUntilVisible(
        rtcSettingsFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(rtcSettingsFinder);
      await tester.pumpAndSettle();

      expect(bridge.openedChannels, <NotificationSettingsChannel>[
        NotificationSettingsChannel.message,
        NotificationSettingsChannel.rtc,
      ]);
    },
  );

  testWidgets('notification settings show Chinese copy under zh locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const NotificationSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u65b0\u6d88\u606f\u901a\u77e5'), findsOneWidget);
    expect(find.text('\u65b0\u6d88\u606f\u901a\u77e5\u603b\u5f00\u5173'), findsOneWidget);
    expect(find.text('\u6253\u5f00\u65b0\u6d88\u606f\u901a\u77e5\u8bbe\u7f6e'), findsOneWidget);
  });

  testWidgets('notification settings render keep-alive extension widgets', (
    tester,
  ) async {
    final endpointManager = EndpointManager.getInstance();
    endpointManager.clear();
    endpointManager.setMethod(
      'show_keep_alive_item',
      '',
      0,
      SimpleFunctionHandler(
        ([dynamic _]) => const ListTile(title: Text('Keep Alive')),
      ),
    );

    addTearDown(endpointManager.clear);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: NotificationSettingsPage(
          notificationBridge: _RecordingNotificationBridge(),
          endpointManager: endpointManager,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final keepAliveFinder = find.text('Keep Alive');
    await tester.scrollUntilVisible(
      keepAliveFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Keep Alive'), findsOneWidget);
  });

  testWidgets(
    'notification settings render in settings-family shell and keep route entries',
    (tester) async {
      final bridge = _RecordingNotificationBridge();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          supportedLocales: const <Locale>[
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NotificationSettingsPage(notificationBridge: bridge),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScaffold), findsOneWidget);
      expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
      expect(find.byType(SettingsSection), findsAtLeastNWidgets(1));
      expect(find.byType(WKSubPageScaffold), findsNothing);

      final messageSettingsFinder = find.text(
        'Open New Message Notification Settings',
      );
      await tester.scrollUntilVisible(
        messageSettingsFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(messageSettingsFinder);
      await tester.pumpAndSettle();
      final rtcSettingsFinder = find.text(
        'Open Call Invitation Notification Settings',
      );
      await tester.scrollUntilVisible(
        rtcSettingsFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(rtcSettingsFinder);
      await tester.pumpAndSettle();

      expect(bridge.openedChannels, <NotificationSettingsChannel>[
        NotificationSettingsChannel.message,
        NotificationSettingsChannel.rtc,
      ]);
    },
  );
}

class _RecordingNotificationBridge
    implements NotificationChannelSettingsBridge {
  final List<NotificationSettingsChannel> openedChannels =
      <NotificationSettingsChannel>[];

  @override
  Future<bool> openChannelSettings(NotificationSettingsChannel channel) async {
    openedChannels.add(channel);
    return true;
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
