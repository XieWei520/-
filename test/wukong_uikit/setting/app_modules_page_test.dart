import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/settings_strings.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_models.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_service.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_uikit/setting/app_modules_page.dart';

void main() {
  test(
    'service returns typed fallback notices when server sync is unavailable',
    () async {
      final cachedService = WorkplacePreferencesService(
        serverSyncEnabled: true,
        loadDirectoryModules: () async => const <AppModuleInfo>[
          AppModuleInfo(
            sid: 'module_cached',
            name: 'Cached',
            desc: 'Cached module',
            status: WorkplaceModuleStatus.selectable,
          ),
        ],
        loadServerSnapshot: () async {
          throw Exception('server down');
        },
        loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
          enabledModuleSids: <String>['module_cached'],
        ),
        loadLegacyEnabledModuleSids: () => const <String>[],
      );

      final cachedState = await cachedService.loadAppModules();
      expect(
        cachedState.notice,
        WorkplacePreferencesNotice.cachedServerFallback,
      );
      expect(cachedState.noticeDetail, 'Exception: server down');
      expect(cachedState.modules.single.checked, isTrue);

      final legacyService = WorkplacePreferencesService(
        serverSyncEnabled: true,
        loadDirectoryModules: () async => const <AppModuleInfo>[
          AppModuleInfo(
            sid: 'module_legacy',
            name: 'Legacy',
            desc: 'Legacy module',
            status: WorkplaceModuleStatus.selectable,
          ),
        ],
        loadServerSnapshot: () async {
          throw Exception('server down');
        },
        loadCachedSnapshot: () => null,
        loadLegacyEnabledModuleSids: () => const <String>['module_legacy'],
      );

      final legacyState = await legacyService.loadAppModules();
      expect(
        legacyState.notice,
        WorkplacePreferencesNotice.legacyLocalFallback,
      );
      expect(legacyState.noticeDetail, 'Exception: server down');
      expect(legacyState.modules.single.checked, isTrue);
    },
  );

  testWidgets(
    'page renders backend snapshot and keeps disabled modules locked',
    (tester) async {
      final service = WorkplacePreferencesService(
        serverSyncEnabled: true,
        loadDirectoryModules: () async => const <AppModuleInfo>[
          AppModuleInfo(
            sid: 'module_hr',
            name: 'HR',
            desc: 'Human Resources',
            status: WorkplaceModuleStatus.selectable,
          ),
          AppModuleInfo(
            sid: 'module_notice',
            name: 'Notice',
            desc: 'Always enabled',
            status: WorkplaceModuleStatus.fixed,
          ),
          AppModuleInfo(
            sid: 'module_old',
            name: 'Legacy',
            desc: 'Disabled',
            status: WorkplaceModuleStatus.disabled,
          ),
        ],
        loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(
          enabledModuleSids: <String>['module_hr'],
          updatedAt: '2026-04-13T12:00:00Z',
          version: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AppModulesPage(service: service)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('app-module-module_hr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-module-module_notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-module-module_old')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-module-check-module_notice-on')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-module-check-module_old-off')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'save sends the checked selectable modules to the backend service',
    (tester) async {
      List<String>? savedSids;
      final service = WorkplacePreferencesService(
        serverSyncEnabled: true,
        loadDirectoryModules: () async => const <AppModuleInfo>[
          AppModuleInfo(
            sid: 'module_hr',
            name: 'HR',
            desc: 'Human Resources',
            status: WorkplaceModuleStatus.selectable,
          ),
        ],
        loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(),
        saveServerModules: (moduleSids) async {
          savedSids = moduleSids;
          return WorkplacePreferencesSnapshot(
            enabledModuleSids: moduleSids,
            updatedAt: '2026-04-13T12:05:00Z',
            version: 4,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: AppModulesPage(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('app-module-module_hr')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('app-modules-save')));
      await tester.pumpAndSettle();

      expect(savedSids, <String>['module_hr']);
    },
  );

  testWidgets('page surfaces cached and unsynced states explicitly', (
    tester,
  ) async {
    final strings = resolveSettingsStrings(locale: const Locale('en', 'US'));
    final service = WorkplacePreferencesService(
      serverSyncEnabled: true,
      loadDirectoryModules: () async => const <AppModuleInfo>[
        AppModuleInfo(
          sid: 'module_cached',
          name: 'Cached',
          desc: 'Cached module',
          status: WorkplaceModuleStatus.selectable,
        ),
      ],
      loadServerSnapshot: () async {
        throw Exception('server down');
      },
      saveServerModules: (_) async {
        throw Exception('sync failed');
      },
      loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
        enabledModuleSids: <String>['module_cached'],
      ),
      loadLegacyEnabledModuleSids: () => const <String>[],
    );

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
        home: AppModulesPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('app-modules-status')), findsOneWidget);
    expect(find.byType(SettingsInfoCard), findsAtLeastNWidgets(1));
    expect(
      find.textContaining(strings.appModulesLoadFailedPrefix),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('app-module-module_cached')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-modules-save')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(strings.appModulesSaveFailedPrefix),
      findsOneWidget,
    );
  });

  testWidgets('page shows local-device status copy in default workplace mode', (
    tester,
  ) async {
    final service = WorkplacePreferencesService(
      loadDirectoryModules: () async => const <AppModuleInfo>[
        AppModuleInfo(
          sid: 'module_local',
          name: 'Local',
          desc: 'Saved on this device',
          status: WorkplaceModuleStatus.selectable,
        ),
      ],
      loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
        enabledModuleSids: <String>['module_local'],
      ),
      loadLegacyEnabledModuleSids: () => const <String>['module_local'],
    );

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
        home: AppModulesPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-modules-status')),
        matching: find.text('Saved on this device'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'app modules page renders readable zh copy in settings-family shell',
    (tester) async {
      final strings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));
      final service = WorkplacePreferencesService(
        loadDirectoryModules: () async => const <AppModuleInfo>[],
        loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(),
      );

      await tester.pumpWidget(
        MaterialApp(
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
          home: AppModulesPage(service: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScaffold), findsOneWidget);
      expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
      expect(find.byType(SettingsSection), findsAtLeastNWidgets(1));
      expect(find.byType(WKSubPageScaffold), findsNothing);
      expect(find.text(strings.appModulesPageTitle), findsAtLeastNWidgets(1));
      expect(find.text(strings.appModulesHeroTitle), findsAtLeastNWidgets(1));
      expect(find.text(strings.appModulesListSectionTitle), findsOneWidget);
      expect(find.text(strings.save), findsOneWidget);
    },
  );
}
