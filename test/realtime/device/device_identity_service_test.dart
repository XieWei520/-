import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/im_config.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/realtime/device/device_identity.dart';
import 'package:wukong_im_app/realtime/device/device_identity_service.dart';
import 'package:wukong_im_app/realtime/device/device_store.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

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

  test('ensureLocalIdentity keeps a stable device_id and install id', () async {
    final authority = DeviceIdentityAuthority(store: DeviceStore());

    final first = await authority.ensureLocalIdentity();
    final second = await authority.ensureLocalIdentity();

    expect(first.deviceId, isNotEmpty);
    expect(first.deviceInstallId, isNotEmpty);
    expect(second.deviceId, first.deviceId);
    expect(second.deviceInstallId, first.deviceInstallId);
    expect(second.deviceSessionId, isEmpty);
    expect(second.bindVersion, 0);
  });

  test(
    'ensureLocalIdentity converges concurrent fresh-install callers',
    () async {
      final authority = DeviceIdentityAuthority(store: DeviceStore());

      final results =
          await Future.wait<DeviceIdentity>(<Future<DeviceIdentity>>[
            authority.ensureLocalIdentity(),
            authority.ensureLocalIdentity(),
            authority.ensureLocalIdentity(),
          ]);

      final first = results.first;
      for (final identity in results.skip(1)) {
        expect(identity.deviceId, first.deviceId);
        expect(identity.deviceInstallId, first.deviceInstallId);
      }
    },
  );

  test(
    'ensureLocalIdentity single-flights across authority instances on fresh install',
    () async {
      final store = _DelayedEmptyDeviceStore();
      final firstAuthority = DeviceIdentityAuthority(store: store);
      final secondAuthority = DeviceIdentityAuthority(store: store);

      final results =
          await Future.wait<DeviceIdentity>(<Future<DeviceIdentity>>[
            firstAuthority.ensureLocalIdentity(),
            secondAuthority.ensureLocalIdentity(),
          ]);

      expect(store.writeCount, 1);
      expect(results[1].deviceId, results[0].deviceId);
      expect(results[1].deviceInstallId, results[0].deviceInstallId);
    },
  );

  test(
    'recordBoundSession persists device_session_id and bind_version',
    () async {
      final authority = DeviceIdentityAuthority(store: DeviceStore());

      await authority.ensureLocalIdentity();
      await authority.recordBoundSession(
        userId: 'u_001',
        deviceSessionId: 'session_001',
        bindVersion: 3,
      );

      final persisted = await DeviceStore().read();
      expect(persisted.userId, 'u_001');
      expect(persisted.deviceSessionId, 'session_001');
      expect(persisted.bindVersion, 3);
      expect(StorageUtils.getDeviceBoundUserId(), 'u_001');
    },
  );

  test(
    'device store writes identity in a single snapshot with typed read support',
    () async {
      final authority = DeviceIdentityAuthority(store: DeviceStore());

      await authority.ensureLocalIdentity();
      await authority.recordBoundSession(
        userId: 'u_009',
        deviceSessionId: 'session_009',
        bindVersion: 9,
      );

      final snapshot = StorageUtils.getString(
        AppConstants.keyDeviceIdentitySnapshot,
      );
      expect(snapshot, isNotNull);
      expect(snapshot, isNotEmpty);
      expect(StorageUtils.getDeviceSessionId(), 'session_009');
      expect(StorageUtils.getDeviceBindVersion(), 9);
      expect(StorageUtils.getDeviceBoundUserId(), 'u_009');
    },
  );

  test('recordBoundSession ignores stale bind versions', () async {
    final authority = DeviceIdentityAuthority(store: DeviceStore());

    await authority.ensureLocalIdentity();
    await authority.recordBoundSession(
      userId: 'u_new',
      deviceSessionId: 'session_new',
      bindVersion: 7,
    );

    final ignored = await authority.recordBoundSession(
      userId: 'u_old',
      deviceSessionId: 'session_old',
      bindVersion: 6,
    );
    final persisted = await DeviceStore().read();

    expect(ignored.bindVersion, 7);
    expect(ignored.userId, 'u_new');
    expect(ignored.deviceSessionId, 'session_new');
    expect(persisted.bindVersion, 7);
    expect(persisted.userId, 'u_new');
    expect(persisted.deviceSessionId, 'session_new');
  });

  test(
    'recordBoundSession serializes concurrent authority writes by bind version',
    () async {
      final store = _DelayedBindDeviceStore();
      final firstAuthority = DeviceIdentityAuthority(store: store);
      final secondAuthority = DeviceIdentityAuthority(store: store);

      await firstAuthority.ensureLocalIdentity();
      final results = await Future.wait<DeviceIdentity>(<Future<DeviceIdentity>>[
        firstAuthority.recordBoundSession(
          userId: 'u_new',
          deviceSessionId: 'session_new',
          bindVersion: 7,
        ),
        secondAuthority.recordBoundSession(
          userId: 'u_old',
          deviceSessionId: 'session_old',
          bindVersion: 6,
        ),
      ]);

      final persisted = await store.read();
      expect(results[0].bindVersion, 7);
      expect(results[1].bindVersion, 7);
      expect(persisted.bindVersion, 7);
      expect(persisted.userId, 'u_new');
      expect(persisted.deviceSessionId, 'session_new');
    },
  );

  test('api device bind payload carries the current IM device flag', () async {
    await StorageUtils.setToken('token_bind');
    final adapter = _RecordingDeviceBindAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;

    final session = await ApiDeviceBindClient().bindDeviceSession(
      identity: const DeviceIdentity(
        deviceId: 'device_bind_01',
        deviceInstallId: 'install_bind_01',
        deviceSessionId: '',
        bindVersion: 6,
        userId: 'u_bind',
        deviceName: 'InfoEquity Windows',
        deviceModel: 'Windows',
      ),
      bindVersion: 7,
    );

    expect(session.deviceSessionId, 'session_bind_01');
    expect(adapter.lastData?['device_flag'], IMConfig.currentDeviceFlag);
  });
}

class _RecordingDeviceBindAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    if (data is Map) {
      lastData = Map<String, dynamic>.from(data);
    }
    return ResponseBody.fromString(
      '{"device_session_id":"session_bind_01","bind_version":7}',
      200,
      headers: {
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedEmptyDeviceStore extends DeviceStore {
  DeviceIdentity _identity = const DeviceIdentity(
    deviceId: '',
    deviceInstallId: '',
    deviceSessionId: '',
    bindVersion: 0,
    userId: '',
    deviceName: 'WuKongIM test',
    deviceModel: 'test',
  );

  int readCount = 0;
  int writeCount = 0;

  @override
  Future<DeviceIdentity> read() async {
    readCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 15));
    return _identity;
  }

  @override
  Future<void> write(DeviceIdentity identity) async {
    writeCount += 1;
    _identity = identity;
  }
}

class _DelayedBindDeviceStore extends _DelayedEmptyDeviceStore {
  @override
  Future<void> write(DeviceIdentity identity) async {
    if (identity.bindVersion == 6) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    } else if (identity.bindVersion == 7) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await super.write(identity);
  }
}
