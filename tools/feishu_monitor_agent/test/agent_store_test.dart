import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/agent_store.dart';
import 'package:test/test.dart';

void main() {
  group('AgentStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'feishu_agent_store_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null when config file does not exist', () async {
      final store = AgentStore(tempDir.path);

      expect(await store.load(), isNull);
    });

    test('saves and loads config as JSON', () async {
      final store = AgentStore(tempDir.path);
      const config = AgentConfig(
        serverUrl: 'https://infoequity.qingyunshe.top',
        agentId: 'agent_1',
        agentToken: 'secret-token',
        deviceName: 'COLORFUL-PC',
        agentVersion: '0.1.0',
        pairedAt: '2026-05-06T10:15:03Z',
        heartbeatIntervalSeconds: 20,
      );

      await store.save(config);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.agentId, 'agent_1');
      expect(loaded.agentToken, 'secret-token');
      expect(
        File(
          '${tempDir.path}${Platform.pathSeparator}agent_config.json',
        ).existsSync(),
        isTrue,
      );
    });
  });
}
