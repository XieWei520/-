import 'dart:async';

import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

import 'xiaoe_monitor_forwarding_service.dart';
import 'xiaoe_monitor_shell_client.dart';
import 'xiaoe_monitor_shell_models.dart';

class XiaoeMonitorAutoForwardRunner
    implements LocalMonitorAutoForwardRunnerController {
  XiaoeMonitorAutoForwardRunner({
    XiaoeMonitorShellClient? client,
    XiaoeMonitorForwardingService? forwardingService,
    XiaoeMonitorForwardingSettingsStore? forwardingSettingsStore,
    Duration interval = const Duration(seconds: 1),
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _client = client ?? XiaoeMonitorShellClient(),
       _forwardingService =
           forwardingService ?? XiaoeMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesXiaoeMonitorForwardingSettingsStore(),
       _interval = interval,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  final XiaoeMonitorShellClient _client;
  final XiaoeMonitorForwardingService _forwardingService;
  final XiaoeMonitorForwardingSettingsStore _forwardingSettingsStore;
  final Duration _interval;
  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  Timer? _timer;
  StreamSubscription<XiaoeMonitorShellEvent>? _eventSubscription;
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

  Future<XiaoeMonitorForwardingResult?> runOnce({bool primeIfNeeded = false}) {
    return _runOnce(primeIfNeeded: primeIfNeeded);
  }

  Future<XiaoeMonitorForwardingResult?> _runOnce({
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
    Iterable<XiaoeMonitorForwardingRoute> routes,
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
              (route) => XiaoeMonitorRoutingSource(
                conversationId: route.sourceConversationId,
                conversationName: route.sourceConversationName,
              ),
            ),
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  List<XiaoeMonitorMessageEvent> _forwardableRecentEvents(
    XiaoeMonitorShellStatus status,
  ) {
    return mergeLocalMonitorStatusEvents<
      XiaoeMonitorShellStatus,
      XiaoeMonitorMessageEvent
    >(
      statuses: <XiaoeMonitorShellStatus>[status],
      isStatusForwardable: (status) => status.isOnline && status.isCapturing,
      eventsForStatus: (status) => status.recentEvents,
      dedupeKeyForEvent: _dedupeKeyFor,
      includeEvent: _isForwardableEvent,
    );
  }

  bool _isForwardableEvent(XiaoeMonitorMessageEvent event) {
    return event.isForwardableText ||
        event.hasImageAttachments ||
        event.hasFileAttachments;
  }

  String _dedupeKeyFor(XiaoeMonitorMessageEvent event) {
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
