import 'dart:async';

import '../../wk_foundation/logging/app_logger.dart';

typedef StartupCallback = Future<void> Function();
typedef StartupMetricCallback = void Function(AppStartupStepMetric metric);

class AppStartupStepMetric {
  const AppStartupStepMetric({
    required this.label,
    required this.background,
    required this.elapsed,
    required this.succeeded,
    this.error,
  });

  final String label;
  final bool background;
  final Duration elapsed;
  final bool succeeded;
  final Object? error;
}

class AppStartupStep {
  const AppStartupStep(this.label, this.run);

  final String label;
  final StartupCallback run;
}

class AppStartupRunner {
  AppStartupRunner({
    required List<AppStartupStep> steps,
    List<AppStartupStep> backgroundSteps = const <AppStartupStep>[],
    required AppLogger logger,
    StartupMetricCallback? onStepMetric,
  }) : _steps = List<AppStartupStep>.unmodifiable(steps),
       _backgroundSteps = List<AppStartupStep>.unmodifiable(backgroundSteps),
       _logger = logger,
       _onStepMetric = onStepMetric;

  final List<AppStartupStep> _steps;
  final List<AppStartupStep> _backgroundSteps;
  final AppLogger _logger;
  final StartupMetricCallback? _onStepMetric;
  Future<void>? _inFlight;
  Future<void>? _backgroundInFlight;
  Future<void>? _failedFuture;
  bool _completed = false;
  bool _backgroundCompleted = false;

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

  Future<void> ensureBackgroundStarted() {
    if (_backgroundCompleted || _backgroundSteps.isEmpty) {
      return Future<void>.value();
    }
    final inFlight = _backgroundInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runBackground();
    _backgroundInFlight = future;
    return future;
  }

  Future<void> _run() async {
    try {
      for (final step in _steps) {
        await _runStep(step, background: false);
      }
      _completed = true;
      unawaited(ensureBackgroundStarted());
    } catch (error, stackTrace) {
      final StackTrace trace = stackTrace;
      _failedFuture = Future<void>.error(error, trace);
      _logger.error('startup failed', error, trace);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _runBackground() async {
    try {
      for (final step in _backgroundSteps) {
        try {
          await _runStep(step, background: true);
        } catch (error, stackTrace) {
          _logger.error(
            'background startup step failed: ${step.label}',
            error,
            stackTrace,
          );
        }
      }
      _backgroundCompleted = true;
    } finally {
      _backgroundInFlight = null;
    }
  }

  Future<void> _runStep(AppStartupStep step, {required bool background}) async {
    final prefix = background ? 'startup:bg' : 'startup';
    _logger.info('$prefix:${step.label}');
    final stopwatch = Stopwatch()..start();
    try {
      await step.run();
      _recordMetric(
        step,
        background: background,
        elapsed: stopwatch.elapsed,
        succeeded: true,
      );
    } catch (error) {
      _recordMetric(
        step,
        background: background,
        elapsed: stopwatch.elapsed,
        succeeded: false,
        error: error,
      );
      rethrow;
    }
  }

  void _recordMetric(
    AppStartupStep step, {
    required bool background,
    required Duration elapsed,
    required bool succeeded,
    Object? error,
  }) {
    final onStepMetric = _onStepMetric;
    if (onStepMetric == null) {
      return;
    }
    onStepMetric(
      AppStartupStepMetric(
        label: step.label,
        background: background,
        elapsed: elapsed == Duration.zero
            ? const Duration(microseconds: 1)
            : elapsed,
        succeeded: succeeded,
        error: error,
      ),
    );
  }
}
