import '../../../data/models/user.dart';
import '../domain/auth_flow_models.dart';

typedef PersistSession =
    Future<void> Function({
      required String uid,
      required String token,
      required String imToken,
    });
typedef RollbackSession = Future<void> Function();

typedef BindDeviceIdentity =
    Future<void> Function({required String uid, required String token});

typedef LoadCurrentUser = Future<UserInfo?> Function();
typedef InitializeAuthenticatedRuntime = Future<void> Function(UserInfo user);
typedef RegisterPush = Future<void> Function();
typedef SyncDrafts = Future<void> Function();
typedef PersistLoginPreferences = Future<void> Function(UserInfo user);

class AuthBootstrapCoordinator {
  AuthBootstrapCoordinator({
    required PersistSession persistSession,
    required RollbackSession rollbackSession,
    required BindDeviceIdentity bindDeviceIdentity,
    required LoadCurrentUser loadCurrentUser,
    required InitializeAuthenticatedRuntime initializeAuthenticatedRuntime,
    required RegisterPush registerPush,
    required SyncDrafts syncDrafts,
    PersistLoginPreferences? persistLoginPreferences,
  }) : _persistSession = persistSession,
       _rollbackSession = rollbackSession,
       _bindDeviceIdentity = bindDeviceIdentity,
       _loadCurrentUser = loadCurrentUser,
       _initializeAuthenticatedRuntime = initializeAuthenticatedRuntime,
       _registerPush = registerPush,
       _syncDrafts = syncDrafts,
       _persistLoginPreferences =
           persistLoginPreferences ?? _noopPersistLoginPreferences;

  final PersistSession _persistSession;
  final RollbackSession _rollbackSession;
  final BindDeviceIdentity _bindDeviceIdentity;
  final LoadCurrentUser _loadCurrentUser;
  final InitializeAuthenticatedRuntime _initializeAuthenticatedRuntime;
  final RegisterPush _registerPush;
  final SyncDrafts _syncDrafts;
  final PersistLoginPreferences _persistLoginPreferences;

  Future<AuthBootstrapResult> bootstrap(AuthCredentialResult result) async {
    if (!result.success || result.user == null) {
      throw StateError(
        result.message ??
            'Auth bootstrap requires a successful credential result.',
      );
    }

    final uid = result.uid.trim();
    final token = result.token.trim();
    final imToken = result.imToken.trim().isNotEmpty
        ? result.imToken.trim()
        : token;
    if (uid.isEmpty || token.isEmpty) {
      throw StateError('Auth bootstrap requires non-empty uid and token.');
    }

    var sessionMayBeDirty = false;
    try {
      sessionMayBeDirty = true;
      await _persistSession(uid: uid, token: token, imToken: imToken);
      await _bindDeviceIdentity(uid: uid, token: token);
      final remoteUser = await _loadCurrentUser();
      final user = (remoteUser ?? result.user!).copyWith(
        uid: uid,
        token: token,
      );
      await _initializeAuthenticatedRuntime(user);
      await _registerPush();
      await _syncDrafts();
      await _persistLoginPreferencesSafely(user);

      if (_requiresProfileCompletion(user)) {
        return AuthBootstrapResult(
          stage: AuthStage.awaitingProfileCompletion,
          user: user,
        );
      }

      return AuthBootstrapResult(
        stage: AuthStage.authenticatedReady,
        user: user,
      );
    } catch (_) {
      if (sessionMayBeDirty) {
        try {
          await _rollbackSession();
        } catch (_) {}
      }
      rethrow;
    }
  }

  bool _requiresProfileCompletion(UserInfo user) {
    final name = user.name?.trim() ?? '';
    final avatar = user.avatar?.trim() ?? '';
    return name.isEmpty || avatar.isEmpty;
  }

  Future<void> _persistLoginPreferencesSafely(UserInfo user) async {
    try {
      await _persistLoginPreferences(user);
    } catch (_) {}
  }

  static Future<void> _noopPersistLoginPreferences(UserInfo user) async {}
}
