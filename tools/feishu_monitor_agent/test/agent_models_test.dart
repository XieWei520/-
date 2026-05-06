import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:test/test.dart';

void main() {
  group('Agent models', () {
    test('PairAgentRequest serializes pairing payload', () {
      const request = PairAgentRequest(
        pairingCode: ' A7K9Q2 ',
        deviceName: ' COLORFUL-PC ',
        platform: ' windows ',
        agentVersion: ' 0.1.0 ',
      );

      expect(request.toJson(), <String, dynamic>{
        'pairing_code': 'A7K9Q2',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'agent_version': '0.1.0',
      });
    });

    test(
      'PairAgentResponse parses token without exposing it in display text',
      () {
        final response = PairAgentResponse.fromJson(const <String, dynamic>{
          'agent_id': 'agent_1',
          'agent_token': 'secret-token',
          'heartbeat_interval_seconds': 20,
          'server_time': '2026-05-06T10:15:03Z',
        });

        expect(response.agentId, 'agent_1');
        expect(response.agentToken, 'secret-token');
        expect(response.heartbeatIntervalSeconds, 20);
        expect(response.serverTime, '2026-05-06T10:15:03Z');
        expect(response.toString(), isNot(contains('secret-token')));
      },
    );

    test('HeartbeatRequest serializes heartbeat payload', () {
      const request = HeartbeatRequest(
        agentId: 'agent_1',
        status: 'online',
        deviceName: 'COLORFUL-PC',
        platform: 'windows',
        agentVersion: '0.1.0',
        capabilities: <String>['feishu_web_group'],
        observedAt: '2026-05-06T10:15:20Z',
      );

      expect(request.toJson(), <String, dynamic>{
        'agent_id': 'agent_1',
        'status': 'online',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'agent_version': '0.1.0',
        'capabilities': <String>['feishu_web_group'],
        'observed_at': '2026-05-06T10:15:20Z',
      });
    });

    test('AgentConfig round trips JSON and redacts token in display text', () {
      const config = AgentConfig(
        serverUrl: 'https://infoequity.qingyunshe.top',
        agentId: 'agent_1',
        agentToken: 'secret-token',
        deviceName: 'COLORFUL-PC',
        agentVersion: '0.1.0',
        pairedAt: '2026-05-06T10:15:03Z',
        heartbeatIntervalSeconds: 20,
      );

      final parsed = AgentConfig.fromJson(config.toJson());

      expect(parsed.serverUrl, 'https://infoequity.qingyunshe.top');
      expect(parsed.agentId, 'agent_1');
      expect(parsed.agentToken, 'secret-token');
      expect(parsed.heartbeatIntervalSeconds, 20);
      expect(parsed.toString(), isNot(contains('secret-token')));
    });

    test('AgentMonitorRoute parses cloud route payload', () {
      final route = AgentMonitorRoute.fromJson(const <String, dynamic>{
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
      });

      expect(route.routeId, 'route_1');
      expect(route.sourceChatName, '\u98de\u4e66\u65b0\u95fb\u7fa4');
      expect(route.destinationGroupNo, 'group_1');
      expect(route.includeText, isTrue);
      expect(route.includeImages, isFalse);
    });

    test('BrowserStatusReportRequest serializes without secrets', () {
      const request = BrowserStatusReportRequest(
        agentId: 'agent_1',
        platform: 'feishu',
        browser: 'chromium',
        profileMode: 'isolated_persistent',
        loginStatus: BrowserLoginStatus.loggedIn,
        observedAt: '2026-05-07T10:00:00Z',
        errorMessage: '',
      );

      expect(request.toJson(), containsPair('login_status', 'logged_in'));
      expect(request.toString(), isNot(contains('secret-token')));
    });

    test('ObservedMessageRequest builds stable JSON payload', () {
      const request = ObservedMessageRequest(
        agentId: 'agent_1',
        routeId: 'route_1',
        sourcePlatform: 'feishu',
        sourceChatName: '\u98de\u4e66\u65b0\u95fb\u7fa4',
        sourceMessageId: 'hash_1',
        messageType: 'text',
        content: '\u65b0\u95fb\u6b63\u6587',
        sourceCreatedAt: '2026-05-07T10:00:00Z',
        observedAt: '2026-05-07T10:00:05Z',
      );

      expect(request.toJson(), containsPair('source_message_id', 'hash_1'));
      expect(
        request.toJson(),
        containsPair('content', '\u65b0\u95fb\u6b63\u6587'),
      );
    });
  });
}
