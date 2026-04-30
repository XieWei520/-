import 'dart:async';

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

  test('startup runner does not wait for background steps', () async {
    final events = <String>[];
    final backgroundCompleter = Completer<void>();
    final runner = AppStartupRunner(
      logger: const AppLogger('startup'),
      steps: <AppStartupStep>[
        AppStartupStep('storage', () async => events.add('storage')),
      ],
      backgroundSteps: <AppStartupStep>[
        AppStartupStep('drafts', () async {
          events.add('drafts:start');
          await backgroundCompleter.future;
          events.add('drafts:end');
        }),
      ],
    );

    await runner.ensureStarted().timeout(const Duration(milliseconds: 100));

    expect(events, <String>['storage', 'drafts:start']);

    backgroundCompleter.complete();
    await runner.ensureBackgroundStarted();

    expect(events, <String>['storage', 'drafts:start', 'drafts:end']);
  });

  test(
    'startup runner records foreground and background step timings',
    () async {
      final events = <AppStartupStepMetric>[];
      final runner = AppStartupRunner(
        logger: const AppLogger('startup'),
        onStepMetric: events.add,
        steps: <AppStartupStep>[AppStartupStep('storage', () async {})],
        backgroundSteps: <AppStartupStep>[AppStartupStep('push', () async {})],
      );

      await runner.ensureStarted();
      await runner.ensureBackgroundStarted();

      expect(events, hasLength(2));
      expect(events[0].label, 'storage');
      expect(events[0].background, isFalse);
      expect(events[0].succeeded, isTrue);
      expect(events[0].elapsed, isNot(Duration.zero));
      expect(events[1].label, 'push');
      expect(events[1].background, isTrue);
      expect(events[1].succeeded, isTrue);
    },
  );

  test(
    'startup runner stops at first failing step and rejects retries',
    () async {
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
    },
  );

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
