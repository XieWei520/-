enum LaunchPlatform {
  android,
  windows;

  String get wireName => name;

  static LaunchPlatform? fromWireName(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'android' => LaunchPlatform.android,
      'win' || 'pc' || 'windows' => LaunchPlatform.windows,
      _ => null,
    };
  }
}

enum StartupNoticeFrequency {
  everyStart('every_start'),
  daily('daily'),
  once('once');

  const StartupNoticeFrequency(this.wireName);

  final String wireName;

  static StartupNoticeFrequency fromWireName(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'daily' => StartupNoticeFrequency.daily,
      'once' => StartupNoticeFrequency.once,
      _ => StartupNoticeFrequency.everyStart,
    };
  }
}

class LaunchPolicyResponse {
  const LaunchPolicyResponse({
    this.serverTime,
    this.platform,
    this.version = '',
    this.build = 0,
    this.versionPolicy,
    this.startupNotice,
  });

  factory LaunchPolicyResponse.fromJson(Map<String, dynamic> json) {
    return LaunchPolicyResponse(
      serverTime: _readDateTime(json['serverTime'] ?? json['server_time']),
      platform: LaunchPlatform.fromWireName(json['platform']?.toString()),
      version: _readString(json['version']),
      build: _readInt(json['build']),
      versionPolicy: _readVersionPolicy(json['versionPolicy']),
      startupNotice: _readStartupNotice(json['startupNotice']),
    );
  }

  final DateTime? serverTime;
  final LaunchPlatform? platform;
  final String version;
  final int build;
  final VersionPolicy? versionPolicy;
  final StartupNotice? startupNotice;
}

class VersionPolicy {
  const VersionPolicy({
    required this.platform,
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumVersion,
    required this.minimumBuild,
    required this.forceUpgrade,
    required this.updateUrl,
    required this.title,
    required this.message,
  });

  factory VersionPolicy.fromJson(Map<String, dynamic> json) {
    final platform = LaunchPlatform.fromWireName(
      _readString(json['platform'] ?? json['os']),
    );
    if (platform == null) {
      throw const FormatException('Unsupported version policy platform');
    }
    return VersionPolicy(
      platform: platform,
      latestVersion: _readString(
        json['latestVersion'] ?? json['latest_version'] ?? json['app_version'],
      ),
      latestBuild: _readInt(
        json['latestBuild'] ?? json['latest_build'] ?? json['build_number'],
      ),
      minimumVersion: _readString(
        json['minimumVersion'] ??
            json['minimum_version'] ??
            json['min_version'],
      ),
      minimumBuild: _readInt(
        json['minimumBuild'] ??
            json['minimum_build'] ??
            json['minimum_build_number'],
      ),
      forceUpgrade: _readBool(
        json['forceUpgrade'] ?? json['force_upgrade'] ?? json['is_force'],
      ),
      updateUrl: _readString(
        json['updateUrl'] ?? json['update_url'] ?? json['download_url'],
      ),
      title: _readString(json['title']).isNotEmpty
          ? _readString(json['title'])
          : '发现新版本',
      message: _readString(
        json['message'] ?? json['update_desc'] ?? json['updateDesc'],
      ),
    );
  }

  final LaunchPlatform platform;
  final String latestVersion;
  final int latestBuild;
  final String minimumVersion;
  final int minimumBuild;
  final bool forceUpgrade;
  final String updateUrl;
  final String title;
  final String message;

  bool requiresForcedUpgrade(int currentBuild) {
    return forceUpgrade && minimumBuild > 0 && currentBuild < minimumBuild;
  }
}

class StartupNotice {
  const StartupNotice({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl = '',
    this.platforms = const <LaunchPlatform>[],
    required this.frequency,
    this.startAt,
    this.endAt,
  });

  factory StartupNotice.fromJson(Map<String, dynamic> json) {
    final id = _readString(json['id'] ?? json['notice_id']);
    final title = _readString(json['title']);
    final content = _readString(json['content']);
    if (id.isEmpty || title.isEmpty || content.isEmpty) {
      throw const FormatException('Startup notice requires id, title, content');
    }
    return StartupNotice(
      id: id,
      title: title,
      content: content,
      imageUrl: _readString(json['imageUrl'] ?? json['image_url']),
      platforms: _readPlatforms(json['platforms']),
      frequency: StartupNoticeFrequency.fromWireName(
        json['frequency']?.toString(),
      ),
      startAt: _readDateTime(json['startAt'] ?? json['start_at']),
      endAt: _readDateTime(json['endAt'] ?? json['end_at']),
    );
  }

  final String id;
  final String title;
  final String content;
  final String imageUrl;
  final List<LaunchPlatform> platforms;
  final StartupNoticeFrequency frequency;
  final DateTime? startAt;
  final DateTime? endAt;

  bool isActiveAt(DateTime now) {
    final start = startAt;
    final end = endAt;
    if (start != null && now.isBefore(start)) {
      return false;
    }
    if (end != null && now.isAfter(end)) {
      return false;
    }
    return true;
  }
}

VersionPolicy? _readVersionPolicy(dynamic value) {
  if (value is! Map) {
    return null;
  }
  try {
    return VersionPolicy.fromJson(Map<String, dynamic>.from(value));
  } catch (_) {
    return null;
  }
}

StartupNotice? _readStartupNotice(dynamic value) {
  if (value is! Map) {
    return null;
  }
  try {
    return StartupNotice.fromJson(Map<String, dynamic>.from(value));
  } catch (_) {
    return null;
  }
}

List<LaunchPlatform> _readPlatforms(dynamic value) {
  if (value is String && value.trim().toLowerCase() == 'all') {
    return const <LaunchPlatform>[];
  }
  if (value is! List) {
    return const <LaunchPlatform>[];
  }
  final platforms = <LaunchPlatform>[];
  for (final item in value) {
    final raw = item?.toString().trim().toLowerCase() ?? '';
    if (raw == 'all') {
      return const <LaunchPlatform>[];
    }
    final platform = LaunchPlatform.fromWireName(raw);
    if (platform != null && !platforms.contains(platform)) {
      platforms.add(platform);
    }
  }
  return platforms;
}

String _readString(dynamic value) {
  return value?.toString().trim() ?? '';
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value.toInt() != 0;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

DateTime? _readDateTime(dynamic value) {
  final raw = _readString(value);
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
