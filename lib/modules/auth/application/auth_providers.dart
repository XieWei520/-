import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/storage_utils.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/config/im_config.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../service/api/api_client.dart';
import '../../../service/api/auth_api.dart';
import '../../../service/api/login_bridge_api.dart';
import '../../../service/api/user_api.dart';
import '../coordinators/auth_bootstrap_coordinator.dart';
import '../data/auth_repository_impl.dart';
import '../data/shared_prefs_auth_login_preferences_store.dart';
import '../domain/auth_flow_models.dart';
import '../domain/auth_login_preferences_store.dart';
import '../domain/auth_repository.dart';
import 'auth_flow_controller.dart';
import 'device_session_controller.dart';

typedef AuthProfileAvatarPicker = Future<String?> Function();

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    authApi: AuthApi.instance,
    userApi: UserApi.instance,
    loginBridgeApi: LoginBridgeApi.instance,
  );
});

final authLoginPreferencesStoreProvider = Provider<AuthLoginPreferencesStore>((
  ref,
) {
  return SharedPrefsAuthLoginPreferencesStore();
});

final quitAllShouldTerminateLocalSessionProvider = Provider<bool>((ref) {
  final deviceFlag = IMConfig.currentDeviceFlag;
  return deviceFlag == IMConfig.deviceFlagPC ||
      deviceFlag == IMConfig.deviceFlagWeb;
});

final localSessionTerminatorProvider = Provider<Future<void> Function()>((ref) {
  final authNotifier = ref.read(authProvider.notifier);
  return () => authNotifier.logout();
});

final authBootstrapCoordinatorProvider = Provider<AuthBootstrapCoordinator>((
  ref,
) {
  final authNotifier = ref.read(authProvider.notifier);
  final preferencesStore = ref.read(authLoginPreferencesStoreProvider);
  _AuthSessionSnapshot? previousSessionSnapshot;
  return AuthBootstrapCoordinator(
    persistSession: ({required uid, required token, required imToken}) async {
      previousSessionSnapshot = _AuthSessionSnapshot(
        uid: (StorageUtils.getUid() ?? '').trim(),
        token: (StorageUtils.getToken() ?? '').trim(),
        imToken: (StorageUtils.getImToken() ?? '').trim(),
      );
      await StorageUtils.setUid(uid);
      await StorageUtils.setToken(token);
      await StorageUtils.setImToken(imToken);
      ApiClient.instance.setToken(token);
    },
    rollbackSession: () async {
      final snapshot = previousSessionSnapshot;
      previousSessionSnapshot = null;
      final restoreUid = snapshot?.hasValidSession == true
          ? snapshot?.uid
          : null;
      final restoreToken = snapshot?.hasValidSession == true
          ? snapshot?.token
          : null;
      final restoreImToken = snapshot?.hasValidSession == true
          ? snapshot?.imToken
          : null;
      await authNotifier.rollbackBootstrapSession(
        restoreUid: restoreUid,
        restoreToken: restoreToken,
        restoreImToken: restoreImToken,
      );
    },
    bindDeviceIdentity: ({required uid, required token}) {
      return authNotifier.bindDeviceIdentity(uid: uid, token: token);
    },
    loadCurrentUser: authNotifier.loadCurrentUser,
    initializeAuthenticatedRuntime: authNotifier.initializeAuthenticatedRuntime,
    registerPush: authNotifier.registerPushAfterLogin,
    syncDrafts: authNotifier.syncDraftScope,
    persistLoginPreferences: (user) {
      return reconcileAuthenticatedLoginPreferences(preferencesStore, user);
    },
  );
});

final authProfileAvatarPickerProvider = Provider<AuthProfileAvatarPicker>((
  ref,
) {
  final picker = ImagePicker();
  return () async {
    if (PlatformUtils.isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
        allowMultiple: false,
        withData: false,
      );
      return result?.files.single.path;
    }

    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    return file?.path;
  };
});

final authFlowControllerProvider =
    StateNotifierProvider.autoDispose<AuthFlowController, AuthFlowState>((ref) {
      return AuthFlowController(
        repository: ref.read(authRepositoryProvider),
        bootstrapCoordinator: ref.read(authBootstrapCoordinatorProvider),
        authNotifier: ref.read(authProvider.notifier),
      );
    });

final deviceSessionControllerProvider =
    StateNotifierProvider.autoDispose<
      DeviceSessionController,
      DeviceSessionState
    >((ref) {
      return DeviceSessionController(
        repository: ref.read(authRepositoryProvider),
      )..load();
    });

class _AuthSessionSnapshot {
  const _AuthSessionSnapshot({
    required this.uid,
    required this.token,
    required this.imToken,
  });

  final String uid;
  final String token;
  final String imToken;

  bool get hasValidSession =>
      uid.isNotEmpty && token.isNotEmpty && imToken.isNotEmpty;
}
