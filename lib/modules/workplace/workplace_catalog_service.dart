import 'package:flutter/foundation.dart';

import '../../service/api/workplace_api.dart';
import 'workplace_catalog_models.dart';

@immutable
class WorkplaceCatalogState {
  const WorkplaceCatalogState({
    this.banners = const <WorkplaceBanner>[],
    this.addedApps = const <WorkplaceApp>[],
    this.recentApps = const <WorkplaceApp>[],
    this.categories = const <WorkplaceCategory>[],
    this.selectedCategoryNo = '',
    this.categoryApps = const <WorkplaceApp>[],
  });

  final List<WorkplaceBanner> banners;
  final List<WorkplaceApp> addedApps;
  final List<WorkplaceApp> recentApps;
  final List<WorkplaceCategory> categories;
  final String selectedCategoryNo;
  final List<WorkplaceApp> categoryApps;

  WorkplaceCatalogState copyWith({
    List<WorkplaceBanner>? banners,
    List<WorkplaceApp>? addedApps,
    List<WorkplaceApp>? recentApps,
    List<WorkplaceCategory>? categories,
    String? selectedCategoryNo,
    List<WorkplaceApp>? categoryApps,
  }) {
    return WorkplaceCatalogState(
      banners: banners ?? this.banners,
      addedApps: addedApps ?? this.addedApps,
      recentApps: recentApps ?? this.recentApps,
      categories: categories ?? this.categories,
      selectedCategoryNo: selectedCategoryNo ?? this.selectedCategoryNo,
      categoryApps: categoryApps ?? this.categoryApps,
    );
  }
}

class WorkplaceCatalogService {
  WorkplaceCatalogService({
    Future<List<WorkplaceBanner>> Function()? fetchBanners,
    Future<List<WorkplaceApp>> Function()? fetchAddedApps,
    Future<List<WorkplaceApp>> Function()? fetchRecordedApps,
    Future<List<WorkplaceCategory>> Function()? fetchCategories,
    Future<List<WorkplaceApp>> Function(String categoryNo)? fetchAppsByCategory,
    Future<void> Function(String appId)? addApp,
    Future<void> Function(String appId)? removeApp,
    Future<void> Function(List<String> appIds)? reorderApps,
    Future<void> Function(String appId)? addRecord,
  }) : _fetchBanners = fetchBanners ?? WorkplaceApi.instance.fetchBanners,
       _fetchAddedApps = fetchAddedApps ?? WorkplaceApi.instance.fetchAddedApps,
       _fetchRecordedApps =
           fetchRecordedApps ?? WorkplaceApi.instance.fetchRecordedApps,
       _fetchCategories =
           fetchCategories ?? WorkplaceApi.instance.fetchCategories,
       _fetchAppsByCategory =
           fetchAppsByCategory ?? WorkplaceApi.instance.fetchAppsByCategory,
       _addApp = addApp ?? WorkplaceApi.instance.addApp,
       _removeApp = removeApp ?? WorkplaceApi.instance.removeApp,
       _reorderApps = reorderApps ?? WorkplaceApi.instance.reorderApps,
       _addRecord = addRecord ?? WorkplaceApi.instance.addRecord;

  final Future<List<WorkplaceBanner>> Function() _fetchBanners;
  final Future<List<WorkplaceApp>> Function() _fetchAddedApps;
  final Future<List<WorkplaceApp>> Function() _fetchRecordedApps;
  final Future<List<WorkplaceCategory>> Function() _fetchCategories;
  final Future<List<WorkplaceApp>> Function(String categoryNo)
  _fetchAppsByCategory;
  final Future<void> Function(String appId) _addApp;
  final Future<void> Function(String appId) _removeApp;
  final Future<void> Function(List<String> appIds) _reorderApps;
  final Future<void> Function(String appId) _addRecord;

  Future<WorkplaceCatalogState> loadCatalog({
    String? preferredCategoryNo,
  }) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _fetchBanners(),
      _fetchAddedApps(),
      _fetchRecordedApps(),
      _fetchCategories(),
    ]);

    final banners = _sortBanners(
      List<WorkplaceBanner>.from(results[0] as List),
    );
    final addedApps = _sortApps(List<WorkplaceApp>.from(results[1] as List));
    final recentApps = _sortApps(List<WorkplaceApp>.from(results[2] as List));
    final categories = _sortCategories(
      List<WorkplaceCategory>.from(results[3] as List),
    );
    final selectedCategoryNo = _selectCategoryNo(
      preferredCategoryNo: preferredCategoryNo,
      categories: categories,
    );

    final categoryApps = selectedCategoryNo.isEmpty
        ? const <WorkplaceApp>[]
        : _sortApps(await _fetchAppsByCategory(selectedCategoryNo));

    return _normalizeState(
      WorkplaceCatalogState(
        banners: banners,
        addedApps: addedApps,
        recentApps: recentApps,
        categories: categories,
        selectedCategoryNo: selectedCategoryNo,
        categoryApps: categoryApps,
      ),
    );
  }

  Future<WorkplaceCatalogState> selectCategory(
    WorkplaceCatalogState current,
    String categoryNo,
  ) async {
    final normalizedCategoryNo = categoryNo.trim();
    if (normalizedCategoryNo.isEmpty ||
        normalizedCategoryNo == current.selectedCategoryNo) {
      return current;
    }

    final apps = _sortApps(await _fetchAppsByCategory(normalizedCategoryNo));
    return _normalizeState(
      current.copyWith(
        selectedCategoryNo: normalizedCategoryNo,
        categoryApps: apps,
      ),
    );
  }

  Future<WorkplaceCatalogState> toggleAppMembership(
    WorkplaceCatalogState current,
    WorkplaceApp app,
  ) async {
    final appId = app.appId.trim();
    if (appId.isEmpty) {
      return current;
    }

    if (app.isAdded) {
      await _removeApp(appId);
    } else {
      await _addApp(appId);
    }

    final addedApps = _sortApps(await _fetchAddedApps());
    final categoryApps = current.selectedCategoryNo.isEmpty
        ? current.categoryApps
        : _sortApps(await _fetchAppsByCategory(current.selectedCategoryNo));

    return _normalizeState(
      current.copyWith(addedApps: addedApps, categoryApps: categoryApps),
    );
  }

  Future<WorkplaceCatalogState> reorderAddedApps(
    WorkplaceCatalogState current,
    int oldIndex,
    int newIndex,
  ) async {
    if (current.addedApps.length < 2 ||
        oldIndex < 0 ||
        oldIndex >= current.addedApps.length ||
        newIndex < 0 ||
        newIndex > current.addedApps.length) {
      return current;
    }

    final reordered = List<WorkplaceApp>.from(current.addedApps);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await _reorderApps(
      reordered.map((app) => app.appId).toList(growable: false),
    );
    return _normalizeState(
      current.copyWith(addedApps: List<WorkplaceApp>.unmodifiable(reordered)),
      preserveAddedOrder: true,
    );
  }

  Future<WorkplaceCatalogState> recordAppUsage(
    WorkplaceCatalogState current,
    WorkplaceApp app,
  ) async {
    final appId = app.appId.trim();
    if (appId.isEmpty) {
      return current;
    }

    await _addRecord(appId);
    final recentApps = _sortApps(await _fetchRecordedApps());
    return _normalizeState(current.copyWith(recentApps: recentApps));
  }

  WorkplaceCatalogState _normalizeState(
    WorkplaceCatalogState state, {
    bool preserveAddedOrder = false,
  }) {
    final addedAppIds = state.addedApps
        .map((app) => app.appId.trim())
        .where((appId) => appId.isNotEmpty)
        .toSet();
    return state.copyWith(
      addedApps: preserveAddedOrder
          ? List<WorkplaceApp>.unmodifiable(
              _mergeAddedFlags(state.addedApps, addedAppIds),
            )
          : _sortApps(_mergeAddedFlags(state.addedApps, addedAppIds)),
      recentApps: _sortApps(_mergeAddedFlags(state.recentApps, addedAppIds)),
      categoryApps: _sortApps(
        _mergeAddedFlags(state.categoryApps, addedAppIds),
      ),
    );
  }

  List<WorkplaceApp> _mergeAddedFlags(
    List<WorkplaceApp> apps,
    Set<String> addedAppIds,
  ) {
    return apps
        .map(
          (app) =>
              app.copyWith(isAdded: addedAppIds.contains(app.appId.trim())),
        )
        .toList(growable: false);
  }

  String _selectCategoryNo({
    required String? preferredCategoryNo,
    required List<WorkplaceCategory> categories,
  }) {
    final normalizedPreferred = preferredCategoryNo?.trim() ?? '';
    if (normalizedPreferred.isNotEmpty &&
        categories.any((item) => item.categoryNo == normalizedPreferred)) {
      return normalizedPreferred;
    }
    return categories.isEmpty ? '' : categories.first.categoryNo;
  }

  List<WorkplaceBanner> _sortBanners(List<WorkplaceBanner> banners) {
    final sorted = List<WorkplaceBanner>.from(banners);
    sorted.sort((left, right) => left.sortNum.compareTo(right.sortNum));
    return List<WorkplaceBanner>.unmodifiable(sorted);
  }

  List<WorkplaceCategory> _sortCategories(List<WorkplaceCategory> categories) {
    final sorted = List<WorkplaceCategory>.from(categories);
    sorted.sort((left, right) => left.sortNum.compareTo(right.sortNum));
    return List<WorkplaceCategory>.unmodifiable(sorted);
  }

  List<WorkplaceApp> _sortApps(List<WorkplaceApp> apps) {
    final sorted = List<WorkplaceApp>.from(apps);
    sorted.sort((left, right) {
      final sortCompare = left.sortNum.compareTo(right.sortNum);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return left.name.compareTo(right.name);
    });
    return List<WorkplaceApp>.unmodifiable(sorted);
  }
}
