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
  });
}
