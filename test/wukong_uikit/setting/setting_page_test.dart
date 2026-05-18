import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/cache_clean_service.dart';
import 'package:wukong_im_app/modules/settings/settings_strings.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_page.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_preferences.dart';

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

  testWidgets('setting page defers cache loading until after first frame', (
    tester,
  ) async {
    final completer = Completer<int>();
    final cacheService = _FakeCacheCleanService(
      onGetTotalCacheBytes: () => completer.future,
    );

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
          home: SettingPage(cacheCleanService: cacheService),
        ),
      ),
    );

    expect(cacheService.getTotalCacheBytesCallCount, 0);
    expect(find.text('设置'), findsOneWidget);

    await tester.pump();
    expect(cacheService.getTotalCacheBytesCallCount, 1);

    completer.complete(2 * 1024 * 1024);
    await tester.pumpAndSettle();

    expect(find.text('2.00 MB'), findsOneWidget);
  });

  testWidgets('setting page keeps rendering when cache size loading throws', (
    tester,
  ) async {
    final cacheService = _FakeCacheCleanService(
      onGetTotalCacheBytes: () async {
        throw FileSystemException(
          'Directory listing failed',
          r'C:\Temp\WinSAT',
          const OSError('Access denied', 5),
        );
      },
    );

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
          home: SettingPage(cacheCleanService: cacheService),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('0 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('setting page renders through the settings-family shell', (
    tester,
  ) async {
    final cacheService = _FakeCacheCleanService(
      onGetTotalCacheBytes: () async => 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
          home: SettingPage(cacheCleanService: cacheService),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-liquid-shell')),
      findsOneWidget,
    );
    expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
    expect(find.byType(LiquidGlassPanel), findsAtLeastNWidgets(1));
    expect(find.byType(WKSubPageScaffold), findsNothing);
  });

  testWidgets('setting page hero uses liquid-glass panel styling only', (
    tester,
  ) async {
    final cacheService = _FakeCacheCleanService(
      onGetTotalCacheBytes: () async => 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
          home: SettingPage(cacheCleanService: cacheService),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final heroFinder = find.byType(SettingsHero).first;
    final heroContainer = tester.widget<Container>(
      find.descendant(of: heroFinder, matching: find.byType(Container)).first,
    );
    expect(heroContainer.decoration, isNull);

    final panelFinder = find.ancestor(
      of: heroFinder,
      matching: find.byType(LiquidGlassPanel),
    );
    final panel = tester.widget<LiquidGlassPanel>(panelFinder.first);
    expect(panel.shadow, LiquidGlassShadows.md);
    expect(panel.borderRadius, LiquidGlassRadii.xl);

    final title = tester.widget<Text>(find.text('General Settings'));
    expect(title.style?.color, LiquidGlassColors.text);
    expect(title.style?.color, isNot(WKColors.colorDark));
  });

  testWidgets('setting page renders tokenized dark mode switch visual', (
    tester,
  ) async {
    final cacheService = _FakeCacheCleanService(
      onGetTotalCacheBytes: () async => 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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
          home: SettingPage(cacheCleanService: cacheService),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(
      const ValueKey<String>('settings-liquid-switch-dark-mode'),
    );
    expect(switchFinder, findsOneWidget);

    final switchBox = tester.widget<DecoratedBox>(switchFinder);
    final decoration = switchBox.decoration as BoxDecoration;
    final expectedTrackColor = WKSettingPreferences.isDarkModeEnabled()
        ? LiquidGlassColors.primary.withValues(alpha: 0.16)
        : LiquidGlassColors.primary.withValues(alpha: 0.08);
    expect(decoration.color, expectedTrackColor);
    expect(decoration.borderRadius, LiquidGlassRadii.pill);
    expect(decoration.border, isA<Border>());
  });

  test('settings strings include migrated shell copy for all target pages', () {
    final zhStrings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));
    final enStrings = resolveSettingsStrings(locale: const Locale('en', 'US'));

    expect(zhStrings.generalHeroTitle, '通用设置');
    expect(zhStrings.notificationHeroTitle, '通知与提醒');
    expect(zhStrings.favoritesPageTitle, '收藏');
    expect(zhStrings.appModulesPageTitle, '应用模块');
    expect(zhStrings.favoritesRetry, '重试');
    expect(zhStrings.appModulesFallbackModuleName, '未知模块');

    expect(enStrings.generalHeroTitle, 'General Settings');
    expect(enStrings.notificationHeroTitle, 'Notifications');
    expect(enStrings.favoritesPageTitle, 'Favorites');
    expect(enStrings.appModulesPageTitle, 'App Modules');
    expect(enStrings.favoritesRetry, 'Retry');
    expect(enStrings.appModulesFallbackModuleName, 'Unknown Module');
    expect(
      enStrings.appModulesLoadFailed('network timeout'),
      'Failed to load app modules: network timeout',
    );
  });

  test('settings strings cover shared shell copy for migration targets', () {
    final zhStrings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));
    final enStrings = resolveSettingsStrings(locale: const Locale('en', 'US'));

    expect(enStrings.generalHeroTitle, 'General Settings');
    expect(
      enStrings.generalHeroSubtitle,
      'Adjust appearance, storage, messaging, modules, and account options.',
    );
    expect(enStrings.generalAppearanceSectionTitle, 'Appearance');
    expect(enStrings.generalStorageSectionTitle, 'Storage');
    expect(enStrings.generalMessagesSectionTitle, 'Messages');
    expect(enStrings.generalModulesSectionTitle, 'Modules');
    expect(enStrings.generalSupportSectionTitle, 'Support');
    expect(enStrings.generalAccountSectionTitle, 'Account');

    expect(enStrings.notificationHeroTitle, 'Notifications');
    expect(
      enStrings.notificationHeroSubtitle,
      'Control alerts, in-app behavior, and system notification access.',
    );
    expect(enStrings.notificationPreferencesSectionTitle, 'Preferences');
    expect(enStrings.notificationSystemSectionTitle, 'System Access');
    expect(enStrings.notificationHelpSectionTitle, 'Need Help?');
    expect(
      enStrings.notificationDisabledHint,
      'When disabled, the app still syncs messages but no new notification alerts are shown.',
    );
    expect(
      enStrings.notificationSystemSettingsHint,
      'If alerts are still missing, open system settings to check notification permissions.',
    );

    expect(enStrings.favoritesPageTitle, 'Favorites');
    expect(enStrings.favoritesHeroTitle, 'Favorite Messages');
    expect(
      enStrings.favoritesHeroSubtitle,
      'Quickly find, open, and manage your saved message collection.',
    );
    expect(enStrings.favoritesSearchHint, 'Search favorites');
    expect(enStrings.favoritesLoadingHint, 'Loading favorites...');
    expect(enStrings.favoritesEmptyTitle, 'No Favorites Yet');
    expect(
      enStrings.favoritesEmptySubtitle,
      'Messages you save will appear here for quick access.',
    );
    expect(
      enStrings.favoritesLoadFailed,
      'Unable to load favorites. Pull down to retry.',
    );
    expect(
      enStrings.favoritesRefreshFailed,
      'Refresh failed. Please try again.',
    );
    expect(enStrings.favoritesRetry, 'Retry');
    expect(enStrings.favoritesDeleteTitle, 'Remove Favorite');
    expect(
      enStrings.favoritesDeleteMessage,
      'Remove this item from favorites? This does not delete the original message.',
    );
    expect(enStrings.favoritesDeleteAction, 'Remove');
    expect(enStrings.favoritesDeleteTooltip, 'Remove from favorites');
    expect(enStrings.favoritesDeleteFailed, 'Failed to remove favorite: ');
    expect(enStrings.favoritesOpenFailed, 'Unable to open favorite: ');
    expect(
      enStrings.favoritesUnsupportedOpen,
      'This favorite cannot be opened on the current platform.',
    );

    expect(enStrings.appModulesPageTitle, 'App Modules');
    expect(enStrings.appModulesSaveAction, 'Save Changes');
    expect(enStrings.appModulesHeroTitle, 'App Modules');
    expect(
      enStrings.appModulesHeroSubtitle,
      'Choose which modules are visible and keep your module list synced.',
    );
    expect(enStrings.appModulesStatusTitle, 'Current Status');
    expect(enStrings.appModulesListSectionTitle, 'Module List');
    expect(
      enStrings.appModulesHelpCopy,
      'Changes apply after saving. Modules unavailable to your account are disabled automatically.',
    );
    expect(enStrings.appModulesLoadingHint, 'Loading modules...');
    expect(enStrings.appModulesEmptyHint, 'No modules available right now.');
    expect(enStrings.appModulesFallbackModuleName, 'Unknown Module');
    expect(enStrings.appModulesSaveSuccess, 'Module settings saved.');
    expect(enStrings.appModulesSyncedStatus, 'Synced');
    expect(enStrings.appModulesRetry, 'Retry');
    expect(
      enStrings.appModulesSaveFailed('network timeout'),
      'Failed to save app modules: network timeout',
    );

    final zhCoverage = <String>[
      zhStrings.generalHeroTitle,
      zhStrings.generalHeroSubtitle,
      zhStrings.generalAppearanceSectionTitle,
      zhStrings.generalStorageSectionTitle,
      zhStrings.generalMessagesSectionTitle,
      zhStrings.generalModulesSectionTitle,
      zhStrings.generalSupportSectionTitle,
      zhStrings.generalAccountSectionTitle,
      zhStrings.notificationHeroTitle,
      zhStrings.notificationHeroSubtitle,
      zhStrings.notificationPreferencesSectionTitle,
      zhStrings.notificationSystemSectionTitle,
      zhStrings.notificationHelpSectionTitle,
      zhStrings.notificationDisabledHint,
      zhStrings.notificationSystemSettingsHint,
      zhStrings.favoritesPageTitle,
      zhStrings.favoritesHeroTitle,
      zhStrings.favoritesHeroSubtitle,
      zhStrings.favoritesSearchHint,
      zhStrings.favoritesLoadingHint,
      zhStrings.favoritesEmptyTitle,
      zhStrings.favoritesEmptySubtitle,
      zhStrings.favoritesLoadFailed,
      zhStrings.favoritesRefreshFailed,
      zhStrings.favoritesRetry,
      zhStrings.favoritesDeleteTitle,
      zhStrings.favoritesDeleteMessage,
      zhStrings.favoritesDeleteAction,
      zhStrings.favoritesDeleteTooltip,
      zhStrings.favoritesDeleteFailed,
      zhStrings.favoritesOpenFailed,
      zhStrings.favoritesUnsupportedOpen,
      zhStrings.appModulesPageTitle,
      zhStrings.appModulesSaveAction,
      zhStrings.appModulesHeroTitle,
      zhStrings.appModulesHeroSubtitle,
      zhStrings.appModulesStatusTitle,
      zhStrings.appModulesListSectionTitle,
      zhStrings.appModulesHelpCopy,
      zhStrings.appModulesLoadingHint,
      zhStrings.appModulesEmptyHint,
      zhStrings.appModulesFallbackModuleName,
      zhStrings.appModulesSaveSuccess,
      zhStrings.appModulesSyncedStatus,
      zhStrings.appModulesLoadFailedPrefix,
      zhStrings.appModulesSaveFailedPrefix,
      zhStrings.appModulesRetry,
    ];
    for (final value in zhCoverage) {
      expect(value.trim(), isNotEmpty);
    }

    expect(
      zhStrings.generalHeroTitle,
      isNot(equals(enStrings.generalHeroTitle)),
    );
    expect(
      zhStrings.notificationHeroTitle,
      isNot(equals(enStrings.notificationHeroTitle)),
    );
    expect(
      zhStrings.favoritesPageTitle,
      isNot(equals(enStrings.favoritesPageTitle)),
    );
    expect(
      zhStrings.appModulesPageTitle,
      isNot(equals(enStrings.appModulesPageTitle)),
    );
  });

  testWidgets('settings surface exposes reusable info and search cards', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'seed');
    addTearDown(controller.dispose);
    String changedValue = '';
    var clearInvoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SettingsSection(
                title: 'Module group',
                children: [
                  ActionSettingTile(
                    icon: Icons.widgets_outlined,
                    title: 'App Modules',
                    subtitle: 'Manage visible modules.',
                    onTap: _noopSettingAction,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SettingsInfoCard(
                icon: Icons.info_outline,
                title: 'Sync status',
                subtitle: 'All modules are synced.',
              ),
              const SizedBox(height: 12),
              SettingsSearchCard(
                controller: controller,
                hintText: 'Search favorites',
                onChanged: (value) => changedValue = value,
                onClear: () {
                  clearInvoked = true;
                  controller.clear();
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Module group'), findsOneWidget);
    expect(find.text('Sync status'), findsOneWidget);
    expect(find.text('All modules are synced.'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('settings-search-clear')),
      findsOneWidget,
    );

    final sectionContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SettingsSection),
            matching: find.byType(Container),
          )
          .first,
    );
    final sectionDecoration = sectionContainer.decoration as BoxDecoration;
    expect(sectionDecoration.color, LiquidGlassColors.surface);
    expect(sectionDecoration.borderRadius, LiquidGlassRadii.xl);
    expect(sectionDecoration.border, isA<Border>());
    expect(sectionDecoration.boxShadow, LiquidGlassShadows.md);
    final sectionTitle = tester.widget<Text>(find.text('Module group'));
    expect(sectionTitle.style?.color, LiquidGlassColors.text);
    final actionTitle = tester.widget<Text>(find.text('App Modules'));
    expect(actionTitle.style?.color, LiquidGlassColors.text);
    final actionSubtitle = tester.widget<Text>(
      find.text('Manage visible modules.'),
    );
    expect(actionSubtitle.style?.color, LiquidGlassColors.textSecondary);
    final leadingIconContainer = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.widgets_outlined),
            matching: find.byType(Container),
          )
          .first,
    );
    final leadingIconDecoration =
        leadingIconContainer.decoration as BoxDecoration;
    expect(leadingIconDecoration.color, LiquidGlassColors.muted);
    expect(leadingIconDecoration.borderRadius, LiquidGlassRadii.md);
    expect(leadingIconDecoration.border, isA<Border>());
    final leadingIcon = tester.widget<Icon>(
      find.byIcon(Icons.widgets_outlined),
    );
    expect(leadingIcon.color, LiquidGlassColors.primary);
    final trailingIcon = tester.widget<Icon>(
      find.byIcon(Icons.chevron_right_rounded),
    );
    expect(trailingIcon.color, LiquidGlassColors.textTertiary);

    final infoContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SettingsInfoCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final infoDecoration = infoContainer.decoration as BoxDecoration;
    expect(infoDecoration.color, LiquidGlassColors.surface);
    expect(infoDecoration.borderRadius, LiquidGlassRadii.xl);
    expect(infoDecoration.border, isA<Border>());
    expect(infoDecoration.boxShadow, LiquidGlassShadows.md);
    final infoTitle = tester.widget<Text>(find.text('Sync status'));
    expect(infoTitle.style?.color, LiquidGlassColors.text);
    final infoSubtitle = tester.widget<Text>(
      find.text('All modules are synced.'),
    );
    expect(infoSubtitle.style?.color, LiquidGlassColors.textSecondary);

    final searchContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SettingsSearchCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final searchDecoration = searchContainer.decoration as BoxDecoration;
    expect(searchDecoration.color, LiquidGlassColors.surface);
    expect(searchDecoration.borderRadius, LiquidGlassRadii.xl);
    expect(searchDecoration.border, isA<Border>());
    expect(searchDecoration.boxShadow, LiquidGlassShadows.md);

    await tester.enterText(find.byType(TextField), 'keyword');
    expect(changedValue, 'keyword');

    await tester.tap(
      find.byKey(const ValueKey<String>('settings-search-clear')),
    );
    await tester.pump();
    expect(clearInvoked, isTrue);
    expect(controller.text, isEmpty);
  });
}

void _noopSettingAction() {}

class _FakeCacheCleanService extends CacheCleanService {
  _FakeCacheCleanService({required this.onGetTotalCacheBytes})
    : super(
        resolveCacheDirectories: _resolveCacheDirectories,
        clearAdditionalCaches: _clearAdditionalCaches,
      );

  static Future<List<Directory>> _resolveCacheDirectories() async =>
      <Directory>[];

  static Future<void> _clearAdditionalCaches() async {}

  final Future<int> Function() onGetTotalCacheBytes;
  int getTotalCacheBytesCallCount = 0;

  @override
  Future<int> getTotalCacheBytes() {
    getTotalCacheBytesCallCount += 1;
    return onGetTotalCacheBytes();
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
