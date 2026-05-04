class WorkplaceModuleStatus {
  WorkplaceModuleStatus._();

  static const int disabled = 0;
  static const int selectable = 1;
  static const int fixed = 2;
}

enum WorkplacePreferencesNotice {
  none,
  localDevicePreference,
  cachedServerFallback,
  legacyLocalFallback,
  saveUnsynced,
}

class WorkplacePreferencesSnapshot {
  final List<String> enabledModuleSids;
  final List<String> addedAppIds;
  final List<String> orderedAppIds;
  final List<String> recordAppIds;
  final String updatedAt;
  final int version;

  const WorkplacePreferencesSnapshot({
    this.enabledModuleSids = const <String>[],
    this.addedAppIds = const <String>[],
    this.orderedAppIds = const <String>[],
    this.recordAppIds = const <String>[],
    this.updatedAt = '',
    this.version = 0,
  });

  factory WorkplacePreferencesSnapshot.fromJson(Map<String, dynamic> json) {
    return WorkplacePreferencesSnapshot(
      enabledModuleSids: _toNormalizedStringList(json['enabled_module_sids']),
      addedAppIds: _toNormalizedStringList(json['added_app_ids']),
      orderedAppIds: _toNormalizedStringList(json['ordered_app_ids']),
      recordAppIds: _toNormalizedStringList(json['record_app_ids']),
      updatedAt: _toString(json['updated_at'] ?? json['updatedAt']),
      version: _toInt(json['version']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled_module_sids': enabledModuleSids,
      'added_app_ids': addedAppIds,
      'ordered_app_ids': orderedAppIds,
      'record_app_ids': recordAppIds,
      'updated_at': updatedAt,
      'version': version,
    };
  }
}

class WorkplaceModuleItem {
  final String sid;
  final String name;
  final String desc;
  final int status;
  final bool checked;

  const WorkplaceModuleItem({
    required this.sid,
    required this.name,
    required this.desc,
    required this.status,
    required this.checked,
  });

  bool get isSelectable => status == WorkplaceModuleStatus.selectable;

  bool get isDisabled => status == WorkplaceModuleStatus.disabled;

  bool get isFixedEnabled => status == WorkplaceModuleStatus.fixed;

  WorkplaceModuleItem copyWith({bool? checked}) {
    return WorkplaceModuleItem(
      sid: sid,
      name: name,
      desc: desc,
      status: status,
      checked: checked ?? this.checked,
    );
  }
}

class WorkplaceModuleScreenState {
  final WorkplacePreferencesSnapshot snapshot;
  final List<WorkplaceModuleItem> modules;
  final WorkplacePreferencesNotice notice;
  final String? noticeDetail;

  const WorkplaceModuleScreenState({
    required this.snapshot,
    required this.modules,
    this.notice = WorkplacePreferencesNotice.none,
    this.noticeDetail,
  });

  bool get isFromCache =>
      notice == WorkplacePreferencesNotice.cachedServerFallback ||
      notice == WorkplacePreferencesNotice.legacyLocalFallback;

  String? get statusMessage => noticeDetail;
}

List<String> _toNormalizedStringList(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  final normalized = <String>[];
  for (final item in raw) {
    final value = item.toString().trim();
    if (value.isEmpty || normalized.contains(value)) {
      continue;
    }
    normalized.add(value);
  }
  return normalized;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _toString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}
