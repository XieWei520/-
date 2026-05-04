import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';

class OpenApiApi {
  OpenApiApi._();

  static final OpenApiApi _instance = OpenApiApi._();
  static OpenApiApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<OpenApiAppInfo> getAppInfo(String appId) async {
    final normalizedAppId = appId.trim();
    if (normalizedAppId.isEmpty) {
      throw Exception('app_id is required.');
    }

    final response = await _client.get(
      '${ApiConfig.apps}/$normalizedAppId',
      options: _plainTextOptions,
    );
    final body = _normalizeResponseData(response.data);
    _throwIfFailed(
      response,
      body,
      fallbackMessage: 'Failed to load OpenAPI app info.',
    );

    final appInfo = OpenApiAppInfo.fromJson(body);
    if (appInfo.appId.isEmpty || appInfo.appName.isEmpty) {
      throw const FormatException('OpenAPI app payload is invalid.');
    }
    return appInfo;
  }

  Future<String> getAuthCode(String appId) async {
    final normalizedAppId = appId.trim();
    if (normalizedAppId.isEmpty) {
      throw Exception('app_id is required.');
    }

    final response = await _client.get(
      ApiConfig.openApiAuthCode,
      queryParameters: <String, dynamic>{'app_id': normalizedAppId},
      options: _plainTextOptions,
    );
    final body = _normalizeResponseData(response.data);
    _throwIfFailed(
      response,
      body,
      fallbackMessage: 'Failed to load OpenAPI auth code.',
    );

    final authCode = (body['authcode'] ?? '').toString().trim();
    if (authCode.isEmpty) {
      throw const FormatException('OpenAPI authcode payload is invalid.');
    }
    return authCode;
  }

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
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw const FormatException(
        'OpenAPI response payload must be a JSON object.',
      );
    }
    throw FormatException(
      'Unsupported OpenAPI response payload type: ${rawData.runtimeType}.',
    );
  }

  void _throwIfFailed(
    Response<dynamic> response,
    Map<String, dynamic> body, {
    required String fallbackMessage,
  }) {
    final statusCode = response.statusCode ?? 200;
    final code = _readIntLike(body['code']);
    final status = _readIntLike(body['status']);
    final hasErrorCode =
        (code != null && code != 0) || (status != null && status >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(_messageOf(body, fallbackMessage));
    }
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

  String _messageOf(Map<String, dynamic> body, String fallbackMessage) {
    final raw = (body['msg'] ?? body['message'] ?? fallbackMessage)
        .toString()
        .trim();
    return raw.isEmpty ? fallbackMessage : raw;
  }
}

class OpenApiAppInfo {
  const OpenApiAppInfo({
    required this.appId,
    required this.appName,
    required this.appLogo,
  });

  final String appId;
  final String appName;
  final String appLogo;

  factory OpenApiAppInfo.fromJson(Map<String, dynamic> json) {
    return OpenApiAppInfo(
      appId: (json['app_id'] ?? '').toString().trim(),
      appName: (json['app_name'] ?? '').toString().trim(),
      appLogo: (json['app_logo'] ?? '').toString().trim(),
    );
  }
}
