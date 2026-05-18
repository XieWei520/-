import 'dart:async';

import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

import 'juliang_monitor_forwarding_service.dart';
import 'juliang_monitor_shell_client.dart';
import 'juliang_monitor_shell_models.dart';

class JuliangMonitorAutoForwardRunner
    implements LocalMonitorAutoForwardRunnerController {
  JuliangMonitorAutoForwardRunner({
    JuliangMonitorShellClient? client,
    JuliangMonitorForwardingService? forwardingService,
    JuliangMonitorForwardingSettingsStore? forwardingSettingsStore,
    Duration interval = const Duration(seconds: 1),
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _client = client ?? JuliangMonitorShellClient(),
       _forwardingService =
           forwardingService ?? JuliangMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesJuliangMonitorForwardingSettingsStore(),
       _interval = interval,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  final JuliangMonitorShellClient _client;
  final JuliangMonitorForwardingService _forwardingService;
  final JuliangMonitorForwardingSettingsStore _forwardingSettingsStore;
  final Duration _interval;
  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  Timer? _timer;
  StreamSubscription<JuliangMonitorShellEvent>? _eventSubscription;
  bool _running = false;
  bool _started = false;
  bool _primed = false;
  bool _snapshotUpdateObserved = false;
  DateTime? _startedAt;

  Duration get interval => _interval;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _primed = false;
    _snapshotUpdateObserved = false;
    _startedAt = _clock().toUtc();
    unawaited(_runOnceGuarded(primeIfNeeded: true));
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runOnceGuarded());
    });
    _subscribeToEvents();
  }

  @override
  void stop() {
    _started = false;
    _primed = false;
    _snapshotUpdateObserved = false;
    _startedAt = null;
    _timer?.cancel();
    _timer = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }

  @override
  void dispose() {
    stop();
  }

  Future<JuliangMonitorForwardingResult?> runOnce({
    bool primeIfNeeded = false,
  }) {
    return _runOnce(primeIfNeeded: primeIfNeeded);
  }

  Future<JuliangMonitorForwardingResult?> _runOnce({
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
      await _syncConfiguredSources(settings.routes);
      final status = await _client.fetchStatus();
      if (!status.isOnline || !status.isCapturing) {
        return null;
      }
      final recentEvents = _forwardableRecentEvents(status);
      if (recentEvents.isEmpty) {
        if (primeIfNeeded) {
          _primed = true;
        }
        return null;
      }
      if (primeIfNeeded && !_primed && !_snapshotUpdateObserved) {
        final startedAt = _startedAt ?? _clock().toUtc();
        final split = splitLocalMonitorStartupEvents(
          events: recentEvents,
          startedAt: startedAt,
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
          return null;
        }
        return _forwardingService.forwardRoutedRecentEvents(
          settings: settings,
          events: split.liveEvents,
        );
      }
      return _forwardingService.forwardRoutedRecentEvents(
        settings: settings,
        events: recentEvents,
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

  Future<void> _syncConfiguredSources(
    Iterable<JuliangMonitorForwardingRoute> routes,
  ) async {
    try {
      await _client.syncConfiguredSources(
        routes
            .where(
              (route) =>
                  route.enabled &&
                  route.targetGroupId.trim().isNotEmpty &&
                  (route.sourceConversationId.trim().isNotEmpty ||
                      route.sourceConversationName.trim().isNotEmpty),
            )
            .map(
              (route) => JuliangMonitorRoutingSource(
                conversationId: route.sourceConversationId,
                conversationName: route.sourceConversationName,
              ),
            ),
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  List<JuliangMonitorMessageEvent> _forwardableRecentEvents(
    JuliangMonitorShellStatus status,
  ) {
    return mergeLocalMonitorStatusEvents<
      JuliangMonitorShellStatus,
      JuliangMonitorMessageEvent
    >(
      statuses: <JuliangMonitorShellStatus>[status],
      isStatusForwardable: (status) => status.isOnline && status.isCapturing,
      eventsForStatus: (status) => status.recentEvents,
      dedupeKeyForEvent: _dedupeKeyFor,
      includeEvent: (event) => event.isForwardableText,
    );
  }

  String _dedupeKeyFor(JuliangMonitorMessageEvent event) {
    return localMonitorMessageDedupeKey(
      dedupeKey: event.dedupeKey,
      eventId: event.eventId,
      messageId: event.messageId,
    );
  }

  void _subscribeToEvents() {
    try {
      _eventSubscription = _client.watchEvents().listen(
        (event) {
          if (_started && event.isSnapshotUpdated) {
            _snapshotUpdateObserved = true;
            unawaited(_runOnceGuarded());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _onError?.call(error, stackTrace);
        },
        cancelOnError: false,
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }
}
