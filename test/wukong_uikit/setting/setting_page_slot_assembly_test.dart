import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/account_security_page.dart';
import 'package:wukong_im_app/modules/settings/message_backup/backup_restore_message_page.dart';
import 'package:wukong_im_app/modules/settings/notification_settings_page.dart';
import 'package:wukong_im_app/modules/settings/privacy_settings_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/settings_slots.dart';
import 'package:wukong_im_app/wukong_uikit/setting/language_settings_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_slot_assembly.dart';

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

  test('settings installer groups cells into stable ordered sections', () {
    final registry = SlotRegistry();
    var openedNotificationSettings = false;
    var openedPrivacySettings = false;
    var openedAccountSecurity = false;
    var clearedAllChatHistory = false;
    var openedMessageBackup = false;
    var openedMessageRecovery = false;
    final sections = resolveSettingsSections(
      registry,
      SettingsSlotContext(
        darkModeStatus: '\u8ddf\u968f\u7cfb\u7edf',
        imageCacheSize: '2 MB',
        hasNewVersion: true,
        openThemeSettings: () {},
        openLanguageSettings: () {},
        openFontSizeSettings: () {},
        openChatBackgroundSettings: () {},
        openNotificationSettings: () {
          openedNotificationSettings = true;
        },
        openPrivacySettings: () {
          openedPrivacySettings = true;
        },
        openAccountSecurity: () {
          openedAccountSecurity = true;
        },
        clearImageCache: () {},
        clearAllChatHistory: () {
          clearedAllChatHistory = true;
        },
        openMessageBackup: () {
          openedMessageBackup = true;
        },
        openMessageRecovery: () {
          openedMessageRecovery = true;
        },
        openAppModules: () {},
        openThirdPartySharing: () {},
        openErrorLogs: () {},
        openAbout: () {},
        logout: () {},
      ),
    );

    expect(sections.map((section) => section.id).toList(), <String>[
      'settings.appearance',
      'settings.cache',
      'settings.message_backup',
      'settings.modules',
      'settings.about',
      'settings.account',
    ]);

    final appearanceSection = sections.firstWhere(
      (section) => section.id == 'settings.appearance',
    );
    final cacheSection = sections.firstWhere(
      (section) => section.id == 'settings.cache',
    );
    final messageBackupSection = sections.firstWhere(
      (section) => section.id == 'settings.message_backup',
    );

    expect(appearanceSection.cells.map((cell) => cell.id).toList(), <String>[
      'settings.dark_mode',
      'settings.language',
      'settings.font_size',
      'settings.chat_background',
    ]);
    expect(cacheSection.cells.map((cell) => cell.id).toList(), <String>[
      'settings.clear_cache',
      'settings.clear_all_chat_history',
    ]);
    expect(messageBackupSection.cells.map((cell) => cell.id).toList(), <String>[
      'settings.message_backup',
      'settings.message_recovery',
    ]);

    cacheSection.cells[1].onTap();
    messageBackupSection.cells[0].onTap();
    messageBackupSection.cells[1].onTap();

    expect(openedNotificationSettings, isFalse);
    expect(openedPrivacySettings, isFalse);
    expect(openedAccountSecurity, isFalse);
    expect(clearedAllChatHistory, isTrue);
    expect(openedMessageBackup, isTrue);
    expect(openedMessageRecovery, isTrue);
    expect(sections.last.cells.single.style, SettingsCellStyle.dangerCentered);
  });

  test('settings spacing aligns with Android grouping', () {
    expect(
      shouldInsertSettingsGap(
        sectionId: 'settings.appearance',
        cellId: 'settings.dark_mode',
      ),
      isTrue,
    );
    expect(
      shouldInsertSettingsGap(
        sectionId: 'settings.appearance',
        cellId: 'settings.language',
      ),
      isFalse,
    );
    expect(
      shouldInsertSettingsGap(
        sectionId: 'settings.modules',
        cellId: 'settings.app_modules',
      ),
      isTrue,
    );
    expect(
      shouldInsertSettingsGap(
        sectionId: 'settings.modules',
        cellId: 'settings.error_logs',
      ),
      isFalse,
    );
  });

  testWidgets('about trailing respects slot-provided badge visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildSettingsAboutTrailing(showNewVersionBadge: false),
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0);
  });

  testWidgets(
    'setting page keeps language and backup routes while removing duplicated notification privacy and account rows',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
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
            navigatorKey: navigatorKey,
            home: const SettingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\u65b0\u6d88\u606f\u901a\u77e5'), findsNothing);
      expect(find.text('\u9690\u79c1'), findsNothing);
      expect(find.text('\u8d26\u53f7\u4e0e\u5b89\u5168'), findsNothing);

      await tester.tap(find.text('\u8bed\u8a00'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSettingsPage), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsPage), findsNothing);
      expect(find.byType(PrivacySettingsPage), findsNothing);
      expect(find.byType(AccountSecurityPage), findsNothing);

      final messageBackupFinder = find.text('\u6d88\u606f\u5907\u4efd');
      await tester.scrollUntilVisible(
        messageBackupFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(messageBackupFinder);
      await tester.pumpAndSettle();
      expect(find.byType(BackupRestoreMessagePage), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final messageRecoveryFinder = find.text('\u6d88\u606f\u6062\u590d');
      await tester.scrollUntilVisible(
        messageRecoveryFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(messageRecoveryFinder);
      await tester.pumpAndSettle();
      expect(find.byType(BackupRestoreMessagePage), findsOneWidget);
    },
  );
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
