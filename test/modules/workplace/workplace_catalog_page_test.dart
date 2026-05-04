import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/cache/media_cache_manager.dart';
import 'package:wukong_im_app/modules/workplace/workplace_catalog_models.dart';
import 'package:wukong_im_app/modules/workplace/workplace_catalog_page.dart';
import 'package:wukong_im_app/modules/workplace/workplace_catalog_service.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_models.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_service.dart';
import 'package:wukong_im_app/wukong_uikit/setting/app_modules_page.dart';

void main() {
  testWidgets(
    'workplace catalog page opens web apps in embedded webview and records usage',
    (tester) async {
      final recorded = <String>[];
      final launchedUrls = <String>[];
      final recentResponses = <List<WorkplaceApp>>[
        const <WorkplaceApp>[],
        const <WorkplaceApp>[
          WorkplaceApp(
            appId: 'crm',
            sortNum: 1,
            icon: 'https://cdn.example.com/crm.png',
            name: 'CRM',
            description: 'Customer management',
            appCategory: 'oa',
            status: 1,
            jumpType: 0,
            appRoute: '',
            webRoute: 'https://crm.example.com',
            isPaidApp: 0,
            isAdded: true,
          ),
        ],
      ];

      final service = WorkplaceCatalogService(
        fetchBanners: () async => const <WorkplaceBanner>[
          WorkplaceBanner(
            bannerNo: 'banner-1',
            cover: 'https://cdn.example.com/banner.png',
            title: 'Workspace',
            description: 'Tools for the team',
            jumpType: 0,
            route: 'https://example.com/workspace',
            sortNum: 1,
            createdAt: '2026-04-16T00:00:00Z',
          ),
        ],
        fetchAddedApps: () async => const <WorkplaceApp>[
          WorkplaceApp(
            appId: 'crm',
            sortNum: 1,
            icon: 'https://cdn.example.com/crm.png',
            name: 'CRM',
            description: 'Customer management',
            appCategory: 'oa',
            status: 1,
            jumpType: 0,
            appRoute: '',
            webRoute: 'https://crm.example.com',
            isPaidApp: 0,
            isAdded: true,
          ),
        ],
        fetchRecordedApps: () async => recentResponses.removeAt(0),
        fetchCategories: () async => const <WorkplaceCategory>[
          WorkplaceCategory(categoryNo: 'oa', name: 'Office', sortNum: 1),
        ],
        fetchAppsByCategory: (_) async => const <WorkplaceApp>[
          WorkplaceApp(
            appId: 'crm',
            sortNum: 1,
            icon: '',
            name: 'CRM',
            description: 'Customer management',
            appCategory: 'oa',
            status: 1,
            jumpType: 0,
            appRoute: '',
            webRoute: 'https://crm.example.com',
            isPaidApp: 0,
            isAdded: true,
          ),
        ],
        addRecord: (appId) async => recorded.add(appId),
      );

      await tester.pumpWidget(
        _buildHost(
          WorkplaceCatalogPage(
            service: service,
            buildWebviewPage: (url) =>
                Scaffold(body: Text('webview-destination:$url')),
            launchUrlExternally: (uri) async {
              launchedUrls.add(uri.toString());
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workplace-banner-banner-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workplace-banner-cover-banner-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workplace-my-app-crm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workplace-my-app-icon-crm')),
        findsOneWidget,
      );
      final bannerCover = tester.widget<CachedMediaImage>(
        find.byKey(const ValueKey('workplace-banner-cover-banner-1')),
      );
      expect(bannerCover.imageUrl, 'https://cdn.example.com/banner.png');
      expect(bannerCover.cacheKey, bannerCover.imageUrl);
      expect(bannerCover.fit, BoxFit.cover);
      expect(bannerCover.maxWidth, greaterThan(0));
      expect(bannerCover.maxHeight, greaterThan(0));

      final appIcon = tester.widget<CachedMediaImage>(
        find.byKey(const ValueKey('workplace-my-app-icon-crm')),
      );
      expect(appIcon.imageUrl, 'https://cdn.example.com/crm.png');
      expect(appIcon.cacheKey, appIcon.imageUrl);
      expect(appIcon.width, 40);
      expect(appIcon.height, 40);
      expect(appIcon.maxWidth, greaterThan(0));
      expect(appIcon.maxHeight, greaterThan(0));

      await tester.tap(
        find.byKey(const ValueKey('workplace-app-open-crm')).first,
      );
      await tester.pumpAndSettle();

      expect(recorded, <String>['crm']);
      expect(launchedUrls, isEmpty);
      expect(
        find.text('webview-destination:https://crm.example.com'),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(
          find.text('webview-destination:https://crm.example.com'),
        ),
      ).pop();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('workplace-recent-app-crm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workplace-category-oa')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workplace-category-app-crm')),
        findsOneWidget,
      );
    },
  );

  testWidgets('workplace catalog page opens banners in embedded webview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHost(
        WorkplaceCatalogPage(
          service: WorkplaceCatalogService(
            fetchBanners: () async => const <WorkplaceBanner>[
              WorkplaceBanner(
                bannerNo: 'banner-1',
                cover: 'https://cdn.example.com/banner.png',
                title: 'Workspace',
                description: 'Tools for the team',
                jumpType: 0,
                route: 'https://example.com/workspace',
                sortNum: 1,
                createdAt: '2026-04-16T00:00:00Z',
              ),
            ],
            fetchAddedApps: () async => const <WorkplaceApp>[],
            fetchRecordedApps: () async => const <WorkplaceApp>[],
            fetchCategories: () async => const <WorkplaceCategory>[],
            fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
          ),
          buildWebviewPage: (url) =>
              Scaffold(body: Text('banner-webview:$url')),
          launchUrlExternally: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('workplace-banner-banner-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('banner-webview:https://example.com/workspace'),
      findsOneWidget,
    );
  });

  testWidgets('workplace catalog page lets users reorder added apps', (
    tester,
  ) async {
    final reorderCalls = <List<String>>[];
    final service = WorkplaceCatalogService(
      fetchBanners: () async => const <WorkplaceBanner>[],
      fetchAddedApps: () async => const <WorkplaceApp>[
        WorkplaceApp(
          appId: 'crm',
          sortNum: 1,
          icon: '',
          name: 'CRM',
          description: 'Customer management',
          appCategory: 'oa',
          status: 1,
          jumpType: 0,
          appRoute: '',
          webRoute: 'https://crm.example.com',
          isPaidApp: 0,
          isAdded: true,
        ),
        WorkplaceApp(
          appId: 'docs',
          sortNum: 2,
          icon: '',
          name: 'Docs',
          description: 'Documentation',
          appCategory: 'oa',
          status: 1,
          jumpType: 0,
          appRoute: '',
          webRoute: 'https://docs.example.com',
          isPaidApp: 0,
          isAdded: true,
        ),
      ],
      fetchRecordedApps: () async => const <WorkplaceApp>[],
      fetchCategories: () async => const <WorkplaceCategory>[
        WorkplaceCategory(categoryNo: 'oa', name: 'Office', sortNum: 1),
      ],
      fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
      reorderApps: (appIds) async =>
          reorderCalls.add(List<String>.from(appIds)),
    );

    await tester.pumpWidget(
      _buildHost(
        WorkplaceCatalogPage(
          service: service,
          launchUrlExternally: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final crmFinder = find.byKey(const ValueKey('workplace-my-app-crm'));
    final docsFinder = find.byKey(const ValueKey('workplace-my-app-docs'));

    expect(crmFinder, findsOneWidget);
    expect(docsFinder, findsOneWidget);
    expect(
      tester.getTopLeft(crmFinder).dy < tester.getTopLeft(docsFinder).dy,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('workplace-app-move-up-docs')));
    await tester.pumpAndSettle();

    expect(reorderCalls, <List<String>>[
      <String>['docs', 'crm'],
    ]);
    expect(
      tester.getTopLeft(docsFinder).dy < tester.getTopLeft(crmFinder).dy,
      isTrue,
    );
  });

  testWidgets(
    'workplace catalog page opens URL appRoute values even for native jump type',
    (tester) async {
      final recorded = <String>[];

      await tester.pumpWidget(
        _buildHost(
          WorkplaceCatalogPage(
            service: WorkplaceCatalogService(
              fetchBanners: () async => const <WorkplaceBanner>[],
              fetchAddedApps: () async => const <WorkplaceApp>[
                WorkplaceApp(
                  appId: 'native-crm',
                  sortNum: 1,
                  icon: '',
                  name: 'Native CRM',
                  description: 'Native entry with URL route',
                  appCategory: 'oa',
                  status: 1,
                  jumpType: 1,
                  appRoute: 'https://native.example.com/dashboard',
                  webRoute: '',
                  isPaidApp: 0,
                  isAdded: true,
                ),
              ],
              fetchRecordedApps: () async => const <WorkplaceApp>[],
              fetchCategories: () async => const <WorkplaceCategory>[],
              fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
              addRecord: (appId) async => recorded.add(appId),
            ),
            buildWebviewPage: (url) =>
                Scaffold(body: Text('native-webview:$url')),
            launchUrlExternally: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('workplace-app-open-native-crm')).first,
      );
      await tester.pumpAndSettle();

      expect(recorded, <String>['native-crm']);
      expect(
        find.text('native-webview:https://native.example.com/dashboard'),
        findsOneWidget,
      );
      expect(find.textContaining('Pending native route'), findsNothing);
    },
  );

  testWidgets(
    'app modules page opens the workplace catalog from its browse action',
    (tester) async {
      await tester.pumpWidget(
        _buildHost(
          AppModulesPage(
            service: WorkplacePreferencesService(
              loadDirectoryModules: () async => const [],
              loadServerSnapshot: () async =>
                  const WorkplacePreferencesSnapshot(),
            ),
            workplaceCatalogPageBuilder: (_) =>
                const Scaffold(body: Text('catalog-destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-workplace-catalog')));
      await tester.pumpAndSettle();

      expect(find.text('catalog-destination'), findsOneWidget);
    },
  );

  testWidgets('workplace catalog only shows reorder controls for added apps', (
    tester,
  ) async {
    final service = WorkplaceCatalogService(
      fetchBanners: () async => const <WorkplaceBanner>[],
      fetchAddedApps: () async => const <WorkplaceApp>[],
      fetchRecordedApps: () async => const <WorkplaceApp>[
        WorkplaceApp(
          appId: 'recent-docs',
          sortNum: 1,
          icon: '',
          name: 'Recent Docs',
          description: 'Read-only shortcut',
          appCategory: 'oa',
          status: 1,
          jumpType: 0,
          appRoute: '',
          webRoute: 'https://docs.example.com',
          isPaidApp: 0,
          isAdded: false,
        ),
      ],
      fetchCategories: () async => const <WorkplaceCategory>[],
      fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
    );

    await tester.pumpWidget(
      _buildHost(
        WorkplaceCatalogPage(
          service: service,
          launchUrlExternally: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workplace-app-move-up-recent-docs')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('workplace-app-move-down-recent-docs')),
      findsNothing,
    );
  });

  testWidgets(
    'workplace app tile keeps actions within a narrow mobile layout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = WorkplaceCatalogService(
        fetchBanners: () async => const <WorkplaceBanner>[],
        fetchAddedApps: () async => const <WorkplaceApp>[
          WorkplaceApp(
            appId: 'collaboration-suite',
            sortNum: 1,
            icon: '',
            name: 'Very Long Collaboration Suite Name',
            description:
                'A detailed workplace tool description that must wrap safely.',
            appCategory: 'oa',
            status: 1,
            jumpType: 0,
            appRoute: '',
            webRoute: 'https://suite.example.com',
            isPaidApp: 0,
            isAdded: true,
          ),
          WorkplaceApp(
            appId: 'docs',
            sortNum: 2,
            icon: '',
            name: 'Docs',
            description: 'Documentation',
            appCategory: 'oa',
            status: 1,
            jumpType: 0,
            appRoute: '',
            webRoute: 'https://docs.example.com',
            isPaidApp: 0,
            isAdded: true,
          ),
        ],
        fetchRecordedApps: () async => const <WorkplaceApp>[],
        fetchCategories: () async => const <WorkplaceCategory>[],
        fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
      );

      await tester.pumpWidget(
        _buildHost(
          WorkplaceCatalogPage(
            service: service,
            launchUrlExternally: (_) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final tileFinder = find.byKey(
        const ValueKey<String>('workplace-my-app-collaboration-suite'),
      );
      final actionsFinder = find.byKey(
        const ValueKey<String>('workplace-app-actions-collaboration-suite'),
      );
      expect(tileFinder, findsOneWidget);
      expect(actionsFinder, findsOneWidget);

      final tileRect = tester.getRect(tileFinder);
      final actionsRect = tester.getRect(actionsFinder);
      expect(actionsRect.left, greaterThanOrEqualTo(tileRect.left));
      expect(actionsRect.right, lessThanOrEqualTo(tileRect.right));
      expect(
        actionsRect.top,
        greaterThan(
          tester
              .getBottomLeft(find.text('Very Long Collaboration Suite Name'))
              .dy,
        ),
      );
    },
  );
}

Widget _buildHost(Widget home) {
  return MaterialApp(
    locale: const Locale('en', 'US'),
    supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en', 'US')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}
