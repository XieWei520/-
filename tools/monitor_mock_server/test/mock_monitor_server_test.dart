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

    test('full flow dedupes observed messages and records forwarded event', () async {
      final codeResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agent-pairing-codes'),
        method: 'POST',
        body: <String, dynamic>{
          'device_name': 'Windows Agent',
          'platform': 'windows',
        },
      );
      final pairingCode =
          (codeResponse.body['data'] as Map<String, dynamic>)['pairing_code']
              as String;

      final pairResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agents/pair'),
        method: 'POST',
        body: <String, dynamic>{
          'pairing_code': pairingCode,
          'device_name': 'COLORFUL-PC',
          'platform': 'windows',
          'agent_version': '0.1.0',
        },
      );
      final pairData = pairResponse.body['data'] as Map<String, dynamic>;
      final agentId = pairData['agent_id'] as String;
      final token = pairData['agent_token'] as String;

      final routeResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/routes'),
        method: 'POST',
        bearerToken: token,
        body: <String, dynamic>{
          'platform': 'feishu',
          'connector_type': 'feishu_web_group',
          'route_type': 'feishu_web_group_to_wukong_im_group',
          'source': <String, dynamic>{'chat_name': '飞书新闻群'},
          'destination': <String, dynamic>{
            'type': 'wukong_im_group',
            'group_no': 'group_1',
            'group_name': '悟空 IM 新闻群',
          },
          'message_policy': <String, dynamic>{
            'include_text': true,
            'include_links': true,
            'include_images': false,
            'include_files': false,
          },
        },
      );
      final routeData = routeResponse.body['data'] as Map<String, dynamic>;
      final routeId = routeData['id'] as String;
      expect(routeData['agent_id'], agentId);
      expect(routeData['status'], 'running');

      final myRoutesResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agents/me/routes'),
        bearerToken: token,
      );
      final myRoutes = myRoutesResponse.body['data'] as List<dynamic>;
      expect(myRoutes, hasLength(1));
      expect((myRoutes.single as Map<String, dynamic>)['id'], routeId);

      final browserStatusReport = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/agents/browser-status'),
        method: 'POST',
        bearerToken: token,
        body: <String, dynamic>{
          'agent_id': agentId,
          'platform': 'feishu',
          'browser': 'chromium',
          'profile_mode': 'isolated_persistent',
          'login_status': 'logged_in',
          'observed_at': '2026-05-06T10:15:30Z',
          'error_message': '',
        },
      );
      expect(
        (browserStatusReport.body['data'] as Map<String, dynamic>)['login_status'],
        'logged_in',
      );

      final browserStatus = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/platforms/feishu/browser-status'),
        bearerToken: token,
      );
      expect(
        (browserStatus.body['data'] as Map<String, dynamic>)['browser'],
        'chromium',
      );

      final observedResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/messages/observed'),
        method: 'POST',
        bearerToken: token,
        body: <String, dynamic>{
          'agent_id': agentId,
          'route_id': routeId,
          'source_platform': 'feishu',
          'source_chat_name': '飞书新闻群',
          'source_message_id': 'msg_1',
          'message_type': 'text',
          'content': '新闻正文',
          'source_created_at': '2026-05-06T10:15:31Z',
          'observed_at': '2026-05-06T10:15:32Z',
        },
      );
      expect(
        (observedResponse.body['data'] as Map<String, dynamic>)['duplicate'],
        isFalse,
      );

      final duplicateResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/messages/observed'),
        method: 'POST',
        bearerToken: token,
        body: <String, dynamic>{
          'agent_id': agentId,
          'route_id': routeId,
          'source_platform': 'feishu',
          'source_chat_name': '飞书新闻群',
          'source_message_id': 'msg_1',
          'message_type': 'text',
          'content': '新闻正文',
          'source_created_at': '2026-05-06T10:15:31Z',
          'observed_at': '2026-05-06T10:15:33Z',
        },
      );
      expect(
        (duplicateResponse.body['data'] as Map<String, dynamic>)['duplicate'],
        isTrue,
      );

      final eventsResponse = await _requestJson(
        client,
        baseUri.resolve('/v1/monitor/events?platform=feishu'),
      );
      final events = eventsResponse.body['data'] as List<dynamic>;
      expect(
        events.any((event) => (event as Map<String, dynamic>)['type'] == 'forwarded'),
        isTrue,
      );
    });

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
