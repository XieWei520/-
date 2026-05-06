import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockMonitorServer {
  MockMonitorServer({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _PairingCode> _codes = <String, _PairingCode>{};
  final Map<String, _Agent> _agents = <String, _Agent>{};
  final Map<String, _Route> _routes = <String, _Route>{};
  final Map<String, _BrowserStatus> _browserStatuses =
      <String, _BrowserStatus>{};
  final Set<String> _observedKeys = <String>{};
  final List<_Event> _events = <_Event>[];
  HttpServer? _server;
  int _nextAgent = 1;
  int _nextRoute = 1;
  int _nextEvent = 1;
  int _nextMessage = 1;

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
    if (request.method == 'POST' &&
        path == '/v1/monitor/agent-pairing-codes') {
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
      await _handleStats(request);
      return;
    }
    if (request.method == 'GET' && path == '/v1/monitor/routes') {
      await _handleRoutes(request);
      return;
    }
    if (request.method == 'POST' && path == '/v1/monitor/routes') {
      await _handleCreateRoute(request);
      return;
    }
    if (request.method == 'GET' && path == '/v1/monitor/agents/me/routes') {
      await _handleMyRoutes(request);
      return;
    }
    if (request.method == 'POST' &&
        path == '/v1/monitor/agents/browser-status') {
      await _handleBrowserStatusReport(request);
      return;
    }
    if (request.method == 'GET' &&
        path == '/v1/monitor/platforms/feishu/browser-status') {
      await _handleBrowserStatusFetch(request);
      return;
    }
    if (request.method == 'POST' && path == '/v1/monitor/messages/observed') {
      await _handleObservedMessage(request);
      return;
    }

    await _writeJson(
      request.response,
      404,
      _error('not_found', '接口不存在'),
    );
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
        _error('pairing_code_not_found', '配对码不存在'),
      );
      return;
    }
    if (pairing.used) {
      await _writeJson(
        request.response,
        409,
        _error('pairing_code_used', '配对码已使用'),
      );
      return;
    }
    if (_clock().toUtc().isAfter(pairing.expiresAt)) {
      await _writeJson(
        request.response,
        410,
        _error('pairing_code_expired', '配对码已过期'),
      );
      return;
    }

    pairing.used = true;
    final agentId = 'agent_${_nextAgent++}';
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
    final agent = _agentFromToken(request);
    if (agent == null) {
      await _writeJson(
        request.response,
        401,
        _error('invalid_agent_token', 'Agent token 无效'),
      );
      return;
    }

    agent
      ..status = _string(body['status'], fallback: 'online')
      ..deviceName = _string(body['device_name'], fallback: agent.deviceName)
      ..version = _string(body['agent_version'], fallback: agent.version)
      ..lastHeartbeatAt = _clock().toUtc().toIso8601String();

    _events.insert(
      0,
      _Event(
        id: 'event_${_nextEvent++}',
        type: 'agent_heartbeat',
        occurredAt: agent.lastHeartbeatAt,
        message: 'Windows Agent ${agent.deviceName} 心跳在线',
      ),
    );

    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'agent_id': agent.id,
        'status': agent.status,
        'next_heartbeat_after_seconds': 20,
        'server_time': agent.lastHeartbeatAt,
      },
    });
  }

  Future<void> _handleAgents(HttpRequest request) async {
    final platform = request.uri.queryParameters['platform'];
    final agents = _agents.values.where((agent) {
      if (platform == null || platform.trim().isEmpty) {
        return true;
      }
      return agent.platform == platform.trim();
    }).toList(growable: false);

    await _writeJson(request.response, 200, <String, dynamic>{
      'data': agents
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
              if (event.routeId.isNotEmpty) 'route_id': event.routeId,
            },
          )
          .toList(growable: false),
      'page': <String, dynamic>{'next_cursor': null},
    });
  }

  Future<void> _handleStats(HttpRequest request) async {
    final runningRoutes = _routes.values
        .where((route) => route.status == 'running')
        .length;
    final todayForwarded = _routes.values.fold<int>(
      0,
      (sum, route) => sum + route.todayForwardedCount,
    );
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'running_routes': runningRoutes,
        'today_forwarded': todayForwarded,
        'alerts': 0,
      },
    });
  }

  Future<void> _handleRoutes(HttpRequest request) async {
    final platform = request.uri.queryParameters['platform'];
    final routes = _routes.values.where((route) {
      if (platform == null || platform.trim().isEmpty) {
        return true;
      }
      return route.platform == platform.trim();
    }).toList(growable: false);

    await _writeJson(request.response, 200, <String, dynamic>{
      'data': routes.map(_routeToJson).toList(growable: false),
    });
  }

  Future<void> _handleCreateRoute(HttpRequest request) async {
    final body = await _readBody(request);
    final agentId = _string(body['agent_id']);
    final assignedAgentId = agentId.isNotEmpty
        ? agentId
        : _agents.isNotEmpty
        ? _agents.values.first.id
        : '';
    final source = _map(body['source']);
    final destination = _map(body['destination']);
    final policy = _map(body['message_policy']);
    final route = _Route(
      id: 'route_${_nextRoute++}',
      platform: _string(body['platform'], fallback: 'feishu'),
      connectorType: _string(
        body['connector_type'],
        fallback: 'feishu_web_group',
      ),
      routeType: _string(
        body['route_type'],
        fallback: 'feishu_web_group_to_wukong_im_group',
      ),
      sourceName: _string(source['chat_name'] ?? body['source_name']),
      destinationName: _string(
        destination['group_name'] ?? body['destination_name'],
        fallback: '悟空 IM 群',
      ),
      agentId: assignedAgentId,
      status: 'running',
      includeText: _bool(policy['include_text'], fallback: true),
      includeLinks: _bool(policy['include_links'], fallback: true),
      includeImages: _bool(policy['include_images']),
      includeFiles: _bool(policy['include_files']),
      createdAt: _clock().toUtc().toIso8601String(),
    );
    _routes[route.id] = route;
    _events.insert(
      0,
      _Event(
        id: 'event_${_nextEvent++}',
        type: 'route_created',
        occurredAt: route.createdAt,
        message: '已创建飞书监控规则 ${route.sourceName} → ${route.destinationName}',
        routeId: route.id,
      ),
    );
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': _routeToJson(route),
    });
  }

  Future<void> _handleMyRoutes(HttpRequest request) async {
    final agent = _agentFromToken(request);
    if (agent == null) {
      await _writeJson(
        request.response,
        401,
        _error('invalid_agent_token', 'Agent token 无效'),
      );
      return;
    }

    final routes = _routes.values
        .where((route) => route.agentId == agent.id)
        .map(_routeToJson)
        .toList(growable: false);
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': routes,
    });
  }

  Future<void> _handleBrowserStatusReport(HttpRequest request) async {
    final body = await _readBody(request);
    final agent = _agentFromToken(request);
    if (agent == null) {
      await _writeJson(
        request.response,
        401,
        _error('invalid_agent_token', 'Agent token 无效'),
      );
      return;
    }

    final platform = _string(body['platform'], fallback: 'feishu');
    final status = _BrowserStatus(
      agentId: agent.id,
      platform: platform,
      browser: _string(body['browser'], fallback: 'chromium'),
      profileMode: _string(
        body['profile_mode'],
        fallback: 'isolated_persistent',
      ),
      loginStatus: _string(body['login_status'], fallback: 'unknown'),
      observedAt:
          DateTime.tryParse(_string(body['observed_at']))?.toUtc() ??
          _clock().toUtc(),
      errorMessage: _string(body['error_message']),
    );
    _browserStatuses['${agent.id}|$platform'] = status;
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': status.toJson(),
    });
  }

  Future<void> _handleBrowserStatusFetch(HttpRequest request) async {
    final status = _latestBrowserStatus('feishu');
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': status?.toJson() ??
          <String, dynamic>{
            'browser': 'chromium',
            'profile_mode': 'isolated_persistent',
            'login_status': 'unknown',
            'observed_at': '',
            'error_message': '',
          },
    });
  }

  Future<void> _handleObservedMessage(HttpRequest request) async {
    final body = await _readBody(request);
    final agent = _agentFromToken(request);
    if (agent == null) {
      await _writeJson(
        request.response,
        401,
        _error('invalid_agent_token', 'Agent token 无效'),
      );
      return;
    }

    final routeId = _string(body['route_id']);
    final route = _routes[routeId];
    if (route == null) {
      await _writeJson(
        request.response,
        404,
        _error('route_not_found', '监控规则不存在'),
      );
      return;
    }
    if (route.agentId.isNotEmpty && route.agentId != agent.id) {
      await _writeJson(
        request.response,
        403,
        _error('route_agent_mismatch', '监控规则未分配给当前 Agent'),
      );
      return;
    }

    final sourceMessageId = _string(body['source_message_id']);
    final dedupeKey = '$routeId:$sourceMessageId';
    final duplicate = _observedKeys.contains(dedupeKey);
    if (!duplicate) {
      _observedKeys.add(dedupeKey);
      route
        ..todayForwardedCount += 1
        ..lastForwardedAt = _string(
          body['observed_at'],
          fallback: _clock().toUtc().toIso8601String(),
        );
      _events.insert(
        0,
        _Event(
          id: 'event_${_nextEvent++}',
          type: 'forwarded',
          occurredAt: route.lastForwardedAt,
          message: '已转发 ${route.sourceName} → ${route.destinationName}',
          routeId: route.id,
        ),
      );
    }

    final messageId = 'message_${_nextMessage++}';
    await _writeJson(request.response, 200, <String, dynamic>{
      'data': <String, dynamic>{
        'accepted': true,
        'duplicate': duplicate,
        'forward_status': duplicate ? 'duplicate' : 'forwarded',
        'message_id': messageId,
      },
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

  Map<String, dynamic> _routeToJson(_Route route) {
    return <String, dynamic>{
      'id': route.id,
      'platform': route.platform,
      'connector_type': route.connectorType,
      'route_type': route.routeType,
      'source_name': route.sourceName,
      'destination_name': route.destinationName,
      'status': route.status,
      'today_forwarded_count': route.todayForwardedCount,
      'last_forwarded_at': route.lastForwardedAt,
      'agent_id': route.agentId,
      'include_text': route.includeText,
      'include_links': route.includeLinks,
      'include_images': route.includeImages,
      'include_files': route.includeFiles,
    };
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

  _Agent? _agentFromToken(HttpRequest request) {
    final token = _bearerToken(request);
    if (token.isEmpty) {
      return null;
    }
    for (final agent in _agents.values) {
      if (agent.token == token) {
        return agent;
      }
    }
    return null;
  }

  _BrowserStatus? _latestBrowserStatus(String platform) {
    _BrowserStatus? latest;
    for (final status in _browserStatuses.values) {
      if (status.platform != platform) {
        continue;
      }
      if (latest == null || status.observedAt.isAfter(latest.observedAt)) {
        latest = status;
      }
    }
    return latest;
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

class _Route {
  _Route({
    required this.id,
    required this.platform,
    required this.connectorType,
    required this.routeType,
    required this.sourceName,
    required this.destinationName,
    required this.agentId,
    required this.status,
    required this.includeText,
    required this.includeLinks,
    required this.includeImages,
    required this.includeFiles,
    required this.createdAt,
  });

  final String id;
  final String platform;
  final String connectorType;
  final String routeType;
  final String sourceName;
  final String destinationName;
  String agentId;
  String status;
  int todayForwardedCount = 0;
  String lastForwardedAt = '';
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;
  final String createdAt;
}

class _BrowserStatus {
  _BrowserStatus({
    required this.agentId,
    required this.platform,
    required this.browser,
    required this.profileMode,
    required this.loginStatus,
    required this.observedAt,
    required this.errorMessage,
  });

  final String agentId;
  final String platform;
  final String browser;
  final String profileMode;
  final String loginStatus;
  final DateTime observedAt;
  final String errorMessage;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'agent_id': agentId,
      'platform': platform,
      'browser': browser,
      'profile_mode': profileMode,
      'login_status': loginStatus,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'error_message': errorMessage,
    };
  }
}

class _Event {
  const _Event({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.message,
    this.routeId = '',
  });

  final String id;
  final String type;
  final String occurredAt;
  final String message;
  final String routeId;
}

String _string(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return fallback;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}
