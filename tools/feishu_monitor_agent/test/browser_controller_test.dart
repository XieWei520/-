import 'dart:io';

import 'package:feishu_monitor_agent/src/browser_controller.dart';
import 'package:feishu_monitor_agent/src/browser_profile.dart';
import 'package:test/test.dart';

void main() {
  group('PuppeteerBrowserController launch safety', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'feishu_browser_controller_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('uses the agent isolated chromium profile as user data dir', () {
      final paths = BrowserProfilePaths(tempDir.path);

      final config = PuppeteerBrowserController.buildLaunchConfig(
        paths,
        headless: true,
      );

      expect(config.headless, isTrue);
      expect(config.userDataDir, paths.profileDir.path);
      expect(config.userDataDir, endsWith('chromium-profile'));
    });

    test('does not point Chromium at a default Chrome or Edge profile', () {
      final paths = BrowserProfilePaths(tempDir.path);

      final config = PuppeteerBrowserController.buildLaunchConfig(
        paths,
        headless: false,
      );
      final launchText = '${config.userDataDir} ${config.args.join(' ')}';

      expect(launchText, isNot(contains('Google\\Chrome\\User Data')));
      expect(launchText, isNot(contains('Microsoft\\Edge\\User Data')));
      expect(launchText, isNot(contains('User Data\\Default')));
    });
  });
}
