import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_cli.dart';
import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/agent_store.dart';
import 'package:feishu_monitor_agent/src/heartbeat_runner.dart';
import 'package:test/test.dart';

void main() {
  group('runAgentCli', () {
    late Directory tempDir;
    late _FakeAgentApi fakeApi;
    late List<String> output;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feishu_agent_cli_test_');
      fakeApi = _FakeAgentApi();
      output = <String>[];
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('pair command stores config and does not print token', () async {
      final exitCode = await runAgentCli(
        <String>[
          'pair',
          '--server',
          'https://infoequity.qingyunshe.top',
          '--code',
          'A7K9Q2',
          '--store-dir',
          tempDir.path,
        ],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 6, 10, 15, 3),
        deviceNameProvider: () => 'COLORFUL-PC',
      );

      final config = await AgentStore(tempDir.path).load();

      expect(exitCode, 0);
      expect(output.join('\n'), contains('绑定成功'));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(config, isNotNull);
      expect(config!.serverUrl, 'https://infoequity.qingyunshe.top');
      expect(config.agentId, 'agent_1');
      expect(config.agentToken, 'secret-token');
      expect(fakeApi.lastPairRequest!.pairingCode, 'A7K9Q2');
      expect(fakeApi.closed, isTrue);
    });

    test('run command sends one heartbeat from stored config', () async {
      await AgentStore(tempDir.path).save(
        const AgentConfig(
          serverUrl: 'https://infoequity.qingyunshe.top',
          agentId: 'agent_1',
          agentToken: 'secret-token',
          deviceName: 'COLORFUL-PC',
          agentVersion: agentVersion,
          pairedAt: '2026-05-06T10:15:03Z',
          heartbeatIntervalSeconds: 20,
        ),
      );

      final exitCode = await runAgentCli(
        <String>['run', '--once', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
        now: () => DateTime.utc(2026, 5, 6, 10, 15, 20),
      );

      expect(exitCode, 0);
      expect(output.join('\n'), contains('心跳成功'));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(fakeApi.heartbeatCount, 1);
      expect(fakeApi.lastHeartbeatToken, 'secret-token');
      expect(fakeApi.lastHeartbeatRequest!.capabilities, <String>[
        'feishu_web_group',
      ]);
      expect(fakeApi.closed, isTrue);
    });

    test('run command reports missing config', () async {
      final exitCode = await runAgentCli(
        <String>['run', '--once', '--store-dir', tempDir.path],
        apiFactory: (_) => fakeApi,
        writeLine: output.add,
      );

      expect(exitCode, 66);
      expect(output.join('\n'), contains('未找到 Agent 配置'));
      expect(fakeApi.heartbeatCount, 0);
    });
  });
}

class _FakeAgentApi implements AgentApiLike {
  PairAgentRequest? lastPairRequest;
  HeartbeatRequest? lastHeartbeatRequest;
  String? lastHeartbeatToken;
  int heartbeatCount = 0;
  bool closed = false;

  @override
  Future<PairAgentResponse> pair(PairAgentRequest request) async {
    lastPairRequest = request;
    return const PairAgentResponse(
      agentId: 'agent_1',
      agentToken: 'secret-token',
      heartbeatIntervalSeconds: 20,
      serverTime: '2026-05-06T10:15:03Z',
    );
  }

  @override
  Future<HeartbeatResponse> heartbeat({
    required String agentToken,
    required HeartbeatRequest request,
  }) async {
    heartbeatCount += 1;
    lastHeartbeatToken = agentToken;
    lastHeartbeatRequest = request;
    return const HeartbeatResponse(
      agentId: 'agent_1',
      status: 'online',
      nextHeartbeatAfterSeconds: 20,
      serverTime: '2026-05-06T10:15:20Z',
    );
  }

  @override
  void close() {
    closed = true;
  }
}
