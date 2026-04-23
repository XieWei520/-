import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_strings.dart';
import '../settings/settings_surface_widgets.dart';
import '../../wukong_scan/scan_webview_page.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'workplace_catalog_models.dart';
import 'workplace_catalog_service.dart';

typedef WorkplaceCatalogUrlLauncher = Future<bool> Function(Uri uri);
typedef WorkplaceCatalogWebviewPageBuilder = Widget Function(String url);

class WorkplaceCatalogPage extends StatefulWidget {
  WorkplaceCatalogPage({
    super.key,
    WorkplaceCatalogService? service,
    this.launchUrlExternally,
    this.buildWebviewPage,
  }) : service = service ?? WorkplaceCatalogService();

  final WorkplaceCatalogService service;
  final WorkplaceCatalogUrlLauncher? launchUrlExternally;
  final WorkplaceCatalogWebviewPageBuilder? buildWebviewPage;

  @override
  State<WorkplaceCatalogPage> createState() => _WorkplaceCatalogPageState();
}

class _WorkplaceCatalogPageState extends State<WorkplaceCatalogPage> {
  WorkplaceCatalogState _state = const WorkplaceCatalogState();
  final Set<String> _busyAppIds = <String>{};
  bool _isLoading = true;
  bool _isReorderingAddedApps = false;
  String? _errorMessage;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  WorkplaceCatalogUrlLauncher get _launchUrlExternally =>
      widget.launchUrlExternally ?? _defaultLaunchUrlExternally;
  WorkplaceCatalogWebviewPageBuilder get _buildWebviewPage =>
      widget.buildWebviewPage ?? _defaultBuildWebviewPage;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalog = await widget.service.loadCatalog(
        preferredCategoryNo: _state.selectedCategoryNo,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _state = catalog;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCategory(String categoryNo) async {
    final normalized = categoryNo.trim();
    if (normalized.isEmpty || _busyAppIds.isNotEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nextState = await widget.service.selectCategory(_state, normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = nextState;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
      _showSnackBar('${_strings.operationFailedPrefix}$error');
    }
  }

  Future<void> _toggleApp(WorkplaceApp app) async {
    final appId = app.appId.trim();
    if (appId.isEmpty ||
        _busyAppIds.contains(appId) ||
        _isReorderingAddedApps) {
      return;
    }

    setState(() => _busyAppIds.add(appId));
    try {
      final nextState = await widget.service.toggleAppMembership(_state, app);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = nextState;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar('${_strings.operationFailedPrefix}$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAppIds.remove(appId));
      }
    }
  }

  Future<void> _openApp(WorkplaceApp app) async {
    final appId = app.appId.trim();
    if (appId.isEmpty ||
        _busyAppIds.contains(appId) ||
        _isReorderingAddedApps) {
      return;
    }

    final inAppUrl = _resolveEmbeddableWebUrl(_orderedAppRouteCandidates(app));
    final externalUrl = inAppUrl.isEmpty
        ? _resolveExternalUrl(_orderedAppRouteCandidates(app))
        : '';
    if (inAppUrl.isEmpty && externalUrl.isEmpty) {
      final pendingRoute = app.appRoute.trim();
      if (pendingRoute.isNotEmpty) {
        _showSnackBar(
          _strings.workplaceCatalogPendingNativeRoute(pendingRoute),
        );
      } else {
        _showSnackBar(_strings.workplaceCatalogNoLaunchRoute);
      }
      return;
    }

    final uri = externalUrl.isEmpty ? null : Uri.tryParse(externalUrl);
    if (inAppUrl.isEmpty && uri == null) {
      _showSnackBar(_strings.workplaceCatalogOpenFailed(externalUrl));
      return;
    }

    setState(() => _busyAppIds.add(appId));
    try {
      if (inAppUrl.isNotEmpty) {
        if (mounted) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => _buildWebviewPage(inAppUrl)));
        }
      } else {
        final opened = await _launchUrlExternally(uri!);
        if (!opened) {
          if (mounted) {
            _showSnackBar(
              _strings.workplaceCatalogOpenFailed(
                _strings.workplaceCatalogNoLaunchRoute,
              ),
            );
          }
          return;
        }
      }

      final nextState = await widget.service.recordAppUsage(_state, app);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = nextState;
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        _showSnackBar(_strings.workplaceCatalogOpenFailed(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyAppIds.remove(appId));
      }
    }
  }

  Future<void> _openBanner(WorkplaceBanner banner) async {
    final route = banner.route.trim();
    final inAppUrl = _resolveEmbeddableWebUrl(<String>[route]);
    if (inAppUrl.isNotEmpty) {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _buildWebviewPage(inAppUrl)));
      return;
    }

    final externalUrl = _resolveExternalUrl(<String>[route]);
    if (externalUrl.isEmpty) {
      if (route.isNotEmpty) {
        _showSnackBar(_strings.workplaceCatalogPendingNativeRoute(route));
      } else {
        _showSnackBar(_strings.workplaceCatalogNoLaunchRoute);
      }
      return;
    }

    final uri = Uri.tryParse(externalUrl);
    if (uri == null) {
      _showSnackBar(_strings.workplaceCatalogOpenFailed(route));
      return;
    }
    final opened = await _launchUrlExternally(uri);
    if (!opened && mounted) {
      _showSnackBar(
        _strings.workplaceCatalogOpenFailed(
          _strings.workplaceCatalogNoLaunchRoute,
        ),
      );
    }
  }

  Future<void> _reorderAddedApps(int oldIndex, int newIndex) async {
    if (_isReorderingAddedApps || _busyAppIds.isNotEmpty) {
      return;
    }

    setState(() {
      _isReorderingAddedApps = true;
      _errorMessage = null;
    });

    try {
      final nextState = await widget.service.reorderAddedApps(
        _state,
        oldIndex,
        newIndex,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _state = nextState;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
      _showSnackBar('${_strings.operationFailedPrefix}$error');
    } finally {
      if (mounted) {
        setState(() => _isReorderingAddedApps = false);
      }
    }
  }

  Future<void> _moveAddedApp(int index, int offset) async {
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= _state.addedApps.length) {
      return;
    }
    final newIndex = offset < 0 ? targetIndex : targetIndex + 1;
    await _reorderAddedApps(index, newIndex);
  }

  List<String> _orderedAppRouteCandidates(WorkplaceApp app) {
    final candidates = <String>[];
    if (app.jumpType == 0) {
      candidates.add(app.webRoute.trim());
      candidates.add(app.appRoute.trim());
    } else {
      candidates.add(app.appRoute.trim());
      candidates.add(app.webRoute.trim());
    }
    return candidates;
  }

  String _resolveEmbeddableWebUrl(List<String> candidates) {
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (_isEmbeddableWebUri(uri)) {
        return candidate;
      }
    }
    return '';
  }

  String _resolveExternalUrl(List<String> candidates) {
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri != null && uri.hasScheme && uri.host.trim().isNotEmpty) {
        return candidate;
      }
    }
    return '';
  }

  bool _isEmbeddableWebUri(Uri? uri) {
    if (uri == null || uri.host.trim().isEmpty) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _defaultBuildWebviewPage(String url) {
    return ScanWebviewPage(initialUrl: url);
  }

  Future<bool> _defaultLaunchUrlExternally(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return SettingsScaffold(
      title: strings.workplaceCatalogPageTitle,
      loading: _isLoading,
      child: RefreshIndicator(
        onRefresh: _loadCatalog,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            WKSpace.md,
            WKSpace.md,
            WKSpace.md,
            WKSpace.xl,
          ),
          children: [
            SettingsHero(
              icon: Icons.grid_view_rounded,
              title: strings.workplaceCatalogHeroTitle,
              subtitle: strings.workplaceCatalogHeroSubtitle,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: WKSpace.md),
              SettingsInfoCard(
                icon: Icons.error_outline_rounded,
                title: strings.workplaceCatalogPageTitle,
                subtitle: '${strings.operationFailedPrefix}${_errorMessage!}',
                isError: true,
              ),
            ],
            const SizedBox(height: WKSpace.md),
            _buildBannerSection(strings),
            const SizedBox(height: WKSpace.md),
            _buildAddedAppsSection(strings),
            const SizedBox(height: WKSpace.md),
            _buildAppSection(
              title: strings.workplaceCatalogRecentSectionTitle,
              apps: _state.recentApps,
              emptyHint: strings.workplaceCatalogEmptyHint,
              itemKeyPrefix: 'workplace-recent-app',
            ),
            const SizedBox(height: WKSpace.md),
            _buildCategorySection(strings),
            const SizedBox(height: WKSpace.md),
            _buildAppSection(
              title: strings.workplaceCatalogCategoryAppsSectionTitle,
              apps: _state.categoryApps,
              emptyHint: strings.workplaceCatalogEmptyHint,
              itemKeyPrefix: 'workplace-category-app',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection(SettingsStrings strings) {
    if (_state.banners.isEmpty) {
      return SettingsInfoCard(
        icon: Icons.campaign_outlined,
        title: strings.workplaceCatalogBannersSectionTitle,
        subtitle: strings.workplaceCatalogEmptyHint,
      );
    }

    return SettingsSection(
      title: strings.workplaceCatalogBannersSectionTitle,
      children: <Widget>[
        SizedBox(
          height: 182,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              WKSpace.lg,
              0,
              WKSpace.lg,
              WKSpace.lg,
            ),
            itemBuilder: (context, index) {
              final banner = _state.banners[index];
              return _BannerCard(
                key: ValueKey<String>('workplace-banner-${banner.bannerNo}'),
                banner: banner,
                onTap: () => _openBanner(banner),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: WKSpace.md),
            itemCount: _state.banners.length,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(SettingsStrings strings) {
    if (_state.categories.isEmpty) {
      return SettingsInfoCard(
        icon: Icons.category_outlined,
        title: strings.workplaceCatalogCategoriesSectionTitle,
        subtitle: strings.workplaceCatalogEmptyHint,
      );
    }

    return SettingsSection(
      title: strings.workplaceCatalogCategoriesSectionTitle,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WKSpace.lg,
            WKSpace.sm,
            WKSpace.lg,
            WKSpace.lg,
          ),
          child: Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.sm,
            children: [
              for (final category in _state.categories)
                ChoiceChip(
                  key: ValueKey<String>(
                    'workplace-category-${category.categoryNo}',
                  ),
                  label: Text(
                    category.name.isEmpty ? category.categoryNo : category.name,
                  ),
                  selected: _state.selectedCategoryNo == category.categoryNo,
                  onSelected: (_) => _selectCategory(category.categoryNo),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddedAppsSection(SettingsStrings strings) {
    if (_state.addedApps.isEmpty) {
      return SettingsSection(
        title: strings.workplaceCatalogMyAppsSectionTitle,
        children: <Widget>[
          ListTile(
            title: Text(strings.workplaceCatalogEmptyHint),
            leading: const Icon(Icons.apps_outlined, color: WKColors.color999),
          ),
        ],
      );
    }

    return SettingsSection(
      title: strings.workplaceCatalogMyAppsSectionTitle,
      children: <Widget>[
        for (var index = 0; index < _state.addedApps.length; index++)
          _WorkplaceAppTile(
            key: ValueKey<String>(
              'workplace-my-app-${_state.addedApps[index].appId}',
            ),
            app: _state.addedApps[index],
            busy:
                _busyAppIds.contains(_state.addedApps[index].appId) ||
                _isReorderingAddedApps,
            onToggle: () => _toggleApp(_state.addedApps[index]),
            onOpen: () => _openApp(_state.addedApps[index]),
            addLabel: strings.workplaceCatalogAddAction,
            removeLabel: strings.workplaceCatalogRemoveAction,
            openLabel: strings.workplaceCatalogOpenAction,
            iconKey: ValueKey<String>(
              'workplace-my-app-icon-${_state.addedApps[index].appId}',
            ),
            moveUpAction: index > 0 ? () => _moveAddedApp(index, -1) : null,
            moveDownAction: index < _state.addedApps.length - 1
                ? () => _moveAddedApp(index, 1)
                : null,
          ),
      ],
    );
  }

  Widget _buildAppSection({
    required String title,
    required List<WorkplaceApp> apps,
    required String emptyHint,
    required String itemKeyPrefix,
  }) {
    return SettingsSection(
      title: title,
      children: apps.isEmpty
          ? <Widget>[
              ListTile(
                title: Text(emptyHint),
                leading: const Icon(
                  Icons.apps_outlined,
                  color: WKColors.color999,
                ),
              ),
            ]
          : <Widget>[
              for (final app in apps)
                _WorkplaceAppTile(
                  key: ValueKey<String>('$itemKeyPrefix-${app.appId}'),
                  app: app,
                  busy: _busyAppIds.contains(app.appId),
                  onToggle: () => _toggleApp(app),
                  onOpen: () => _openApp(app),
                  addLabel: _strings.workplaceCatalogAddAction,
                  removeLabel: _strings.workplaceCatalogRemoveAction,
                  openLabel: _strings.workplaceCatalogOpenAction,
                  iconKey: ValueKey<String>('$itemKeyPrefix-icon-${app.appId}'),
                ),
            ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({super.key, required this.banner, required this.onTap});

  final WorkplaceBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: Material(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(WKRadius.xl),
          child: Container(
            padding: const EdgeInsets.all(WKSpace.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WKRadius.xl),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFEAF7FF), Color(0xFFF8FBFF)],
              ),
              border: Border.all(color: WKColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBannerVisual(),
                const SizedBox(height: WKSpace.md),
                Text(
                  banner.title.isEmpty ? banner.bannerNo : banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: WKSpace.xs),
                Expanded(
                  child: Text(
                    banner.description.isEmpty
                        ? banner.route
                        : banner.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: WKColors.color999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerVisual() {
    final cover = banner.cover.trim();
    if (cover.isEmpty) {
      return _buildBannerFallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(WKRadius.lg),
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: Image.network(
          cover,
          key: ValueKey<String>('workplace-banner-cover-${banner.bannerNo}'),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildBannerFallback(),
        ),
      ),
    );
  }

  Widget _buildBannerFallback() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: WKColors.brand50,
        borderRadius: BorderRadius.circular(WKRadius.lg),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.rocket_launch_outlined, color: WKColors.brand500),
    );
  }
}

class _WorkplaceAppTile extends StatelessWidget {
  const _WorkplaceAppTile({
    super.key,
    required this.app,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
    required this.addLabel,
    required this.removeLabel,
    required this.openLabel,
    required this.iconKey,
    this.moveUpAction,
    this.moveDownAction,
  });

  final WorkplaceApp app;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final String addLabel;
  final String removeLabel;
  final String openLabel;
  final Key iconKey;
  final VoidCallback? moveUpAction;
  final VoidCallback? moveDownAction;

  @override
  Widget build(BuildContext context) {
    final title = app.name.trim().isEmpty ? app.appId : app.name;
    final subtitle = app.description.trim().isEmpty
        ? (app.webRoute.trim().isNotEmpty ? app.webRoute : app.appRoute)
        : app.description;
    final showReorderControls = moveUpAction != null || moveDownAction != null;
    return ListTile(
      leading: _buildIconAvatar(title),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: WKSpace.xs,
        children: [
          TextButton(
            key: ValueKey<String>('workplace-app-open-${app.appId}'),
            onPressed: busy ? null : onOpen,
            child: Text(openLabel),
          ),
          FilledButton.tonal(
            key: ValueKey<String>('workplace-app-toggle-${app.appId}'),
            onPressed: busy ? null : onToggle,
            child: Text(app.isAdded ? removeLabel : addLabel),
          ),
          if (showReorderControls)
            IconButton(
              key: ValueKey<String>('workplace-app-move-up-${app.appId}'),
              onPressed: busy ? null : moveUpAction,
              icon: const Icon(Icons.arrow_upward_rounded),
              color: WKColors.color999,
            ),
          if (showReorderControls)
            IconButton(
              key: ValueKey<String>('workplace-app-move-down-${app.appId}'),
              onPressed: busy ? null : moveDownAction,
              icon: const Icon(Icons.arrow_downward_rounded),
              color: WKColors.color999,
            ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WKSpace.lg,
        vertical: WKSpace.xs,
      ),
    );
  }

  Widget _buildIconAvatar(String title) {
    final icon = app.icon.trim();
    if (icon.isEmpty) {
      return _buildFallbackAvatar(title);
    }
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.network(
          icon,
          key: iconKey,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(title),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String title) {
    return CircleAvatar(
      backgroundColor: WKColors.brand50,
      foregroundColor: WKColors.brand500,
      child: Text(
        title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
