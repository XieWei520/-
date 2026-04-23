import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import '../wukong_base/base/base_model.dart';
import 'login_contract.dart';
import '../../core/config/api_config.dart';

/// Login model
class LoginModel extends BaseModel {
  late final Dio _dio;
  static const String _appId = 'wukongchat';
  static const String _appKey = '25b002c6be2d539f264c';

  LoginModel() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'appid': _appId,
      },
    ));
  }

  /// 添加TangSengDaoDao服务器需要的签名请求头
  void _addSignHeaders(RequestOptions options) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateRandomString(16);

    String dataStr = '';
    if (options.data != null) {
      if (options.data is String) {
        dataStr = options.data as String;
      } else if (options.data is Map) {
        dataStr = jsonEncode(options.data);
      }
    }

    final signStr = dataStr + nonce + timestamp + _appKey;
    final sign = crypto_lib.md5.convert(utf8.encode(signStr)).toString();

    options.headers['timestamp'] = timestamp;
    options.headers['noncestr'] = nonce;
    options.headers['sign'] = sign;
  }

  /// 生成随机字符串
  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  /// 使用签名头发送请求
  Future<Response<dynamic>> _postWithSign(String path, {dynamic data}) async {
    final options = Options(
      headers: {
        'Content-Type': 'application/json',
        'appid': _appId,
      },
      validateStatus: (status) => true, // 接受所有状态码以便处理错误
    );

    // 创建临时RequestOptions以生成签名
    final tempOptions = RequestOptions(
      path: path,
      data: data,
      headers: options.headers,
    );
    _addSignHeaders(tempOptions);

    final finalOptions = Options(headers: tempOptions.headers);
    return _dio.post(path, data: data, options: finalOptions);
  }

  /// Login with phone number and password
  /// phone: 手机号
  /// password: 密码
  /// zoneCode: 区号，如 "0086"
  Future<LoginResult> login(String phone, String password, {String zoneCode = '0086'}) async {
    try {
      // 服务器期望 username 格式为 zone+phone (如 "008613912345678")
      String loginUsername;
      if (zoneCode.startsWith('00')) {
        // 区号已经带00，直接拼接
        loginUsername = zoneCode + phone;
      } else {
        // 区号不带00，添加前缀
        loginUsername = '00$zoneCode$phone';
      }

      final response = await _postWithSign(
        '/v1/user/login',  // 使用手机号登录接口
        data: {
          'username': loginUsername,
          'password': password,
          'flag': 0, // APP登录
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          return LoginResult.success(
            userInfo: UserInfo.fromJson(data['data']),
          );
        } else {
          return LoginResult.fail(
            code: data['code'] ?? -1,
            msg: data['msg'] ?? 'Login failed',
          );
        }
      }
      return LoginResult.fail(code: response.statusCode ?? -1, msg: 'Network error');
    } on DioException catch (e) {
      return LoginResult.fail(
        code: e.response?.statusCode ?? -1,
        msg: _getDioErrorMessage(e),
      );
    } catch (e) {
      return LoginResult.fail(code: -1, msg: e.toString());
    }
  }

  /// Send verification code
  Future<SMSSendResult> sendCode(String phone, String zone, int type) async {
    try {
      // 服务器期望 zone 格式为 "0086"（带前导零）
      String zoneStr = zone;
      if (!zoneStr.startsWith('00')) {
        zoneStr = '00$zoneStr';
      }
      final response = await _postWithSign(
        '/v1/user/sms/registercode',
        data: {
          'phone': phone,
          'zone': zoneStr,
          'type': type,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return SMSSendResult(
          code: data['code'] ?? 0,
          msg: data['msg'] ?? '',
        );
      }
      return SMSSendResult(code: -1, msg: 'Network error');
    } on DioException catch (e) {
      return SMSSendResult(
        code: e.response?.statusCode ?? -1,
        msg: _getDioErrorMessage(e),
      );
    } catch (e) {
      return SMSSendResult(code: -1, msg: e.toString());
    }
  }

  /// Register new user
  Future<RegisterResult> register(
    String phone,
    String password,
    String code,
    String zone,
  ) async {
    try {
      // 服务器期望 zone 格式为 "0086"（带前导零）
      String zoneStr = zone;
      if (!zoneStr.startsWith('00')) {
        zoneStr = '00$zoneStr';
      }
      // 注册时服务器会自动拼接 zone + phone
      final response = await _postWithSign(
        '/v1/user/register',
        data: {
          'phone': phone,  // 使用 phone 字段
          'password': password,
          'code': code,
          'zone': zoneStr,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == 0) {
          return RegisterResult.success(
            userInfo: UserInfo.fromJson(data['data']),
          );
        } else {
          return RegisterResult.fail(
            code: data['code'] ?? -1,
            msg: data['msg'] ?? 'Registration failed',
          );
        }
      }
      return RegisterResult.fail(code: -1, msg: 'Network error');
    } on DioException catch (e) {
      return RegisterResult.fail(
        code: e.response?.statusCode ?? -1,
        msg: _getDioErrorMessage(e),
      );
    } catch (e) {
      return RegisterResult.fail(code: -1, msg: e.toString());
    }
  }

  /// Reset password
  Future<ResetPwdResult> resetPassword(
    String phone,
    String newPassword,
    String code,
    String zone,
  ) async {
    try {
      // 服务器期望 zone 格式为 "0086"（带前导零）
      String zoneStr = zone;
      if (!zoneStr.startsWith('00')) {
        zoneStr = '00$zoneStr';
      }
      final response = await _postWithSign(
        '/v1/user/pwdforget',
        data: {
          'phone': phone,
          'password': newPassword,
          'code': code,
          'zone': zoneStr,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return ResetPwdResult(
          code: data['code'] ?? 0,
          msg: data['msg'] ?? '',
        );
      }
      return ResetPwdResult(code: -1, msg: 'Network error');
    } on DioException catch (e) {
      return ResetPwdResult(
        code: e.response?.statusCode ?? -1,
        msg: _getDioErrorMessage(e),
      );
    } catch (e) {
      return ResetPwdResult(code: -1, msg: e.toString());
    }
  }

  /// Get country codes
  Future<List<CountryCode>> getCountryCodes() async {
    // Return default country codes
    return [
      CountryCode(code: '0086', name: '中国', nameEn: 'China'),
      CountryCode(code: '0085', name: '日本', nameEn: 'Japan'),
      CountryCode(code: '0082', name: '韩国', nameEn: 'South Korea'),
      CountryCode(code: '0081', name: '美国', nameEn: 'United States'),
      CountryCode(code: '0084', name: '越南', nameEn: 'Vietnam'),
      CountryCode(code: '0066', name: '泰国', nameEn: 'Thailand'),
      CountryCode(code: '0060', name: '马来西亚', nameEn: 'Malaysia'),
      CountryCode(code: '0065', name: '新加坡', nameEn: 'Singapore'),
      CountryCode(code: '00852', name: '香港', nameEn: 'Hong Kong'),
      CountryCode(code: '00886', name: '台湾', nameEn: 'Taiwan'),
      CountryCode(code: '0049', name: '德国', nameEn: 'Germany'),
      CountryCode(code: '0033', name: '法国', nameEn: 'France'),
      CountryCode(code: '0044', name: '英国', nameEn: 'United Kingdom'),
      CountryCode(code: '0061', name: '澳大利亚', nameEn: 'Australia'),
      CountryCode(code: '001', name: '加拿大', nameEn: 'Canada'),
    ];
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  /// 处理Dio错误并返回友好的错误消息
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时，请稍后重试';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) {
          // 服务器返回400，通常是参数验证失败
          final data = e.response?.data;
          if (data is Map && data['msg'] != null) {
            return data['msg'].toString();
          }
          return '请求参数错误';
        } else if (statusCode == 401) {
          return '认证失败，请重新登录';
        } else if (statusCode == 404) {
          return '请求的服务不存在';
        } else if (statusCode == 500) {
          return '服务器内部错误';
        }
        return '服务器错误: $statusCode';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送请求超时';
      case DioExceptionType.unknown:
      default:
        // 对于 unknown 类型，检查是否有响应数据
        if (e.response?.data != null) {
          final data = e.response?.data;
          if (data is Map && data['msg'] != null) {
            return data['msg'].toString();
          }
        }
        return e.message ?? '未知错误';
    }
  }
}

/// Login result
class LoginResult {
  final bool success;
  final int code;
  final String msg;
  final UserInfo? userInfo;

  LoginResult._({
    required this.success,
    required this.code,
    required this.msg,
    this.userInfo,
  });

  factory LoginResult.success({required UserInfo userInfo}) {
    return LoginResult._(
      success: true,
      code: 0,
      msg: 'Success',
      userInfo: userInfo,
    );
  }

  factory LoginResult.fail({required int code, required String msg}) {
    return LoginResult._(
      success: false,
      code: code,
      msg: msg,
    );
  }
}

/// SMS send result
class SMSSendResult {
  final int code;
  final String msg;

  SMSSendResult({required this.code, required this.msg});
}

/// Register result
class RegisterResult {
  final bool success;
  final int code;
  final String msg;
  final UserInfo? userInfo;

  RegisterResult._({
    required this.success,
    required this.code,
    required this.msg,
    this.userInfo,
  });

  factory RegisterResult.success({required UserInfo userInfo}) {
    return RegisterResult._(
      success: true,
      code: 0,
      msg: 'Success',
      userInfo: userInfo,
    );
  }

  factory RegisterResult.fail({required int code, required String msg}) {
    return RegisterResult._(
      success: false,
      code: code,
      msg: msg,
    );
  }
}

/// Reset password result
class ResetPwdResult {
  final int code;
  final String msg;

  ResetPwdResult({required this.code, required this.msg});
}
