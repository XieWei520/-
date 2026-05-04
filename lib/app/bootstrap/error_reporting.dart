import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef SentryInitCallback = Future<void> Function({
  required String dsn,
  required Future<void> Function() appRunner,
});

typedef IsolateErrorHookInstaller = void Function();

class ErrorReportingConfig {
  const ErrorReportingConfig({required this.dsn});

  final String? dsn;

  bool get enabled => dsn != null;

  static String? normalizeDsn(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

RawReceivePort? _isolateErrorPort;
bool _isolateErrorHookInstalled = false;

Future<void> runWithErrorReporting({
  required ErrorReportingConfig config,
  required Future<void> Function() startup,
  required VoidCallback runAppCallback,
  SentryInitCallback sentryInitializer = _defaultSentryInitializer,
  IsolateErrorHookInstaller installIsolateErrorHook = _installIsolateErrorHook,
}) async {
  if (!config.enabled) {
    await startup();
    runAppCallback();
    return;
  }

  installIsolateErrorHook();

  await sentryInitializer(
    dsn: config.dsn!,
    appRunner: () async {
      await startup();
      runAppCallback();
    },
  );
}

Future<void> _defaultSentryInitializer({
  required String dsn,
  required Future<void> Function() appRunner,
}) {
  return SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.attachStacktrace = true;
      options.tracesSampleRate = 0.1;
    },
    appRunner: appRunner,
  );
}

void _installIsolateErrorHook() {
  if (_isolateErrorHookInstalled) {
    return;
  }
  _isolateErrorHookInstalled = true;

  _isolateErrorPort ??= RawReceivePort((Object? pair) {
    if (pair is! List<Object?> || pair.isEmpty) {
      return;
    }
    final Object error = pair.first ?? 'unknown isolate error';
    final StackTrace? stackTrace =
        pair.length > 1 ? _coerceStackTrace(pair[1]) : null;
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  });
  Isolate.current.addErrorListener(_isolateErrorPort!.sendPort);
}

StackTrace? _coerceStackTrace(Object? value) {
  if (value is StackTrace) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return StackTrace.fromString(value);
  }
  return null;
}
