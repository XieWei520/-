import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';

void main() {
  test('syncLoggedIn starts every runner when logged in', () {
    final feishu = _FakeRunner();
    final dingtalk = _FakeRunner();
    final coordinator = LocalMonitorAutoForwardCoordinator(
      runners: <LocalMonitorAutoForwardRunnerController>[feishu, dingtalk],
    );

    coordinator.syncLoggedIn(true);

    expect(feishu.startCount, 1);
    expect(dingtalk.startCount, 1);
    expect(feishu.stopCount, 0);
    expect(dingtalk.stopCount, 0);
  });

  test('syncLoggedIn stops every runner when logged out', () {
    final feishu = _FakeRunner();
    final dingtalk = _FakeRunner();
    final coordinator = LocalMonitorAutoForwardCoordinator(
      runners: <LocalMonitorAutoForwardRunnerController>[feishu, dingtalk],
    );

    coordinator.syncLoggedIn(false);

    expect(feishu.stopCount, 1);
    expect(dingtalk.stopCount, 1);
    expect(feishu.startCount, 0);
    expect(dingtalk.startCount, 0);
  });

  test('dispose disposes every runner and ignores later sync requests', () {
    final feishu = _FakeRunner();
    final dingtalk = _FakeRunner();
    final coordinator = LocalMonitorAutoForwardCoordinator(
      runners: <LocalMonitorAutoForwardRunnerController>[feishu, dingtalk],
    );

    coordinator.dispose();
    coordinator.syncLoggedIn(true);

    expect(feishu.disposeCount, 1);
    expect(dingtalk.disposeCount, 1);
    expect(feishu.startCount, 0);
    expect(dingtalk.startCount, 0);
  });

  test('lazy loader waits until logged in before creating runners', () {
    var loadCalls = 0;
    final coordinator = LocalMonitorAutoForwardCoordinator(
      loadRunners: () async {
        loadCalls += 1;
        return <LocalMonitorAutoForwardRunnerController>[_FakeRunner()];
      },
    );

    coordinator.syncLoggedIn(false);

    expect(loadCalls, 0);
  });

  test('lazy loader starts loaded runners after login', () async {
    final runner = _FakeRunner();
    var loadCalls = 0;
    final coordinator = LocalMonitorAutoForwardCoordinator(
      loadRunners: () async {
        loadCalls += 1;
        return <LocalMonitorAutoForwardRunnerController>[runner];
      },
    );

    coordinator.syncLoggedIn(true);
    await Future<void>.delayed(Duration.zero);

    expect(loadCalls, 1);
    expect(runner.startCount, 1);
    expect(runner.stopCount, 0);
  });

  test('lazy loader does not start runners after logout race', () async {
    final completer =
        Completer<List<LocalMonitorAutoForwardRunnerController>>();
    final runner = _FakeRunner();
    final coordinator = LocalMonitorAutoForwardCoordinator(
      loadRunners: () => completer.future,
    );

    coordinator.syncLoggedIn(true);
    coordinator.syncLoggedIn(false);
    completer.complete(<LocalMonitorAutoForwardRunnerController>[runner]);
    await Future<void>.delayed(Duration.zero);

    expect(runner.startCount, 0);

    coordinator.syncLoggedIn(true);

    expect(runner.startCount, 1);
  });

  test(
    'lazy loader disposes runners loaded after coordinator dispose',
    () async {
      final completer =
          Completer<List<LocalMonitorAutoForwardRunnerController>>();
      final runner = _FakeRunner();
      final coordinator = LocalMonitorAutoForwardCoordinator(
        loadRunners: () => completer.future,
      );

      coordinator.syncLoggedIn(true);
      coordinator.dispose();
      completer.complete(<LocalMonitorAutoForwardRunnerController>[runner]);
      await Future<void>.delayed(Duration.zero);

      expect(runner.startCount, 0);
      expect(runner.disposeCount, 1);
    },
  );
}

class _FakeRunner implements LocalMonitorAutoForwardRunnerController {
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  void start() {
    startCount += 1;
  }

  @override
  void stop() {
    stopCount += 1;
  }

  @override
  void dispose() {
    disposeCount += 1;
  }
}
