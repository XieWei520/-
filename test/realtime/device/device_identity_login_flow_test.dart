import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/realtime/device/device_identity.dart';
import 'package:wukong_im_app/realtime/device/device_identity_service.dart';
import 'package:wukong_im_app/realtime/device/device_store.dart';
import 'package:wukong_im_app/service/api/auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'WuKongIM',
      packageName: 'wukong_im_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await StorageUtils.init();
    await StorageUtils.clear();
  });

  test('completeLogin binds device session before push sync', () async {
    final authority = _FakeDeviceIdentityAuthority(
      deviceSessionId: 'session_login_01',
    );
    final container = ProviderContainer(
      overrides: [
        deviceIdentityAuthorityProvider.overrideWithValue(authority),
        authCurrentUserLoaderProvider.overrideWithValue(
          () async => UserInfo(uid: 'u_login_01', token: 'token_login_01'),
        ),
        authDraftSyncProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authProvider.notifier)
        .completeLogin(LoginData(uid: 'u_login_01', token: 'token_login_01'));

    expect(authority.bindCalls, hasLength(1));
    expect(authority.bindCalls.single.userId, 'u_login_01');
    expect(authority.bindCalls.single.token, 'token_login_01');
    expect(StorageUtils.getDeviceSessionId(), 'session_login_01');
    expect(container.read(authProvider).isLoggedIn, isTrue);
  });

  test('restored login binds device session before exposing authenticated state', () async {
    await StorageUtils.setUid('u_restore_01');
    await StorageUtils.setToken('token_restore_01');

    final authority = _FakeDeviceIdentityAuthority(
      deviceSessionId: 'session_restore_01',
    );
    final container = ProviderContainer(
      overrides: [
        deviceIdentityAuthorityProvider.overrideWithValue(authority),
        authCurrentUserLoaderProvider.overrideWithValue(
          () async => UserInfo(uid: 'u_restore_01', token: 'token_restore_01'),
        ),
        authDraftSyncProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await _waitFor(
      () => !container.read(authProvider).isRestoringSession,
    );

    expect(authority.bindCalls, hasLength(1));
    expect(authority.bindCalls.single.userId, 'u_restore_01');
    expect(authority.bindCalls.single.token, 'token_restore_01');
    expect(StorageUtils.getDeviceSessionId(), 'session_restore_01');
    expect(container.read(authProvider).isLoggedIn, isTrue);
  });
}

class _BindCall {
  const _BindCall(this.userId, this.token);

  final String userId;
  final String token;
}

class _FakeDeviceIdentityAuthority extends DeviceIdentityAuthority {
  _FakeDeviceIdentityAuthority({required this.deviceSessionId})
    : super(store: _FakeDeviceStore());

  final String deviceSessionId;
  final List<_BindCall> bindCalls = <_BindCall>[];

  @override
  Future<DeviceIdentity> bindAuthenticatedSession({
    required String userId,
    required String token,
  }) async {
    bindCalls.add(_BindCall(userId, token));
    await StorageUtils.setDeviceSessionId(deviceSessionId);
    return DeviceIdentity(
      deviceId: 'device_login_01',
      deviceInstallId: 'install_login_01',
      deviceSessionId: deviceSessionId,
      bindVersion: 1,
      userId: userId,
      deviceName: 'WuKongIM test',
      deviceModel: 'test',
    );
  }
}

class _FakeDeviceStore extends DeviceStore {
  @override
  Future<DeviceIdentity> read() async {
    return const DeviceIdentity(
      deviceId: 'device_login_01',
      deviceInstallId: 'install_login_01',
      deviceSessionId: '',
      bindVersion: 0,
      userId: '',
      deviceName: 'WuKongIM test',
      deviceModel: 'test',
    );
  }

  @override
  Future<void> write(DeviceIdentity identity) async {}
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for test condition.');
}
