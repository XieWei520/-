import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/bootstrap/app_startup.dart';
import 'package:wukong_im_app/wk_foundation/logging/app_logger.dart';
import 'package:wukong_im_app/wk_foundation/runtime/app_environment.dart';

void main() {
  test('startup runner executes steps once and in order', () async {
    final events = <String>[];
    final runner = AppStartupRunner(
      logger: const AppLogger('startup'),
      steps: <AppStartupStep>[
        AppStartupStep('storage', () async => events.add('storage')),
        AppStartupStep('push', () async => events.add('push')),
      ],
    );

    await runner.ensureStarted();
    await runner.ensureStarted();

    expect(events, <String>['storage', 'push']);
  });

  test('startup runner stops at first failing step and rejects retries', () async {
    final events = <String>[];
    final runner = AppStartupRunner(
      logger: const AppLogger('startup'),
      steps: <AppStartupStep>[
        AppStartupStep('storage', () async => events.add('storage')),
        AppStartupStep('broken', () async {
          events.add('broken');
          throw StateError('boom');
        }),
        AppStartupStep('never', () async => events.add('never')),
      ],
    );

    await expectLater(runner.ensureStarted(), throwsA(isA<StateError>()));
    await expectLater(runner.ensureStarted(), throwsA(isA<StateError>()));

    expect(events, <String>['storage', 'broken']);
  });

  test('AppEnvironment rejects mismatched platform and web flags', () {
    expect(
      () => AppEnvironment(platform: AppPlatform.windows, isWeb: true),
      throwsArgumentError,
    );
    expect(
      () => AppEnvironment(platform: AppPlatform.web, isWeb: false),
      throwsArgumentError,
    );
  });

  test('AppEnvironment.detect honors debug platform override', () {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    try {
      final environment = AppEnvironment.detect();
      expect(environment.platform, AppPlatform.windows);
      expect(environment.isWeb, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  test('desktop environments opt into sqflite ffi while mobile does not', () {
    final windows = AppEnvironment(platform: AppPlatform.windows, isWeb: false);
    final android = AppEnvironment(platform: AppPlatform.android, isWeb: false);
    final web = AppEnvironment(platform: AppPlatform.web, isWeb: true);

    expect(windows.usesSqfliteFfi, isTrue);
    expect(android.usesSqfliteFfi, isFalse);
    expect(web.usesSqfliteFfi, isFalse);
  });
}
