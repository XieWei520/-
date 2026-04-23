import 'package:dio/dio.dart';

import '../../../data/models/user.dart';
import '../../../service/api/auth_api.dart';
import '../../../service/api/login_bridge_api.dart';
import '../../../service/api/user_api.dart';
import '../../../wk_foundation/errors/app_failure.dart';
import '../domain/auth_flow_models.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi authApi,
    UserApi? userApi,
    LoginBridgeApi? loginBridgeApi,
  }) : _authApi = authApi,
       _userApi = userApi ?? UserApi.instance,
       _loginBridgeApi = loginBridgeApi ?? LoginBridgeApi.instance;

  final AuthApi _authApi;
  final UserApi _userApi;
  final LoginBridgeApi _loginBridgeApi;

  @override
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _authApi.login(phone, password, zone: zone);
      if (response.requiresLoginVerification) {
        final verificationUid = response.data?.uid?.trim() ?? '';
        if (verificationUid.isNotEmpty) {
          return AuthCredentialResult.verificationRequired(
            uid: verificationUid,
            phone: response.data?.phone?.trim(),
            message: response.msg,
          );
        }
      }

      final data = response.data;
      final uid = data?.uid?.trim() ?? '';
      final token = data?.token?.trim() ?? '';
      final imToken = _resolveImToken(data?.imToken, token);
      if (!response.success || uid.isEmpty || token.isEmpty || data == null) {
        return AuthCredentialResult.failure(response.msg ?? 'Login failed.');
      }

      return AuthCredentialResult.success(
        uid: uid,
        token: token,
        imToken: imToken,
        user: data.toUserInfo().copyWith(
          uid: uid,
          token: token,
          zone: data.zone ?? zone,
          phone: data.phone ?? phone,
        ),
      );
    } on DioException catch (error) {
      final verificationResult = _tryResolveLoginVerification(error);
      if (verificationResult != null) {
        return verificationResult;
      }
      return AuthCredentialResult.failure(
        AppFailure.describe(error, fallbackMessage: 'Login failed.'),
      );
    } catch (error) {
      return AuthCredentialResult.failure(
        AppFailure.describe(error, fallbackMessage: 'Login failed.'),
      );
    }
  }

  @override
  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _authApi.loginWithUsername(username, password);
      final data = response.data;
      final uid = data?.uid?.trim() ?? '';
      final token = data?.token?.trim() ?? '';
      final imToken = _resolveImToken(data?.imToken, token);
      if (!response.success || uid.isEmpty || token.isEmpty || data == null) {
        return AuthCredentialResult.failure(response.msg ?? 'Login failed.');
      }

      return AuthCredentialResult.success(
        uid: uid,
        token: token,
        imToken: imToken,
        user: data.toUserInfo().copyWith(
          uid: uid,
          token: token,
          username: data.username ?? username,
        ),
      );
    } on DioException catch (error) {
      final verificationResult = _tryResolveLoginVerification(error);
      if (verificationResult != null) {
        return verificationResult;
      }
      return AuthCredentialResult.failure(
        AppFailure.describe(error, fallbackMessage: 'Login failed.'),
      );
    } catch (error) {
      return AuthCredentialResult.failure(
        AppFailure.describe(error, fallbackMessage: 'Login failed.'),
      );
    }
  }

  @override
  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
    String? displayName,
  }) async {
    try {
      final trimmedDisplayName = displayName?.trim() ?? '';
      final resolvedName = trimmedDisplayName.isNotEmpty
          ? trimmedDisplayName
          : phone;
      final response = await _authApi.register(
        username: '$zone$phone',
        password: password,
        zone: zone,
        phone: phone,
        code: code,
        name: resolvedName,
        inviteCode: inviteCode,
      );
      final data = response.data;
      final uid = data?.uid?.trim() ?? '';
      final token = data?.token?.trim() ?? '';
      final imToken = _resolveImToken(data?.imToken, token);
      if (!response.success || uid.isEmpty || token.isEmpty || data == null) {
        return AuthCredentialResult.failure(
          response.msg ?? 'Registration failed.',
        );
      }
      final responseName = data.name?.trim() ?? '';
      final resolvedResponseName = responseName.isNotEmpty
          ? responseName
          : resolvedName;

      return AuthCredentialResult.success(
        uid: uid,
        token: token,
        imToken: imToken,
        user: UserInfo(
          uid: uid,
          token: token,
          name: resolvedResponseName,
          zone: zone,
          phone: phone,
        ),
      );
    } catch (error) {
      return AuthCredentialResult.failure(
        AppFailure.describe(error, fallbackMessage: 'Registration failed.'),
      );
    }
  }

  @override
  Future<void> sendRegisterCode({required String zone, required String phone}) {
    return _authApi.sendRegisterCode(phone, zone: zone);
  }

  @override
  Future<void> sendLoginVerificationCode(String uid) {
    return _authApi.sendLoginVerificationCode(uid);
  }

  @override
  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    try {
      final response = await _authApi.verifyLoginCode(uid: uid, code: code);
      final data = response.data;
      final resolvedUid = data?.uid?.trim() ?? '';
      final token = data?.token?.trim() ?? '';
      final imToken = _resolveImToken(data?.imToken, token);
      if (!response.success ||
          resolvedUid.isEmpty ||
          token.isEmpty ||
          data == null) {
        return AuthCredentialResult.failure(
          response.msg ?? 'Login verification failed.',
        );
      }

      return AuthCredentialResult.success(
        uid: resolvedUid,
        token: token,
        imToken: imToken,
        user: data.toUserInfo().copyWith(uid: resolvedUid, token: token),
      );
    } catch (error) {
      return AuthCredentialResult.failure(
        AppFailure.describe(
          error,
          fallbackMessage: 'Login verification failed.',
        ),
      );
    }
  }

  @override
  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) {
    return _authApi.sendForgetPwdCode(phone, zone: zone);
  }

  @override
  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) {
    return _authApi.resetPassword(phone, code, newPassword, zone: zone);
  }

  @override
  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async {
    final trimmedAvatarPath = avatarFilePath?.trim() ?? '';
    String? avatarUrl;
    if (trimmedAvatarPath.isNotEmpty) {
      final uploadedAvatar = await _userApi.uploadAvatar(trimmedAvatarPath);
      if (uploadedAvatar.trim().isNotEmpty) {
        avatarUrl = uploadedAvatar;
      }
    }

    await _userApi.updateUserInfo(name: name, sex: sex, avatar: avatarUrl);

    final currentUser = await _userApi.getCurrentUser();
    return currentUser.copyWith(
      name: name,
      sex: sex ?? currentUser.sex,
      avatar: avatarUrl ?? currentUser.avatar,
    );
  }

  @override
  Future<List<LoginBridgeDeviceRecord>> loadDevices() {
    return _loginBridgeApi.getDevices();
  }

  @override
  Future<void> deleteDevice(String deviceId) {
    return _loginBridgeApi.deleteDevice(deviceId);
  }

  @override
  Future<void> quitPcWebSessions() {
    return _loginBridgeApi.quitPc();
  }

  @override
  Future<void> grantWebLogin({required String authCode, String? encrypt}) {
    return _loginBridgeApi.grantLogin(authCode, encrypt: encrypt);
  }

  @override
  Future<String> loadThirdLoginAuthCode() {
    return _loginBridgeApi.getThirdLoginAuthCode();
  }

  @override
  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode) {
    return _loginBridgeApi.getThirdLoginAuthStatus(authCode);
  }

  @override
  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(
    String authCode,
  ) async {
    try {
      final response = await _loginBridgeApi.loginWithAuthCode(authCode);
      final data = response.data;
      final uid = data?.uid?.trim() ?? '';
      final token = data?.token?.trim() ?? '';
      final imToken = _resolveImToken(data?.imToken, token);
      if (!response.success || data == null || uid.isEmpty || token.isEmpty) {
        return AuthCredentialResult.failure(
          response.msg ?? 'Third-party login failed.',
        );
      }

      return AuthCredentialResult.success(
        uid: uid,
        token: token,
        imToken: imToken,
        user: data.toUserInfo().copyWith(uid: uid, token: token),
      );
    } catch (error) {
      return AuthCredentialResult.failure(
        AppFailure.describe(
          error,
          fallbackMessage: 'Third-party login failed.',
        ),
      );
    }
  }

  @override
  Future<UserInfo?> getCurrentUser() {
    return _authApi.getCurrentUser();
  }

  AuthCredentialResult? _tryResolveLoginVerification(DioException error) {
    final response = error.response;
    if (response == null) {
      return null;
    }

    final loginResp = LoginResp.fromResponseData(
      response.data,
      statusCode: response.statusCode,
    );
    if (!loginResp.requiresLoginVerification) {
      return null;
    }

    final verificationUid = loginResp.data?.uid?.trim() ?? '';
    if (verificationUid.isEmpty) {
      return null;
    }

    return AuthCredentialResult.verificationRequired(
      uid: verificationUid,
      phone: loginResp.data?.phone?.trim(),
      message: loginResp.msg,
    );
  }

  String _resolveImToken(String? rawImToken, String token) {
    final normalizedImToken = rawImToken?.trim() ?? '';
    if (normalizedImToken.isNotEmpty) {
      return normalizedImToken;
    }
    return token;
  }
}
