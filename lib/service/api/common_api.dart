import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/chat_background_option.dart';
import 'api_client.dart';

class CommonApi {
  CommonApi._();

  static final CommonApi _instance = CommonApi._();
  static CommonApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
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
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  List<Map<String, dynamic>> _normalizeListResponse(dynamic rawData) {
    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (rawData is String) {
      final body = rawData.trim();
      if (body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is List) {
            return decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false);
          }
        } catch (_) {
          // Fall through to wrapped-response parsing below.
        }
      }
    }

    final body = _normalizeResponseData(rawData);
    final candidates = [
      body['data'],
      body['list'],
      body['items'],
      body['result'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return const [];
  }

  Future<AppRuntimeCapabilities> getRuntimeCapabilities() async {
    final response = await _client.get(
      '/v1/common/appconfig',
      options: _plainTextOptions,
    );
    final body = _normalizeResponseData(response.data);
    final webLoginUrl = AppRuntimeCapabilities.resolveWebLoginUrl(body);

    if (webLoginUrl.isEmpty) {
      return AppRuntimeCapabilities.fromAppConfigBody(
        body: body,
        webLoginReachable: false,
        webLoginStatusMessage: '服务端未返回网页端登录地址',
      );
    }

    final probe = await _probeUrl(webLoginUrl);
    return AppRuntimeCapabilities.fromAppConfigBody(
      body: body,
      webLoginReachable: probe.reachable,
      webLoginStatusMessage: probe.message,
    );
  }

  Future<AppVersionInfo?> getAppNewVersion(String version) async {
    final platform = _appVersionPlatformSegment();
    final response = await _client.get(
      '/v1/common/appversion/$platform/$version',
      options: _plainTextOptions,
    );
    final body = _normalizeResponseData(response.data);
    if (body.isEmpty) {
      return null;
    }
    return AppVersionInfo.fromJson(body);
  }

  String _appVersionPlatformSegment() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<List<AppModuleInfo>> getAppModules() async {
    final response = await _client.get(
      '/v1/common/appmodule',
      options: _plainTextOptions,
    );
    final list = _normalizeListResponse(response.data);
    return list.map(AppModuleInfo.fromJson).toList();
  }

  Future<List<ChatBackgroundOption>> getChatBackgrounds() async {
    final response = await _client.get(
      '/v1/common/chatbg',
      options: _plainTextOptions,
    );
    final list = _normalizeListResponse(response.data);
    return list.map(ChatBackgroundOption.fromJson).toList(growable: false);
  }

  Future<_UrlProbeResult> _probeUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return const _UrlProbeResult(reachable: false, message: '网页端登录地址格式无效');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
        followRedirects: false,
      ),
    );

    try {
      final response = await dio.getUri(uri);
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 400) {
        return _UrlProbeResult(
          reachable: true,
          message: '网页端登录地址可达（HTTP $statusCode）',
        );
      }
      return _UrlProbeResult(
        reachable: false,
        message: '网页端登录地址不可用（HTTP $statusCode）',
      );
    } on DioException catch (error) {
      return _UrlProbeResult(
        reachable: false,
        message: '网页端登录地址不可达：${error.message ?? error.type.name}',
      );
    } catch (error) {
      return _UrlProbeResult(reachable: false, message: '网页端登录地址不可达：$error');
    } finally {
      dio.close(force: true);
    }
  }
}

class AppRuntimeCapabilities {
  final String webLoginUrl;
  final bool webLoginReachable;
  final String webLoginStatusMessage;
  final bool canModifyApiUrl;
  final bool thirdLoginEnabled;
  final String thirdLoginStatusMessage;
  final bool shortNoEditable;
  final String shortNoEditStatusMessage;
  final bool phoneSearchEnabled;
  final String phoneSearchStatusMessage;
  final bool momentsEnabled;
  final String momentsStatusMessage;
  final bool registerInviteEnabled;
  final bool registerInviteRequired;

  const AppRuntimeCapabilities({
    required this.webLoginUrl,
    required this.webLoginReachable,
    required this.webLoginStatusMessage,
    this.canModifyApiUrl = false,
    this.thirdLoginEnabled = true,
    this.thirdLoginStatusMessage = 'Server allows third-party login.',
    this.shortNoEditable = false,
    this.shortNoEditStatusMessage = '运行态配置检测未完成，暂不开放短编号修改',
    this.phoneSearchEnabled = true,
    this.phoneSearchStatusMessage = '服务端允许手机号搜索',
    this.momentsEnabled = true,
    this.momentsStatusMessage = '服务端允许使用朋友圈',
    this.registerInviteEnabled = false,
    this.registerInviteRequired = false,
  });

  factory AppRuntimeCapabilities.fromAppConfigBody({
    required Map<String, dynamic> body,
    required bool webLoginReachable,
    required String webLoginStatusMessage,
  }) {
    final shortNoEditOff = _readBoolFlag(
      body['shortno_edit_off'] ?? body['shortNoEditOff'],
    );
    final phoneSearchOff = _readBoolFlag(
      body['phone_search_off'] ?? body['phoneSearchOff'],
    );
    final momentsOff = _readBoolFlag(
      body['moment_off'] ??
          body['moments_off'] ??
          body['circle_off'] ??
          body['momentOff'] ??
          body['momentsOff'],
    );
    final registerInviteOn = _readBoolFlag(
      body['register_invite_on'] ?? body['registerInviteOn'],
    );
    final registerInviteRequired = _readBoolFlag(
      body['register_invite_required'] ??
          body['registerInviteRequired'] ??
          body['register_invite_must'] ??
          body['registerInviteMust'] ??
          body['register_invite_need'] ??
          body['registerInviteNeed'],
    );
    final canModifyApiUrl = _readBoolFlag(
      body['can_modify_api_url'] ?? body['canModifyApiUrl'],
    );
    final thirdLoginEnabled = _resolveThirdLoginEnabled(body);

    return AppRuntimeCapabilities(
      webLoginUrl: resolveWebLoginUrl(body),
      webLoginReachable: webLoginReachable,
      webLoginStatusMessage: webLoginStatusMessage,
      canModifyApiUrl: canModifyApiUrl,
      thirdLoginEnabled: thirdLoginEnabled,
      thirdLoginStatusMessage: thirdLoginEnabled
          ? 'Server allows third-party login.'
          : 'Server has not enabled third-party login.',
      shortNoEditable: !shortNoEditOff,
      shortNoEditStatusMessage: shortNoEditOff ? '服务端已关闭短编号修改' : '服务端允许修改短编号',
      phoneSearchEnabled: !phoneSearchOff,
      phoneSearchStatusMessage: phoneSearchOff ? '服务端已关闭手机号搜索' : '服务端允许手机号搜索',
      momentsEnabled: !momentsOff,
      momentsStatusMessage: momentsOff ? '服务端已关闭朋友圈入口' : '服务端允许使用朋友圈',
      registerInviteEnabled: registerInviteOn,
      registerInviteRequired: registerInviteOn && registerInviteRequired,
    );
  }

  bool get hasWebLoginUrl => webLoginUrl.isNotEmpty;

  bool get pcWebLoginEntryEnabled => hasWebLoginUrl && webLoginReachable;

  String? get pcWebLoginDisabledReason {
    if (pcWebLoginEntryEnabled) {
      return null;
    }
    if (!hasWebLoginUrl) {
      return '服务端未开放网页端登录地址';
    }
    return webLoginStatusMessage;
  }

  static String resolveWebLoginUrl(Map<String, dynamic> body) {
    return (body['web_url'] ?? body['webUrl'] ?? '').toString().trim();
  }

  static bool _resolveThirdLoginEnabled(Map<String, dynamic> body) {
    final enabledFlag = _readOptionalBoolFlag(
      body['third_login_on'] ??
          body['thirdLoginOn'] ??
          body['github_login_on'] ??
          body['githubLoginOn'] ??
          body['gitee_login_on'] ??
          body['giteeLoginOn'],
    );
    if (enabledFlag != null) {
      return enabledFlag;
    }

    final disabledFlag = _readOptionalBoolFlag(
      body['third_login_off'] ??
          body['thirdLoginOff'] ??
          body['github_login_off'] ??
          body['githubLoginOff'] ??
          body['gitee_login_off'] ??
          body['giteeLoginOff'],
    );
    if (disabledFlag != null) {
      return !disabledFlag;
    }

    // Android keeps third-party login visible unless the server explicitly
    // disables it, so we mirror that behavior here.
    return true;
  }

  static bool _readBoolFlag(dynamic rawValue) {
    if (rawValue is bool) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt() != 0;
    }
    if (rawValue is String) {
      final normalized = rawValue.trim().toLowerCase();
      return normalized == '1' || normalized == 'true';
    }
    return false;
  }

  static bool? _readOptionalBoolFlag(dynamic rawValue) {
    if (rawValue == null) {
      return null;
    }
    return _readBoolFlag(rawValue);
  }
}

class AppVersionInfo {
  final String os;
  final String appVersion;
  final int isForce;
  final String updateDesc;
  final String downloadUrl;
  final String createdAt;

  const AppVersionInfo({
    required this.os,
    required this.appVersion,
    required this.isForce,
    required this.updateDesc,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      os: (json['os'] ?? '').toString().trim(),
      appVersion: (json['app_version'] ?? json['appVersion'] ?? '')
          .toString()
          .trim(),
      isForce: _toInt(json['is_force'] ?? json['isForce']),
      updateDesc: (json['update_desc'] ?? json['updateDesc'] ?? '')
          .toString()
          .trim(),
      downloadUrl: (json['download_url'] ?? json['downloadUrl'] ?? '')
          .toString()
          .trim(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '')
          .toString()
          .trim(),
    );
  }

  bool get hasDownloadUrl => downloadUrl.isNotEmpty;
  bool get isForceUpdate => isForce == 1;
}

class AppModuleInfo {
  final String sid;
  final String name;
  final String desc;
  final int status;

  const AppModuleInfo({
    required this.sid,
    required this.name,
    required this.desc,
    required this.status,
  });

  factory AppModuleInfo.fromJson(Map<String, dynamic> json) {
    return AppModuleInfo(
      sid: (json['sid'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      desc: (json['desc'] ?? '').toString().trim(),
      status: _toInt(json['status']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class _UrlProbeResult {
  final bool reachable;
  final String message;

  const _UrlProbeResult({required this.reachable, required this.message});
}
