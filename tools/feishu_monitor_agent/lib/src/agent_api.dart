import 'dart:convert';
import 'dart:io';

import 'agent_models.dart';
import 'heartbeat_runner.dart';

class AgentApiException implements Exception {
  const AgentApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() =>
      'AgentApiException(statusCode: $statusCode, code: $code, message: $message)';
}

class AgentApi implements AgentApiLike {
  AgentApi({required String serverUrl, HttpClient? client})
    : _serverUri = Uri.parse(serverUrl),
      _client = client ?? HttpClient();

  final Uri _serverUri;
  final HttpClient _client;

  Future<PairAgentResponse> pair(PairAgentRequest request) async {
    final json = await _postJson(
      '/v1/monitor/agents/pair',
      body: request.toJson(),
    );
    return PairAgentResponse.fromJson(_dataObject(json));
  }

  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  }) async {
    final json = await _postJson(
      '/v1/monitor/agents/heartbeat',
      body: request.toJson(),
      bearerToken: agentToken,
    );
    return HeartbeatResponse.fromJson(_dataObject(json));
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
    String? bearerToken,
  }) async {
    final uri = _serverUri.resolve(path);
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${bearerToken.trim()}',
      );
    }
    request.write(jsonEncode(body));
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    final decoded = responseBody.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody);
    final json = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromJson(response.statusCode, json);
    }
    return json;
  }

  AgentApiException _exceptionFromJson(
    int statusCode,
    Map<String, dynamic> json,
  ) {
    final error = json['error'];
    if (error is Map) {
      final normalized = Map<String, dynamic>.from(error);
      return AgentApiException(
        statusCode,
        _string(normalized['code'], fallback: 'monitor_api_error'),
        _string(normalized['message'], fallback: 'Monitor API request failed.'),
      );
    }
    return AgentApiException(
      statusCode,
      'monitor_api_error',
      'Monitor API request failed.',
    );
  }

  Map<String, dynamic> _dataObject(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return json;
  }

  void close() {
    _client.close(force: true);
  }
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}
