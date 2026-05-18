import 'dart:async';

import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

import 'dingtalk_monitor_auto_forward_diagnostics.dart';
import 'dingtalk_monitor_forwarding_service.dart';
import 'dingtalk_monitor_shell_client.dart';
import 'dingtalk_monitor_shell_models.dart';

class DingTalkMonitorAutoForwardRunner
    implements LocalMonitorAutoForwardRunnerController {
  DingTalkMonitorAutoForwardRunner({
    DingTalkMonitorShellClient? client,
    DingTalkMonitorForwardingService? forwardingService,
    DingTalkMonitorForwardingSettingsStore? forwardingSettingsStore,
    DingTalkMonitorAutoForwardDiagnosticsStore? diagnosticsStore,
    Duration interval = const Duration(seconds: 1),
    bool activeProbeEnabled = false,
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _client = client ?? DingTalkMonitorShellClient(),
       _forwardingService =
           forwardingService ?? DingTalkMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesDingTalkMonitorForwardingSettingsStore(),
       _diagnosticsStore =
           diagnosticsStore ??
           const FileDingTalkMonitorAutoForwardDiagnosticsStore(),
       _interval = interval,
       _activeProbeEnabled = activeProbeEnabled,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  final DingTalkMonitorShellClient _client;
  final DingTalkMonitorForwardingService _forwardingService;
  final DingTalkMonitorForwardingSettingsStore _forwardingSettingsStore;
  final DingTalkMonitorAutoForwardDiagnosticsStore _diagnosticsStore;
  final Duration _interval;
  final bool _activeProbeEnabled;
  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  Timer? _timer;
  bool _running = false;
  bool _started = false;
  bool _primed = false;
  int _runCount = 0;
  int _sessionSent = 0;
  int _sessionFailed = 0;
  DateTime? _lastSentAt;
  DateTime? _lastFailureAt;
  DateTime? _startedAt;

  Duration get interval => _interval;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _primed = false;
    _runCount = 0;
    _sessionSent = 0;
    _sessionFailed = 0;
    _lastSentAt = null;
    _lastFailureAt = null;
    _startedAt = _clock().toUtc();
    unawaited(_saveDiagnostics(state: 'started'));
    unawaited(_runOnceGuarded(primeIfNeeded: true));
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runOnceGuarded(primeIfNeeded: true));
    });
  }

  @override
  void stop() {
    _started = false;
    _primed = false;
    _startedAt = null;
    _timer?.cancel();
    _timer = null;
    unawaited(_saveDiagnostics(state: 'stopped'));
  }

  @override
  void dispose() {
    stop();
  }

  Future<DingTalkMonitorForwardingResult?> runOnce({
    bool primeIfNeeded = false,
  }) {
    return _runOnce(primeIfNeeded: primeIfNeeded);
  }

  Future<DingTalkMonitorForwardingResult?> _runOnce({
    required bool primeIfNeeded,
  }) async {
    if (_running) {
      return null;
    }
    _running = true;
    _runCount += 1;
    DingTalkMonitorForwardingSettings? settings;
    DingTalkMonitorShellStatus? status;
    List<DingTalkMonitorMessageEvent> recentEvents =
        const <DingTalkMonitorMessageEvent>[];
    try {
      settings = await _forwardingSettingsStore.load();
      if (!settings.enabled ||
          settings.routes.every(
            (route) => !route.enabled || route.targetGroupId.trim().isEmpty,
          )) {
        await _saveDiagnostics(state: 'skipped-settings', settings: settings);
        return null;
      }

      status = await _client.fetchStatus();
      if (!status.isOnline || !status.isCapturing) {
        status = await _restartHostCapture();
      }
      if (!status.isOnline || !status.isCapturing) {
        await _saveDiagnostics(
          state: 'skipped-host',
          settings: settings,
          status: status,
        );
        return null;
      }

      if (_activeProbeEnabled && (!primeIfNeeded || _primed)) {
        await _probeLatestBestEffort();
      }

      final rawRecentEvents = await _client.fetchForwardableRecentEvents();
      recentEvents = rawRecentEvents
          .where((event) => event.isForwardableText)
          .toList(growable: false);
      if (recentEvents.isEmpty) {
        if (primeIfNeeded) {
          _primed = true;
        }
        await _saveDiagnostics(
          state: 'skipped-empty',
          settings: settings,
          status: status,
          recentEvents: rawRecentEvents,
        );
        return null;
      }

      if (primeIfNeeded && !_primed) {
        final split =
            splitLocalMonitorStartupEvents<DingTalkMonitorMessageEvent>(
              events: recentEvents,
              startedAt: _startedAt,
              observedAtForEvent: (event) => event.observedAt,
            );
        if (split.startupEvents.isNotEmpty) {
          await _forwardingService.primeRoutedRecentEvents(
            settings: settings,
            events: split.startupEvents,
          );
        }
        _primed = true;
        if (split.liveEvents.isEmpty) {
          await _saveDiagnostics(
            state: 'primed',
            settings: settings,
            status: status,
            recentEvents: rawRecentEvents,
            startupEventCount: split.startupEvents.length,
            liveEventCount: split.liveEvents.length,
          );
          return null;
        }
        final result = await _forwardingService.forwardRoutedRecentEvents(
          settings: settings,
          events: split.liveEvents,
        );
        _recordForwardingResult(result);
        await _saveDiagnostics(
          state: 'completed',
          settings: settings,
          status: status,
          recentEvents: rawRecentEvents,
          result: result,
          startupEventCount: split.startupEvents.length,
          liveEventCount: split.liveEvents.length,
        );
        return result;
      }

      final result = await _forwardingService.forwardRoutedRecentEvents(
        settings: settings,
        events: recentEvents,
      );
      _recordForwardingResult(result);
      await _saveDiagnostics(
        state: 'completed',
        settings: settings,
        status: status,
        recentEvents: rawRecentEvents,
        result: result,
      );
      return result;
    } catch (error) {
      _sessionFailed += 1;
      _lastFailureAt = _clock().toUtc();
      await _saveDiagnostics(
        state: 'error',
        settings: settings,
        status: status,
        recentEvents: recentEvents,
        error: error,
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  Future<DingTalkMonitorShellStatus> _restartHostCapture() async {
    await _client.startCapture();
    return _client.fetchStatus();
  }

  Future<void> _runOnceGuarded({required bool primeIfNeeded}) async {
    try {
      await _runOnce(primeIfNeeded: primeIfNeeded);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  Future<void> _probeLatestBestEffort() async {
    try {
      await _client.probeLatest();
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  void _recordForwardingResult(DingTalkMonitorForwardingResult result) {
    final now = _clock().toUtc();
    if (result.sent > 0) {
      _sessionSent += result.sent;
      _lastSentAt = now;
    }
    if (result.failed > 0) {
      _sessionFailed += result.failed;
      _lastFailureAt = now;
    }
  }

  Future<void> _saveDiagnostics({
    required String state,
    DingTalkMonitorForwardingSettings? settings,
    DingTalkMonitorShellStatus? status,
    List<DingTalkMonitorMessageEvent> recentEvents =
        const <DingTalkMonitorMessageEvent>[],
    DingTalkMonitorForwardingResult? result,
    Object? error,
    int startupEventCount = 0,
    int liveEventCount = 0,
  }) async {
    try {
      await _diagnosticsStore.save(
        buildDingTalkMonitorAutoForwardDiagnosticsSnapshot(
          updatedAt: _clock().toUtc(),
          state: state,
          settings: settings,
          status: status,
          recentEvents: recentEvents,
          result: result,
          error: error,
          runCount: _runCount,
          primed: _primed,
          startupEventCount: startupEventCount,
          liveEventCount: liveEventCount,
          sessionSent: _sessionSent,
          sessionFailed: _sessionFailed,
          lastSentAt: _lastSentAt,
          lastFailureAt: _lastFailureAt,
        ),
      );
    } catch (diagnosticError, stackTrace) {
      _onError?.call(diagnosticError, stackTrace);
    }
  }
}
