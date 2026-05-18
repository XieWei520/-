import 'dart:async';

import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

import 'feishu_monitor_forwarding_service.dart';
import 'feishu_monitor_shell_client.dart';
import 'feishu_monitor_shell_models.dart';

class FeishuMonitorAutoForwardRunner
    implements LocalMonitorAutoForwardRunnerController {
  FeishuMonitorAutoForwardRunner({
    FeishuMonitorShellClient? client,
    FeishuMonitorShellClientGroup? clientGroup,
    FeishuMonitorForwardingService? forwardingService,
    FeishuMonitorForwardingSettingsStore? forwardingSettingsStore,
    Duration interval = const Duration(seconds: 1),
    Duration eventReconnectDelay = const Duration(seconds: 1),
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _clientGroup =
           clientGroup ??
           FeishuMonitorShellClientGroup.single(
             client ?? FeishuMonitorShellClient(),
           ),
       _forwardingService =
           forwardingService ?? FeishuMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesFeishuMonitorForwardingSettingsStore(),
       _interval = interval,
       _eventReconnectDelay = eventReconnectDelay,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  final FeishuMonitorShellClientGroup _clientGroup;
  final FeishuMonitorForwardingService _forwardingService;
  final FeishuMonitorForwardingSettingsStore _forwardingSettingsStore;
  final Duration _interval;
  final Duration _eventReconnectDelay;
  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  Timer? _timer;
  final Map<FeishuMonitorShellClient, Timer> _eventReconnectTimers =
      <FeishuMonitorShellClient, Timer>{};
  final Map<
    FeishuMonitorShellClient,
    StreamSubscription<FeishuMonitorShellEvent>
  >
  _eventSubscriptions =
      <FeishuMonitorShellClient, StreamSubscription<FeishuMonitorShellEvent>>{};
  bool _running = false;
  bool _started = false;
  bool _primed = false;
  bool _snapshotUpdateObserved = false;
  int _eventGeneration = 0;
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
    _eventGeneration += 1;
    _startedAt = _clock().toUtc();
    unawaited(_runOnceGuarded(primeIfNeeded: true));
    _timer = Timer.periodic(_interval, (_) {
      unawaited(_runOnceGuarded());
    });
    _subscribeToEvents(_eventGeneration);
  }

  @override
  void stop() {
    _started = false;
    _primed = false;
    _snapshotUpdateObserved = false;
    _eventGeneration += 1;
    _startedAt = null;
    _timer?.cancel();
    _timer = null;
    for (final timer in _eventReconnectTimers.values) {
      timer.cancel();
    }
    _eventReconnectTimers.clear();
    for (final subscription in _eventSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _eventSubscriptions.clear();
  }

  @override
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
      final assignedWorkerIds = _clientGroup.workerIdsForRoutes(
        settings.routes,
      );
      await _syncConfiguredMediaSources(settings.routes);
      final statuses = await _clientGroup.fetchStatuses(
        workerIds: assignedWorkerIds,
        onError: _onError,
      );
      final recentEvents = _mergeForwardableRecentEvents(statuses);
      if (primeIfNeeded && !_primed && !_snapshotUpdateObserved) {
        if (recentEvents.isEmpty) {
          return null;
        }
        final split = splitLocalMonitorStartupEvents(
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
          return null;
        }
        return _forwardingService.forwardRoutedRecentEvents(
          settings: settings,
          events: split.liveEvents,
        );
      }
      if (recentEvents.isEmpty) {
        return null;
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

  void _subscribeToEvents(int generation) {
    if (!_started || generation != _eventGeneration) {
      return;
    }
    for (final client in _clientGroup.clients) {
      _subscribeClientToEvents(client, generation);
    }
  }

  void _subscribeClientToEvents(
    FeishuMonitorShellClient client,
    int generation,
  ) {
    if (!_started ||
        generation != _eventGeneration ||
        _eventSubscriptions.containsKey(client)) {
      return;
    }
    try {
      late final StreamSubscription<FeishuMonitorShellEvent> subscription;
      subscription = client.watchEvents().listen(
        (event) {
          if (_started &&
              generation == _eventGeneration &&
              _eventSubscriptions[client] == subscription &&
              event.isSnapshotUpdated) {
            _snapshotUpdateObserved = true;
            unawaited(_runOnceGuarded());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _onError?.call(error, stackTrace);
          if (_eventSubscriptions[client] == subscription &&
              generation == _eventGeneration) {
            _eventSubscriptions.remove(client);
            _scheduleEventReconnect(client, generation);
          }
        },
        onDone: () {
          if (_eventSubscriptions[client] == subscription &&
              generation == _eventGeneration) {
            _eventSubscriptions.remove(client);
            _scheduleEventReconnect(client, generation);
          }
        },
        cancelOnError: true,
      );
      _eventSubscriptions[client] = subscription;
    } catch (error, stackTrace) {
      if (generation == _eventGeneration) {
        _onError?.call(error, stackTrace);
        _eventSubscriptions.remove(client);
        _scheduleEventReconnect(client, generation);
      }
    }
  }

  void _scheduleEventReconnect(
    FeishuMonitorShellClient client,
    int generation,
  ) {
    if (!_started ||
        generation != _eventGeneration ||
        _eventReconnectTimers.containsKey(client)) {
      return;
    }

    _eventReconnectTimers[client] = Timer(_eventReconnectDelay, () {
      if (generation == _eventGeneration) {
        _eventReconnectTimers.remove(client);
        _subscribeClientToEvents(client, generation);
      }
    });
  }

  Future<void> _syncConfiguredMediaSources(
    List<FeishuMonitorForwardingRoute> routes,
  ) async {
    try {
      await _clientGroup.syncConfiguredMediaSources(routes);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  List<FeishuMonitorMessageEvent> _mergeForwardableRecentEvents(
    List<FeishuMonitorShellStatus> statuses,
  ) {
    return mergeLocalMonitorStatusEvents<
      FeishuMonitorShellStatus,
      FeishuMonitorMessageEvent
    >(
      statuses: statuses,
      isStatusForwardable: (status) => status.isOnline && status.isCapturing,
      eventsForStatus: (status) => status.recentEvents,
      dedupeKeyForEvent: _dedupeKeyFor,
      includeEvent: (event) => !_isStaleStartupNetworkImage(event),
    );
  }

  bool _isStaleStartupNetworkImage(FeishuMonitorMessageEvent event) {
    if (event.captureSource.trim() != 'network_original_image') {
      return false;
    }
    final startedAt = _startedAt;
    final observedAt = event.observedAt;
    if (startedAt == null || observedAt == null) {
      return false;
    }
    return observedAt.toUtc().isBefore(startedAt);
  }

  String _dedupeKeyFor(FeishuMonitorMessageEvent event) {
    return localMonitorMessageDedupeKey(
      dedupeKey: event.dedupeKey,
      eventId: event.eventId,
    );
  }
}
