import 'dart:async';

import 'package:feishu_monitor_shell_app/src/probe_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs one probe for a single request', () async {
    final calls = <String>[];
    final scheduler = ProbeScheduler(
      runProbe: (reason) async {
        calls.add(reason);
      },
    );

    scheduler.request('event');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event']);
    expect(scheduler.isRunning, isFalse);
  });

  test('coalesces rapid requests while a probe is running', () async {
    final calls = <String>[];
    final completer = Completer<void>();
    final scheduler = ProbeScheduler(
      runProbe: (reason) async {
        calls.add(reason);
        if (calls.length == 1) {
          await completer.future;
        }
      },
    );

    scheduler.request('event');
    scheduler.request('event');
    scheduler.request('fallback');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event']);

    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event', 'pending']);
    expect(scheduler.isRunning, isFalse);
  });

  test('reports probe errors and still drains one pending request', () async {
    final calls = <String>[];
    final errors = <Object>[];
    final completer = Completer<void>();
    final scheduler = ProbeScheduler(
      runProbe: (reason) async {
        calls.add(reason);
        if (calls.length == 1) {
          await completer.future;
          throw StateError('probe failed');
        }
      },
      onError: (error, stackTrace) {
        errors.add(error);
      },
    );

    scheduler.request('event');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    scheduler.request('fallback');

    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event', 'pending']);
    expect(errors, hasLength(1));
    expect(errors.single, isA<StateError>());
    expect(scheduler.isRunning, isFalse);
  });
}
