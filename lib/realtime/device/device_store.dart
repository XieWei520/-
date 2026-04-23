import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/platform_utils.dart';
import '../../core/utils/storage_utils.dart';
import 'device_identity.dart';

class DeviceStore {
  static const String _identityPersistenceScope =
      'shared_preferences_device_identity';

  Object get identityPersistenceScope => _identityPersistenceScope;

  Future<DeviceIdentity> read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.appName.trim();
    final platformName = PlatformUtils.platformName;
    return DeviceIdentity(
      deviceId: StorageUtils.getDeviceId()?.trim() ?? '',
      deviceInstallId: StorageUtils.getDeviceInstallId()?.trim() ?? '',
      deviceSessionId: StorageUtils.getDeviceSessionId()?.trim() ?? '',
      bindVersion: StorageUtils.getDeviceBindVersion(),
      userId: StorageUtils.getDeviceBoundUserId()?.trim() ?? '',
      deviceName: '${appName.isEmpty ? 'WuKongIM' : appName} $platformName',
      deviceModel: platformName,
    );
  }

  Future<void> write(DeviceIdentity identity) async {
    final snapshot = jsonEncode(<String, Object>{
      'device_id': identity.deviceId,
      'device_install_id': identity.deviceInstallId,
      'device_session_id': identity.deviceSessionId,
      'device_bind_version': identity.bindVersion,
      'device_bound_user_id': identity.userId,
    });
    _requireWrite(
      key: 'device_identity_snapshot',
      ok: await StorageUtils.setDeviceIdentitySnapshot(snapshot),
    );
  }

  void _requireWrite({required String key, required bool ok}) {
    if (!ok) {
      throw StateError('Failed to persist $key');
    }
  }
}
