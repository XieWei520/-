import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';
import 'package:wukong_im_app/modules/auth/data/auth_repository_impl.dart';
import 'package:wukong_im_app/service/api/auth_api.dart';

class _RecordingAuthApi implements AuthApi {
  Object? loginError;
  String? lastRegisterUsername;
  String? lastRegisterPassword;
  String? lastRegisterZone;
  String? lastRegisterPhone;
  String? lastRegisterCode;
  String? lastRegisterName;
  String? lastRegisterInviteCode;

  RegisterResp registerResponse = RegisterResp(
    code: 0,
    data: RegisterData(uid: 'uid-1', token: 'token-1', name: 'Server Name'),
  );
  LoginResp loginResponse = LoginResp(
    code: 0,
    data: LoginData(
      uid: 'uid-login',
      token: 'token-login',
      phone: '13800138000',
    ),
  );

  @override
  Future<LoginResp> login(
    String phone,
    String password, {
    String zone = '86',
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    return loginResponse;
  }

  @override
  Future<RegisterResp> register({
    required String username,
    required String password,
    required String zone,
    required String phone,
    required String code,
    required String name,
    String? inviteCode,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? deviceInstallId,
  }) async {
    lastRegisterUsername = username;
    lastRegisterPassword = password;
    lastRegisterZone = zone;
    lastRegisterPhone = phone;
    lastRegisterCode = code;
    lastRegisterName = name;
    lastRegisterInviteCode = inviteCode;
    return registerResponse;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthRepositoryImpl.registerWithPhone', () {
    const zone = '0086';
    const phone = '13800138000';
    const code = '123456';
    const password = '123456';

    test('maps non-empty displayName to AuthApi.register name', () async {
      final authApi = _RecordingAuthApi();
      final repository = AuthRepositoryImpl(authApi: authApi);

      await repository.registerWithPhone(
        zone: zone,
        phone: phone,
        code: code,
        password: password,
        displayName: '  昵称A  ',
      );

      expect(authApi.lastRegisterName, '昵称A');
    });

    test('falls back to phone when displayName is omitted', () async {
      final authApi = _RecordingAuthApi();
      final repository = AuthRepositoryImpl(authApi: authApi);

      await repository.registerWithPhone(
        zone: zone,
        phone: phone,
        code: code,
        password: password,
      );

      expect(authApi.lastRegisterName, phone);
    });

    test(
      'falls back to phone when displayName is blank and response name is empty',
      () async {
        final authApi = _RecordingAuthApi()
          ..registerResponse = RegisterResp(
            code: 0,
            data: RegisterData(uid: 'uid-2', token: 'token-2', name: '  '),
          );
        final repository = AuthRepositoryImpl(authApi: authApi);

        final result = await repository.registerWithPhone(
          zone: zone,
          phone: phone,
          code: code,
          password: password,
          displayName: '   ',
        );

        expect(authApi.lastRegisterName, phone);
        expect(result.success, isTrue);
        expect(result.user?.name, phone);
      },
    );
  });

  group('AuthRepositoryImpl.loginWithPhone', () {
    test(
      'maps legacy verification response carried by DioException into verification state',
      () async {
        final authApi = _RecordingAuthApi()
          ..loginError = DioException(
            requestOptions: RequestOptions(path: '/v1/user/login'),
            response: Response<String>(
              requestOptions: RequestOptions(path: '/v1/user/login'),
              statusCode: 400,
              data:
                  '{"status":110,"msg":"需要验证手机号码！","uid":"u-verify","phone":"192******75"}',
            ),
            type: DioExceptionType.badResponse,
          );
        final repository = AuthRepositoryImpl(authApi: authApi);

        final result = await repository.loginWithPhone(
          zone: '0086',
          phone: '19212455075',
          password: 'xixiewei',
        );

        expect(result.requiresLoginVerification, isTrue);
        expect(result.loginVerificationContext, isNotNull);
        expect(result.loginVerificationContext?.uid, 'u-verify');
        expect(result.loginVerificationContext?.phone, '192******75');
        expect(result.success, isFalse);
        expect(result.message, '需要验证手机号码！');
      },
    );
    test('preserves separate im token from login response', () async {
      final authApi = _RecordingAuthApi()
        ..loginResponse = LoginResp(
          code: 0,
          data: LoginData(
            uid: 'uid-login',
            token: 'http-token-login',
            imToken: 'im-token-login',
            phone: '13800138000',
          ),
        );
      final repository = AuthRepositoryImpl(authApi: authApi);

      final result = await repository.loginWithPhone(
        zone: '0086',
        phone: '19212455075',
        password: 'xixiewei',
      );

      expect(result.success, isTrue);
      expect(result.token, 'http-token-login');
      expect(result.imToken, 'im-token-login');
    });
  });
}
