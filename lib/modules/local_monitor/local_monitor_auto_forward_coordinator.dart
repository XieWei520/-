import 'dart:async';

abstract class LocalMonitorAutoForwardRunnerController {
  void start();
  void stop();
  void dispose();
}

typedef LocalMonitorAutoForwardRunnerLoader =
    Future<List<LocalMonitorAutoForwardRunnerController>> Function();

class LocalMonitorAutoForwardCoordinator {
  LocalMonitorAutoForwardCoordinator({
    List<LocalMonitorAutoForwardRunnerController>? runners,
    LocalMonitorAutoForwardRunnerLoader? loadRunners,
  }) : assert(
         runners != null || loadRunners != null,
         'Either runners or loadRunners must be provided.',
       ),
       _runners = runners == null
           ? null
           : List<LocalMonitorAutoForwardRunnerController>.unmodifiable(
               runners,
             ),
       _loadRunners = loadRunners;

  final LocalMonitorAutoForwardRunnerLoader? _loadRunners;
  List<LocalMonitorAutoForwardRunnerController>? _runners;
  Future<void>? _loadFuture;
  bool _disposed = false;
  bool _shouldRun = false;

  void syncLoggedIn(bool isLoggedIn) {
    if (_disposed) {
      return;
    }
    _shouldRun = isLoggedIn;
    if (!isLoggedIn) {
      _stopRunners();
      return;
    }

    final runners = _runners;
    if (runners != null) {
      _startRunners(runners);
      return;
    }

    final loadRunners = _loadRunners;
    if (loadRunners == null) {
      return;
    }
    _loadFuture ??= _loadAndSyncRunners(loadRunners);
    unawaited(_loadFuture);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final runners = _runners;
    if (runners == null) {
      return;
    }
    for (final runner in runners) {
      runner.dispose();
    }
  }

  Future<void> _loadAndSyncRunners(
    LocalMonitorAutoForwardRunnerLoader loadRunners,
  ) async {
    List<LocalMonitorAutoForwardRunnerController> runners;
    try {
      runners = List<LocalMonitorAutoForwardRunnerController>.unmodifiable(
        await loadRunners(),
      );
    } catch (_) {
      if (!_disposed) {
        _loadFuture = null;
      }
      return;
    }

    if (_disposed) {
      for (final runner in runners) {
        runner.dispose();
      }
      return;
    }

    _runners = runners;
    if (_shouldRun) {
      _startRunners(runners);
    }
  }

  void _startRunners(List<LocalMonitorAutoForwardRunnerController> runners) {
    for (final runner in runners) {
      runner.start();
    }
  }

  void _stopRunners() {
    final runners = _runners;
    if (runners == null) {
      return;
    }
    for (final runner in runners) {
      runner.stop();
    }
  }
}
