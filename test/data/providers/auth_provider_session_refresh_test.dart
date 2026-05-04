import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/data/providers/channel_provider.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';
import 'package:wukong_im_app/realtime/device/device_identity.dart';
import 'package:wukong_im_app/realtime/device/device_identity_service.dart';
import 'package:wukong_im_app/realtime/device/device_store.dart';
import 'package:wukong_im_app/service/api/auth_api.dart';
import 'package:wukong_im_app/service/im/im_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
    await StorageUtils.clear();
  });

  test(
    'commitBootstrapResult invalidates friend, request, group, and conversation providers',
    () async {
      final friendBuilds = ValueNotifier<int>(0);
      final requestBuilds = ValueNotifier<int>(0);
      final groupBuilds = ValueNotifier<int>(0);
      final conversationBuilds = ValueNotifier<int>(0);
      final container = ProviderContainer(
        overrides: [
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
          authLogoutRequestProvider.overrideWithValue(() async {}),
          authAutoLoginDisablerProvider.overrideWithValue(() async {}),
          imServiceProvider.overrideWith((ref) => _NoopIMService()),
          friendListProvider.overrideWith(
            (ref) => _TrackingFriendListNotifier(friendBuilds),
          ),
          friendRequestListProvider.overrideWith(
            (ref) => _TrackingFriendRequestListNotifier(requestBuilds),
          ),
          myGroupListProvider.overrideWith(
            (ref) => _TrackingMyGroupListNotifier(groupBuilds),
          ),
          conversationProvider.overrideWith(
            (ref) => _TrackingConversationNotifier(conversationBuilds),
          ),
        ],
      );
      addTearDown(container.dispose);

      final friendSub = container.listen(friendListProvider, (_, __) {});
      final requestSub = container.listen(
        friendRequestListProvider,
        (_, __) {},
      );
      final groupSub = container.listen(myGroupListProvider, (_, __) {});
      final conversationSub = container.listen(
        conversationProvider,
        (_, __) {},
      );
      addTearDown(friendSub.close);
      addTearDown(requestSub.close);
      addTearDown(groupSub.close);
      addTearDown(conversationSub.close);

      final authNotifier = container.read(authProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final baselineFriendBuilds = friendBuilds.value;
      final baselineRequestBuilds = requestBuilds.value;
      final baselineGroupBuilds = groupBuilds.value;
      final baselineConversationBuilds = conversationBuilds.value;

      await authNotifier.commitBootstrapResult(
        AuthBootstrapResult(
          stage: AuthStage.authenticatedReady,
          user: UserInfo(uid: 'u_sync', token: 'token_sync', name: 'Sync User'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(friendBuilds.value, greaterThan(baselineFriendBuilds));
      expect(requestBuilds.value, greaterThan(baselineRequestBuilds));
      expect(groupBuilds.value, greaterThan(baselineGroupBuilds));
      expect(conversationBuilds.value, greaterThan(baselineConversationBuilds));
    },
  );

  test('logout resets the home bootstrap state', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _NoopBindAuthNotifier(ref)),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        authLogoutRequestProvider.overrideWithValue(() async {}),
        authAutoLoginDisablerProvider.overrideWithValue(() async {}),
        deviceIdentityAuthorityProvider.overrideWithValue(
          _buildTestDeviceIdentityAuthority(),
        ),
        imServiceProvider.overrideWith((ref) => _NoopIMService()),
      ],
    );
    addTearDown(container.dispose);

    final authNotifier = container.read(authProvider.notifier);
    final homeController = container.read(homeBootstrapStateProvider.notifier);
    homeController.state = const HomeBootstrapState.ready();

    await StorageUtils.setUid('u_logout');
    await StorageUtils.setToken('token_logout');
    await authNotifier.logout();

    final nextBootstrapState = container.read(homeBootstrapStateProvider);
    expect(nextBootstrapState.isLoading, isTrue);
    expect(nextBootstrapState.isReady, isFalse);
    expect(nextBootstrapState.error, isNull);
  });

  test('completeLogin stores IM token separately from HTTP token', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _NoopBindAuthNotifier(ref)),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        authLogoutRequestProvider.overrideWithValue(() async {}),
        authAutoLoginDisablerProvider.overrideWithValue(() async {}),
        deviceIdentityAuthorityProvider.overrideWithValue(
          _buildTestDeviceIdentityAuthority(),
        ),
        imServiceProvider.overrideWith((ref) => _NoopIMService()),
      ],
    );
    addTearDown(container.dispose);

    final authNotifier = container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await authNotifier.completeLogin(
      LoginData(
        uid: 'u_login',
        token: 'http_token_login',
        imToken: 'im_token_login',
        name: 'Login User',
      ),
    );

    expect(StorageUtils.getUid(), 'u_login');
    expect(StorageUtils.getToken(), 'http_token_login');
    expect(StorageUtils.getImToken(), 'im_token_login');
  });

  test(
    'restored session without stored IM token is cleared before auth restore',
    () async {
      await StorageUtils.setUid('u_restore');
      await StorageUtils.setToken('http_token_restore');

      final container = ProviderContainer(
        overrides: [
          authCurrentUserLoaderProvider.overrideWithValue(
            () async => UserInfo(
              uid: 'u_restore',
              token: 'http_token_restore',
              name: 'Restore User',
            ),
          ),
          authDraftSyncProvider.overrideWithValue(() async {}),
          authLogoutRequestProvider.overrideWithValue(() async {}),
          authAutoLoginDisablerProvider.overrideWithValue(() async {}),
          deviceIdentityAuthorityProvider.overrideWithValue(
            _buildTestDeviceIdentityAuthority(),
          ),
          imServiceProvider.overrideWith((ref) => _NoopIMService()),
        ],
      );
      addTearDown(container.dispose);

      await _waitForAuthRestore(container);

      final authState = container.read(authProvider);
      expect(authState.isLoggedIn, isFalse);
      expect(authState.isRestoringSession, isFalse);
      expect(authState.userInfo, isNull);
      expect(StorageUtils.getUid(), isNull);
      expect(StorageUtils.getToken(), isNull);
    },
  );

  test('vip_expired downgrades current logged-in VIP user', () async {
    final imService = _NoopIMService();
    final container = ProviderContainer(
      overrides: [
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        authLogoutRequestProvider.overrideWithValue(() async {}),
        authAutoLoginDisablerProvider.overrideWithValue(() async {}),
        imServiceProvider.overrideWith((ref) => imService),
      ],
    );
    addTearDown(container.dispose);

    final authNotifier = container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await authNotifier.connectAuthenticatedSession(
      UserInfo(uid: 'u_vip', token: 'token_vip', vipLevel: 1),
    );

    imService.emitVipExpired();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authProvider).userInfo?.vipLevel, 0);
  });

  test('vip_expired keeps non-vip current user unchanged', () async {
    final imService = _NoopIMService();
    final container = ProviderContainer(
      overrides: [
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        authLogoutRequestProvider.overrideWithValue(() async {}),
        authAutoLoginDisablerProvider.overrideWithValue(() async {}),
        imServiceProvider.overrideWith((ref) => imService),
      ],
    );
    addTearDown(container.dispose);

    final authNotifier = container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await authNotifier.connectAuthenticatedSession(
      UserInfo(uid: 'u_nonvip', token: 'token_nonvip', vipLevel: 0),
    );

    final before = container.read(authProvider).userInfo;
    imService.emitVipExpired();
    await Future<void>.delayed(Duration.zero);
    final after = container.read(authProvider).userInfo;

    expect(after?.vipLevel, 0);
    expect(identical(before, after), isTrue);
  });

  test('disposing auth provider unregisters vip_expired handler', () async {
    final imService = _NoopIMService();
    final container = ProviderContainer(
      overrides: [
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        authLogoutRequestProvider.overrideWithValue(() async {}),
        authAutoLoginDisablerProvider.overrideWithValue(() async {}),
        imServiceProvider.overrideWith((ref) => imService),
      ],
    );

    container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    expect(imService.vipExpiredHandlerCount, 1);

    container.dispose();

    expect(imService.vipExpiredHandlerCount, 0);
    expect(() => imService.emitVipExpired(), returnsNormally);
  });
}

class _NoopIMService extends IMService {
  final Map<String, void Function()> _vipExpiredHandlers =
      <String, void Function()>{};

  int get vipExpiredHandlerCount => _vipExpiredHandlers.length;

  @override
  void registerVipExpiredHandler({
    required String key,
    required void Function() handler,
  }) {
    _vipExpiredHandlers[key] = handler;
  }

  @override
  void unregisterVipExpiredHandler(String key) {
    _vipExpiredHandlers.remove(key);
  }

  void emitVipExpired() {
    final handlers = List<void Function()>.from(_vipExpiredHandlers.values);
    for (final handler in handlers) {
      handler();
    }
  }

  @override
  Future<bool> init() async => true;

  @override
  void disconnect({bool isLogout = false}) {}
}

class _NoopBindAuthNotifier extends AuthNotifier {
  _NoopBindAuthNotifier(super.ref);

  @override
  Future<void> bindDeviceIdentity({
    required String uid,
    required String token,
  }) async {}
}

DeviceIdentityAuthority _buildTestDeviceIdentityAuthority() {
  return DeviceIdentityAuthority(
    store: _MemoryDeviceStore(),
    client: _NoopDeviceBindClient(),
  );
}

Future<void> _waitForAuthRestore(ProviderContainer container) async {
  for (var index = 0; index < 20; index++) {
    await Future<void>.delayed(Duration.zero);
    if (!container.read(authProvider).isRestoringSession) {
      return;
    }
  }
}

class _NoopDeviceBindClient implements DeviceBindClient {
  @override
  Future<BoundDeviceSession> bindDeviceSession({
    required DeviceIdentity identity,
    required int bindVersion,
  }) async {
    return BoundDeviceSession(
      deviceSessionId: 'device_session_test',
      bindVersion: bindVersion,
    );
  }
}

class _MemoryDeviceStore extends DeviceStore {
  DeviceIdentity _identity = const DeviceIdentity(
    deviceId: 'device_test',
    deviceInstallId: 'install_test',
    deviceSessionId: '',
    bindVersion: 0,
    userId: '',
    deviceName: 'Test Device',
    deviceModel: 'windows',
  );

  @override
  Object get identityPersistenceScope => this;

  @override
  Future<DeviceIdentity> read() async => _identity;

  @override
  Future<void> write(DeviceIdentity identity) async {
    _identity = identity;
  }
}

class _TrackingConversationNotifier extends ConversationNotifier {
  _TrackingConversationNotifier(this.buildCounter) : super() {
    buildCounter.value += 1;
  }

  final ValueNotifier<int> buildCounter;
}

class _TrackingFriendListNotifier extends FriendListNotifier {
  _TrackingFriendListNotifier(this.buildCounter) : super();

  final ValueNotifier<int> buildCounter;

  @override
  Future<void> loadFriends() async {
    buildCounter.value += 1;
    state = const AsyncValue.data(<Friend>[]);
  }
}

class _TrackingFriendRequestListNotifier extends FriendRequestListNotifier {
  _TrackingFriendRequestListNotifier(this.buildCounter) : super();

  final ValueNotifier<int> buildCounter;

  @override
  Future<void> loadRequests() async {
    buildCounter.value += 1;
    state = const AsyncValue.data(<FriendRequest>[]);
  }
}

class _TrackingMyGroupListNotifier extends MyGroupListNotifier {
  _TrackingMyGroupListNotifier(this.buildCounter) : super();

  final ValueNotifier<int> buildCounter;

  @override
  Future<void> loadGroups() async {
    buildCounter.value += 1;
    state = const AsyncValue.data(<GroupInfo>[]);
  }
}
