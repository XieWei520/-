import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/launch_policy_api.dart';
import 'launch_policy_models.dart';

typedef LaunchPackageInfoReader = Future<LaunchPackageInfo> Function();
typedef LaunchPlatformReader = LaunchPlatform? Function();
typedef LaunchNow = DateTime Function();

abstract class LaunchPolicyApiGateway {
  Future<LaunchPolicyResponse> fetchLaunchPolicy({
    required LaunchPlatform platform,
    required String version,
    required int buildNumber,
  });
}

class LaunchPolicyApiGatewayAdapter implements LaunchPolicyApiGateway {
  LaunchPolicyApiGatewayAdapter(this._api);

  final LaunchPolicyApi _api;

  @override
  Future<LaunchPolicyResponse> fetchLaunchPolicy({
    required LaunchPlatform platform,
    required String version,
    required int buildNumber,
  }) {
    return _api.fetchLaunchPolicy(
      platform: platform,
      version: version,
      buildNumber: buildNumber,
    );
  }
}

class LaunchPackageInfo {
  const LaunchPackageInfo({required this.version, required this.buildNumber});

  final String version;
  final int buildNumber;

  static Future<LaunchPackageInfo> fromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    return LaunchPackageInfo(
      version: info.version,
      buildNumber: int.tryParse(info.buildNumber.trim()) ?? 0,
    );
  }
}

enum LaunchPolicyDecisionType { none, forceUpgrade, showNotice }

class LaunchPolicyDecision {
  const LaunchPolicyDecision._({
    required this.type,
    this.versionPolicy,
    this.startupNotice,
  });

  const LaunchPolicyDecision.none()
    : this._(type: LaunchPolicyDecisionType.none);

  const LaunchPolicyDecision.forceUpgrade(VersionPolicy policy)
    : this._(
        type: LaunchPolicyDecisionType.forceUpgrade,
        versionPolicy: policy,
      );

  const LaunchPolicyDecision.showNotice(StartupNotice notice)
    : this._(type: LaunchPolicyDecisionType.showNotice, startupNotice: notice);

  final LaunchPolicyDecisionType type;
  final VersionPolicy? versionPolicy;
  final StartupNotice? startupNotice;
}

class LaunchPolicyController {
  LaunchPolicyController({
    LaunchPolicyApiGateway? api,
    LaunchPackageInfoReader? packageInfoReader,
    LaunchPlatformReader? platformReader,
    LaunchNow? now,
  }) : _api = api ?? LaunchPolicyApiGatewayAdapter(LaunchPolicyApi()),
       _packageInfoReader = packageInfoReader ?? LaunchPackageInfo.fromPlatform,
       _platformReader = platformReader ?? _defaultPlatformReader,
       _now = now ?? DateTime.now;

  final LaunchPolicyApiGateway _api;
  final LaunchPackageInfoReader _packageInfoReader;
  final LaunchPlatformReader _platformReader;
  final LaunchNow _now;

  bool _checkInFlight = false;

  Future<LaunchPolicyDecision> checkLaunchPolicy() async {
    if (_checkInFlight) {
      return const LaunchPolicyDecision.none();
    }
    final platform = _platformReader();
    if (platform == null) {
      return const LaunchPolicyDecision.none();
    }
    _checkInFlight = true;
    try {
      final packageInfo = await _packageInfoReader();
      final response = await _api.fetchLaunchPolicy(
        platform: platform,
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
      final policy = response.versionPolicy;
      if (policy != null &&
          policy.requiresForcedUpgrade(packageInfo.buildNumber)) {
        return LaunchPolicyDecision.forceUpgrade(policy);
      }

      final notice = response.startupNotice;
      if (notice != null &&
          notice.isActiveAt(_now()) &&
          _noticeTargetsPlatform(notice, platform) &&
          _shouldShowNotice(notice, _now())) {
        return LaunchPolicyDecision.showNotice(notice);
      }
      return const LaunchPolicyDecision.none();
    } catch (_) {
      return const LaunchPolicyDecision.none();
    } finally {
      _checkInFlight = false;
    }
  }

  Future<void> markNoticeShown(
    StartupNotice notice, {
    DateTime? shownAt,
  }) async {
    final now = shownAt ?? _now();
    await StorageUtils.setString(
      _noticeShownKey(notice.id),
      now.toIso8601String(),
    );
  }

  bool _shouldShowNotice(StartupNotice notice, DateTime now) {
    final rawShownAt = StorageUtils.getString(_noticeShownKey(notice.id));
    final shownAt = DateTime.tryParse(rawShownAt ?? '');
    if (shownAt == null) {
      return true;
    }
    return switch (notice.frequency) {
      StartupNoticeFrequency.everyStart => true,
      StartupNoticeFrequency.once => false,
      StartupNoticeFrequency.daily => !_sameLocalDate(shownAt, now),
    };
  }

  bool _noticeTargetsPlatform(StartupNotice notice, LaunchPlatform platform) {
    return notice.platforms.isEmpty || notice.platforms.contains(platform);
  }

  static LaunchPlatform? _defaultPlatformReader() {
    if (kIsWeb) {
      return null;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => LaunchPlatform.android,
      TargetPlatform.windows => LaunchPlatform.windows,
      _ => null,
    };
  }

  static bool _sameLocalDate(DateTime left, DateTime right) {
    final l = left.toLocal();
    final r = right.toLocal();
    return l.year == r.year && l.month == r.month && l.day == r.day;
  }

  static String _noticeShownKey(String noticeId) {
    return 'launch_policy.notice_shown.$noticeId';
  }
}
