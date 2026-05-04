import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/workplace/workplace_catalog_models.dart';
import 'package:wukong_im_app/modules/workplace/workplace_catalog_service.dart';

void main() {
  group('WorkplaceCatalogService', () {
    test(
      'loadCatalog hydrates banners, added apps, recent apps, categories, and selected category apps',
      () async {
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
          fetchRecordedApps: () async => const <WorkplaceApp>[
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
              isAdded: 0 == 1,
            ),
          ],
          fetchCategories: () async => const <WorkplaceCategory>[
            WorkplaceCategory(categoryNo: 'oa', name: 'Office', sortNum: 1),
            WorkplaceCategory(
              categoryNo: 'ops',
              name: 'Operations',
              sortNum: 2,
            ),
          ],
          fetchAppsByCategory: (categoryNo) async {
            expect(categoryNo, 'oa');
            return const <WorkplaceApp>[
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
                isAdded: false,
              ),
            ];
          },
        );

        final state = await service.loadCatalog();

        expect(state.banners.single.bannerNo, 'banner-1');
        expect(state.addedApps.single.appId, 'crm');
        expect(state.recentApps.single.appId, 'docs');
        expect(state.selectedCategoryNo, 'oa');
        expect(state.categoryApps.length, 2);
        expect(
          state.categoryApps.firstWhere((app) => app.appId == 'crm').isAdded,
          isTrue,
        );
        expect(
          state.categoryApps.firstWhere((app) => app.appId == 'docs').isAdded,
          isFalse,
        );
      },
    );

    test(
      'toggleAppMembership refreshes added apps and selected category apps after add',
      () async {
        final addedResponses = <List<WorkplaceApp>>[
          const <WorkplaceApp>[
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
          const <WorkplaceApp>[
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
        ];
        final categoryResponses = <List<WorkplaceApp>>[
          const <WorkplaceApp>[
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
              isAdded: false,
            ),
          ],
          const <WorkplaceApp>[
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
        ];
        final addCalls = <String>[];

        final service = WorkplaceCatalogService(
          fetchBanners: () async => const <WorkplaceBanner>[],
          fetchAddedApps: () async => addedResponses.removeAt(0),
          fetchRecordedApps: () async => const <WorkplaceApp>[],
          fetchCategories: () async => const <WorkplaceCategory>[
            WorkplaceCategory(categoryNo: 'oa', name: 'Office', sortNum: 1),
          ],
          fetchAppsByCategory: (_) async => categoryResponses.removeAt(0),
          addApp: (appId) async => addCalls.add(appId),
        );

        final initialState = await service.loadCatalog();
        final target = initialState.categoryApps.firstWhere(
          (app) => app.appId == 'docs',
        );

        final nextState = await service.toggleAppMembership(
          initialState,
          target,
        );

        expect(addCalls, <String>['docs']);
        expect(nextState.addedApps.map((app) => app.appId), <String>[
          'crm',
          'docs',
        ]);
        expect(
          nextState.categoryApps
              .firstWhere((app) => app.appId == 'docs')
              .isAdded,
          isTrue,
        );
      },
    );

    test(
      'reorderAddedApps persists the dragged order without resorting it',
      () async {
        final reorderCalls = <List<String>>[];
        final service = WorkplaceCatalogService(
          fetchBanners: () async => const <WorkplaceBanner>[],
          fetchAddedApps: () async => const <WorkplaceApp>[],
          fetchRecordedApps: () async => const <WorkplaceApp>[],
          fetchCategories: () async => const <WorkplaceCategory>[],
          fetchAppsByCategory: (_) async => const <WorkplaceApp>[],
          reorderApps: (appIds) async =>
              reorderCalls.add(List<String>.from(appIds)),
        );

        const current = WorkplaceCatalogState(
          addedApps: <WorkplaceApp>[
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
            WorkplaceApp(
              appId: 'hr',
              sortNum: 3,
              icon: '',
              name: 'HR',
              description: 'Human resources',
              appCategory: 'oa',
              status: 1,
              jumpType: 0,
              appRoute: '',
              webRoute: 'https://hr.example.com',
              isPaidApp: 0,
              isAdded: true,
            ),
          ],
        );

        final nextState = await service.reorderAddedApps(current, 2, 0);

        expect(reorderCalls, <List<String>>[
          <String>['hr', 'crm', 'docs'],
        ]);
        expect(
          nextState.addedApps.map((app) => app.appId).toList(growable: false),
          <String>['hr', 'crm', 'docs'],
        );
      },
    );
  });
}
