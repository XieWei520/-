import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_models.dart';
import 'package:wukong_im_app/modules/workplace/workplace_preferences_service.dart';
import 'package:wukong_im_app/service/api/common_api.dart';

void main() {
  group('WorkplacePreferencesService', () {
    test(
      'loadAppModules merges directory metadata with server snapshot and persists cache',
      () async {
        WorkplacePreferencesSnapshot? cachedSnapshot;
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => _directoryModules,
          loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(
            enabledModuleSids: <String>['module.todo'],
            addedAppIds: <String>['app.crm'],
            orderedAppIds: <String>['app.crm'],
            recordAppIds: <String>['app.attendance'],
            updatedAt: '2026-04-10T12:34:56Z',
            version: 10,
          ),
          saveServerModules: (_) async => const WorkplacePreferencesSnapshot(),
          loadCachedSnapshot: () => null,
          saveCachedSnapshot: (snapshot) async {
            cachedSnapshot = snapshot;
          },
          loadLegacyEnabledModuleSids: () => const <String>['module.crm'],
          saveLegacyEnabledModuleSids: (_) async {},
        );

        final state = await service.loadAppModules();

        expect(state.snapshot.version, 10);
        expect(state.snapshot.updatedAt, '2026-04-10T12:34:56Z');
        expect(state.isFromCache, isFalse);
        expect(state.statusMessage, isNull);
        expect(state.modules, hasLength(4));
        expect(state.modules[0].sid, 'module.fixed');
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[0].isFixedEnabled, isTrue);
        expect(state.modules[1].sid, 'module.disabled');
        expect(state.modules[1].checked, isFalse);
        expect(state.modules[1].isDisabled, isTrue);
        expect(state.modules[2].sid, 'module.todo');
        expect(state.modules[2].checked, isTrue);
        expect(state.modules[2].isSelectable, isTrue);
        expect(state.modules[3].sid, 'module.crm');
        expect(state.modules[3].checked, isFalse);
        expect(cachedSnapshot?.version, 10);
      },
    );

    test(
      'loadAppModules keeps fresh server data when cache persistence fails',
      () async {
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => _selectableModules,
          loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(
            enabledModuleSids: <String>['module.cached'],
            updatedAt: '2026-04-10T09:00:00Z',
            version: 9,
          ),
          saveServerModules: (_) async => const WorkplacePreferencesSnapshot(),
          loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
            enabledModuleSids: <String>['module.legacy'],
            updatedAt: '2026-04-10T08:00:00Z',
            version: 3,
          ),
          saveCachedSnapshot: (_) async {
            throw StateError('cache write failed');
          },
          loadLegacyEnabledModuleSids: () => const <String>['module.legacy'],
          saveLegacyEnabledModuleSids: (_) async {},
        );

        final state = await service.loadAppModules();

        expect(state.isFromCache, isFalse);
        expect(state.snapshot.version, 9);
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].checked, isFalse);
      },
    );

    test(
      'loadAppModules falls back to cached snapshot merged with legacy modules',
      () async {
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => _selectableModules,
          loadServerSnapshot: () async {
            throw StateError('server down');
          },
          saveServerModules: (_) async => const WorkplacePreferencesSnapshot(),
          loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
            enabledModuleSids: <String>['module.cached'],
            updatedAt: '2026-04-10T08:00:00Z',
            version: 3,
          ),
          saveCachedSnapshot: (_) async {},
          loadLegacyEnabledModuleSids: () => const <String>[
            'module.legacy',
            'module.cached',
          ],
          saveLegacyEnabledModuleSids: (_) async {},
        );

        final state = await service.loadAppModules();

        expect(state.modules[0].sid, 'module.cached');
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].sid, 'module.legacy');
        expect(state.modules[1].checked, isTrue);
        expect(state.snapshot.enabledModuleSids, <String>[
          'module.cached',
          'module.legacy',
        ]);
        expect(state.isFromCache, isTrue);
        expect(state.notice, WorkplacePreferencesNotice.cachedServerFallback);
        expect(state.noticeDetail, contains('server down'));
      },
    );

    test(
      'loadAppModules falls back to legacy local module selection when server and cache are unavailable',
      () async {
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => _selectableModules,
          loadServerSnapshot: () async {
            throw StateError('server down');
          },
          saveServerModules: (_) async => const WorkplacePreferencesSnapshot(),
          loadCachedSnapshot: () => null,
          saveCachedSnapshot: (_) async {},
          loadLegacyEnabledModuleSids: () => const <String>['module.cached'],
          saveLegacyEnabledModuleSids: (_) async {},
        );

        final state = await service.loadAppModules();

        expect(state.modules[0].sid, 'module.cached');
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].sid, 'module.legacy');
        expect(state.modules[1].checked, isFalse);
        expect(state.snapshot.enabledModuleSids, <String>['module.cached']);
        expect(state.isFromCache, isTrue);
        expect(state.notice, WorkplacePreferencesNotice.legacyLocalFallback);
        expect(state.noticeDetail, contains('server down'));
      },
    );

    test(
      'saveEnabledModules returns page-ready state and updates cache and legacy on success',
      () async {
        List<String>? remoteSavedSids;
        WorkplacePreferencesSnapshot? cachedSnapshot;
        List<String>? legacySavedSids;
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => const <AppModuleInfo>[],
          loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(),
          saveServerModules: (enabledModuleSids) async {
            remoteSavedSids = enabledModuleSids;
            return WorkplacePreferencesSnapshot(
              enabledModuleSids: enabledModuleSids,
              addedAppIds: const <String>['app.crm'],
              updatedAt: '2026-04-10T16:20:00Z',
              version: 12,
            );
          },
          loadCachedSnapshot: () => null,
          saveCachedSnapshot: (snapshot) async {
            cachedSnapshot = snapshot;
          },
          loadLegacyEnabledModuleSids: () => const <String>[],
          saveLegacyEnabledModuleSids: (enabledSids) async {
            legacySavedSids = enabledSids;
          },
        );

        final state = await service
            .saveEnabledModules(const <WorkplaceModuleItem>[
              WorkplaceModuleItem(
                sid: 'module.fixed',
                name: 'Fixed',
                desc: '',
                status: WorkplaceModuleStatus.fixed,
                checked: true,
              ),
              WorkplaceModuleItem(
                sid: 'module.disabled',
                name: 'Disabled',
                desc: '',
                status: WorkplaceModuleStatus.disabled,
                checked: true,
              ),
              WorkplaceModuleItem(
                sid: 'module.todo',
                name: 'Todo',
                desc: '',
                status: WorkplaceModuleStatus.selectable,
                checked: true,
              ),
              WorkplaceModuleItem(
                sid: 'module.crm',
                name: 'CRM',
                desc: '',
                status: WorkplaceModuleStatus.selectable,
                checked: false,
              ),
            ]);

        expect(remoteSavedSids, <String>['module.todo']);
        expect(cachedSnapshot?.enabledModuleSids, <String>['module.todo']);
        expect(legacySavedSids, <String>['module.todo']);
        expect(state.snapshot.version, 12);
        expect(state.snapshot.updatedAt, '2026-04-10T16:20:00Z');
        expect(state.modules.map((item) => item.sid).toList(), <String>[
          'module.fixed',
          'module.disabled',
          'module.todo',
          'module.crm',
        ]);
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].checked, isFalse);
        expect(state.modules[2].checked, isTrue);
        expect(state.modules[3].checked, isFalse);
        expect(state.isFromCache, isFalse);
        expect(state.statusMessage, isNull);
      },
    );

    test(
      'saveEnabledModules does not overwrite cache or legacy storage when remote save fails',
      () async {
        var legacySaveCalls = 0;
        var cacheSaveCalls = 0;
        final service = WorkplacePreferencesService(
          serverSyncEnabled: true,
          loadDirectoryModules: () async => const <AppModuleInfo>[],
          loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(),
          saveServerModules: (_) async {
            throw StateError('save failed');
          },
          loadCachedSnapshot: () => null,
          saveCachedSnapshot: (_) async {
            cacheSaveCalls += 1;
          },
          loadLegacyEnabledModuleSids: () => const <String>['module.todo'],
          saveLegacyEnabledModuleSids: (_) async {
            legacySaveCalls += 1;
          },
        );

        await expectLater(
          () => service.saveEnabledModules(const <WorkplaceModuleItem>[
            WorkplaceModuleItem(
              sid: 'module.todo',
              name: 'Todo',
              desc: '',
              status: WorkplaceModuleStatus.selectable,
              checked: true,
            ),
          ]),
          throwsA(isA<StateError>()),
        );
        expect(cacheSaveCalls, 0);
        expect(legacySaveCalls, 0);
      },
    );

    test(
      'loadAppModules defaults to local device preferences and skips server sync',
      () async {
        var serverLoadCalls = 0;
        final service = WorkplacePreferencesService(
          loadDirectoryModules: () async => _selectableModules,
          loadServerSnapshot: () async {
            serverLoadCalls += 1;
            throw StateError('server should be skipped');
          },
          loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
            enabledModuleSids: <String>['module.cached'],
            updatedAt: '2026-04-10T08:00:00Z',
            version: 3,
          ),
          loadLegacyEnabledModuleSids: () => const <String>[
            'module.legacy',
            'module.cached',
          ],
        );

        final state = await service.loadAppModules();

        expect(serverLoadCalls, 0);
        expect(state.notice, WorkplacePreferencesNotice.localDevicePreference);
        expect(state.snapshot.enabledModuleSids, <String>[
          'module.cached',
          'module.legacy',
        ]);
        expect(state.modules[0].sid, 'module.cached');
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].sid, 'module.legacy');
        expect(state.modules[1].checked, isTrue);
        expect(state.isFromCache, isFalse);
        expect(state.statusMessage, isNull);
      },
    );

    test(
      'saveEnabledModules persists locally and skips remote sync by default',
      () async {
        var serverSaveCalls = 0;
        WorkplacePreferencesSnapshot? cachedSnapshot;
        List<String>? legacySavedSids;
        final service = WorkplacePreferencesService(
          loadDirectoryModules: () async => const <AppModuleInfo>[],
          loadServerSnapshot: () async => const WorkplacePreferencesSnapshot(),
          saveServerModules: (_) async {
            serverSaveCalls += 1;
            throw StateError('server should be skipped');
          },
          loadCachedSnapshot: () => const WorkplacePreferencesSnapshot(
            addedAppIds: <String>['app.crm'],
            orderedAppIds: <String>['app.crm'],
            recordAppIds: <String>['app.attendance'],
            updatedAt: '2026-04-10T16:20:00Z',
            version: 12,
          ),
          saveCachedSnapshot: (snapshot) async {
            cachedSnapshot = snapshot;
          },
          loadLegacyEnabledModuleSids: () => const <String>[],
          saveLegacyEnabledModuleSids: (enabledSids) async {
            legacySavedSids = enabledSids;
          },
        );

        final state = await service
            .saveEnabledModules(const <WorkplaceModuleItem>[
              WorkplaceModuleItem(
                sid: 'module.fixed',
                name: 'Fixed',
                desc: '',
                status: WorkplaceModuleStatus.fixed,
                checked: true,
              ),
              WorkplaceModuleItem(
                sid: 'module.todo',
                name: 'Todo',
                desc: '',
                status: WorkplaceModuleStatus.selectable,
                checked: true,
              ),
              WorkplaceModuleItem(
                sid: 'module.crm',
                name: 'CRM',
                desc: '',
                status: WorkplaceModuleStatus.selectable,
                checked: false,
              ),
            ]);

        expect(serverSaveCalls, 0);
        expect(cachedSnapshot?.enabledModuleSids, <String>['module.todo']);
        expect(cachedSnapshot?.addedAppIds, <String>['app.crm']);
        expect(cachedSnapshot?.orderedAppIds, <String>['app.crm']);
        expect(cachedSnapshot?.recordAppIds, <String>['app.attendance']);
        expect(legacySavedSids, <String>['module.todo']);
        expect(state.notice, WorkplacePreferencesNotice.localDevicePreference);
        expect(state.snapshot.enabledModuleSids, <String>['module.todo']);
        expect(state.snapshot.version, 12);
        expect(state.modules[0].checked, isTrue);
        expect(state.modules[1].checked, isTrue);
        expect(state.modules[2].checked, isFalse);
      },
    );
  });
}

const List<AppModuleInfo> _directoryModules = <AppModuleInfo>[
  AppModuleInfo(
    sid: 'module.fixed',
    name: 'Fixed Module',
    desc: '',
    status: WorkplaceModuleStatus.fixed,
  ),
  AppModuleInfo(
    sid: 'module.disabled',
    name: 'Disabled Module',
    desc: '',
    status: WorkplaceModuleStatus.disabled,
  ),
  AppModuleInfo(
    sid: 'module.todo',
    name: 'Todo',
    desc: '',
    status: WorkplaceModuleStatus.selectable,
  ),
  AppModuleInfo(
    sid: 'module.crm',
    name: 'CRM',
    desc: '',
    status: WorkplaceModuleStatus.selectable,
  ),
];

const List<AppModuleInfo> _selectableModules = <AppModuleInfo>[
  AppModuleInfo(
    sid: 'module.cached',
    name: 'Cached',
    desc: '',
    status: WorkplaceModuleStatus.selectable,
  ),
  AppModuleInfo(
    sid: 'module.legacy',
    name: 'Legacy',
    desc: '',
    status: WorkplaceModuleStatus.selectable,
  ),
];
