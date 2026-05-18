import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/favorites/favorites_page.dart';
import 'package:wukong_im_app/modules/customer_service/customer_service_badge.dart';
import 'package:wukong_im_app/modules/settings/account_security_page.dart';
import 'package:wukong_im_app/modules/settings/notification_settings_page.dart';
import 'package:wukong_im_app/modules/settings/privacy_settings_page.dart';
import 'package:wukong_im_app/modules/user/user_page.dart';
import 'package:wukong_im_app/modules/vip/vip_badge.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/providers/slot_registry_provider.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_login/pc_login_page.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/personal_info_menu.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/my_info_page.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_qr_page.dart';

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

  test('buildAndroidUserMenuEntries respects slot ordering', () {
    final registry = SlotRegistry();
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_custom',
        priority: 999,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_custom',
          imgResource: 'custom',
          text: 'Custom',
        ),
      ),
    );

    final entries = buildAndroidUserMenuEntries(
      hasNewVersion: true,
      showWebLoginEntry: true,
      onOpenSettings: () {},
      onOpenNotifications: () {},
      onOpenFavorites: () {},
      onOpenPrivacySettings: () {},
      onOpenAccountSecurity: () {},
      onOpenWebLogin: () {},
      registry: registry,
    );

    expect(entries.first.sid, 'personal_center_custom');
    expect(entries.map((entry) => entry.sid).toList(), <String>[
      'personal_center_custom',
      'personal_center_currency',
      'personal_center_new_msg_notice',
      'personal_center_favorites',
      'personal_center_privacy',
      'personal_center_account_security',
      'personal_center_web_login',
    ]);
    final generalEntry = entries.firstWhere(
      (entry) => entry.sid == 'personal_center_currency',
    );
    expect(generalEntry.showNewVersionBadge, isTrue);
  });

  test(
    'buildAndroidUserMenuEntries applies stable group gaps for user-center rows',
    () {
      final entries = buildAndroidUserMenuEntries(
        hasNewVersion: false,
        showWebLoginEntry: false,
        onOpenSettings: () {},
        onOpenNotifications: () {},
        onOpenFavorites: () {},
        onOpenPrivacySettings: () {},
        onOpenAccountSecurity: () {},
        onOpenWebLogin: () {},
      );

      expect(entries.map((entry) => entry.sid).toList(), <String>[
        'personal_center_currency',
        'personal_center_new_msg_notice',
        'personal_center_favorites',
        'personal_center_privacy',
        'personal_center_account_security',
      ]);
      expect(entries.first.showBottomGap, isFalse);
      expect(entries[1].showBottomGap, isTrue);
      expect(entries[2].showBottomGap, isTrue);
      expect(entries.last.showBottomGap, isTrue);
    },
  );

  test(
    'buildAndroidUserMenuEntries routes rows to matching open callbacks',
    () {
      var settingsTapCount = 0;
      var notificationsTapCount = 0;
      var favoritesTapCount = 0;
      var privacyTapCount = 0;
      var accountSecurityTapCount = 0;
      var webLoginTapCount = 0;

      final entries = buildAndroidUserMenuEntries(
        hasNewVersion: false,
        showWebLoginEntry: true,
        onOpenSettings: () => settingsTapCount++,
        onOpenNotifications: () => notificationsTapCount++,
        onOpenFavorites: () => favoritesTapCount++,
        onOpenPrivacySettings: () => privacyTapCount++,
        onOpenAccountSecurity: () => accountSecurityTapCount++,
        onOpenWebLogin: () => webLoginTapCount++,
      );

      const expectedRows = <String>[
        'personal_center_currency',
        'personal_center_new_msg_notice',
        'personal_center_favorites',
        'personal_center_privacy',
        'personal_center_account_security',
        'personal_center_web_login',
      ];
      for (final sid in expectedRows) {
        final entry = entries.firstWhere((item) => item.sid == sid);
        entry.onTap();
      }

      expect(settingsTapCount, 1);
      expect(notificationsTapCount, 1);
      expect(favoritesTapCount, 1);
      expect(privacyTapCount, 1);
      expect(accountSecurityTapCount, 1);
      expect(webLoginTapCount, 1);
    },
  );

  test(
    'buildAndroidUserMenuEntries keeps version badge only on general row',
    () {
      final entries = buildAndroidUserMenuEntries(
        hasNewVersion: true,
        showWebLoginEntry: true,
        onOpenSettings: () {},
        onOpenNotifications: () {},
        onOpenFavorites: () {},
        onOpenPrivacySettings: () {},
        onOpenAccountSecurity: () {},
        onOpenWebLogin: () {},
      );

      final generalEntry = entries.firstWhere(
        (entry) => entry.sid == 'personal_center_currency',
      );
      expect(generalEntry.showNewVersionBadge, isTrue);
      for (final entry in entries.where(
        (item) => item.sid != 'personal_center_currency',
      )) {
        expect(entry.showNewVersionBadge, isFalse);
      }
    },
  );

  testWidgets(
    'UserPage renders ordered production rows, applies grouping gaps, and navigates to authoritative pages',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const expectedSids = <String>[
        'personal_center_currency',
        'personal_center_new_msg_notice',
        'personal_center_favorites',
        'personal_center_privacy',
        'personal_center_account_security',
        'personal_center_web_login',
      ];
      const expectedTitles = <String>[
        '\u901a\u7528',
        '\u65b0\u6d88\u606f\u901a\u77e5',
        '\u6536\u85cf',
        '\u9690\u79c1',
        '\u8d26\u53f7\u4e0e\u5b89\u5168',
        '\u7535\u8111\u7aef\u767b\u5f55',
      ];
      final navigatorKey = GlobalKey<NavigatorState>();
      final slotRegistry = SlotRegistry();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPageVersionLoaderProvider.overrideWithValue(() async => null),
            slotRegistryProvider.overrideWithValue(slotRegistry),
          ],
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
            home: const UserPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('我的'), findsOneWidget);

      final menuItemElements = find
          .byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('user_menu_');
          })
          .evaluate()
          .toList(growable: false);
      final renderedSids = menuItemElements
          .map(
            (element) => (element.widget.key! as ValueKey<String>).value
                .substring('user_menu_'.length),
          )
          .toList(growable: false);
      expect(renderedSids, expectedSids);

      final renderedTitles = <String>[
        for (final sid in expectedSids) _readUserMenuTitle(tester, sid),
      ];
      expect(renderedTitles, expectedTitles);

      expect(_hasGroupedGapAfter(tester, 'personal_center_currency'), isFalse);
      expect(
        _hasGroupedGapAfter(tester, 'personal_center_new_msg_notice'),
        isTrue,
      );
      expect(_hasGroupedGapAfter(tester, 'personal_center_favorites'), isTrue);
      expect(_hasGroupedGapAfter(tester, 'personal_center_privacy'), isFalse);
      expect(
        _hasGroupedGapAfter(tester, 'personal_center_account_security'),
        isFalse,
      );
      expect(_hasGroupedGapAfter(tester, 'personal_center_web_login'), isTrue);

      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_currency',
        pageFinder: find.byType(SettingPage),
        navigatorKey: navigatorKey,
      );
      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_new_msg_notice',
        pageFinder: find.byType(NotificationSettingsPage),
        navigatorKey: navigatorKey,
      );
      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_favorites',
        pageFinder: find.byType(FavoritesPage),
        navigatorKey: navigatorKey,
      );
      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_privacy',
        pageFinder: find.byType(PrivacySettingsPage),
        navigatorKey: navigatorKey,
      );
      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_account_security',
        pageFinder: find.byType(AccountSecurityPage),
        navigatorKey: navigatorKey,
      );
      await _tapMenuAndExpectPage(
        tester,
        sid: 'personal_center_web_login',
        pageFinder: find.byType(PCLoginPage),
        navigatorKey: navigatorKey,
      );
    },
  );

  testWidgets(
    'UserPage skips version reload after a pushed page returns with cleared auth state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      late _TestAuthNotifier authNotifier;
      var versionLoadCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              authNotifier = _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'tester-uid', name: 'Tester'),
                ),
              );
              return authNotifier;
            }),
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
            userPageVersionLoaderProvider.overrideWithValue(() async {
              versionLoadCount += 1;
              return null;
            }),
            slotRegistryProvider.overrideWithValue(SlotRegistry()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const UserPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(versionLoadCount, 1);

      final settingsRowFinder = find.byKey(
        const ValueKey<String>('user_menu_personal_center_currency'),
      );
      final tapTargetFinder = find.descendant(
        of: settingsRowFinder,
        matching: find.byType(InkWell),
      );
      expect(tapTargetFinder, findsOneWidget);

      final tapTarget = tester.widget<InkWell>(tapTargetFinder);
      expect(tapTarget.onTap, isNotNull);
      tapTarget.onTap!.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SettingPage), findsOneWidget);

      authNotifier.setAuthState(
        AuthState(isLoggedIn: false, isRestoringSession: false),
      );
      await tester.pump();

      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(versionLoadCount, 1);
    },
  );

  test('buildUserMenuLeadingIcon renders a stable fallback shell', () {
    expect(
      buildUserMenuLeadingIcon(sid: 'unknown', iconAsset: ''),
      isA<Container>(),
    );
  });

  testWidgets('UserPage separates avatar and qr entry taps', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return _TestAuthNotifier(
              ref,
              initialState: AuthState(
                isLoggedIn: true,
                isRestoringSession: false,
                userInfo: UserInfo(
                  uid: 'tester-uid',
                  name: 'Tester',
                  avatar: 'https://example.com/avatar.png',
                ),
              ),
            );
          }),
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
          userPageVersionLoaderProvider.overrideWithValue(() async => null),
          slotRegistryProvider.overrideWithValue(SlotRegistry()),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: const UserPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey<String>('user_profile_avatar')));
    await tester.pumpAndSettle();
    expect(find.byType(MyInfoPage), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('user_profile_qr')));
    await tester.pumpAndSettle();
    expect(find.byType(UserQrPage), findsOneWidget);
  });

  testWidgets('UserPage shows vip badge and management entry for vip users', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return _TestAuthNotifier(
              ref,
              initialState: AuthState(
                isLoggedIn: true,
                isRestoringSession: false,
                userInfo: UserInfo(
                  uid: 'vip_uid',
                  name: 'Vip User',
                  vipLevel: 1,
                ),
              ),
            );
          }),
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
          userPageVersionLoaderProvider.overrideWithValue(() async => null),
          slotRegistryProvider.overrideWithValue(SlotRegistry()),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: const UserPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VipBadge), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('user_menu_vip_management')),
      findsOneWidget,
    );
    expect(find.text('管理系统'), findsOneWidget);

    await _tapMenuAndExpectPage(
      tester,
      sid: 'vip_management',
      pageFinder: find.byType(VipManagementPage),
      navigatorKey: navigatorKey,
      afterOpen: () {
        expect(
          find.byKey(const ValueKey('management-center-feishu')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('management-center-dingtalk')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('management-center-xiaoe')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets('UserPage shows customer service badge in profile header', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) {
            return _TestAuthNotifier(
              ref,
              initialState: AuthState(
                isLoggedIn: true,
                isRestoringSession: false,
                userInfo: UserInfo(
                  uid: 'cs_self',
                  name: 'Support',
                  category: 'customerService',
                ),
              ),
            );
          }),
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
          userPageVersionLoaderProvider.overrideWithValue(() async => null),
          slotRegistryProvider.overrideWithValue(SlotRegistry()),
        ],
        child: const MaterialApp(home: UserPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Support'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('user-profile-customer-service-badge')),
      findsOneWidget,
    );
    expect(find.byType(CustomerServiceBadge), findsOneWidget);
  });

  testWidgets(
    'UserPage profile header truncates long names and badges without narrow-screen overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longName =
          'Very Long Merchant Display Name That Should Truncate Safely';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              return _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(
                    uid: 'dense_header',
                    name: longName,
                    category: 'customerService',
                    vipLevel: 1,
                  ),
                ),
              );
            }),
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
            userPageVersionLoaderProvider.overrideWithValue(() async => null),
            slotRegistryProvider.overrideWithValue(SlotRegistry()),
          ],
          child: const MaterialApp(home: UserPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
      expect(find.byType(VipBadge), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-customer-service-badge'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UserPage profile header wraps name and badges on extra narrow screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(240, 640);
      tester.view.padding = const FakeViewPadding(top: 44);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      const longName =
          'Extremely Long Customer Service Merchant Name With Multiple Labels';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              return _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(
                    uid: 'extra_narrow_header',
                    name: longName,
                    category: 'customerService',
                    vipLevel: 1,
                  ),
                ),
              );
            }),
            authCurrentUserLoaderProvider.overrideWithValue(() async => null),
            authDraftSyncProvider.overrideWithValue(() async {}),
            userPageVersionLoaderProvider.overrideWithValue(() async => null),
            slotRegistryProvider.overrideWithValue(SlotRegistry()),
          ],
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              );
            },
            home: const UserPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
      expect(find.byType(VipBadge), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-customer-service-badge'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'WKSettingsSwitchCell uses Android-style compact switch control',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WKSettingsSwitchCell(title: '消息免打扰', value: true),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('wk_android_switch')), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    },
  );

  testWidgets('user page can render inside warm Web frame', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UserPage(forceWebFrameForTesting: true)),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('user-web-frame')),
      findsOneWidget,
    );
  });

  testWidgets('user web profile header uses approved warm adaptive card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UserPage(forceWebFrameForTesting: true)),
      ),
    );
    await tester.pump();

    final cardFinder = find.byKey(const ValueKey<String>('user-profile-card'));
    expect(cardFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('user-profile-accent')),
      findsOneWidget,
    );

    final card = tester.widget<Container>(cardFinder);
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, WKWebColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(WKWebRadius.panel));
    expect((decoration.border as Border).top.color, WKWebColors.borderWarm);
  });

  testWidgets(
    'user page aligns profile card and menu groups to one shape system',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: UserPage())),
      );
      await tester.pump();

      final profileFinder = find.byKey(
        const ValueKey<String>('user-profile-card'),
      );
      final firstGroupFinder = find.byKey(
        const ValueKey<String>('user-menu-group-personal_center_currency'),
      );
      final firstRowFinder = find.byKey(
        const ValueKey<String>('user_menu_personal_center_currency'),
      );

      final profileDecoration =
          tester.widget<Container>(profileFinder).decoration as BoxDecoration;
      expect(
        profileDecoration.borderRadius,
        BorderRadius.circular(WKWebRadius.panel),
      );

      final groupMaterial = tester.widget<Material>(firstGroupFinder);
      final groupShape = groupMaterial.shape as RoundedRectangleBorder?;
      expect(
        groupShape?.borderRadius,
        BorderRadius.circular(WKWebRadius.panel),
      );

      expect(
        tester.getSize(firstRowFinder).height,
        LiquidGlassSizes.listRowHeight,
      );
      expect(
        tester.getTopLeft(firstGroupFinder).dx,
        tester.getTopLeft(profileFinder).dx,
      );
      expect(
        tester.getSize(firstGroupFinder).width,
        tester.getSize(profileFinder).width,
      );
    },
  );
}

String _readUserMenuTitle(WidgetTester tester, String sid) {
  final rowFinder = find.byKey(ValueKey<String>('user_menu_$sid'));
  final textFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(Text),
  );
  expect(textFinder, findsOneWidget);
  return tester.widget<Text>(textFinder).data ?? '';
}

bool _hasGroupedGapAfter(WidgetTester tester, String sid) {
  final rowFinder = find.byKey(ValueKey<String>('user_menu_$sid'));
  final nextRowFinder = _nextUserMenuRowFinder(sid);
  if (nextRowFinder == null || nextRowFinder.evaluate().isEmpty) {
    return true;
  }
  final rowBottom = tester.getBottomLeft(rowFinder).dy;
  final nextRowTop = tester.getTopLeft(nextRowFinder).dy;
  return nextRowTop - rowBottom >= LiquidGlassSizes.sectionGap;
}

Finder? _nextUserMenuRowFinder(String sid) {
  const order = <String>[
    'personal_center_currency',
    'personal_center_new_msg_notice',
    'personal_center_favorites',
    'personal_center_privacy',
    'personal_center_account_security',
    'personal_center_web_login',
    'vip_management',
  ];
  final index = order.indexOf(sid);
  if (index < 0 || index == order.length - 1) {
    return null;
  }
  return find.byKey(ValueKey<String>('user_menu_${order[index + 1]}'));
}

Future<void> _tapMenuAndExpectPage(
  WidgetTester tester, {
  required String sid,
  required Finder pageFinder,
  required GlobalKey<NavigatorState> navigatorKey,
  VoidCallback? afterOpen,
}) async {
  final rowFinder = find.byKey(ValueKey<String>('user_menu_$sid'));
  final tapTargetFinder = find.descendant(
    of: rowFinder,
    matching: find.byType(InkWell),
  );
  expect(tapTargetFinder, findsOneWidget);

  await tester.ensureVisible(rowFinder);
  final tapTarget = tester.widget<InkWell>(tapTargetFinder);
  expect(tapTarget.onTap, isNotNull);
  tapTarget.onTap!.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  expect(pageFinder, findsOneWidget);
  afterOpen?.call();

  navigatorKey.currentState!.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }

  void setAuthState(AuthState nextState) {
    state = nextState;
  }
}
