import 'dart:async';

import 'package:wukong_im_app/modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

import 'mengxia_monitor_forwarding_service.dart';
import 'mengxia_monitor_shell_client.dart';
import 'mengxia_monitor_shell_models.dart';

class MengxiaMonitorAutoForwardRunner
    implements LocalMonitorAutoForwardRunnerController {
  MengxiaMonitorAutoForwardRunner({
    MengxiaMonitorShellClient? client,
    MengxiaMonitorForwardingService? forwardingService,
    MengxiaMonitorForwardingSettingsStore? forwardingSettingsStore,
    Duration interval = const Duration(seconds: 1),
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _client = client ?? MengxiaMonitorShellClient(),
       _forwardingService =
           forwardingService ?? MengxiaMonitorForwardingService(),
       _forwardingSettingsStore =
           forwardingSettingsStore ??
           const SharedPreferencesMengxiaMonitorForwardingSettingsStore(),
       _interval = interval,
       _clock = clock ?? DateTime.now,
       _onError = onError;

  final MengxiaMonitorShellClient _client;
  final MengxiaMonitorForwardingService _forwardingService;
  final MengxiaMonitorForwardingSettingsStore _forwardingSettingsStore;
  final Duration _interval;
  final DateTime Function() _clock;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  Timer? _timer;
  bool _running = false;
  bool _started = false;
  bool _primed = false;
  DateTime? _startedAt;

  Duration get interval => _interval;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _primed = false;
    _startedAt = _clock().toUtc();
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
  }

  @override
  void dispose() {
    stop();
  }

  Future<MengxiaMonitorForwardingResult?> runOnce({
    bool primeIfNeeded = false,
  }) {
    return _runOnce(primeIfNeeded: primeIfNeeded);
  }

  Future<MengxiaMonitorForwardingResult?> _runOnce({
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
      if (!status.isOnline || !status.isCapturing || status.needsManualLogin) {
        return null;
      }

      final recentEvents = status.recentEvents
          .where((event) => event.isForwardable)
          .toList(growable: false);
      if (recentEvents.isEmpty) {
        if (primeIfNeeded) {
          _primed = true;
        }
        return null;
      }

      if (primeIfNeeded && !_primed) {
        final split =
            splitLocalMonitorStartupEvents<MengxiaMonitorMessageEvent>(
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

      return _forwardingService.forwardRoutedRecentEvents(
        settings: settings,
        events: recentEvents,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _runOnceGuarded({required bool primeIfNeeded}) async {
    try {
      await _runOnce(primeIfNeeded: primeIfNeeded);
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }

  Future<void> _syncConfiguredSources(
    List<MengxiaMonitorForwardingRoute> routes,
  ) async {
    try {
      await _client.syncConfiguredSources(
        routes
            .where(
              (route) =>
                  route.enabled &&
                  route.targetGroupId.trim().isNotEmpty &&
                  route.sourceConversationId.trim().isNotEmpty,
            )
            .map(
              (route) => MengxiaMonitorRoutingSource(
                conversationId: route.sourceConversationId,
                conversationName: route.sourceConversationName,
              ),
            ),
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
    }
  }
}
