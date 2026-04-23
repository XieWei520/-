import '../../../data/models/user.dart';
import '../../../service/api/login_bridge_api.dart';
import 'auth_flow_models.dart';

abstract class DeviceSessionRepository {
  Future<List<LoginBridgeDeviceRecord>> loadDevices();

  Future<void> deleteDevice(String deviceId);

  Future<void> quitPcWebSessions();
}

abstract class AuthRepository implements DeviceSessionRepository {
  Future<AuthCredentialResult> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  });

  Future<AuthCredentialResult> loginWithUsername({
    required String username,
    required String password,
  });

  Future<AuthCredentialResult> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
    String? displayName,
  });

  Future<void> sendRegisterCode({required String zone, required String phone});

  Future<void> sendLoginVerificationCode(String uid);

  Future<AuthCredentialResult> verifyLoginCode({
    required String uid,
    required String code,
  });

  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  });

  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  });

  Future<UserInfo> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  });

  Future<void> grantWebLogin({
    required String authCode,
    String? encrypt,
  });

  Future<String> loadThirdLoginAuthCode();

  Future<ThirdLoginStatusResult> loadThirdLoginStatus(String authCode);

  Future<AuthCredentialResult> loginWithThirdPartyAuthCode(String authCode);

  Future<UserInfo?> getCurrentUser();
}
