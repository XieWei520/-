import '../../wk_foundation/logging/app_logger.dart';

typedef StartupCallback = Future<void> Function();

class AppStartupStep {
  const AppStartupStep(this.label, this.run);

  final String label;
  final StartupCallback run;
}

class AppStartupRunner {
  AppStartupRunner({
    required List<AppStartupStep> steps,
    required AppLogger logger,
  })  : _steps = List<AppStartupStep>.unmodifiable(steps),
        _logger = logger;

  final List<AppStartupStep> _steps;
  final AppLogger _logger;
  Future<void>? _inFlight;
  Future<void>? _failedFuture;
  bool _completed = false;

  Future<void> ensureStarted() {
    if (_completed) {
      return Future<void>.value();
    }
    final failedFuture = _failedFuture;
    if (failedFuture != null) {
      return failedFuture;
    }
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _run();
    _inFlight = future;
    return future;
  }

  Future<void> _run() async {
    try {
      for (final step in _steps) {
        _logger.info('startup:${step.label}');
        await step.run();
      }
      _completed = true;
    } catch (error, stackTrace) {
      final StackTrace trace = stackTrace;
      _failedFuture = Future<void>.error(error, trace);
      _logger.error('startup failed', error, trace);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}
