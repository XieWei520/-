import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/user.dart';
import '../../realtime/device/device_identity_service.dart';
import '../../realtime/device/device_store.dart';
import '../../service/api/api_client.dart';
import '../../service/api/auth_api.dart';
import '../../service/im/im_service.dart';
import '../../modules/auth/data/shared_prefs_auth_login_preferences_store.dart';
import '../../modules/auth/domain/auth_flow_models.dart';
import '../../modules/home/home_surface_kernel.dart';
import '../../wukong_base/msg/draft_manager.dart';
import '../../wukong_push/device_badge_service.dart';
import '../../wukong_push/push_service.dart';
import 'channel_provider.dart';
import 'conversation_provider.dart';
import 'user_provider.dart';

class AuthState {
  final bool isLoggedIn;
  final bool needsProfileCompletion;
  final UserInfo? userInfo;
  final bool isRestoringSession;
  final bool isLoading;
  final String? error;

  AuthState({
    this.isLoggedIn = false,
    this.needsProfileCompletion = false,
    this.userInfo,
    this.isRestoringSession = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? needsProfileCompletion,
    UserInfo? userInfo,
    bool? isRestoringSession,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      needsProfileCompletion:
          needsProfileCompletion ?? this.needsProfileCompletion,
      userInfo: userInfo ?? this.userInfo,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

final deviceIdentityAuthorityProvider = Provider<DeviceIdentityAuthority>((
  ref,
) {
  return DeviceIdentityAuthority(store: DeviceStore());
});

final authCurrentUserLoaderProvider = Provider<Future<UserInfo?> Function()>((
  ref,
) {
  final authApi = AuthApi.instance;
  return () async {
    try {
      return await authApi.getCurrentUser();
    } catch (_) {
      return null;
    }
  };
});

final authDraftSyncProvider = Provider<Future<void> Function()>((ref) {
  return () => DraftManager().loadAllDrafts();
});

final authLogoutRequestProvider = Provider<Future<void> Function()>((ref) {
  final authApi = AuthApi.instance;
  return () => authApi.logout();
});

final authAutoLoginDisablerProvider = Provider<Future<void> Function()>((ref) {
  final preferencesStore = SharedPrefsAuthLoginPreferencesStore();
  return () => preferencesStore.disableAutoLogin();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref)
    : _currentUserLoader = _ref.read(authCurrentUserLoaderProvider),
      _draftSync = _ref.read(authDraftSyncProvider),
      _logoutRequest = _ref.read(authLogoutRequestProvider),
      _disableAutoLogin = _ref.read(authAutoLoginDisablerProvider),
      _imService = _ref.read(imServiceProvider.notifier),
      _deviceIdentityAuthority = _ref.read(deviceIdentityAuthorityProvider),
      super(AuthState(isRestoringSession: true)) {
    _registerImVipExpiredHandler();
    _checkLoginStatus();
  }

  final Ref _ref;
  final AuthApi _authApi = AuthApi.instance;
  final Future<UserInfo?> Function() _currentUserLoader;
  final Future<void> Function() _draftSync;
  final Future<void> Function() _logoutRequest;
  final Future<void> Function() _disableAutoLogin;
  final IMService _imService;
  final DeviceIdentityAuthority _deviceIdentityAuthority;
  late final String _vipExpiredHandlerKey =
      'auth_notifier_vip_expired_${identityHashCode(this)}';

  void _registerImVipExpiredHandler() {
    _imService.registerVipExpiredHandler(
      key: _vipExpiredHandlerKey,
      handler: () {
        final current = state.userInfo;
        if (current == null || current.vipLevel != 1) {
          return;
        }
        updateCurrentUser(current.copyWith(vipLevel: 0));
      },
    );
  }

  Future<void> _syncDraftScope() async {
    await _draftSync();
  }

  Future<void> _commitLogin(UserInfo userInfo) async {
    await connectAuthenticatedSession(userInfo);
    await registerPushAfterLogin();
  }

  bool _startRequest() {
    if (state.isLoading || state.isRestoringSession) {
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    return true;
  }

  Future<void> _checkLoginStatus() async {
    if (!StorageUtils.isLoggedIn()) {
      state = state.copyWith(isRestoringSession: false);
      return;
    }

    final restoredToken = StorageUtils.getToken()?.trim() ?? '';
    final restoredImToken = StorageUtils.getImToken()?.trim() ?? '';
    if (restoredToken.isEmpty || restoredImToken.isEmpty) {
      ApiClient.instance.clearToken();
      await StorageUtils.logout();
      await syncDraftScope();
      state = AuthState(isRestoringSession: false);
      return;
    }
    if (restoredToken.isNotEmpty) {
      ApiClient.instance.setToken(restoredToken);
    }

    final userInfo = await loadCurrentUser();
    if (userInfo != null && userInfo.uid.isNotEmpty) {
      if (StorageUtils.getUid()?.trim() != userInfo.uid) {
        await StorageUtils.setUid(userInfo.uid);
      }
      if (restoredToken.isNotEmpty) {
        await bindDeviceIdentity(uid: userInfo.uid, token: restoredToken);
      }
      await syncDraftScope();
      await _commitLogin(userInfo);
      return;
    }

    ApiClient.instance.clearToken();
    await StorageUtils.logout();
    await syncDraftScope();
    state = AuthState(isRestoringSession: false);
  }

  Future<void> completeLogin(LoginData loginData) async {
    final uid = loginData.uid?.trim() ?? '';
    final token = loginData.token?.trim() ?? '';
    final imToken = loginData.imToken?.trim() ?? token;
    if (uid.isEmpty || token.isEmpty) {
      throw Exception('登录结果缺少 uid 或 token');
    }

    await StorageUtils.setUid(uid);
    await StorageUtils.setToken(token);
    await StorageUtils.setImToken(imToken);
    ApiClient.instance.setToken(token);
    await bindDeviceIdentity(uid: uid, token: token);
    await syncDraftScope();

    final remoteUserInfo = await loadCurrentUser();
    final userInfo =
        remoteUserInfo ??
        loginData.toUserInfo().copyWith(
          uid: uid,
          token: token,
          name: loginData.name,
          avatar: loginData.avatar,
          username: loginData.username,
          phone: loginData.phone,
          zone: loginData.zone,
          shortNo: loginData.shortNo,
        );

    await _commitLogin(userInfo);
  }

  Future<void> bindDeviceIdentity({
    required String uid,
    required String token,
  }) {
    return _deviceIdentityAuthority.bindAuthenticatedSession(
      userId: uid,
      token: token,
    );
  }

  Future<UserInfo?> loadCurrentUser() => _currentUserLoader();

  Future<void> initializeAuthenticatedRuntime(UserInfo user) async {
    final initialized = await _ref.read(imServiceProvider.notifier).init();
    if (!initialized) {
      throw StateError('IM initialization failed for user ${user.uid}.');
    }
  }

  Future<void> rollbackBootstrapSession({
    String? restoreUid,
    String? restoreToken,
    String? restoreImToken,
  }) async {
    final restoredUid = restoreUid?.trim() ?? '';
    final restoredToken = restoreToken?.trim() ?? '';
    final restoredImToken = restoreImToken?.trim() ?? '';
    _ref.read(imServiceProvider.notifier).disconnect(isLogout: true);
    if (restoredUid.isNotEmpty &&
        restoredToken.isNotEmpty &&
        restoredImToken.isNotEmpty) {
      await StorageUtils.setUid(restoredUid);
      await StorageUtils.setToken(restoredToken);
      await StorageUtils.setImToken(restoredImToken);
      ApiClient.instance.setToken(restoredToken);
      return;
    }
    ApiClient.instance.clearToken();
    await StorageUtils.setUid('');
    await StorageUtils.setToken('');
    await StorageUtils.setImToken('');
  }

  Future<void> connectAuthenticatedSession(UserInfo user) async {
    state = state.copyWith(
      isLoggedIn: true,
      needsProfileCompletion: false,
      userInfo: user,
      isRestoringSession: false,
      isLoading: false,
      error: null,
    );
    _invalidatePostLoginProviders();
  }

  Future<void> registerPushAfterLogin() => PushService.instance.handleLogin();

  Future<void> syncDraftScope() => _syncDraftScope();

  Future<void> commitBootstrapResult(AuthBootstrapResult result) async {
    state = state.copyWith(
      isLoggedIn: true,
      needsProfileCompletion: result.requiresProfileCompletion,
      userInfo: result.user,
      isRestoringSession: false,
      isLoading: false,
      error: null,
    );
    _invalidatePostLoginProviders();
  }

  Future<void> completeProfile(UserInfo userInfo) async {
    state = state.copyWith(
      isLoggedIn: true,
      needsProfileCompletion: false,
      userInfo: userInfo,
      isRestoringSession: false,
      isLoading: false,
      error: null,
    );
    _invalidatePostLoginProviders();
  }

  Future<bool> loginWithPhone(
    String phone,
    String password, {
    String zone = '86',
  }) async {
    if (!_startRequest()) {
      return false;
    }

    try {
      final resp = await _authApi.login(phone, password, zone: zone);
      if (resp.success && resp.data != null) {
        await completeLogin(resp.data!);
        return true;
      }

      state = state.copyWith(isLoading: false, error: resp.msg ?? '登录失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> loginWithUsername(String username, String password) async {
    if (!_startRequest()) {
      return false;
    }

    try {
      final resp = await _authApi.loginWithUsername(username, password);
      if (resp.success && resp.data != null) {
        await completeLogin(resp.data!);
        return true;
      }

      state = state.copyWith(isLoading: false, error: resp.msg ?? '登录失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String name,
    required String zone,
    required String phone,
    required String code,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
  }) async {
    if (!_startRequest()) {
      return false;
    }

    try {
      final resp = await _authApi.register(
        username: username,
        password: password,
        name: name,
        zone: zone,
        phone: phone,
        code: code,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceModel: deviceModel,
      );
      if (resp.success) {
        if (resp.data?.uid != null && resp.data?.token != null) {
          await completeLogin(
            LoginData(
              uid: resp.data!.uid,
              token: resp.data!.token,
              imToken: resp.data!.imToken,
              name: resp.data!.name ?? name,
              username: username,
              zone: zone,
              phone: phone,
            ),
          );
          return true;
        }
        state = state.copyWith(isLoading: false);
        return true;
      }

      state = state.copyWith(isLoading: false, error: resp.msg ?? '注册失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> usernameRegister({
    required String username,
    required String password,
    String? name,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
  }) async {
    if (!_startRequest()) {
      return false;
    }

    try {
      final resp = await _authApi.usernameRegister(
        username: username,
        password: password,
        name: name,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceModel: deviceModel,
      );
      if (resp.success) {
        if (resp.data?.uid != null && resp.data?.token != null) {
          await completeLogin(
            LoginData(
              uid: resp.data!.uid,
              token: resp.data!.token,
              imToken: resp.data!.imToken,
              name: resp.data!.name ?? name,
              username: username,
            ),
          );
          return true;
        }
        state = state.copyWith(isLoading: false);
        return true;
      }

      state = state.copyWith(isLoading: false, error: resp.msg ?? '注册失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> sendRegisterCode(String phone, {String zone = '86'}) async {
    try {
      await _authApi.sendRegisterCode(phone, zone: zone);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _logoutRequest();
    } catch (_) {}
    try {
      await _disableAutoLogin();
    } catch (_) {}
    _ref.read(imServiceProvider.notifier).disconnect(isLogout: true);
    await PushService.instance.handleLogout();
    await DeviceBadgeService.instance.clearLocalBadge();
    ApiClient.instance.clearToken();
    await StorageUtils.logout();
    await syncDraftScope();
    state = AuthState();
    _ref.invalidate(friendListProvider);
    _ref.invalidate(friendRequestListProvider);
    _ref.invalidate(myGroupListProvider);
    _ref.invalidate(conversationProvider);
    _ref.invalidate(currentChatProvider);
    _ref.invalidate(homeBootstrapStateProvider);
  }

  void updateCurrentUser(UserInfo userInfo) {
    if (!state.isLoggedIn) {
      return;
    }
    state = state.copyWith(userInfo: userInfo, error: null);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _imService.unregisterVipExpiredHandler(_vipExpiredHandlerKey);
    super.dispose();
  }

  void _invalidatePostLoginProviders() {
    _ref.invalidate(friendListProvider);
    _ref.invalidate(friendRequestListProvider);
    _ref.invalidate(myGroupListProvider);
    _ref.invalidate(conversationProvider);
  }
}
