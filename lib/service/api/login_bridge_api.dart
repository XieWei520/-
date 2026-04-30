import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/im_config.dart';
import '../../realtime/device/device_identity_service.dart';
import '../../realtime/device/device_store.dart';
import 'api_client.dart';
import 'auth_api.dart';

String _messageOf(Map<String, dynamic> body, String fallbackMessage) {
  final raw = (body['msg'] ?? body['message'] ?? fallbackMessage)
      .toString()
      .trim();
  return raw.isEmpty ? fallbackMessage : raw;
}

bool _readBoolLike(dynamic rawValue) {
  if (rawValue is bool) {
    return rawValue;
  }
  if (rawValue is num) {
    return rawValue.toInt() != 0;
  }
  final normalized = rawValue?.toString().trim().toLowerCase() ?? '';
  return normalized == '1' || normalized == 'true';
}

int? _readIntLike(dynamic rawValue) {
  if (rawValue is num) {
    return rawValue.toInt();
  }
  final normalized = rawValue?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
}

class LoginBridgeApi {
  LoginBridgeApi._();

  static final LoginBridgeApi _instance = LoginBridgeApi._();
  static LoginBridgeApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final DeviceIdentityAuthority _deviceIdentityAuthority =
      DeviceIdentityAuthority(store: DeviceStore());
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Map<String, dynamic> _normalizeResponseData(dynamic rawData) {
    if (rawData == null) {
      return {};
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        return {};
      }
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        return {'data': decoded};
      } catch (_) {
        return {'message': body};
      }
    }
    return {'data': rawData};
  }

  void _throwIfFailed(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final body = _normalizeResponseData(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = _readIntLike(body['code']);
    final status = _readIntLike(body['status']);
    final message = _messageOf(body, fallbackMessage);
    final hasErrorCode =
        (code != null && code != 0) || (status != null && status >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  Future<LoginBridgeDeviceInfo> buildDeviceInfo() async {
    final identity = await _deviceIdentityAuthority.ensureLocalIdentity();

    return LoginBridgeDeviceInfo(
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
      deviceModel: identity.deviceModel,
    );
  }

  Future<LoginUuidResult> getLoginUuid({
    LoginBridgeDeviceInfo? deviceInfo,
  }) async {
    final resolvedDeviceInfo = deviceInfo ?? await buildDeviceInfo();
    final response = await _client.get(
      '/v1/user/loginuuid',
      queryParameters: {
        'device_id': resolvedDeviceInfo.deviceId,
        'device_name': resolvedDeviceInfo.deviceName,
        'device_model': resolvedDeviceInfo.deviceModel,
      },
    );
    _throwIfFailed(response, fallbackMessage: '获取登录二维码失败');
    return LoginUuidResult.fromJson(_normalizeResponseData(response.data));
  }

  Future<LoginStatusResult> getLoginStatus(String uuid) async {
    final response = await _client.get(
      '/v1/user/loginstatus',
      queryParameters: {'uuid': uuid},
    );
    _throwIfFailed(response, fallbackMessage: '获取登录状态失败');
    return LoginStatusResult.fromJson(_normalizeResponseData(response.data));
  }

  Future<LoginResp> loginWithAuthCode(String authCode, {int? flag}) async {
    final response = await _client.post(
      '/v1/user/login_authcode/$authCode',
      queryParameters: {'flag': flag ?? IMConfig.currentDeviceFlag},
      options: _plainTextOptions,
    );

    return LoginResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

  Future<void> grantLogin(String authCode, {String? encrypt}) async {
    final response = await _client.get(
      '/v1/user/grant_login',
      queryParameters: {
        'auth_code': authCode,
        if (encrypt != null && encrypt.trim().isNotEmpty)
          'encrypt': encrypt.trim(),
      },
    );
    _throwIfFailed(response, fallbackMessage: '确认登录失败');
  }

  Future<void> quitPc() async {
    final response = await _client.post('/v1/user/pc/quit');
    _throwIfFailed(response, fallbackMessage: '退出电脑端/网页端登录失败');
  }

  Future<List<LoginBridgeDeviceRecord>> getDevices() async {
    final response = await _client.get('/v1/user/devices');
    _throwIfFailed(response, fallbackMessage: '获取登录设备失败');

    final body = _normalizeResponseData(response.data);
    final rawList = body['data'] is List
        ? List<dynamic>.from(body['data'] as List)
        : <dynamic>[];

    return rawList
        .map(
          (item) => LoginBridgeDeviceRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> deleteDevice(String deviceId) async {
    final normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty) {
      throw Exception('设备 ID 不能为空');
    }

    final response = await _client.delete(
      '/v1/user/devices/$normalizedDeviceId',
    );
    _throwIfFailed(response, fallbackMessage: '移除登录设备失败');
  }

  Future<String> getThirdLoginAuthCode() async {
    final response = await _client.get('/v1/user/thirdlogin/authcode');
    _throwIfFailed(response, fallbackMessage: '获取第三方登录授权码失败');
    final body = _normalizeResponseData(response.data);
    final authCode = (body['authcode'] ?? body['auth_code'] ?? '').toString();
    if (authCode.isEmpty) {
      throw Exception('服务端未返回第三方登录授权码');
    }
    return authCode;
  }

  Future<ThirdLoginStatusResult> getThirdLoginAuthStatus(
    String authCode,
  ) async {
    final response = await _client.get(
      '/v1/user/thirdlogin/authstatus',
      queryParameters: {'authcode': authCode},
      options: _plainTextOptions,
    );
    final body = _normalizeResponseData(response.data);
    final statusCode = response.statusCode ?? 200;
    if (statusCode >= 400) {
      final message = (body['msg'] ?? body['message'] ?? '获取第三方登录状态失败')
          .toString();
      throw Exception(message);
    }
    return ThirdLoginStatusResult.fromJson(
      body,
      statusCode: response.statusCode,
    );
  }
}

class LoginBridgeDeviceInfo {
  final String deviceId;
  final String deviceName;
  final String deviceModel;

  const LoginBridgeDeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
  });
}

class LoginUuidResult {
  final String uuid;
  final String qrcode;

  const LoginUuidResult({required this.uuid, required this.qrcode});

  factory LoginUuidResult.fromJson(Map<String, dynamic> json) {
    return LoginUuidResult(
      uuid: (json['uuid'] ?? '').toString(),
      qrcode: (json['qrcode'] ?? '').toString(),
    );
  }
}

class LoginStatusResult {
  final String status;
  final String? uid;
  final String? authCode;
  final String? encrypt;
  final String? pubKey;

  const LoginStatusResult({
    required this.status,
    this.uid,
    this.authCode,
    this.encrypt,
    this.pubKey,
  });

  bool get isWaitScan => status == 'waitScan';
  bool get isScanned => status == 'scanned';
  bool get isAuthed => status == 'authed' || (authCode?.isNotEmpty ?? false);
  bool get isExpired => status == 'expired';

  factory LoginStatusResult.fromJson(Map<String, dynamic> json) {
    return LoginStatusResult(
      status: (json['status'] ?? '').toString(),
      uid: json['uid']?.toString(),
      authCode: (json['auth_code'] ?? json['authcode'])?.toString(),
      encrypt: json['encrypt']?.toString(),
      pubKey: (json['pub_key'] ?? json['pubKey'])?.toString(),
    );
  }
}

class LoginBridgeDeviceRecord {
  final int id;
  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final String lastLogin;
  final bool self;

  const LoginBridgeDeviceRecord({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
    required this.lastLogin,
    required this.self,
  });

  factory LoginBridgeDeviceRecord.fromJson(Map<String, dynamic> json) {
    return LoginBridgeDeviceRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceId: (json['device_id'] ?? '').toString(),
      deviceName: (json['device_name'] ?? '未知设备').toString(),
      deviceModel: (json['device_model'] ?? '').toString(),
      lastLogin: (json['last_login'] ?? '').toString(),
      self: _readBoolLike(json['self']),
    );
  }
}

class ThirdLoginStatusResult {
  final int status;
  final LoginResp? result;
  final String? message;

  const ThirdLoginStatusResult({
    required this.status,
    this.result,
    this.message,
  });

  bool get isPending => status == 0;
  bool get isSuccess => status == 1 && result?.data != null;
  bool get isFailed => status == 2;

  factory ThirdLoginStatusResult.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final status = json['status'] is num
        ? (json['status'] as num).toInt()
        : int.tryParse(json['status']?.toString() ?? '') ?? 0;
    final resultJson = json['result'];

    return ThirdLoginStatusResult(
      status: status,
      result: resultJson is Map
          ? LoginResp.fromJson(
              Map<String, dynamic>.from(resultJson),
              statusCode: statusCode,
            )
          : null,
      message: (json['msg'] ?? json['message'])?.toString(),
    );
  }
}
