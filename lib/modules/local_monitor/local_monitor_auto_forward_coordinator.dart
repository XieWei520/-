abstract class LocalMonitorAutoForwardRunnerController {
  void start();
  void stop();
  void dispose();
}

class LocalMonitorAutoForwardCoordinator {
  LocalMonitorAutoForwardCoordinator({
    required List<LocalMonitorAutoForwardRunnerController> runners,
  }) : _runners = List<LocalMonitorAutoForwardRunnerController>.unmodifiable(
         runners,
       );

  final List<LocalMonitorAutoForwardRunnerController> _runners;
  bool _disposed = false;

  void syncLoggedIn(bool isLoggedIn) {
    if (_disposed) {
      return;
    }
    for (final runner in _runners) {
      if (isLoggedIn) {
        runner.start();
      } else {
        runner.stop();
      }
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final runner in _runners) {
      runner.dispose();
    }
  }
}
