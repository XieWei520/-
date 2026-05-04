import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/storage_utils.dart';
import '../modules/home/home_badge_snapshot.dart';
import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';
import '../wukong_base/net/api_client.dart';

const String pushUpdateDeviceBadgeEndpoint = 'push_update_device_badge';

typedef RemoteBadgeRegistrar = Future<void> Function(int badge);
typedef DeviceBadgeUpdater = Future<void> Function(int badge);

abstract class DeviceBadgePlatformBridge {
  Future<void> setBadgeCount(int count);
}

class DefaultDeviceBadgePlatformBridge implements DeviceBadgePlatformBridge {
  const DefaultDeviceBadgePlatformBridge();

  static const MethodChannel _channel = MethodChannel(
    'wukong_im_app/device_badge',
  );

  @override
  Future<void> setBadgeCount(int count) async {
    try {
      await _channel.invokeMethod<void>('setBadgeCount', <String, dynamic>{
        'count': math.max(0, count),
      });
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

class DeviceBadgeService {
  DeviceBadgeService({
    RemoteBadgeRegistrar? registerRemoteBadge,
    DeviceBadgePlatformBridge? platformBridge,
    bool Function()? isLoggedIn,
  }) : _registerRemoteBadge =
           registerRemoteBadge ?? _defaultRegisterRemoteBadge,
       _platformBridge =
           platformBridge ?? const DefaultDeviceBadgePlatformBridge(),
       _isLoggedIn = isLoggedIn ?? StorageUtils.isLoggedIn;

  static final DeviceBadgeService instance = DeviceBadgeService();

  final RemoteBadgeRegistrar _registerRemoteBadge;
  final DeviceBadgePlatformBridge _platformBridge;
  final bool Function() _isLoggedIn;

  bool _registered = false;

  void registerEndpoint({EndpointManager? endpointManager}) {
    final manager = endpointManager ?? EndpointManager.getInstance();
    if (_registered || manager.hasEndpoint(pushUpdateDeviceBadgeEndpoint)) {
      _registered = true;
      return;
    }
    manager.setMethod(
      pushUpdateDeviceBadgeEndpoint,
      '',
      0,
      AsyncFunctionHandler(([dynamic param]) => updateBadge(_readBadge(param))),
    );
    _registered = true;
  }

  Future<void> updateBadge(int badge) async {
    final normalized = math.max(0, badge);
    if (_isLoggedIn()) {
      try {
        await _registerRemoteBadge(normalized);
      } catch (error, stackTrace) {
        debugPrint('DeviceBadgeService: remote badge sync failed -> $error');
        debugPrint('$stackTrace');
      }
    }
    await _platformBridge.setBadgeCount(normalized);
  }

  Future<void> clearLocalBadge() {
    return _platformBridge.setBadgeCount(0);
  }

  static Future<void> _defaultRegisterRemoteBadge(int badge) async {
    await ApiClient.instance.post(
      '/v1/user/device_badge',
      data: <String, dynamic>{'badge': badge},
    );
  }

  static int _readBadge(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is Map) {
      for (final key in const <String>['badge', 'count', 'unread']) {
        if (raw.containsKey(key)) {
          return _readBadge(raw[key]);
        }
      }
    }
    return int.tryParse(raw?.toString().trim() ?? '') ?? 0;
  }
}

class DeviceBadgeSyncBridge {
  DeviceBadgeSyncBridge({
    required DeviceBadgeUpdater updateBadge,
    required bool Function() isLoggedIn,
  }) : _updateBadge = updateBadge,
       _isLoggedIn = isLoggedIn;

  final DeviceBadgeUpdater _updateBadge;
  final bool Function() _isLoggedIn;

  int? _lastSyncedBadge;

  Future<void> sync(HomeBadgeSnapshot snapshot) async {
    if (!_isLoggedIn()) {
      _lastSyncedBadge = null;
      return;
    }
    final totalUnread = math.max(0, snapshot.totalUnread);
    if (_lastSyncedBadge == totalUnread) {
      return;
    }
    _lastSyncedBadge = totalUnread;
    await _updateBadge(totalUnread);
  }

  void reset() {
    _lastSyncedBadge = null;
  }
}
