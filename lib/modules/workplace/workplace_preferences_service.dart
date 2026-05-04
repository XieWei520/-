import '../../service/api/common_api.dart';
import '../../service/api/workplace_api.dart';
import '../../wukong_uikit/setting/setting_preferences.dart';
import 'workplace_preferences_models.dart';

class WorkplacePreferencesService {
  WorkplacePreferencesService({
    this.serverSyncEnabled = false,
    Future<List<AppModuleInfo>> Function()? loadDirectoryModules,
    Future<WorkplacePreferencesSnapshot> Function()? loadServerSnapshot,
    Future<WorkplacePreferencesSnapshot> Function(List<String> moduleSids)?
    saveServerModules,
    WorkplacePreferencesSnapshot? Function()? loadCachedSnapshot,
    Future<void> Function(WorkplacePreferencesSnapshot snapshot)?
    saveCachedSnapshot,
    List<String> Function()? loadLegacyEnabledModuleSids,
    Future<void> Function(List<String> moduleSids)? saveLegacyEnabledModuleSids,
  }) : _loadDirectoryModules = loadDirectoryModules ?? _defaultLoadDirectory,
       _loadServerSnapshot = loadServerSnapshot ?? _defaultLoadSnapshot,
       _saveServerModules = saveServerModules ?? _defaultSaveSnapshot,
       _loadCachedSnapshot = loadCachedSnapshot ?? _defaultLoadCachedSnapshot,
       _saveCachedSnapshot = saveCachedSnapshot ?? _defaultSaveCachedSnapshot,
       _loadLegacyEnabledModuleSids =
           loadLegacyEnabledModuleSids ?? _defaultLoadLegacyEnabledSids,
       _saveLegacyEnabledModuleSids =
           saveLegacyEnabledModuleSids ?? _defaultSaveLegacyEnabledSids;

  final bool serverSyncEnabled;
  final Future<List<AppModuleInfo>> Function() _loadDirectoryModules;
  final Future<WorkplacePreferencesSnapshot> Function() _loadServerSnapshot;
  final Future<WorkplacePreferencesSnapshot> Function(List<String> moduleSids)
  _saveServerModules;
  final WorkplacePreferencesSnapshot? Function() _loadCachedSnapshot;
  final Future<void> Function(WorkplacePreferencesSnapshot snapshot)
  _saveCachedSnapshot;
  final List<String> Function() _loadLegacyEnabledModuleSids;
  final Future<void> Function(List<String> moduleSids)
  _saveLegacyEnabledModuleSids;

  Future<WorkplaceModuleScreenState> loadAppModules() async {
    final directory = await _loadDirectoryModules();
    if (!serverSyncEnabled) {
      return _buildState(
        directory: directory,
        snapshot: _loadLocalSnapshot(),
        notice: WorkplacePreferencesNotice.localDevicePreference,
      );
    }

    try {
      final snapshot = await _loadServerSnapshot();
      try {
        await _saveCachedSnapshot(snapshot);
      } catch (_) {}
      return _buildState(directory: directory, snapshot: snapshot);
    } catch (error) {
      final cached = _loadCachedSnapshot();
      if (cached != null) {
        return _buildState(
          directory: directory,
          snapshot: _mergeLegacyModules(cached),
          notice: WorkplacePreferencesNotice.cachedServerFallback,
          noticeDetail: error.toString(),
        );
      }
      final legacySnapshot = WorkplacePreferencesSnapshot(
        enabledModuleSids: _normalizeSids(_loadLegacyEnabledModuleSids()),
      );
      return _buildState(
        directory: directory,
        snapshot: legacySnapshot,
        notice: WorkplacePreferencesNotice.legacyLocalFallback,
        noticeDetail: error.toString(),
      );
    }
  }

  Future<WorkplaceModuleScreenState> saveEnabledModules(
    List<WorkplaceModuleItem> modules,
  ) async {
    final enabledModuleSids = _normalizeSids(
      modules
          .where((item) => item.isSelectable && item.checked)
          .map((item) => item.sid)
          .toList(growable: false),
    );
    if (!serverSyncEnabled) {
      final snapshot = _loadLocalSnapshot(
        overrideEnabledModuleSids: enabledModuleSids,
      );
      await _saveCachedSnapshot(snapshot);
      await _saveLegacyEnabledModuleSids(enabledModuleSids);
      return _buildState(
        directory: _directoryFromModules(modules),
        snapshot: snapshot,
        notice: WorkplacePreferencesNotice.localDevicePreference,
      );
    }

    final snapshot = await _saveServerModules(enabledModuleSids);
    await _saveCachedSnapshot(snapshot);
    await _saveLegacyEnabledModuleSids(enabledModuleSids);
    return _buildState(
      directory: _directoryFromModules(modules),
      snapshot: snapshot,
    );
  }

  WorkplaceModuleScreenState _buildState({
    required List<AppModuleInfo> directory,
    required WorkplacePreferencesSnapshot snapshot,
    WorkplacePreferencesNotice notice = WorkplacePreferencesNotice.none,
    String? noticeDetail,
  }) {
    final enabled = snapshot.enabledModuleSids.toSet();
    final modules = directory
        .map((module) {
          final checked = switch (module.status) {
            WorkplaceModuleStatus.fixed => true,
            WorkplaceModuleStatus.disabled => false,
            _ => enabled.contains(module.sid),
          };
          return WorkplaceModuleItem(
            sid: module.sid,
            name: module.name,
            desc: module.desc,
            status: module.status,
            checked: checked,
          );
        })
        .toList(growable: false);
    return WorkplaceModuleScreenState(
      snapshot: snapshot,
      modules: modules,
      notice: notice,
      noticeDetail: noticeDetail,
    );
  }

  WorkplacePreferencesSnapshot _loadLocalSnapshot({
    List<String>? overrideEnabledModuleSids,
  }) {
    final cached = _loadCachedSnapshot();
    final enabledModuleSids =
        overrideEnabledModuleSids ??
        _normalizeSids(<String>[
          ...?cached?.enabledModuleSids,
          ..._loadLegacyEnabledModuleSids(),
        ]);
    return WorkplacePreferencesSnapshot(
      enabledModuleSids: enabledModuleSids,
      addedAppIds: cached?.addedAppIds ?? const <String>[],
      orderedAppIds: cached?.orderedAppIds ?? const <String>[],
      recordAppIds: cached?.recordAppIds ?? const <String>[],
      updatedAt: cached?.updatedAt ?? '',
      version: cached?.version ?? 0,
    );
  }

  List<AppModuleInfo> _directoryFromModules(List<WorkplaceModuleItem> modules) {
    return modules
        .map((item) {
          return AppModuleInfo(
            sid: item.sid,
            name: item.name,
            desc: item.desc,
            status: item.status,
          );
        })
        .toList(growable: false);
  }

  WorkplacePreferencesSnapshot _mergeLegacyModules(
    WorkplacePreferencesSnapshot snapshot,
  ) {
    final mergedEnabled = _normalizeSids(<String>[
      ...snapshot.enabledModuleSids,
      ..._loadLegacyEnabledModuleSids(),
    ]);
    return WorkplacePreferencesSnapshot(
      enabledModuleSids: mergedEnabled,
      addedAppIds: snapshot.addedAppIds,
      orderedAppIds: snapshot.orderedAppIds,
      recordAppIds: snapshot.recordAppIds,
      updatedAt: snapshot.updatedAt,
      version: snapshot.version,
    );
  }

  List<String> _normalizeSids(List<String> sids) {
    final normalized = <String>[];
    for (final sid in sids) {
      final value = sid.trim();
      if (value.isEmpty || normalized.contains(value)) {
        continue;
      }
      normalized.add(value);
    }
    return normalized;
  }

  static Future<List<AppModuleInfo>> _defaultLoadDirectory() {
    return CommonApi.instance.getAppModules();
  }

  static Future<WorkplacePreferencesSnapshot> _defaultLoadSnapshot() {
    return WorkplaceApi.instance.getPreferences();
  }

  static Future<WorkplacePreferencesSnapshot> _defaultSaveSnapshot(
    List<String> moduleSids,
  ) {
    return WorkplaceApi.instance.updateEnabledModules(moduleSids);
  }

  static WorkplacePreferencesSnapshot? _defaultLoadCachedSnapshot() {
    final raw = WKSettingPreferences.getWorkplacePreferencesSnapshotCache();
    if (raw == null) {
      return null;
    }
    return WorkplacePreferencesSnapshot.fromJson(raw);
  }

  static Future<void> _defaultSaveCachedSnapshot(
    WorkplacePreferencesSnapshot snapshot,
  ) {
    return WKSettingPreferences.setWorkplacePreferencesSnapshotCache(
      snapshot.toJson(),
    );
  }

  static List<String> _defaultLoadLegacyEnabledSids() {
    return WKSettingPreferences.getLegacyEnabledModuleSids();
  }

  static Future<void> _defaultSaveLegacyEnabledSids(List<String> moduleSids) {
    return WKSettingPreferences.setLegacyEnabledModuleSids(moduleSids);
  }
}
