import 'dart:convert';

import 'package:dio/dio.dart';

import '../../modules/monitor/monitor_models.dart';
import 'api_client.dart';

class MonitorApi {
  MonitorApi._();

  static final MonitorApi _instance = MonitorApi._();
  static MonitorApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<MonitorStats> fetchStats({required MonitorPlatform platform}) async {
    final response = await _client.get(
      '/v1/monitor/platforms/${platform.apiValue}/stats',
      options: _plainTextOptions,
    );
    return MonitorStats.fromJson(_resolveObjectPayload(response.data));
  }

  Future<List<MonitorAgent>> fetchAgents({MonitorPlatform? platform}) async {
    final response = await _client.get(
      '/v1/monitor/agents',
      queryParameters: platform == null
          ? null
          : <String, dynamic>{'platform': platform.apiValue},
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorAgent.fromJson)
        .toList(growable: false);
  }

  Future<List<MonitorRoute>> fetchRoutes({MonitorPlatform? platform}) async {
    final response = await _client.get(
      '/v1/monitor/routes',
      queryParameters: platform == null
          ? null
          : <String, dynamic>{'platform': platform.apiValue},
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorRoute.fromJson)
        .toList(growable: false);
  }

  Future<List<MonitorLogEntry>> fetchLogs({
    MonitorPlatform? platform,
    int limit = 20,
  }) async {
    final response = await _client.get(
      '/v1/monitor/events',
      queryParameters: <String, dynamic>{
        if (platform != null) 'platform': platform.apiValue,
        'limit': limit,
      },
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorLogEntry.fromJson)
        .toList(growable: false);
  }

  Future<MonitorBrowserStatus> fetchBrowserStatus({
    required MonitorPlatform platform,
  }) async {
    final response = await _client.get(
      '/v1/monitor/platforms/${platform.apiValue}/browser-status',
      options: _plainTextOptions,
    );
    return MonitorBrowserStatus.fromJson(_resolveObjectPayload(response.data));
  }

  Future<MonitorRoute> createFeishuRoute(
    CreateFeishuMonitorRouteRequest request,
  ) async {
    final response = await _client.post(
      '/v1/monitor/routes',
      data: request.toJson(),
      options: _plainTextOptions,
    );
    return MonitorRoute.fromJson(_resolveObjectPayload(response.data));
  }

  Future<void> updateRouteStatus({
    required String routeId,
    required MonitorRouteStatus status,
  }) async {
    final response = await _client.put(
      '/v1/monitor/routes/${routeId.trim()}/status',
      data: <String, dynamic>{'status': status.apiValue},
      options: _plainTextOptions,
    );
    _ensureSuccess(response, fallback: 'update monitor route status failed');
  }

  Future<MonitorPairingCode> createPairingCode(String deviceName) async {
    final response = await _client.post(
      '/v1/monitor/agent-pairing-codes',
      data: <String, dynamic>{
        'device_name': deviceName.trim(),
        'platform': 'windows',
      },
      options: _plainTextOptions,
    );
    return MonitorPairingCode.fromJson(_resolveObjectPayload(response.data));
  }

  Map<String, dynamic> _resolveObjectPayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Response data payload must be a JSON object.');
  }

  List<dynamic> _resolveListPayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body is List ? body as List<dynamic> : const <dynamic>[];
    }
    if (data is List) {
      return data;
    }
    throw const FormatException('Response data payload must be a JSON array.');
  }

  Map<String, dynamic> _normalizeBody(dynamic rawData) {
    if (rawData == null) {
      throw const FormatException('Response payload is empty.');
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        throw const FormatException('Response payload is empty.');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is List) {
        return <String, dynamic>{'data': decoded};
      }
      throw const FormatException('Response payload must be valid JSON.');
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is List) {
      return <String, dynamic>{'data': rawData};
    }
    throw FormatException(
      'Unsupported response payload type: ${rawData.runtimeType}.',
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    throw const FormatException('Response item must be a JSON object.');
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _normalizeBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }
}
