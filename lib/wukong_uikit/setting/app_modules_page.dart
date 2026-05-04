import 'package:flutter/material.dart';

import '../../modules/settings/settings_strings.dart';
import '../../modules/settings/settings_surface_widgets.dart';
import '../../modules/workplace/workplace_catalog_page.dart';
import '../../modules/workplace/workplace_preferences_models.dart';
import '../../modules/workplace/workplace_preferences_service.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';

class AppModulesPage extends StatefulWidget {
  AppModulesPage({
    super.key,
    WorkplacePreferencesService? service,
    WidgetBuilder? workplaceCatalogPageBuilder,
  }) : service = service ?? WorkplacePreferencesService(),
       workplaceCatalogPageBuilder =
           workplaceCatalogPageBuilder ?? ((_) => WorkplaceCatalogPage());

  final WorkplacePreferencesService service;
  final WidgetBuilder workplaceCatalogPageBuilder;

  @override
  State<AppModulesPage> createState() => _AppModulesPageState();
}

class _AppModulesPageState extends State<AppModulesPage> {
  List<WorkplaceModuleItem> _modules = const <WorkplaceModuleItem>[];
  WorkplacePreferencesSnapshot _snapshot = const WorkplacePreferencesSnapshot();
  WorkplacePreferencesNotice _notice = WorkplacePreferencesNotice.none;
  String? _noticeDetail;
  bool _isLoading = true;
  bool _isSaving = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() {
      _isLoading = true;
      _notice = WorkplacePreferencesNotice.none;
      _noticeDetail = null;
    });

    try {
      final state = await widget.service.loadAppModules();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = state.snapshot;
        _modules = state.modules;
        _notice = state.notice;
        _noticeDetail = state.noticeDetail;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = const WorkplacePreferencesSnapshot();
        _modules = const <WorkplaceModuleItem>[];
        _notice = WorkplacePreferencesNotice.cachedServerFallback;
        _noticeDetail = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveModules() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      final state = await widget.service.saveEnabledModules(_modules);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = state.snapshot;
        _modules = state.modules;
        _notice = WorkplacePreferencesNotice.none;
        _noticeDetail = null;
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notice = WorkplacePreferencesNotice.saveUnsynced;
        _noticeDetail = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggleModule(int index) {
    final module = _modules[index];
    if (!module.isSelectable) {
      return;
    }

    final nextModules = List<WorkplaceModuleItem>.from(_modules);
    nextModules[index] = module.copyWith(checked: !module.checked);
    setState(() => _modules = nextModules);
  }

  Future<void> _openWorkplaceCatalog() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: widget.workplaceCatalogPageBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return SettingsScaffold(
      title: strings.appModulesPageTitle,
      onSave: _isLoading || _isSaving ? null : _saveModules,
      saveActionKey: const ValueKey<String>('app-modules-save'),
      loading: _isLoading || _isSaving,
      child: RefreshIndicator(
        onRefresh: _loadModules,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            WKSpace.md,
            WKSpace.md,
            WKSpace.md,
            WKSpace.xl,
          ),
          children: [
            SettingsHero(
              icon: Icons.widgets_outlined,
              title: strings.appModulesHeroTitle,
              subtitle: strings.appModulesHeroSubtitle,
            ),
            const SizedBox(height: WKSpace.md),
            SettingsInfoCard(
              key: const ValueKey<String>('app-modules-status'),
              icon: _statusIcon(),
              title: strings.appModulesStatusTitle,
              subtitle: _statusMessage(strings),
              isError: _notice == WorkplacePreferencesNotice.saveUnsynced,
            ),
            const SizedBox(height: WKSpace.md),
            SettingsInfoCard(
              icon: Icons.grid_view_rounded,
              title: strings.workplaceCatalogEntryTitle,
              subtitle: strings.workplaceCatalogEntrySubtitle,
              trailing: OutlinedButton(
                key: const ValueKey<String>('open-workplace-catalog'),
                onPressed: _openWorkplaceCatalog,
                child: Text(strings.workplaceCatalogBrowseAction),
              ),
            ),
            const SizedBox(height: WKSpace.md),
            SettingsSection(
              title: strings.appModulesListSectionTitle,
              children: _modules.isNotEmpty
                  ? <Widget>[
                      for (var index = 0; index < _modules.length; index++)
                        _AppModuleCell(
                          module: _modules[index],
                          onTap: () => _toggleModule(index),
                        ),
                    ]
                  : <Widget>[
                      ListTile(
                        title: Text(strings.appModulesEmptyHint),
                        subtitle: Text(strings.appModulesLoadingHint),
                      ),
                    ],
            ),
            const SizedBox(height: WKSpace.md),
            SettingsInfoCard(
              icon: Icons.info_outline_rounded,
              title: strings.appModulesHeroTitle,
              subtitle: strings.appModulesHelpCopy,
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon() {
    return switch (_notice) {
      WorkplacePreferencesNotice.localDevicePreference =>
        Icons.devices_outlined,
      WorkplacePreferencesNotice.cachedServerFallback =>
        Icons.cloud_off_rounded,
      WorkplacePreferencesNotice.legacyLocalFallback =>
        Icons.history_toggle_off_rounded,
      WorkplacePreferencesNotice.saveUnsynced => Icons.sync_problem_rounded,
      WorkplacePreferencesNotice.none => Icons.cloud_done_outlined,
    };
  }

  String _statusMessage(SettingsStrings strings) {
    if (_isLoading && _modules.isEmpty) {
      return strings.appModulesLoadingHint;
    }
    return switch (_notice) {
      WorkplacePreferencesNotice.localDevicePreference =>
        _localDeviceStatusLabel(),
      WorkplacePreferencesNotice.cachedServerFallback =>
        strings.appModulesLoadFailed(_noticeDetail ?? ''),
      WorkplacePreferencesNotice.legacyLocalFallback =>
        strings.appModulesLoadFailed(_noticeDetail ?? ''),
      WorkplacePreferencesNotice.saveUnsynced => strings.appModulesSaveFailed(
        _noticeDetail ?? '',
      ),
      WorkplacePreferencesNotice.none =>
        _snapshot.updatedAt.trim().isEmpty
            ? strings.appModulesSyncedStatus
            : '${strings.appModulesSyncedStatus} · ${_snapshot.updatedAt.trim()}',
    };
  }

  String _localDeviceStatusLabel() {
    final languageCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    if (languageCode == 'en') {
      return 'Saved on this device';
    }
    return '当前设备偏好';
  }
}

class _AppModuleCell extends StatelessWidget {
  const _AppModuleCell({required this.module, required this.onTap});

  final WorkplaceModuleItem module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = resolveSettingsStrings(
      locale: Localizations.localeOf(context),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('app-module-${module.sid}'),
        onTap: module.isSelectable ? onTap : null,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WKSpace.lg,
            vertical: WKSpace.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name.isEmpty
                          ? strings.appModulesFallbackModuleName
                          : module.name,
                      style: const TextStyle(
                        fontSize: 16,
                        color: WKColors.colorDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (module.desc.trim().isNotEmpty) ...[
                      const SizedBox(height: WKSpace.xs),
                      Text(
                        module.desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: WKColors.color999,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              _ModuleCheck(
                key: ValueKey<String>(
                  'app-module-check-${module.sid}-${module.checked ? "on" : "off"}',
                ),
                checked: module.checked,
                enabled: module.isSelectable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCheck extends StatelessWidget {
  const _ModuleCheck({super.key, required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.8,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: checked ? WKColors.brand500 : WKColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? WKColors.brand500 : WKColors.colorCCC,
            width: 2,
          ),
        ),
        child: checked
            ? const Center(
                child: Icon(Icons.check, size: 12, color: WKColors.white),
              )
            : null,
      ),
    );
  }
}
