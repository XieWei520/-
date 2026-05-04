import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/config/im_config.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/user.dart';
import '../../realtime/device/device_identity_service.dart';
import '../../realtime/device/device_store.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi._();

  static final AuthApi _instance = AuthApi._();
  static AuthApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final DeviceIdentityAuthority _deviceIdentityAuthority =
      DeviceIdentityAuthority(store: DeviceStore());
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<Map<String, String>> _resolveDevicePayload({
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? deviceInstallId,
  }) async {
    final identity = await _deviceIdentityAuthority.ensureLocalIdentity();
    final defaults = <String, String>{
      'device_id': identity.deviceId,
      'device_name': identity.deviceName,
      'device_model': identity.deviceModel,
      'device_install_id': identity.deviceInstallId,
    };

    String pick(String? explicit, String key) {
      final trimmed = explicit?.trim() ?? '';
      return trimmed.isNotEmpty ? trimmed : defaults[key]!;
    }

    return {
      'device_id': pick(deviceId, 'device_id'),
      'device_name': pick(deviceName, 'device_name'),
      'device_model': pick(deviceModel, 'device_model'),
      'device_install_id': pick(deviceInstallId, 'device_install_id'),
    };
  }

  Map<String, dynamic> _normalizeResponseData(dynamic rawData) {
    return _normalizeAuthResponseData(rawData);
  }

  int _resolveCode(Map<String, dynamic> json, int? statusCode) {
    final rawCode = json['code'];
    if (rawCode is num) {
      return rawCode.toInt();
    }
    if (rawCode is String) {
      final parsed = int.tryParse(rawCode);
      if (parsed != null) {
        return parsed;
      }
    }

    final rawStatus = json['status'];
    if (rawStatus is num) {
      return rawStatus >= 400 ? rawStatus.toInt() : 0;
    }
    if (rawStatus is String) {
      final parsed = int.tryParse(rawStatus);
      if (parsed != null) {
        return parsed >= 400 ? parsed : 0;
      }
    }

    return (statusCode ?? 200) >= 400 ? (statusCode ?? 400) : 0;
  }

  String _resolveMessage(
    Map<String, dynamic> json, {
    required String fallback,
  }) {
    final message = json['msg'] ?? json['message'];
    if (message == null) {
      return fallback;
    }
    final resolved = message.toString().trim();
    return resolved.isEmpty ? fallback : resolved;
  }

  void _throwIfFailed(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final body = _normalizeResponseData(response.data);
    final code = _resolveCode(body, response.statusCode);
    if (code != 0) {
      throw AuthApiException(
        _resolveMessage(body, fallback: fallbackMessage),
        statusCode: response.statusCode ?? code,
      );
    }
  }

  Future<LoginResp> login(
    String phone,
    String password, {
    String zone = '86',
  }) async {
    var zoneStr = zone;
    if (!zoneStr.startsWith('00')) {
      zoneStr = '00$zoneStr';
    }

    final device = await _resolveDevicePayload();
    final response = await _client.post(
      ApiConfig.userLogin,
      options: _plainTextOptions,
      data: jsonEncode({
        'username': zoneStr + phone,
        'password': password,
        'flag': IMConfig.currentDeviceFlag,
        'device': device,
      }),
    );

    return LoginResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

  Future<LoginResp> loginWithUsername(String username, String password) async {
    final device = await _resolveDevicePayload();
    final response = await _client.post(
      ApiConfig.userUsernameLogin,
      options: _plainTextOptions,
      data: jsonEncode({
        'username': username,
        'password': password,
        'flag': IMConfig.currentDeviceFlag,
        'device': device,
      }),
    );

    return LoginResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

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
    var zoneStr = zone;
    if (!zoneStr.startsWith('00') && !zoneStr.startsWith('0')) {
      zoneStr = '00$zoneStr';
    }

    final device = await _resolveDevicePayload(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceModel: deviceModel,
      deviceInstallId: deviceInstallId,
    );
    final data = <String, dynamic>{
      'zone': zoneStr,
      'phone': phone,
      'code': code,
      'password': password,
      'name': name,
      'flag': IMConfig.currentDeviceFlag,
      'device': device,
    };
    final trimmedInviteCode = inviteCode?.trim() ?? '';
    if (trimmedInviteCode.isNotEmpty) {
      data['invite_code'] = trimmedInviteCode;
    }

    final response = await _client.post(
      ApiConfig.userRegister,
      options: _plainTextOptions,
      data: jsonEncode(data),
    );

    return RegisterResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

  Future<UserInfo> getCurrentUser() async {
    final uid = StorageUtils.getUid();
    if (uid != null && uid.isNotEmpty) {
      final response = await _client.get(
        '${ApiConfig.userInfo}/$uid',
        options: _plainTextOptions,
      );
      _throwIfFailed(response, fallbackMessage: 'Session expired.');

      final json = _normalizeResponseData(response.data);
      final data = json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : json;
      final userInfo = UserInfo.fromJson(data);
      return userInfo.copyWith(
        uid: userInfo.uid.isNotEmpty ? userInfo.uid : uid,
        token: userInfo.token ?? StorageUtils.getToken(),
      );
    }

    final validateResponse = await _client.get(
      ApiConfig.userSetting,
      options: _plainTextOptions,
    );
    _throwIfFailed(validateResponse, fallbackMessage: 'Session expired.');
    return UserInfo(uid: '', token: StorageUtils.getToken());
  }

  Future<void> sendRegisterCode(String phone, {String zone = '86'}) async {
    var zoneStr = zone;
    if (!zoneStr.startsWith('00')) {
      zoneStr = '00$zoneStr';
    }

    final response = await _client.post(
      ApiConfig.smsRegisterCode,
      options: _plainTextOptions,
      data: jsonEncode({'phone': phone, 'zone': zoneStr}),
    );

    _throwIfFailed(response, fallbackMessage: 'Failed to send register code.');
  }

  Future<void> sendForgetPwdCode(String phone, {String zone = '86'}) async {
    var zoneStr = zone;
    if (!zoneStr.startsWith('00')) {
      zoneStr = '00$zoneStr';
    }

    final response = await _client.post(
      ApiConfig.smsForgetPwd,
      options: _plainTextOptions,
      data: jsonEncode({'phone': phone, 'zone': zoneStr}),
    );

    _throwIfFailed(
      response,
      fallbackMessage: 'Failed to send reset password code.',
    );
  }

  Future<void> sendLoginVerificationCode(String uid) async {
    final response = await _client.post(
      '/v1/user/sms/login_check_phone',
      options: _plainTextOptions,
      data: jsonEncode({'uid': uid}),
    );

    _throwIfFailed(
      response,
      fallbackMessage: 'Failed to send login verification code.',
    );
  }

  Future<LoginResp> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    final response = await _client.post(
      '/v1/user/login/check_phone',
      options: _plainTextOptions,
      data: jsonEncode({'uid': uid, 'code': code}),
    );

    return LoginResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

  Future<RegisterResp> usernameRegister({
    required String username,
    required String password,
    String? name,
    String? deviceId,
    String? deviceName,
    String? deviceModel,
    String? deviceInstallId,
  }) async {
    final device = await _resolveDevicePayload(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceModel: deviceModel,
      deviceInstallId: deviceInstallId,
    );
    final data = <String, dynamic>{
      'username': username,
      'password': password,
      'flag': IMConfig.currentDeviceFlag,
      'device': device,
    };

    if (name != null && name.isNotEmpty) {
      data['name'] = name;
    }

    final response = await _client.post(
      ApiConfig.userUsernameRegister,
      options: _plainTextOptions,
      data: jsonEncode(data),
    );

    return RegisterResp.fromJson(
      _normalizeResponseData(response.data),
      statusCode: response.statusCode,
    );
  }

  Future<void> resetPassword(
    String phone,
    String code,
    String newPassword, {
    String zone = '86',
  }) async {
    var zoneStr = zone;
    if (!zoneStr.startsWith('00')) {
      zoneStr = '00$zoneStr';
    }

    final response = await _client.post(
      '/v1/user/pwdforget',
      options: _plainTextOptions,
      data: jsonEncode({
        'zone': zoneStr,
        'phone': phone,
        'code': code,
        'pwd': newPassword,
      }),
    );

    _throwIfFailed(response, fallbackMessage: 'Failed to reset password.');
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final response = await _client.post(
      '/v1/user/updatepassword',
      options: _plainTextOptions,
      data: jsonEncode({'oldpassword': oldPassword, 'password': newPassword}),
    );

    _throwIfFailed(response, fallbackMessage: 'Failed to change password.');
  }

  Future<void> logout() async {
    final response = await _client.post(
      '/v1/user/quit?flag=${IMConfig.currentDeviceFlag}',
      options: _plainTextOptions,
    );

    _throwIfFailed(response, fallbackMessage: 'Failed to log out.');
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LoginResp {
  LoginResp({required this.code, this.msg, this.data});

  final int code;
  final String? msg;
  final LoginData? data;

  factory LoginResp.fromResponseData(dynamic rawData, {int? statusCode}) {
    return LoginResp.fromJson(
      _normalizeAuthResponseData(rawData),
      statusCode: statusCode,
    );
  }

  factory LoginResp.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    final resolvedStatus = _resolveStatusCode(json, statusCode);
    final resolvedCode =
        _readIntField(json['code']) ??
        _readIntField(json['status']) ??
        (resolvedStatus >= 400 ? resolvedStatus : 0);
    final dataJson = json['data'];
    final hasDirectData =
        json.containsKey('uid') ||
        json.containsKey('token') ||
        json.containsKey('im_token') ||
        json.containsKey('imToken') ||
        json.containsKey('username');

    return LoginResp(
      code: resolvedCode,
      msg: (json['msg'] ?? json['message'])?.toString(),
      data: dataJson is Map
          ? LoginData.fromJson(Map<String, dynamic>.from(dataJson))
          : hasDirectData
          ? LoginData.fromJson(json)
          : null,
    );
  }

  bool get success => code == 0;

  bool get requiresLoginVerification =>
      code == 110 && (data?.uid?.trim().isNotEmpty ?? false);
}

class LoginData {
  LoginData({
    this.uid,
    this.token,
    this.imToken,
    this.name,
    this.username,
    this.avatar,
    this.sex,
    this.category,
    this.shortNo,
    this.shortStatus,
    this.zone,
    this.phone,
    this.settings,
  });

  final String? uid;
  final String? token;
  final String? imToken;
  final String? name;
  final String? username;
  final String? avatar;
  final int? sex;
  final String? category;
  final String? shortNo;
  final int? shortStatus;
  final String? zone;
  final String? phone;
  final Map<String, dynamic>? settings;

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      uid: json['uid'],
      token: json['token'],
      imToken: json['im_token'],
      name: json['name'],
      username: json['username'],
      avatar: json['avatar'],
      sex: json['sex'],
      category: json['category'],
      shortNo: json['short_no'],
      shortStatus: json['short_status'],
      zone: json['zone'],
      phone: json['phone'],
      settings: json['setting'] is Map
          ? Map<String, dynamic>.from(json['setting'])
          : null,
    );
  }

  UserInfo toUserInfo() {
    return UserInfo(
      uid: uid ?? '',
      token: token,
      name: name,
      avatar: avatar,
      sex: sex,
      category: category,
      username: username,
      shortNo: shortNo,
      shortStatus: shortStatus,
      zone: zone,
      phone: phone,
    );
  }
}

class RegisterResp {
  RegisterResp({required this.code, this.msg, this.data});

  final int code;
  final String? msg;
  final RegisterData? data;

  factory RegisterResp.fromJson(Map<String, dynamic> json, {int? statusCode}) {
    final resolvedStatus = _resolveStatusCode(json, statusCode);
    final resolvedCode =
        _readIntField(json['code']) ??
        (resolvedStatus >= 400 ? resolvedStatus : 0);
    final hasDirectData =
        json.containsKey('uid') ||
        json.containsKey('token') ||
        json.containsKey('im_token') ||
        json.containsKey('imToken') ||
        json.containsKey('username');

    return RegisterResp(
      code: resolvedCode,
      msg: (json['msg'] ?? json['message'])?.toString(),
      data: json['data'] is Map
          ? RegisterData.fromJson(Map<String, dynamic>.from(json['data']))
          : hasDirectData
          ? RegisterData.fromJson(json)
          : null,
    );
  }

  bool get success => code == 0;
}

class RegisterData {
  RegisterData({this.uid, this.token, this.imToken, this.name});

  final String? uid;
  final String? token;
  final String? imToken;
  final String? name;

  factory RegisterData.fromJson(Map<String, dynamic> json) {
    return RegisterData(
      uid: json['uid'],
      token: json['token'],
      imToken: json['im_token'],
      name: json['name'],
    );
  }
}

int _resolveStatusCode(Map<String, dynamic> json, int? statusCode) {
  final parsedStatus = _readIntField(json['status']);
  if (parsedStatus != null) {
    return parsedStatus;
  }
  return statusCode ?? 200;
}

int? _readIntField(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

Map<String, dynamic> _normalizeAuthResponseData(dynamic rawData) {
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
