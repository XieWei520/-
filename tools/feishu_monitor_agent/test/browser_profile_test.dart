import 'dart:io';

import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/agent_store.dart';
import 'package:feishu_monitor_agent/src/browser_profile.dart';
import 'package:test/test.dart';

void main() {
  group('BrowserProfilePaths', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('feishu_profile_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('uses chromium-profile and runtime under store directory', () {
      final paths = BrowserProfilePaths(tempDir.path);

      expect(paths.profileDir.path, endsWith('chromium-profile'));
      expect(paths.runtimeDir.path, endsWith('runtime'));
      expect(
        paths.lastBrowserStatusFile.path,
        endsWith('last-browser-status.json'),
      );
      expect(paths.dedupeCacheFile.path, endsWith('dedupe-cache.json'));
    });

    test('clearProfile keeps agent_config.json', () async {
      await AgentStore(tempDir.path).save(
        const AgentConfig(
          serverUrl: 'https://infoequity.qingyunshe.top',
          agentId: 'agent_1',
          agentToken: 'secret-token',
          deviceName: 'COLORFUL-PC',
          agentVersion: '0.1.0',
          pairedAt: '2026-05-07T10:00:00Z',
          heartbeatIntervalSeconds: 20,
        ),
      );
      final paths = BrowserProfilePaths(tempDir.path);
      await paths.profileDir.create(recursive: true);
      await File(
        '${paths.profileDir.path}${Platform.pathSeparator}Cookies',
      ).writeAsString('cookie-data');

      await BrowserProfileCleaner(paths).clearProfile();

      expect(await paths.profileDir.exists(), isFalse);
      expect(
        await File(
          '${tempDir.path}${Platform.pathSeparator}agent_config.json',
        ).exists(),
        isTrue,
      );
    });
  });
}
