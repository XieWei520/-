import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockMonitorServer {
  MockMonitorServer({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _PairingCode> _codes = <String, _PairingCode>{};
  final Map<String, _Agent> _agents = <String, _Agent>{};
  final List<_Event> _events = <_Event>[];
  HttpServer? _server;
  int _nextAgent = 1;
  int _nextEvent = 1;

  Future<HttpServer> start({int port = 8787}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    unawaited(_listen(server));
    return server;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _listen(HttpServer server) async {
    await for (final request in server) {
      try {
        await _handle(request);
      } catch (error) {
        await _writeJson(request.response, 500, <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'mock_server_error',
            'message': error.toString(),
            'details': <String, dynamic>{},
            'request_id': 'mock_request',
          },
        });
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/v1/monitor/agent-pairing-codes') {
      await _handleCreateCode(request);
      return;
    }
    if (request.method == 'POST' && path == '/v1/monitor/agents/pair') {
      await _handlePair(request);
      return;
    }
    if (request.method == 'POST' && path == '/v1/monitor/agents/heartbeat') {
      await _handleHeartbeat(request);
      return;
    }
    if (request.method == 'GET' && path == '/v1/monitor/agents') {
      await _handleAgents(request);
      return;
    }
    if (request.method == 'GET' && path == '/v1/monitor/events') {
      await _handleEvents(request);
      return;
    }
    if (request.method == 'GET' &&
        path == '/v1/monitor/platforms/feishu/stats') {
      await _writeJson(request.response, 200, <String, dynamic>{
        'data': <String, dynamic>{
          'running_routes': 0,
          'today_forwarded': 0,
          'alerts': 0,
        },
      });
      return;
    }
    if (request.method == 'GET' && path == '/v1/monitor/routes') {
      await _writeJson(request.response, 200, <String, dynamic>{
        'data': <dynamic>[],
      });
      return;
    }
    await _writeJson(request.response, 404, _error('not_found', '接口不存在'));
  }

  Future<void> _handleCreateCode(HttpRequest request) async {
    final body = await _readBody(request);
    final code = _codes.isEmpty ? 'A7K9Q2' : 'A7K9Q${_codes.length + 2}';
    final expiresAt = _clock().toUtc().add(const Duration(minutes: 10));
    _codes[code] = _PairingCode(
      code: code,
      deviceName: _string(body['device_name'], fallback: 'Windows Agent'),
      platform: _string(body['platform'], fallback: 'windows'),
      expiresAt: expiresAt,
    );
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'pairing_code': code,
        'expires_at': expiresAt.toIso8601String(),
      },
    });
  }

  Future<void> _handlePair(HttpRequest request) async {
    final body = await _readBody(request);
    final code = _string(body['pairing_code']);
    final pairing = _codes[code];
    if (pairing == null) {
      await _writeJson(
        request.response,
        404,
        _error('pairing_code_not_found', '绑定码不存在'),
      );
      return;
    }
    if (pairing.used) {
      await _writeJson(
        request.response,
        409,
        _error('pairing_code_used', '绑定码已使用'),
      );
      return;
    }
    if (_clock().toUtc().isAfter(pairing.expiresAt)) {
      await _writeJson(
        request.response,
        410,
        _error('pairing_code_expired', '绑定码已过期'),
      );
      return;
    }
    pairing.used = true;
    final agentNumber = _nextAgent++;
    final agentId = 'agent_$agentNumber';
    final token = 'mock_token_$agentId';
    final agent = _Agent(
      id: agentId,
      token: token,
      deviceName: _string(body['device_name'], fallback: pairing.deviceName),
      platform: _string(body['platform'], fallback: pairing.platform),
      version: _string(body['agent_version'], fallback: '0.1.0'),
      status: 'offline',
      lastHeartbeatAt: '',
    );
    _agents[agentId] = agent;
    _events.insert(
      0,
      _Event(
        id: 'event_${_nextEvent++}',
        type: 'agent_paired',
        occurredAt: _clock().toUtc().toIso8601String(),
        message: 'Windows Agent ${agent.deviceName} 已绑定',
      ),
    );
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'agent_id': agentId,
        'agent_token': token,
        'heartbeat_interval_seconds': 20,
        'server_time': _clock().toUtc().toIso8601String(),
      },
    });
  }

  Future<void> _handleHeartbeat(HttpRequest request) async {
    final body = await _readBody(request);
    final token = _bearerToken(request);
    final agentId = _string(body['agent_id']);
    final agent = _agents[agentId];
    if (agent == null || token != agent.token) {
      await _writeJson(
        request.response,
        401,
        _error('invalid_agent_token', 'Agent token 无效'),
      );
      return;
    }
    agent
      ..status = 'online'
      ..deviceName = _string(body['device_name'], fallback: agent.deviceName)
      ..version = _string(body['agent_version'], fallback: agent.version)
      ..lastHeartbeatAt = _clock().toUtc().toIso8601String();
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'agent_id': agentId,
        'status': agent.status,
        'next_heartbeat_after_seconds': 20,
        'server_time': _clock().toUtc().toIso8601String(),
      },
    });
  }

  Future<void> _handleAgents(HttpRequest request) async {
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': _agents.values
          .map(
            (agent) => <String, dynamic>{
              'id': agent.id,
              'device_name': agent.deviceName,
              'platform': agent.platform,
              'version': agent.version,
              'status': agent.status,
              'last_heartbeat_at': agent.lastHeartbeatAt,
            },
          )
          .toList(growable: false),
      'page': <String, dynamic>{'next_cursor': null},
    });
  }

  Future<void> _handleEvents(HttpRequest request) async {
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': _events
          .map(
            (event) => <String, dynamic>{
              'id': event.id,
              'type': event.type,
              'occurred_at': event.occurredAt,
              'message': event.message,
            },
          )
          .toList(growable: false),
      'page': <String, dynamic>{'next_cursor': null},
    });
  }

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final rawBody = await utf8.decoder.bind(request).join();
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(rawBody);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Map<String, dynamic> _error(String code, String message) {
    return <String, dynamic>{
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        'details': <String, dynamic>{},
        'request_id': 'mock_request',
      },
    };
  }

  String _bearerToken(HttpRequest request) {
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefix = 'Bearer ';
    if (authorization.startsWith(prefix)) {
      return authorization.substring(prefix.length).trim();
    }
    return '';
  }
}

class _PairingCode {
  _PairingCode({
    required this.code,
    required this.deviceName,
    required this.platform,
    required this.expiresAt,
  });

  final String code;
  final String deviceName;
  final String platform;
  final DateTime expiresAt;
  bool used = false;
}

class _Agent {
  _Agent({
    required this.id,
    required this.token,
    required this.deviceName,
    required this.platform,
    required this.version,
    required this.status,
    required this.lastHeartbeatAt,
  });

  final String id;
  final String token;
  String deviceName;
  final String platform;
  String version;
  String status;
  String lastHeartbeatAt;
}

class _Event {
  const _Event({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.message,
  });

  final String id;
  final String type;
  final String occurredAt;
  final String message;
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
