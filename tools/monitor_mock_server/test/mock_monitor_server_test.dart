import 'dart:convert';
import 'dart:io';

import 'package:monitor_mock_server/src/mock_monitor_server.dart';
import 'package:test/test.dart';

void main() {
  group('MockMonitorServer', () {
    late MockMonitorServer server;
    late HttpClient client;
    late Uri baseUri;

    setUp(() async {
      server = MockMonitorServer(
        clock: () => DateTime.utc(2026, 5, 6, 10, 15, 3),
      );
      final bound = await server.start(port: 0);
      baseUri = Uri.parse(
        'http://${InternetAddress.loopbackIPv4.host}:${bound.port}',
      );
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    test(
      'creates code, pairs, heartbeats, lists online agent and events',
      () async {
        final codeResponse = await _requestJson(
          client,
          baseUri.resolve('/v1/monitor/agent-pairing-codes'),
          method: 'POST',
          body: <String, dynamic>{
            'device_name': 'Windows Agent',
            'platform': 'windows',
          },
        );
        final codeData = codeResponse.body['data'] as Map<String, dynamic>;
        expect(codeData['pairing_code'], 'A7K9Q2');

        final pairResponse = await _requestJson(
          client,
          baseUri.resolve('/v1/monitor/agents/pair'),
          method: 'POST',
          body: <String, dynamic>{
            'pairing_code': codeData['pairing_code'],
            'device_name': 'COLORFUL-PC',
            'platform': 'windows',
            'agent_version': '0.1.0',
          },
        );
        final pairData = pairResponse.body['data'] as Map<String, dynamic>;
        expect(pairData['agent_id'], 'agent_1');
        expect(pairData['agent_token'], 'mock_token_agent_1');

        final heartbeatResponse = await _requestJson(
          client,
          baseUri.resolve('/v1/monitor/agents/heartbeat'),
          method: 'POST',
          bearerToken: pairData['agent_token'] as String,
          body: <String, dynamic>{
            'agent_id': pairData['agent_id'],
            'status': 'online',
            'device_name': 'COLORFUL-PC',
            'platform': 'windows',
            'agent_version': '0.1.0',
            'capabilities': <String>['feishu_web_group'],
            'observed_at': '2026-05-06T10:15:20Z',
          },
        );
        expect(
          (heartbeatResponse.body['data'] as Map<String, dynamic>)['status'],
          'online',
        );

        final agentsResponse = await _requestJson(
          client,
          baseUri.resolve('/v1/monitor/agents?platform=feishu'),
        );
        final agents = agentsResponse.body['data'] as List<dynamic>;
        expect(agents, hasLength(1));
        expect((agents.single as Map<String, dynamic>)['status'], 'online');

        final eventsResponse = await _requestJson(
          client,
          baseUri.resolve('/v1/monitor/events?platform=feishu'),
        );
        final events = eventsResponse.body['data'] as List<dynamic>;
        expect(events, isNotEmpty);
        expect(
          events
              .map((event) => (event as Map<String, dynamic>)['message'])
              .join('\n'),
          contains('已绑定'),
        );
      },
    );

    test('reusing a pairing code returns HTTP 409', () async {
      final codeResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agent-pairing-codes'),
        method: 'POST',
        body: <String, dynamic>{
          'device_name': 'Windows Agent',
          'platform': 'windows',
        },
      );
      final code =
          (codeResponse.body['data'] as Map<String, dynamic>)['pairing_code']
              as String;

      Future<_JsonResponse> pair() => _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agents/pair'),
        method: 'POST',
        body: <String, dynamic>{
          'pairing_code': code,
          'device_name': 'COLORFUL-PC',
          'platform': 'windows',
          'agent_version': '0.1.0',
        },
      );

      expect((await pair()).statusCode, 200);
      final reused = await pair();

      expect(reused.statusCode, 409);
      expect(
        (reused.body['error'] as Map<String, dynamic>)['code'],
        'pairing_code_used',
      );
    });
  });
}

Future<_JsonResponse> _requestJson(
  HttpClient client,
  Uri uri, {
  String method = 'GET',
  Map<String, dynamic>? body,
  String? bearerToken,
}) async {
  final request = await client.openUrl(method, uri);
  request.headers.contentType = ContentType.json;
  if (bearerToken != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
  }
  if (body != null) {
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final responseBody = await utf8.decoder.bind(response).join();
  return _JsonResponse(
    response.statusCode,
    jsonDecode(responseBody) as Map<String, dynamic>,
  );
}

class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}
