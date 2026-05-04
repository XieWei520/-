import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../service/api/collection_api.dart';
import '../settings/settings_strings.dart';
import '../settings/settings_surface_widgets.dart';
import '../../widgets/wk_design_tokens.dart';
import 'favorite_record.dart';

typedef FavoriteRecordOpener = Future<bool> Function(FavoriteRecord record);

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.pageSize = 20, this.onOpenRecord});

  final int pageSize;
  final FavoriteRecordOpener? onOpenRecord;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _deletingIds = <String>{};

  Timer? _searchDebounce;
  List<FavoriteRecord> _records = const <FavoriteRecord>[];
  bool _isLoading = false;
  bool _didScheduleInitialLoad = false;
  String? _errorText;
  int _requestToken = 0;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleInitialLoad) {
      return;
    }
    _didScheduleInitialLoad = true;
    unawaited(_loadFavorites(showLoading: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites({required bool showLoading}) async {
    final requestToken = ++_requestToken;
    final keyword = _searchController.text.trim();
    final strings = _strings;

    if (mounted) {
      setState(() {
        _errorText = null;
        if (showLoading) {
          _isLoading = true;
        }
      });
    }

    try {
      final payload = keyword.isEmpty
          ? await CollectionApi.instance.getList(
              page: 1,
              pageSize: widget.pageSize,
            )
          : await CollectionApi.instance.search(
              keyword: keyword,
              page: 1,
              pageSize: widget.pageSize,
            );
      if (!mounted || requestToken != _requestToken) {
        return;
      }

      final records = payload
          .map(FavoriteRecord.fromMap)
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);

      setState(() {
        _records = records;
        _isLoading = false;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted || requestToken != _requestToken) {
        return;
      }

      if (_records.isNotEmpty && !showLoading) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(strings.favoritesRefreshFailed);
        return;
      }

      setState(() {
        _records = const <FavoriteRecord>[];
        _isLoading = false;
        _errorText = strings.favoritesLoadFailed;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadFavorites(showLoading: false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      unawaited(_loadFavorites(showLoading: true));
    });
  }

  Future<void> _confirmDelete(FavoriteRecord record) async {
    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: ValueKey<String>('favorites-delete-dialog-${record.id}'),
          title: Text(strings.favoritesDeleteTitle),
          content: Text(strings.favoritesDeleteMessage),
          actions: [
            TextButton(
              key: const ValueKey<String>('favorites-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              key: const ValueKey<String>('favorites-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.favoritesDeleteAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _delete(record);
  }

  Future<void> _delete(FavoriteRecord record) async {
    final strings = _strings;
    setState(() {
      _deletingIds.add(record.id);
    });

    try {
      await CollectionApi.instance.delete(record.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingIds.remove(record.id);
        _records = _records
            .where((item) => item.id.trim() != record.id.trim())
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _deletingIds.remove(record.id);
      });
      _showSnackBar(strings.favoritesDeleteFailed);
    }
  }

  Future<void> _handleRecordTap(FavoriteRecord record) async {
    final strings = _strings;
    final opener = widget.onOpenRecord ?? _openRecordExternally;
    final opened = await opener(record);
    if (opened || !mounted) {
      return;
    }
    _showSnackBar(
      record.canOpenExternally
          ? strings.favoritesOpenFailed
          : strings.favoritesUnsupportedOpen,
    );
  }

  Future<bool> _openRecordExternally(FavoriteRecord record) async {
    final uri = record.externalUri;
    if (uri == null) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showSnackBar(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final listKey = _records.isNotEmpty
        ? const ValueKey<String>('favorites-list')
        : _errorText == null
        ? const ValueKey<String>('favorites-empty-scroll')
        : null;

    return SettingsScaffold(
      title: strings.favoritesPageTitle,
      loading: _isLoading && _records.isEmpty,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            key: listKey,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              WKSpace.md,
              WKSpace.md,
              WKSpace.md,
              WKSpace.xl,
            ),
            children: [
              SettingsHero(
                icon: Icons.bookmark_outline_rounded,
                title: strings.favoritesHeroTitle,
                subtitle: strings.favoritesHeroSubtitle,
              ),
              const SizedBox(height: WKSpace.md),
              SettingsSearchCard(
                controller: _searchController,
                fieldKey: const ValueKey<String>('favorites-search-box'),
                hintText: strings.favoritesSearchHint,
                onChanged: (value) {
                  _onSearchChanged(value);
                  setState(() {});
                },
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  setState(() {});
                },
              ),
              const SizedBox(height: WKSpace.md),
              ..._buildContent(strings),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(SettingsStrings strings) {
    if (_isLoading && _records.isEmpty) {
      return <Widget>[
        SettingsInfoCard(
          key: const ValueKey<String>('favorites-loading'),
          icon: Icons.hourglass_top_rounded,
          title: strings.favoritesLoadingHint,
          subtitle: strings.favoritesHeroSubtitle,
          trailing: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    if (_errorText != null && _records.isEmpty) {
      return <Widget>[
        SettingsInfoCard(
          key: const ValueKey<String>('favorites-error-state'),
          icon: Icons.error_outline_rounded,
          title: strings.favoritesLoadFailed,
          subtitle: _errorText!,
          isError: true,
        ),
        const SizedBox(height: WKSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const ValueKey<String>('favorites-retry-button'),
            onPressed: () => _loadFavorites(showLoading: true),
            child: Text(strings.favoritesRetry),
          ),
        ),
      ];
    }

    if (_records.isEmpty) {
      return <Widget>[
        SettingsInfoCard(
          key: const ValueKey<String>('favorites-empty-state'),
          icon: Icons.bookmark_border_rounded,
          title: strings.favoritesEmptyTitle,
          subtitle: strings.favoritesEmptySubtitle,
        ),
      ];
    }

    return <Widget>[
      SettingsSection(
        title: strings.favoritesPageTitle,
        children: [
          for (final record in _records) _buildRecordRow(record, strings),
        ],
      ),
    ];
  }

  Widget _buildRecordRow(FavoriteRecord record, SettingsStrings strings) {
    final title = record.content.trim().isNotEmpty ? record.content : record.title;
    final detailParts = <String>[
      if (record.title.trim().isNotEmpty && record.title.trim() != title.trim())
        record.title,
      if (record.subtitle.trim().isNotEmpty) record.subtitle,
    ];
    final deleting = _deletingIds.contains(record.id);

    return ListTile(
      key: ValueKey<String>('favorites-row-${record.id}'),
      onTap: () => _handleRecordTap(record),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: detailParts.isEmpty
          ? null
          : Text(
              detailParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: deleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              key: ValueKey<String>('favorites-delete-${record.id}'),
              onPressed: () => _confirmDelete(record),
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.favoritesDeleteTooltip,
            ),
    );
  }
}
