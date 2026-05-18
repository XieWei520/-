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
