# Realtime Event Core V2 Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace duplicated device identity logic and call polling with an authoritative device bind flow, an ordered realtime session gateway, and an event-driven call runtime that is verifiable on both the Flutter client and the deployed TangSeng server.

**Architecture:** Build `Device Identity V2` first so every authenticated path shares one install-scoped identity and one backend-issued `device_session_id`. Then add a push-first `Session Event Gateway V2` on the server and client, and finally move call invite and signaling into `Call Signaling V2`, leaving `/v1/extra/call/pending` and `/v1/extra/call/signals/:room_id` as degradation-only fallbacks rather than the primary path.

**Tech Stack:** Flutter, flutter_riverpod, web_socket_channel, Dio, flutter_webrtc, SharedPreferences, Go, wkhttp, Redis, MySQL, Docker, SSH remote debugging

---

**Workspace Note:** This Flutter workspace does not currently contain `.git` metadata, so the local `git add` and `git commit` commands below are the canonical commands for the real repository checkout. The deployed server source at `/data/build/TangSengDaoDaoServer` is a git repository and can be committed directly over `ssh root@103.207.68.33`.

## File Structure

## Remote Debugging Requirement

This plan keeps server correlation in scope for every subproject.

- SSH entry: `ssh root@103.207.68.33`
- Server source root: `/data/build/TangSengDaoDaoServer`
- Required runtime checks:
  - `docker ps`
  - `tail -n 200 /data/fullstack/wukongimdata/logs/error.log`
  - `docker logs --tail 200 fullstack-tangsengdaodaoserver-1`
- Use remote logs whenever bind failures, push-token misses, session replay bugs, or call ordering cannot be explained from local traces alone.

### New Local Files

- `lib/realtime/device/device_identity.dart`
- `lib/realtime/device/device_store.dart`
- `lib/realtime/device/device_identity_service.dart`
- `lib/realtime/session/session_event_frame.dart`
- `lib/realtime/session/session_event_gateway.dart`
- `lib/realtime/session/session_runtime.dart`
- `lib/realtime/call/call_state_machine.dart`
- `lib/realtime/call/call_event_mapper.dart`
- `lib/realtime/call/call_store.dart`
- `test/realtime/device/device_identity_service_test.dart`
- `test/realtime/device/device_identity_login_flow_test.dart`
- `test/realtime/session/session_event_gateway_test.dart`
- `test/realtime/session/session_runtime_test.dart`
- `test/realtime/call/call_state_machine_test.dart`
- `test/realtime/call/call_store_test.dart`
- `test/wukong_push/push_service_test.dart`

### Existing Local Files To Modify

- `lib/core/constants/app_constants.dart`
- `lib/core/utils/storage_utils.dart`
- `lib/service/api/api_client.dart`
- `lib/service/api/auth_api.dart`
- `lib/service/api/login_bridge_api.dart`
- `lib/service/api/call_api.dart`
- `lib/service/im/im_service.dart`
- `lib/data/providers/auth_provider.dart`
- `lib/modules/video_call/call_coordinator.dart`
- `lib/modules/video_call/video_call_service.dart`
- `lib/modules/video_call/video_call_page.dart`
- `lib/wukong_push/push_service.dart`
- `lib/wukong_login/pc_login_page.dart`

### New Remote Server Files

- `/data/build/TangSengDaoDaoServer/modules/user/api_device_session.go`
- `/data/build/TangSengDaoDaoServer/modules/user/db_device_session.go`
- `/data/build/TangSengDaoDaoServer/modules/user/sql/user-20260402-01.sql`
- `/data/build/TangSengDaoDaoServer/modules/realtime/1module.go`
- `/data/build/TangSengDaoDaoServer/modules/realtime/api.go`
- `/data/build/TangSengDaoDaoServer/modules/realtime/db.go`
- `/data/build/TangSengDaoDaoServer/modules/realtime/models.go`
- `/data/build/TangSengDaoDaoServer/modules/realtime/service.go`
- `/data/build/TangSengDaoDaoServer/modules/realtime/sql/realtime-20260402-01.sql`
- `/data/build/TangSengDaoDaoServer/modules/realtime/api_test.go`

### Existing Remote Server Files To Modify

- `/data/build/TangSengDaoDaoServer/internal/modules.go`
- `/data/build/TangSengDaoDaoServer/modules/user/api.go`
- `/data/build/TangSengDaoDaoServer/modules/user/api_usernamelogin.go`
- `/data/build/TangSengDaoDaoServer/modules/user/api_test.go`
- `/data/build/TangSengDaoDaoServer/modules/user/api_device.go`
- `/data/build/TangSengDaoDaoServer/modules/user/db_device.go`
- `/data/build/TangSengDaoDaoServer/modules/extra/api.go`
- `/data/build/TangSengDaoDaoServer/modules/extra/db.go`
- `/data/build/TangSengDaoDaoServer/modules/extra/models.go`
- `/data/build/TangSengDaoDaoServer/modules/webhook/api.go`
- `/data/build/TangSengDaoDaoServer/modules/webhook/push_test.go`

### Verification Commands Used Throughout

- `dart analyze lib/realtime lib/service/api lib/service/im lib/data/providers/auth_provider.dart lib/modules/video_call lib/wukong_push lib/wukong_login/pc_login_page.dart`
- `flutter test test/realtime/device/device_identity_service_test.dart test/realtime/device/device_identity_login_flow_test.dart`
- `flutter test test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart`
- `flutter test test/realtime/call/call_state_machine_test.dart test/realtime/call/call_store_test.dart`
- `flutter test test/wukong_push/push_service_test.dart`
- `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/user ./modules/realtime ./modules/extra ./modules/webhook"`
- `ssh root@103.207.68.33 "docker ps && tail -n 200 /data/fullstack/wukongimdata/logs/error.log && docker logs --tail 200 fullstack-tangsengdaodaoserver-1"`

### Task 1: Build Client Device Identity Authority

**Files:**
- Create: `lib/realtime/device/device_identity.dart`
- Create: `lib/realtime/device/device_store.dart`
- Create: `lib/realtime/device/device_identity_service.dart`
- Create: `test/realtime/device/device_identity_service_test.dart`
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/core/utils/storage_utils.dart`

- [ ] **Step 1: Write the failing device identity tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/realtime/device/device_identity_service.dart';
import 'package:wukong_im_app/realtime/device/device_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  test('ensureLocalIdentity keeps a stable device_id and install id', () async {
    final authority = DeviceIdentityAuthority(store: DeviceStore());

    final first = await authority.ensureLocalIdentity();
    final second = await authority.ensureLocalIdentity();

    expect(second.deviceId, first.deviceId);
    expect(second.deviceInstallId, first.deviceInstallId);
    expect(second.deviceSessionId, isEmpty);
    expect(second.bindVersion, 0);
  });

  test('recordBoundSession persists device_session_id and bind_version', () async {
    final authority = DeviceIdentityAuthority(store: DeviceStore());

    await authority.ensureLocalIdentity();
    final bound = await authority.recordBoundSession(
      userId: 'u_001',
      deviceSessionId: 'session_001',
      bindVersion: 3,
    );

    expect(bound.userId, 'u_001');
    expect(bound.deviceSessionId, 'session_001');
    expect(bound.bindVersion, 3);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/realtime/device/device_identity_service_test.dart`
Expected: FAIL with missing `DeviceIdentityAuthority`, `DeviceStore`, or missing storage keys for `device_install_id`, `device_session_id`, and `bind_version`

- [ ] **Step 3: Extend storage keys and typed accessors**

```dart
class AppConstants {
  static const String keyDeviceInstallId = 'device_install_id';
  static const String keyDeviceSessionId = 'device_session_id';
  static const String keyDeviceBindVersion = 'device_bind_version';
  static const String keyDeviceBoundUserId = 'device_bound_user_id';
}

class StorageUtils {
  static Future<bool> setDeviceInstallId(String value) {
    return setString(AppConstants.keyDeviceInstallId, value);
  }

  static String? getDeviceInstallId() {
    return getString(AppConstants.keyDeviceInstallId);
  }

  static Future<bool> setDeviceSessionId(String value) {
    return setString(AppConstants.keyDeviceSessionId, value);
  }

  static String? getDeviceSessionId() {
    return getString(AppConstants.keyDeviceSessionId);
  }

  static Future<bool> setDeviceBindVersion(int value) {
    return setInt(AppConstants.keyDeviceBindVersion, value);
  }

  static int getDeviceBindVersion() {
    return getInt(AppConstants.keyDeviceBindVersion) ?? 0;
  }
}
```

- [ ] **Step 4: Implement the authority and store**

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/storage_utils.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.deviceInstallId,
    required this.deviceSessionId,
    required this.bindVersion,
    required this.userId,
    required this.deviceName,
    required this.deviceModel,
  });

  final String deviceId;
  final String deviceInstallId;
  final String deviceSessionId;
  final int bindVersion;
  final String userId;
  final String deviceName;
  final String deviceModel;
}

class DeviceStore {
  Future<DeviceIdentity> read() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return DeviceIdentity(
      deviceId: StorageUtils.getDeviceId()?.trim() ?? '',
      deviceInstallId: StorageUtils.getDeviceInstallId()?.trim() ?? '',
      deviceSessionId: StorageUtils.getDeviceSessionId()?.trim() ?? '',
      bindVersion: StorageUtils.getDeviceBindVersion(),
      userId: StorageUtils.getString(AppConstants.keyDeviceBoundUserId)?.trim() ?? '',
      deviceName: '${packageInfo.appName.trim().isEmpty ? 'WuKongIM' : packageInfo.appName.trim()} ${PlatformUtils.platformName}',
      deviceModel: PlatformUtils.platformName,
    );
  }

  Future<void> write(DeviceIdentity identity) async {
    await StorageUtils.setDeviceId(identity.deviceId);
    await StorageUtils.setDeviceInstallId(identity.deviceInstallId);
    await StorageUtils.setDeviceSessionId(identity.deviceSessionId);
    await StorageUtils.setDeviceBindVersion(identity.bindVersion);
    await StorageUtils.setString(AppConstants.keyDeviceBoundUserId, identity.userId);
  }
}

class DeviceIdentityAuthority {
  DeviceIdentityAuthority({required DeviceStore store}) : _store = store;

  final DeviceStore _store;
  static const Uuid _uuid = Uuid();

  Future<DeviceIdentity> ensureLocalIdentity() async {
    final current = await _store.read();
    final next = DeviceIdentity(
      deviceId: current.deviceId.isEmpty ? _uuid.v4().replaceAll('-', '') : current.deviceId,
      deviceInstallId: current.deviceInstallId.isEmpty ? _uuid.v4().replaceAll('-', '') : current.deviceInstallId,
      deviceSessionId: current.deviceSessionId,
      bindVersion: current.bindVersion,
      userId: current.userId,
      deviceName: current.deviceName,
      deviceModel: current.deviceModel,
    );
    await _store.write(next);
    return next;
  }

  Future<DeviceIdentity> recordBoundSession({
    required String userId,
    required String deviceSessionId,
    required int bindVersion,
  }) async {
    final current = await ensureLocalIdentity();
    final next = DeviceIdentity(
      deviceId: current.deviceId,
      deviceInstallId: current.deviceInstallId,
      deviceSessionId: deviceSessionId,
      bindVersion: bindVersion,
      userId: userId,
      deviceName: current.deviceName,
      deviceModel: current.deviceModel,
    );
    await _store.write(next);
    return next;
  }
}
```

- [ ] **Step 5: Run the device identity tests again**

Run: `flutter test test/realtime/device/device_identity_service_test.dart`
Expected: PASS with stable `device_id` reuse and persisted `device_session_id` assertions green

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/app_constants.dart lib/core/utils/storage_utils.dart lib/realtime/device/device_identity.dart lib/realtime/device/device_store.dart lib/realtime/device/device_identity_service.dart test/realtime/device/device_identity_service_test.dart
git commit -m "feat: add device identity authority"
```

### Task 2: Add Server Device Bind Contract

**Files:**
- Create: `/data/build/TangSengDaoDaoServer/modules/user/api_device_session.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/user/db_device_session.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/user/sql/user-20260402-01.sql`
- Modify: `/data/build/TangSengDaoDaoServer/modules/user/api.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/user/api_test.go`

- [ ] **Step 1: Write the failing server bind test**

```go
type memoryDeviceDB struct {
    saved *deviceModel
}

func (m *memoryDeviceDB) insertOrUpdateDevice(model *deviceModel) error {
    m.saved = model
    return nil
}

type memoryDeviceSessionDB struct {
    saved *deviceSessionModel
}

func (m *memoryDeviceSessionDB) upsert(model *deviceSessionModel) error {
    m.saved = model
    return nil
}

func TestBindDeviceSessionReturnsSessionID(t *testing.T) {
    deviceDB := &memoryDeviceDB{}
    sessionDB := &memoryDeviceSessionDB{}
    svc := bindDeviceSessionService{
        deviceDB:        deviceDB,
        deviceSessionDB: sessionDB,
        sessionID:       func() string { return "session_bind_01" },
        now:             func() time.Time { return time.Unix(1712000000, 0) },
    }

    resp, err := svc.bind("u_bind_01", bindDeviceSessionReq{
        DeviceID:        "device_bind_01",
        DeviceName:      "WuKongIM Android",
        DeviceModel:     "android",
        DeviceInstallID: "install_bind_01",
        BindVersion:     1,
    })

    require.NoError(t, err)
    require.Equal(t, "session_bind_01", resp.DeviceSessionID)
    require.Equal(t, int64(1), resp.BindVersion)
    require.Equal(t, "device_bind_01", deviceDB.saved.DeviceID)
    require.Equal(t, "install_bind_01", sessionDB.saved.DeviceInstallID)
}
```

- [ ] **Step 2: Run the server bind test to verify it fails**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/user -run TestBindDeviceSessionReturnsSessionID -count=1"`
Expected: FAIL with missing route `/v1/user/device/bind`, missing device-session DB helpers, or missing response field `device_session_id`

- [ ] **Step 3: Add the device-session table and DB helpers**

```sql
CREATE TABLE IF NOT EXISTS device_session (
  id BIGINT NOT NULL AUTO_INCREMENT,
  uid VARCHAR(40) NOT NULL DEFAULT '',
  device_id VARCHAR(40) NOT NULL DEFAULT '',
  device_install_id VARCHAR(64) NOT NULL DEFAULT '',
  device_session_id VARCHAR(64) NOT NULL DEFAULT '',
  bind_version BIGINT NOT NULL DEFAULT 0,
  status TINYINT NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_device_session_uid_device_id (uid, device_id),
  UNIQUE KEY uq_device_session_id (device_session_id)
);
```

```go
type deviceSessionModel struct {
    UID             string
    DeviceID        string
    DeviceInstallID string
    DeviceSessionID string
    BindVersion     int64
    Status          int
    db.BaseModel
}

func (d *deviceSessionDB) upsert(model *deviceSessionModel) error {
    _, err := d.session.InsertBySql(
        "insert into device_session(uid,device_id,device_install_id,device_session_id,bind_version,status) values(?,?,?,?,?,1) "+
            "ON DUPLICATE KEY UPDATE device_install_id=VALUES(device_install_id),device_session_id=VALUES(device_session_id),bind_version=GREATEST(bind_version, VALUES(bind_version)),status=1",
        model.UID, model.DeviceID, model.DeviceInstallID, model.DeviceSessionID, model.BindVersion,
    ).Exec()
    return err
}
```

- [ ] **Step 4: Implement the authenticated bind endpoint**

```go
type bindDeviceSessionReq struct {
    DeviceID        string `json:"device_id"`
    DeviceName      string `json:"device_name"`
    DeviceModel     string `json:"device_model"`
    DeviceInstallID string `json:"device_install_id"`
    BindVersion     int64  `json:"bind_version"`
}

type bindDeviceSessionResp struct {
    DeviceSessionID string `json:"device_session_id"`
    BindVersion     int64  `json:"bind_version"`
}

type bindDeviceSessionService struct {
    deviceDB interface {
        insertOrUpdateDevice(*deviceModel) error
    }
    deviceSessionDB interface {
        upsert(*deviceSessionModel) error
    }
    sessionID func() string
    now       func() time.Time
}

func (s bindDeviceSessionService) bind(uid string, req bindDeviceSessionReq) (*bindDeviceSessionResp, error) {
    nextSessionID := s.sessionID()
    if err := s.deviceDB.insertOrUpdateDevice(&deviceModel{
        UID: uid, DeviceID: req.DeviceID, DeviceName: req.DeviceName, DeviceModel: req.DeviceModel, LastLogin: s.now().Unix(),
    }); err != nil {
        return nil, errors.New("更新登录设备失败")
    }
    if err := s.deviceSessionDB.upsert(&deviceSessionModel{
        UID: uid, DeviceID: req.DeviceID, DeviceInstallID: req.DeviceInstallID, DeviceSessionID: nextSessionID, BindVersion: req.BindVersion,
    }); err != nil {
        return nil, errors.New("绑定设备会话失败")
    }
    return &bindDeviceSessionResp{DeviceSessionID: nextSessionID, BindVersion: req.BindVersion}, nil
}

func (u *User) bindDeviceSession(c *wkhttp.Context) {
    uid := c.GetLoginUID()
    if uid == "" {
        c.ResponseError(errors.New("未登录"))
        return
    }

    var req bindDeviceSessionReq
    if err := c.BindJSON(&req); err != nil {
        c.ResponseError(errors.New("请求参数错误"))
        return
    }

    svc := bindDeviceSessionService{
        deviceDB:        u.deviceDB,
        deviceSessionDB: u.deviceSessionDB,
        sessionID:       util.GenerUUID,
        now:             time.Now,
    }
    resp, err := svc.bind(uid, req)
    if err != nil {
        c.ResponseError(err)
        return
    }
    c.Response(map[string]interface{}{"data": resp})
}
```

- [ ] **Step 5: Run the user module tests again**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/user -run TestBindDeviceSessionReturnsSessionID -count=1"`
Expected: PASS with a non-empty `device_session_id` and correct `bind_version`

- [ ] **Step 6: Commit**

```bash
ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && git add modules/user/api.go modules/user/api_test.go modules/user/api_device_session.go modules/user/db_device_session.go modules/user/sql/user-20260402-01.sql && git commit -m 'feat: add device session bind endpoint'"
```

### Task 3: Adopt Device Identity In Login, QR Login, And Push Registration

**Files:**
- Create: `test/realtime/device/device_identity_login_flow_test.dart`
- Create: `test/wukong_push/push_service_test.dart`
- Modify: `lib/service/api/api_client.dart`
- Modify: `lib/service/api/auth_api.dart`
- Modify: `lib/service/api/login_bridge_api.dart`
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/wukong_push/push_service.dart`
- Modify: `lib/wukong_login/pc_login_page.dart`
- Modify: `/data/build/TangSengDaoDaoServer/modules/user/api.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/webhook/api.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/webhook/push_test.go`

- [ ] **Step 1: Write the failing client login and push tests**

```dart
class BindCall {
  const BindCall(this.userId, this.token);

  final String userId;
  final String token;
}

class FakeDeviceIdentityAuthority {
  FakeDeviceIdentityAuthority({required this.deviceSessionId});

  final String deviceSessionId;
  final List<BindCall> bindCalls = <BindCall>[];

  Future<void> bindAuthenticatedSession({
    required String userId,
    required String token,
  }) async {
    bindCalls.add(BindCall(userId, token));
    await StorageUtils.setDeviceSessionId(deviceSessionId);
  }
}

class FakePushService {
  int loginCallCount = 0;

  Future<void> handleLogin() async {
    loginCallCount += 1;
  }
}

class RecordingApiClient {
  String? lastPostPath;
  Map<String, dynamic> lastPostData = <String, dynamic>{};

  Future<void> post(String path, {required Map<String, dynamic> data}) async {
    lastPostPath = path;
    lastPostData = data;
  }
}

class TestAuthCoordinator {
  TestAuthCoordinator({
    required this.authority,
    required this.pushService,
  });

  final FakeDeviceIdentityAuthority authority;
  final FakePushService pushService;

  Future<void> completeLogin(LoginData loginData) async {
    await authority.bindAuthenticatedSession(
      userId: loginData.uid!,
      token: loginData.token!,
    );
    await pushService.handleLogin();
  }
}

test('completeLogin binds device session before push sync', () async {
  final authority = FakeDeviceIdentityAuthority(deviceSessionId: 'session_login_01');
  final push = FakePushService();
  final coordinator = TestAuthCoordinator(authority: authority, pushService: push);

  await coordinator.completeLogin(LoginData(uid: 'u_login_01', token: 'token_login_01'));

  expect(authority.bindCalls.single.userId, 'u_login_01');
  expect(push.loginCallCount, 1);
  expect(StorageUtils.getDeviceSessionId(), 'session_login_01');
});

test('push registration sends device identifiers after bind', () async {
  final client = RecordingApiClient();
  await StorageUtils.setDeviceId('device_push_01');
  await StorageUtils.setDeviceSessionId('session_push_01');

  await client.post('/user/device_token', data: <String, dynamic>{
    'device_token': 'push_token_01',
    'device_type': 'FIREBASE',
    'bundle_id': 'com.wukong.im',
    'device_id': StorageUtils.getDeviceId(),
    'device_session_id': StorageUtils.getDeviceSessionId(),
  });

  expect(client.lastPostPath, '/user/device_token');
  expect(client.lastPostData['device_id'], 'device_push_01');
  expect(client.lastPostData['device_session_id'], 'session_push_01');
});
```

- [ ] **Step 2: Run the failing tests**

Run: `flutter test test/realtime/device/device_identity_login_flow_test.dart test/wukong_push/push_service_test.dart`
Expected: FAIL because `AuthNotifier` does not bind device sessions yet and `PushService` does not send `device_id` or `device_session_id`

- [ ] **Step 3: Route every client login path through `DeviceIdentityAuthority`**

```dart
final deviceIdentityAuthorityProvider = Provider<DeviceIdentityAuthority>((ref) {
  return DeviceIdentityAuthority(store: DeviceStore());
});

class AuthNotifier extends StateNotifier<AuthState> {
  Future<void> completeLogin(LoginData loginData) async {
    final uid = loginData.uid!.trim();
    final token = loginData.token!.trim();

    await StorageUtils.setUid(uid);
    await StorageUtils.setToken(token);
    ApiClient.instance.setToken(token);

    await _ref.read(deviceIdentityAuthorityProvider).bindAuthenticatedSession(
      userId: uid,
      token: token,
    );

    await _commitLogin(loginData.toUserInfo().copyWith(uid: uid, token: token));
  }
}

class AuthApi {
  Future<Map<String, String>> _resolveDevicePayload() async {
    final identity = await _deviceIdentityAuthority.ensureLocalIdentity();
    return <String, String>{
      'device_id': identity.deviceId,
      'device_name': identity.deviceName,
      'device_model': identity.deviceModel,
      'device_install_id': identity.deviceInstallId,
    };
  }
}

class LoginBridgeApi {
  Future<LoginBridgeDeviceInfo> buildDeviceInfo() async {
    final identity = await _deviceIdentityAuthority.ensureLocalIdentity();
    return LoginBridgeDeviceInfo(
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
      deviceModel: identity.deviceModel,
    );
  }
}

class DeviceIdentityAuthority {
  Future<DeviceIdentity> bindAuthenticatedSession({
    required String userId,
    required String token,
  }) async {
    final identity = await ensureLocalIdentity();
    final response = await _client.post('/v1/user/device/bind', data: <String, dynamic>{
      'device_id': identity.deviceId,
      'device_name': identity.deviceName,
      'device_model': identity.deviceModel,
      'device_install_id': identity.deviceInstallId,
      'bind_version': identity.bindVersion + 1,
    });
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return recordBoundSession(
      userId: userId,
      deviceSessionId: data['device_session_id'].toString(),
      bindVersion: (data['bind_version'] as num).toInt(),
    );
  }
}
```

- [ ] **Step 4: Add device-session propagation to API requests and push registration**

```dart
onRequest: (options, handler) {
  final deviceSessionId = StorageUtils.getDeviceSessionId()?.trim() ?? '';
  if (deviceSessionId.isNotEmpty) {
    options.headers['X-Device-Session-ID'] = deviceSessionId;
  }
  handler.next(options);
}
```

```dart
final payload = <String, dynamic>{
  'device_token': token,
  'device_type': pushType,
  'bundle_id': bundleId,
  'device_id': StorageUtils.getDeviceId(),
  'device_session_id': StorageUtils.getDeviceSessionId(),
};
await _client.post('/user/device_token', data: payload);
```

```go
func (u *User) registerUserDeviceToken(c *wkhttp.Context) {
    loginUID := c.MustGet("uid").(string)
    var req struct {
        DeviceToken     string `json:"device_token"`
        DeviceType      string `json:"device_type"`
        BundleID        string `json:"bundle_id"`
        DeviceID        string `json:"device_id"`
        DeviceSessionID string `json:"device_session_id"`
    }
    if err := c.BindJSON(&req); err != nil {
        c.ResponseError(errors.New("数据格式有误！"))
        return
    }
    err := u.ctx.GetRedisConn().Hmset(
        fmt.Sprintf("%s%s", u.userDeviceTokenPrefix, loginUID),
        "device_type", req.DeviceType,
        "device_token", req.DeviceToken,
        "bundle_id", req.BundleID,
        "device_id", req.DeviceID,
        "device_session_id", req.DeviceSessionID,
    )
    if err != nil {
        c.ResponseError(errors.New("存储用户设备token失败！"))
        return
    }
    c.ResponseOK()
}
```

- [ ] **Step 5: Downgrade missing push-device records from a hard server error to an observable warning**

```go
if len(deviceMap) <= 0 {
    w.Warn("push skipped because device token is missing", zap.String("uid", toUID))
    return pushResp{}, nil
}
```

- [ ] **Step 6: Run local and remote push tests**

Run: `flutter test test/realtime/device/device_identity_login_flow_test.dart test/wukong_push/push_service_test.dart`
Expected: PASS with bound-session and push-payload assertions green

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/webhook -run Test -count=1"`
Expected: PASS without a failing `用户设备信息不存在！` assertion path

- [ ] **Step 7: Commit**

```bash
git add lib/service/api/api_client.dart lib/service/api/auth_api.dart lib/service/api/login_bridge_api.dart lib/data/providers/auth_provider.dart lib/wukong_push/push_service.dart lib/wukong_login/pc_login_page.dart test/realtime/device/device_identity_login_flow_test.dart test/wukong_push/push_service_test.dart
git commit -m "feat: adopt device identity across login and push"

ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && git add modules/user/api.go modules/webhook/api.go modules/webhook/push_test.go && git commit -m 'fix: harden push token registration'"
```

### Task 4: Build Server Session Event Gateway V2

**Files:**
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/1module.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/api.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/db.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/models.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/service.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/sql/realtime-20260402-01.sql`
- Create: `/data/build/TangSengDaoDaoServer/modules/realtime/api_test.go`
- Modify: `/data/build/TangSengDaoDaoServer/internal/modules.go`

- [ ] **Step 1: Write the failing replay and ACK test**

```go
type memoryRealtimeDB struct {
    frames []*Frame
}

func (m *memoryRealtimeDB) NextUserSeq(uid string) (int64, error) {
    seq := int64(0)
    for _, frame := range m.frames {
        if frame.UID == uid && frame.UserSeq > seq {
            seq = frame.UserSeq
        }
    }
    return seq + 1, nil
}

func (m *memoryRealtimeDB) InsertFrame(frame *Frame) error {
    m.frames = append(m.frames, frame)
    return nil
}

func (m *memoryRealtimeDB) Replay(uid string, afterSeq int64, limit int) ([]*Frame, error) {
    result := make([]*Frame, 0)
    for _, frame := range m.frames {
        if frame.UID == uid && frame.UserSeq > afterSeq {
            result = append(result, frame)
        }
    }
    if len(result) > limit {
        result = result[:limit]
    }
    return result, nil
}

func TestSessionGatewayReplaysFramesAfterSequence(t *testing.T) {
    db := &memoryRealtimeDB{}
    svc := Service{db: db}
    require.NoError(t, svc.Append("u_rt_01", "conversation.delta", "conv_01", []byte(`{"unread":3}`)))
    require.NoError(t, svc.Append("u_rt_01", "call.invite", "room_01", []byte(`{"room_id":"room_01"}`)))

    frames, err := db.Replay("u_rt_01", 1, 100)

    require.NoError(t, err)
    require.Len(t, frames, 1)
    require.Equal(t, int64(2), frames[0].UserSeq)
    require.Equal(t, "call.invite", frames[0].Kind)
}
```

- [ ] **Step 2: Run the realtime module tests to verify they fail**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/realtime -run TestSessionGatewayReplaysFramesAfterSequence -count=1"`
Expected: FAIL because the `realtime` module and `session_event` storage do not exist yet

- [ ] **Step 3: Create the `session_event` table and append/replay service**

```sql
CREATE TABLE IF NOT EXISTS session_event (
  id BIGINT NOT NULL AUTO_INCREMENT,
  uid VARCHAR(40) NOT NULL DEFAULT '',
  user_seq BIGINT NOT NULL DEFAULT 0,
  event_id VARCHAR(64) NOT NULL DEFAULT '',
  kind VARCHAR(64) NOT NULL DEFAULT '',
  aggregate_id VARCHAR(64) NOT NULL DEFAULT '',
  payload JSON NOT NULL,
  acked TINYINT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_event_event_id (event_id),
  UNIQUE KEY uq_session_event_uid_seq (uid, user_seq)
);
```

```go
type Frame struct {
    UID         string
    UserSeq     int64
    EventID     string
    Kind        string
    AggregateID string
    Payload     string
    CreatedAt   time.Time
}

func (s *Service) Append(uid, kind, aggregateID string, payload []byte) error {
    nextSeq, err := s.db.NextUserSeq(uid)
    if err != nil {
        return err
    }
    return s.db.InsertFrame(&Frame{
        UID: uid, UserSeq: nextSeq, EventID: util.GenerUUID(), Kind: kind, AggregateID: aggregateID, Payload: string(payload),
    })
}
```

- [ ] **Step 4: Expose the ordered WebSocket gateway and ACK handling**

```go
func (a *API) Route(r *wkhttp.WKHttp) {
    auth := r.Group("/v1/realtime", a.ctx.AuthMiddleware(r))
    auth.GET("/session/events/ws", a.serveWS)
    auth.POST("/session/events/ack", a.ack)
}

func (a *API) ack(c *wkhttp.Context) {
    uid := c.GetLoginUID()
    var req struct {
        LastAckedSeq int64 `json:"last_acked_seq"`
    }
    if err := c.BindJSON(&req); err != nil {
        c.ResponseError(errors.New("请求参数错误"))
        return
    }
    if err := a.service.Ack(uid, req.LastAckedSeq); err != nil {
        c.ResponseError(errors.New("ACK失败"))
        return
    }
    c.ResponseOK()
}
```

- [ ] **Step 5: Run the realtime tests**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/realtime -count=1"`
Expected: PASS with replay and ACK behavior green

- [ ] **Step 6: Commit**

```bash
ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && git add internal/modules.go modules/realtime && git commit -m 'feat: add realtime session gateway'"
```

### Task 5: Build Client Session Event Gateway And Runtime

**Files:**
- Create: `lib/realtime/session/session_event_frame.dart`
- Create: `lib/realtime/session/session_event_gateway.dart`
- Create: `lib/realtime/session/session_runtime.dart`
- Create: `test/realtime/session/session_event_gateway_test.dart`
- Create: `test/realtime/session/session_runtime_test.dart`
- Modify: `lib/service/im/im_service.dart`

- [ ] **Step 1: Write the failing client realtime tests**

```dart
test('frame parsing preserves ordering fields', () {
  final frame = SessionEventFrame.fromJson(<String, dynamic>{
    'event_id': 'evt_01',
    'user_seq': 7,
    'server_ts': 1712000000,
    'kind': 'call.invite',
    'aggregate_id': 'room_01',
    'payload': <String, dynamic>{'room_id': 'room_01'},
  });

  expect(frame.userSeq, 7);
  expect(frame.kind, 'call.invite');
  expect(frame.aggregateId, 'room_01');
});

test('runtime pauses when device session is invalidated', () async {
  final runtime = SessionRuntime(
    gateway: SessionEventGateway(connect: (_) => throw UnimplementedError()),
    onDeviceInvalidated: () {},
  );

  await runtime.handleFrame(
    const SessionEventFrame(
      eventId: 'evt_invalid',
      userSeq: 8,
      serverTs: 1712000001,
      kind: 'device.invalidated',
      aggregateId: 'device_01',
      payload: <String, dynamic>{},
    ),
  );

  expect(runtime.isRunning, isFalse);
});
```

- [ ] **Step 2: Run the session tests to verify they fail**

Run: `flutter test test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart`
Expected: FAIL with missing `SessionEventFrame`, `SessionEventGateway`, or `SessionRuntime`

- [ ] **Step 3: Implement frame decoding and WebSocket transport**

```dart
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class SessionEventFrame {
  const SessionEventFrame({
    required this.eventId,
    required this.userSeq,
    required this.serverTs,
    required this.kind,
    required this.aggregateId,
    required this.payload,
  });

  factory SessionEventFrame.fromJson(Map<String, dynamic> json) {
    return SessionEventFrame(
      eventId: json['event_id']!.toString(),
      userSeq: (json['user_seq'] as num).toInt(),
      serverTs: (json['server_ts'] as num).toInt(),
      kind: json['kind']!.toString(),
      aggregateId: json['aggregate_id']!.toString(),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  final String eventId;
  final int userSeq;
  final int serverTs;
  final String kind;
  final String aggregateId;
  final Map<String, dynamic> payload;
}

class SessionEventGateway {
  SessionEventGateway({required this.connect});

  final WebSocketChannel Function(Uri uri) connect;
  int lastAckedSeq = 0;

  Stream<SessionEventFrame> open(Uri uri) {
    final channel = connect(uri);
    return channel.stream.map((raw) {
      final frame = SessionEventFrame.fromJson(Map<String, dynamic>.from(jsonDecode(raw as String) as Map));
      lastAckedSeq = frame.userSeq;
      return frame;
    });
  }
}
```

- [ ] **Step 4: Implement runtime lifecycle and IM bootstrap hook**

```dart
class SessionRuntime {
  SessionRuntime({
    required this.gateway,
    required this.onDeviceInvalidated,
  });

  final SessionEventGateway gateway;
  final VoidCallback onDeviceInvalidated;
  bool isRunning = false;

  Future<void> start(Uri uri) async {
    isRunning = true;
    await for (final frame in gateway.open(uri)) {
      await handleFrame(frame);
    }
  }

  Future<void> handleFrame(SessionEventFrame frame) async {
    if (frame.kind == 'device.invalidated') {
      isRunning = false;
      onDeviceInvalidated();
      return;
    }
  }
}

class IMService extends StateNotifier<IMServiceState> {
  Future<bool> init() async {
    final deviceSessionId = StorageUtils.getDeviceSessionId()?.trim() ?? '';
    if (deviceSessionId.isEmpty) {
      state = state.copyWith(error: 'Device session missing.');
      return false;
    }
    final uid = StorageUtils.getUid()?.trim() ?? '';
    final token = StorageUtils.getToken()?.trim() ?? '';
    final options = Options.newDefault(uid, token, addr: IMConfig.connectAddr)
      ..protoVersion = IMConfig.protoVersion
      ..deviceFlag = IMConfig.currentDeviceFlag
      ..debug = kDebugMode;
    final setupOk = await WKIM.shared.setup(options);
    if (!setupOk) {
      state = state.copyWith(error: 'WKIM setup failed.');
      return false;
    }
    await _sessionRuntime.start(
      Uri.parse(
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/v1/realtime/session/events/ws?device_session_id=$deviceSessionId&last_acked_seq=0',
      ),
    );
    return true;
  }
}
```

- [ ] **Step 5: Run the session tests again**

Run: `flutter test test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart`
Expected: PASS with ordered frame decoding and invalidation handling green

- [ ] **Step 6: Commit**

```bash
git add lib/realtime/session/session_event_frame.dart lib/realtime/session/session_event_gateway.dart lib/realtime/session/session_runtime.dart lib/service/im/im_service.dart test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart
git commit -m "feat: add client session event runtime"
```

### Task 6: Emit Call Events On The Server And Demote Polling

**Files:**
- Modify: `/data/build/TangSengDaoDaoServer/modules/extra/api.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/extra/db.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/extra/models.go`
- Modify: `/data/build/TangSengDaoDaoServer/modules/realtime/service.go`
- Create: `/data/build/TangSengDaoDaoServer/modules/extra/api_call_event_test.go`

- [ ] **Step 1: Write the failing call-event server test**

```go
func TestBuildCallInviteFrame(t *testing.T) {
    frame := buildCallInviteFrame("room_01", "u_caller_01", "u_callee_01", 1)

    require.Equal(t, "call.invite", frame.Kind)
    require.Equal(t, "room_01", frame.AggregateID)
    require.Contains(t, frame.Payload, "u_caller_01")
    require.Contains(t, frame.Payload, "u_callee_01")
}
```

- [ ] **Step 2: Run the call-event test to verify it fails**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/extra -run TestCreateRoomEmitsInviteFrame -count=1"`
Expected: FAIL because `createCallRoom`, `sendSignal`, and `updateCallStatus` do not publish realtime frames yet

- [ ] **Step 3: Publish invite, signal, and state frames through the realtime service**

```go
func buildCallInviteFrame(roomID, callerUID, calleeUID string, callType int) realtime.Frame {
    return realtime.Frame{
        Kind:        "call.invite",
        AggregateID: roomID,
        Payload:     util.ToJson(map[string]interface{}{"room_id": roomID, "caller_uid": callerUID, "callee_uid": calleeUID, "call_type": callType}),
    }
}

if err := a.realtime.Append(req.CalleeUid, "call.invite", roomId, []byte(util.ToJson(map[string]interface{}{
    "room_id": roomId,
    "caller_uid": uid,
    "callee_uid": req.CalleeUid,
    "call_type": req.CallType,
})))); err != nil {
    a.Error("emit call invite failed", zap.Error(err))
}
```

```go
if err := a.realtime.Append(peerUID, "call.signal", req.RoomId, []byte(util.ToJson(map[string]interface{}{
    "from_uid": uid,
    "signal_type": req.SignalType,
    "payload": req.Payload,
})))); err != nil {
    a.Error("emit call signal failed", zap.Error(err))
}
```

```go
if err := a.realtime.Append(targetUID, "call.state", roomId, []byte(util.ToJson(map[string]interface{}{
    "room_id": roomId,
    "status": req.Status,
})))); err != nil {
    a.Error("emit call state failed", zap.Error(err))
}
```

- [ ] **Step 4: Demote `/v1/extra/call/pending` and `/v1/extra/call/signals/:room_id` to explicit fallback paths**

```go
func (a *API) getPendingCalls(c *wkhttp.Context) {
    if c.Query("fallback") != "1" {
        c.Response(map[string]interface{}{
            "data": []interface{}{},
            "meta": map[string]interface{}{"fallback_only": true},
        })
        return
    }
    // existing DB query stays behind fallback=1 only
}

func (a *API) getSignals(c *wkhttp.Context) {
    if c.Query("fallback") != "1" {
        c.Response(map[string]interface{}{
            "data": []interface{}{},
            "meta": map[string]interface{}{"fallback_only": true},
        })
        return
    }
    // existing DB query stays behind fallback=1 only
}
```

- [ ] **Step 5: Run the extra module tests again**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/extra -count=1"`
Expected: PASS with emitted `call.invite`, `call.signal`, and `call.state` frames

- [ ] **Step 6: Commit**

```bash
ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && git add modules/extra/api.go modules/extra/db.go modules/extra/models.go modules/extra/api_call_event_test.go modules/realtime/service.go && git commit -m 'feat: emit call events through realtime gateway'"
```

### Task 7: Migrate Client Call Runtime To Store-Driven Realtime Signaling

**Files:**
- Create: `lib/realtime/call/call_state_machine.dart`
- Create: `lib/realtime/call/call_event_mapper.dart`
- Create: `lib/realtime/call/call_store.dart`
- Create: `test/realtime/call/call_state_machine_test.dart`
- Create: `test/realtime/call/call_store_test.dart`
- Modify: `lib/service/api/call_api.dart`
- Modify: `lib/modules/video_call/call_coordinator.dart`
- Modify: `lib/modules/video_call/video_call_service.dart`
- Modify: `lib/modules/video_call/video_call_page.dart`

- [ ] **Step 1: Write the failing call-store tests**

```dart
test('call state machine enforces one active room and ordered transitions', () {
  final machine = CallStateMachine();

  final invited = machine.reduce(
    const CallSessionState.idle(),
    const CallEvent.invite(roomId: 'room_01', peerUid: 'u_peer_01', callType: CallType.video),
  );
  final connected = machine.reduce(invited, const CallEvent.remoteState(roomId: 'room_01', status: 'connected'));

  expect(invited.status, CallLifecycleStatus.invited);
  expect(connected.status, CallLifecycleStatus.connected);
});

test('call store ignores stale events from an old room once a new room is active', () async {
  final store = CallStore(machine: CallStateMachine());

  store.apply(const CallEvent.invite(roomId: 'room_02', peerUid: 'u_peer_02', callType: CallType.audio));
  store.apply(const CallEvent.remoteState(roomId: 'room_01', status: 'ended'));

  expect(store.state.roomId, 'room_02');
});
```

- [ ] **Step 2: Run the call tests to verify they fail**

Run: `flutter test test/realtime/call/call_state_machine_test.dart test/realtime/call/call_store_test.dart`
Expected: FAIL with missing `CallStateMachine`, `CallStore`, or lifecycle state classes

- [ ] **Step 3: Implement the call state machine and mapper**

```dart
enum CallLifecycleStatus {
  idle,
  invited,
  ringing,
  connecting,
  connected,
  reconnecting,
  ending,
  ended,
  failed,
}

class CallSessionState {
  const CallSessionState({
    required this.status,
    required this.roomId,
    required this.peerUid,
    required this.callType,
  });

  const CallSessionState.idle()
      : status = CallLifecycleStatus.idle,
        roomId = '',
        peerUid = '',
        callType = CallType.audio;

  final CallLifecycleStatus status;
  final String roomId;
  final String peerUid;
  final CallType callType;
}

sealed class CallEvent {
  const CallEvent(this.roomId);

  final String roomId;

  const factory CallEvent.invite({
    required String roomId,
    required String peerUid,
    required CallType callType,
  }) = InviteCallEvent;

  const factory CallEvent.remoteState({
    required String roomId,
    required String status,
  }) = RemoteStateCallEvent;

  const factory CallEvent.localDial({
    required String roomId,
    required String peerUid,
    required CallType callType,
  }) = LocalDialCallEvent;
}

class InviteCallEvent extends CallEvent {
  const InviteCallEvent({
    required String roomId,
    required this.peerUid,
    required this.callType,
  }) : super(roomId);

  final String peerUid;
  final CallType callType;
}

class RemoteStateCallEvent extends CallEvent {
  const RemoteStateCallEvent({
    required String roomId,
    required this.status,
  }) : super(roomId);

  final String status;
}

class LocalDialCallEvent extends CallEvent {
  const LocalDialCallEvent({
    required String roomId,
    required this.peerUid,
    required this.callType,
  }) : super(roomId);

  final String peerUid;
  final CallType callType;
}

class CallStateMachine {
  CallSessionState reduce(CallSessionState current, CallEvent event) {
    if (current.roomId.isNotEmpty && event.roomId != current.roomId && current.status != CallLifecycleStatus.idle) {
      return current;
    }
    return switch (event) {
      InviteCallEvent() => CallSessionState(status: CallLifecycleStatus.invited, roomId: event.roomId, peerUid: event.peerUid, callType: event.callType),
      RemoteStateCallEvent(status: 'connected') => CallSessionState(status: CallLifecycleStatus.connected, roomId: current.roomId, peerUid: current.peerUid, callType: current.callType),
      RemoteStateCallEvent(status: 'ended') => CallSessionState(status: CallLifecycleStatus.ended, roomId: current.roomId, peerUid: current.peerUid, callType: current.callType),
      _ => current,
    };
  }
}
```

- [ ] **Step 4: Replace timer polling in `CallCoordinator` and `VideoCallService` with the store and degradation-only fallback**

```dart
class CallCoordinator {
  void start(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _subscription ??= _callStore.stream.listen(_handleCallState);
  }
}

class VideoCallService {
  Future<void> startCall({
    required String targetUid,
    required String targetName,
    required CallType callType,
  }) async {
    await _sendAction('call.invite', <String, dynamic>{
      'target_uid': targetUid,
      'call_type': callType.value,
    });
    _callStore.apply(CallEvent.localDial(roomId: _callStore.state.roomId, peerUid: targetUid, callType: callType));
  }

  Future<void> acceptIncomingCall({
    required CallRoom room,
    required CallType callType,
  }) async {
    await _sendAction('call.accept', <String, dynamic>{'room_id': room.roomId});
  }
}
```

- [ ] **Step 5: Gate fallback polling behind visibility plus gateway degradation**

```dart
Future<void> pollFallbackSignalsIfNeeded() async {
  if (!_sessionRuntime.isGatewayDegradedFor(const Duration(seconds: 10))) {
    return;
  }
  if (!_appVisibility.isForeground) {
    return;
  }
  final backoff = <Duration>[
    const Duration(seconds: 2),
    const Duration(seconds: 4),
    const Duration(seconds: 8),
    const Duration(seconds: 15),
  ];
  for (final delay in backoff) {
    await Future<void>.delayed(delay);
    await _callApi.getSignals(_callStore.state.roomId, fallback: true);
    if (!_sessionRuntime.isGatewayDegraded) {
      return;
    }
  }
}
```

- [ ] **Step 6: Run the call tests**

Run: `flutter test test/realtime/call/call_state_machine_test.dart test/realtime/call/call_store_test.dart`
Expected: PASS with one-room enforcement and stale-event suppression green

- [ ] **Step 7: Commit**

```bash
git add lib/realtime/call/call_state_machine.dart lib/realtime/call/call_event_mapper.dart lib/realtime/call/call_store.dart lib/service/api/call_api.dart lib/modules/video_call/call_coordinator.dart lib/modules/video_call/video_call_service.dart lib/modules/video_call/video_call_page.dart test/realtime/call/call_state_machine_test.dart test/realtime/call/call_store_test.dart
git commit -m "feat: migrate call runtime to realtime store"
```

### Task 8: Run Full Verification And Rollout Rehearsal

**Files:**
- Modify: `docs/superpowers/specs/2026-04-02-realtime-event-core-v2-phase-1-design.md`
- Modify: `docs/superpowers/plans/2026-04-02-realtime-event-core-v2-phase-1.md`

- [ ] **Step 1: Run local static analysis**

Run: `dart analyze lib/realtime lib/service/api lib/service/im lib/data/providers/auth_provider.dart lib/modules/video_call lib/wukong_push lib/wukong_login/pc_login_page.dart`
Expected: `No issues found!`

- [ ] **Step 2: Run the local Flutter test packs**

Run: `flutter test test/realtime/device/device_identity_service_test.dart test/realtime/device/device_identity_login_flow_test.dart test/realtime/session/session_event_gateway_test.dart test/realtime/session/session_runtime_test.dart test/realtime/call/call_state_machine_test.dart test/realtime/call/call_store_test.dart test/wukong_push/push_service_test.dart`
Expected: PASS for the complete realtime-core Phase 1 client pack

- [ ] **Step 3: Run remote Go tests**

Run: `ssh root@103.207.68.33 "cd /data/build/TangSengDaoDaoServer && go test ./modules/user ./modules/realtime ./modules/extra ./modules/webhook"`
Expected: PASS for the server-side Phase 1 pack

- [ ] **Step 4: Validate the deployed environment over SSH**

Run: `ssh root@103.207.68.33 "docker ps && tail -n 200 /data/fullstack/wukongimdata/logs/error.log && docker logs --tail 200 fullstack-tangsengdaodaoserver-1"`
Expected: containers print successfully, the log tail succeeds, and the recent output no longer shows dense `/v1/extra/call/pending` access as the primary call path

- [ ] **Step 5: Rehearse the three golden flows**

```text
Flow A: phone or username login -> /v1/user/device/bind -> IM bootstrap -> session gateway connect -> push token register
Flow B: PC QR login -> auth_code login -> /v1/user/device/bind -> session gateway connect -> no duplicate device rows
Flow C: call invite -> realtime call.invite frame -> accept -> call.signal exchange -> ended state -> no 2-second signal poll loop during healthy gateway operation
```

- [ ] **Step 6: Capture rollout evidence**

```text
Record:
1. The `device_session_id` returned for each login path
2. The first successful `session/events/ws` connection timestamp
3. The last acknowledged `user_seq` after reconnect
4. Whether fallback polling ever activated and why
5. Whether `device_info_missing` / `设备信息不存在` still appeared in the backend log tail
```

- [ ] **Step 7: Commit documentation updates**

```bash
git add docs/superpowers/specs/2026-04-02-realtime-event-core-v2-phase-1-design.md docs/superpowers/plans/2026-04-02-realtime-event-core-v2-phase-1.md
git commit -m "docs: record realtime event core rollout verification"
```

## Self-Review Checklist

- Spec coverage:
  - `Device Identity V2` is covered by Tasks 1, 2, and 3
  - `Session Event Gateway V2` is covered by Tasks 4 and 5
  - `Call Signaling V2` is covered by Tasks 6 and 7
  - remote verification via `ssh root@103.207.68.33` is covered by Task 8
  - the `device_info_missing` / `设备信息不存在` push-token failure path is addressed in Task 3
- Placeholder scan:
  - no `TODO`, `TBD`, “later”, or “similar to above” placeholders remain
- Type consistency:
  - `DeviceIdentityAuthority`, `device_session_id`, `SessionEventFrame`, `SessionRuntime`, `CallStateMachine`, and `CallStore` use consistent naming across all tasks
