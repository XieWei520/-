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

    test('fetchAssignedRoutes sends bearer token and parses routes', () async {
      final api = AgentApi(serverUrl: serverUri.toString());

      final routes = await api.fetchAssignedRoutes(agentToken: 'secret-token');

      expect(routes, hasLength(1));
      expect(routes.single.routeId, 'route_1');
      expect(routes.single.sourceChatName, '\u98de\u4e66\u65b0\u95fb\u7fa4');
      expect(requests.single.method, 'GET');
      expect(requests.single.path, '/v1/monitor/agents/me/routes');
      expect(requests.single.authorization, 'Bearer secret-token');
      api.close();
    });

    test(
      'reportBrowserStatus posts status payload with bearer token',
      () async {
        final api = AgentApi(serverUrl: serverUri.toString());

        await api.reportBrowserStatus(
          agentToken: 'secret-token',
          request: const BrowserStatusReportRequest(
            agentId: 'agent_1',
            platform: 'feishu',
            browser: 'chromium',
            profileMode: 'isolated_persistent',
            loginStatus: BrowserLoginStatus.loggedIn,
            observedAt: '2026-05-07T10:00:00Z',
            errorMessage: '',
          ),
        );

        expect(requests.single.method, 'POST');
        expect(requests.single.path, '/v1/monitor/agents/browser-status');
        expect(requests.single.authorization, 'Bearer secret-token');
        expect(requests.single.body, containsPair('login_status', 'logged_in'));
        api.close();
      },
    );

    test('reportObservedMessage parses duplicate and forward status', () async {
      final api = AgentApi(serverUrl: serverUri.toString());

      final response = await api.reportObservedMessage(
        agentToken: 'secret-token',
        request: const ObservedMessageRequest(
          agentId: 'agent_1',
          routeId: 'route_1',
          sourcePlatform: 'feishu',
          sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
          sourceMessageId: 'hash_1',
          messageType: 'text',
          content: '\u65b0\u95fb\u6b63\u6587',
          sourceCreatedAt: '2026-05-07T10:00:00Z',
          observedAt: '2026-05-07T10:00:05Z',
        ),
      );

      expect(response.accepted, isTrue);
      expect(response.duplicate, isFalse);
      expect(response.forwardStatus, 'forwarded');
      expect(requests.single.path, '/v1/monitor/messages/observed');
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
    } else if (request.uri.path == '/v1/monitor/agents/me/routes') {
      request.response.write(
        jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'route_id': 'route_1',
              'platform': 'feishu',
              'connector_type': 'feishu_web_group',
              'route_type': 'feishu_web_group_to_wukong_im_group',
              'source': <String, dynamic>{
                'chat_name': '\u98de\u4e66\u65b0\u95fb\u7fa4',
              },
              'destination': <String, dynamic>{
                'type': 'wukong_im_group',
                'group_no': 'group_1',
                'group_name': '\u609f\u7a7a IM \u65b0\u95fb\u7fa4',
              },
              'message_policy': <String, dynamic>{
                'include_text': true,
                'include_links': true,
                'include_images': false,
                'include_files': false,
              },
            },
          ],
        }),
      );
    } else if (request.uri.path == '/v1/monitor/agents/browser-status') {
      request.response.write(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'ok': true},
        }),
      );
    } else if (request.uri.path == '/v1/monitor/messages/observed') {
      request.response.write(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{
            'accepted': true,
            'duplicate': false,
            'forward_status': 'forwarded',
            'message_id': 'message_1',
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
