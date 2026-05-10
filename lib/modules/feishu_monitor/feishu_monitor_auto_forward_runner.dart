import 'dart:async';

import 'feishu_monitor_forwarding_service.dart';
import 'feishu_monitor_shell_client.dart';
import 'feishu_monitor_shell_models.dart';

class FeishuMonitorAutoForwardRunner {
  FeishuMonitorAutoForwardRunner({
    FeishuMonitorShellClient? client,
    FeishuMonitorForwardingService? forwardingService,
    FeishuMonitorForwardingSettingsStore? forwardingSettingsStore,
    Duration interval = const Duration(seconds: 1),
    Duration eventReconnectDelay = const Duration(seconds: 1),
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _client = client ?? FeishuMonitorShellClient(),
       _forwardingService =
           forwardingService ?? FeishuMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesFeishuMonitorForwardingSettingsStore(),
       _interval = interval,
       _eventReconnectDelay = eventReconnectDelay,
       _onError = onError;

  final FeishuMonitorShellClient _client;
  final FeishuMonitorForwardingService _forwardingService;
  final FeishuMonitorForwardingSettingsStore _forwardingSettingsStore;
  final Duration _interval;
  final Duration _eventReconnectDelay;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  Timer? _timer;
  Timer? _eventReconnectTimer;
  StreamSubscription<FeishuMonitorShellEvent>? _eventSubscription;
  bool _running = false;
  bool _started = false;
  bool _primed = false;
  int _eventGeneration = 0;

  Duration get interval => _interval;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _primed = false;
    _eventGeneration += 1;
    unawaited(_runOnceGuarded(primeIfNeeded: true));
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runOnceGuarded());
    });
    _subscribeToEvents(_eventGeneration);
  }

  void stop() {
    _started = false;
    _primed = false;
    _eventGeneration += 1;
    _timer?.cancel();
    _timer = null;
    _eventReconnectTimer?.cancel();
    _eventReconnectTimer = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }

  void dispose() {
    stop();
  }

  Future<FeishuMonitorForwardingResult?> runOnce() async {
    return _runOnce(primeIfNeeded: false);
  }

  Future<FeishuMonitorForwardingResult?> _runOnce({
    required bool primeIfNeeded,
  }) async {
    if (_running) {
      return null;
    }
    _running = true;
    try {
      final settings = await _forwardingSettingsStore.load();
      if (!settings.enabled ||
          settings.routes.every(
            (route) => !route.enabled || route.targetGroupId.trim().isEmpty,
          )) {
        return null;
      }
      final status = await _client.fetchStatus();
      if (!status.isOnline || !status.isCapturing) {
        return null;
      }
      if (status.recentEvents.isEmpty) {
        return null;
      }
      if (_started && !_primed) {
        await _forwardingService.primeRoutedRecentEvents(
          settings: settings,
          events: status.recentEvents,
        );
        _primed = true;
        return null;
      }
      return _forwardingService.forwardRoutedRecentEvents(
        settings: settings,
        events: status.recentEvents,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnceGuarded({bool primeIfNeeded = false}) async {
    try {
      await _runOnce(primeIfNeeded: primeIfNeeded);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  void _subscribeToEvents(int generation) {
    if (!_started ||
        generation != _eventGeneration ||
        _eventSubscription != null) {
      return;
    }

    try {
      late final StreamSubscription<FeishuMonitorShellEvent> subscription;
      subscription = _client.watchEvents().listen(
        (event) {
          if (_started &&
              generation == _eventGeneration &&
              _eventSubscription == subscription &&
              event.isSnapshotUpdated) {
            unawaited(_runOnceGuarded());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _onError?.call(error, stackTrace);
          if (_eventSubscription == subscription &&
              generation == _eventGeneration) {
            _eventSubscription = null;
            _scheduleEventReconnect(generation);
          }
        },
        onDone: () {
          if (_eventSubscription == subscription &&
              generation == _eventGeneration) {
            _eventSubscription = null;
            _scheduleEventReconnect(generation);
          }
        },
        cancelOnError: true,
      );
      _eventSubscription = subscription;
    } catch (error, stackTrace) {
      if (generation == _eventGeneration) {
        _onError?.call(error, stackTrace);
        _eventSubscription = null;
        _scheduleEventReconnect(generation);
      }
    }
  }

  void _scheduleEventReconnect(int generation) {
    if (!_started ||
        generation != _eventGeneration ||
        _eventReconnectTimer != null) {
      return;
    }

    _eventReconnectTimer = Timer(_eventReconnectDelay, () {
      if (generation == _eventGeneration) {
        _eventReconnectTimer = null;
        _subscribeToEvents(generation);
      }
    });
  }
}
