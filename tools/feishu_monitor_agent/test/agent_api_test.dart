import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_api.dart';
import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:test/test.dart';

void main() {
  group('AgentApi', () {
    late HttpServer server;
    late Uri serverUri;
    final requests = <_CapturedRequest>[];

    setUp(() async {
      requests.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUri = Uri.parse('http://${server.address.host}:${server.port}');
      unawaited(_serve(server, requests));
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('pair posts JSON payload and parses response', () async {
      final api = AgentApi(serverUrl: serverUri.toString());

      final response = await api.pair(
        const PairAgentRequest(
          pairingCode: 'A7K9Q2',
          deviceName: 'COLORFUL-PC',
          platform: 'windows',
          agentVersion: '0.1.0',
        ),
      );

      expect(response.agentId, 'agent_1');
      expect(response.agentToken, 'secret-token');
      expect(response.heartbeatIntervalSeconds, 20);
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/v1/monitor/agents/pair');
      expect(requests.single.body, containsPair('pairing_code', 'A7K9Q2'));
      api.close();
    });

    test('heartbeat sends bearer token and parses response', () async {
      final api = AgentApi(serverUrl: serverUri.toString());

      final response = await api.heartbeat(
        agentToken: 'secret-token',
        request: const HeartbeatRequest(
          agentId: 'agent_1',
          status: 'online',
          deviceName: 'COLORFUL-PC',
          platform: 'windows',
          agentVersion: '0.1.0',
          capabilities: <String>['feishu_web_group'],
          observedAt: '2026-05-06T10:15:20Z',
        ),
      );

      expect(response.agentId, 'agent_1');
      expect(response.status, 'online');
      expect(response.nextHeartbeatAfterSeconds, 20);
      expect(requests.single.authorization, 'Bearer secret-token');
      expect(requests.single.path, '/v1/monitor/agents/heartbeat');
      api.close();
    });

    test('non-2xx response throws sanitized AgentApiException', () async {
      final api = AgentApi(serverUrl: serverUri.toString());

      expect(
        () => api.pair(
          const PairAgentRequest(
            pairingCode: 'BAD',
            deviceName: 'COLORFUL-PC',
            platform: 'windows',
            agentVersion: '0.1.0',
          ),
        ),
        throwsA(
          isA<AgentApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.code, 'code', 'pairing_code_used')
              .having(
                (error) => error.toString(),
                'toString',
                isNot(contains('secret-token')),
              ),
        ),
      );
      api.close();
    });
  });
}

Future<void> _serve(HttpServer server, List<_CapturedRequest> requests) async {
  await for (final request in server) {
    final rawBody = await utf8.decoder.bind(request).join();
    final decodedBody = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;
    requests.add(
      _CapturedRequest(
        method: request.method,
        path: request.uri.path,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        body: decodedBody,
      ),
    );

    request.response.headers.contentType = ContentType.json;
    if (decodedBody['pairing_code'] == 'BAD') {
      request.response.statusCode = 409;
      request.response.write(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'pairing_code_used',
            'message': '绑定码已使用',
            'details': <String, dynamic>{},
            'request_id': 'test_request',
          },
        }),
      );
      await request.response.close();
      continue;
    }

    if (request.uri.path == '/v1/monitor/agents/pair') {
      request.response.write(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'agent_id': 'agent_1',
            'agent_token': 'secret-token',
            'heartbeat_interval_seconds': 20,
            'server_time': '2026-05-06T10:15:03Z',
          },
        }),
      );
    } else if (request.uri.path == '/v1/monitor/agents/heartbeat') {
      request.response.write(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'agent_id': 'agent_1',
            'status': 'online',
            'next_heartbeat_after_seconds': 20,
            'server_time': '2026-05-06T10:15:20Z',
          },
        }),
      );
    } else {
      request.response.statusCode = 404;
      request.response.write(
        jsonEncode(<String, dynamic>{'error': 'not found'}),
      );
    }
    await request.response.close();
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.authorization,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final Map<String, dynamic> body;
}
