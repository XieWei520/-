import 'dart:convert';

import 'package:dio/dio.dart';

import 'dingtalk_monitor_shell_models.dart';

class DingTalkMonitorShellClient {
  DingTalkMonitorShellClient({
    Dio? dio,
    String baseUrl = 'http://127.0.0.1:17651',
    String token = 'local-dev-token',
  }) : _dio = dio ?? Dio(),
       _baseUrl = baseUrl.trim(),
       _token = token.trim();

  final Dio _dio;
  final String _baseUrl;
  final String _token;

  Options get _options => Options(
    headers: <String, String>{'X-DingTalk-Host-Token': _token},
    responseType: ResponseType.plain,
  );

  Future<DingTalkMonitorShellStatus> fetchStatus() async {
    final response = await _dio.get<String>(
      '$_baseUrl/status',
      options: _options,
    );
    return DingTalkMonitorShellStatus.fromJson(
      _readJsonObject(response.data),
    );
  }

  Future<List<DingTalkMonitorMessageEvent>> fetchForwardableRecentEvents({
    int limit = 50,
  }) async {
    final response = await _dio.get<String>(
      '$_baseUrl/events/forwardable-recent',
      queryParameters: <String, Object>{'limit': limit},
      options: _options,
    );
    return dingTalkMonitorList(
      _readJsonList(response.data),
      DingTalkMonitorMessageEvent.fromJson,
    );
  }

  Future<void> startCapture() => _postWithoutBody('/control/start');

  Future<void> stopCapture() => _postWithoutBody('/control/stop');

  Future<void> reloadRuntime() => _postWithoutBody('/control/reload');

  Future<void> probeLatest() => _postWithoutBody('/control/probe-latest');

  Future<void> _postWithoutBody(String path) async {
    await _dio.post<String>('$_baseUrl$path', options: _options);
  }
}

Map<String, dynamic> _readJsonObject(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) {
    return const <String, dynamic>{};
  }
  final decoded = jsonDecode(normalized);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return const <String, dynamic>{};
}

List<dynamic> _readJsonList(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) {
    return const <dynamic>[];
  }
  final decoded = jsonDecode(normalized);
  if (decoded is List) {
    return decoded;
  }
  return const <dynamic>[];
}
