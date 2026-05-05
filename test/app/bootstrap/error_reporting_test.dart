import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/bootstrap/error_reporting.dart';

void main() {
  test('normalizeDsn returns null for null input', () {
    expect(ErrorReportingConfig.normalizeDsn(null), isNull);
  });

  test('normalizeDsn returns null for blank or whitespace input', () {
    expect(ErrorReportingConfig.normalizeDsn(''), isNull);
    expect(ErrorReportingConfig.normalizeDsn('   '), isNull);
    expect(ErrorReportingConfig.normalizeDsn('\n\t  '), isNull);
  });

  test('normalizeDsn trims surrounding whitespace', () {
    expect(
      ErrorReportingConfig.normalizeDsn('  https://example@sentry.io/123  '),
      'https://example@sentry.io/123',
    );
  });

  test('runWithErrorReporting bypasses Sentry when disabled', () async {
    final events = <String>[];
    var sentryInitialized = false;
    var isolateHookInstalled = false;

    await runWithErrorReporting(
      config: const ErrorReportingConfig(dsn: null),
      startup: () async => events.add('startup'),
      runAppCallback: () => events.add('runApp'),
      sentryInitializer:
          ({
            required String dsn,
            required Future<void> Function() appRunner,
          }) async {
            sentryInitialized = true;
            await appRunner();
          },
      installIsolateErrorHook: () {
        isolateHookInstalled = true;
      },
    );

    expect(events, <String>['startup', 'runApp']);
    expect(sentryInitialized, isFalse);
    expect(isolateHookInstalled, isFalse);
  });

  test('runWithErrorReporting initializes Sentry when enabled', () async {
    final events = <String>[];
    String? initializedDsn;
    var isolateHookInstalled = false;

    await runWithErrorReporting(
      config: const ErrorReportingConfig(dsn: 'https://example@sentry.io/123'),
      startup: () async => events.add('startup'),
      runAppCallback: () => events.add('runApp'),
      sentryInitializer:
          ({
            required String dsn,
            required Future<void> Function() appRunner,
          }) async {
            initializedDsn = dsn;
            await appRunner();
          },
      installIsolateErrorHook: () {
        isolateHookInstalled = true;
      },
    );

    expect(initializedDsn, 'https://example@sentry.io/123');
    expect(isolateHookInstalled, isTrue);
    expect(events, <String>['startup', 'runApp']);
  });
}
