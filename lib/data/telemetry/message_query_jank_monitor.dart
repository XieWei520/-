import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../realtime/telemetry/realtime_rollout_telemetry.dart';

typedef MessageQueryTimingsCallbackRegistrar =
    void Function(TimingsCallback callback);

class MessageQueryFrameTiming {
  const MessageQueryFrameTiming({
    required this.buildDuration,
    required this.rasterDuration,
  });

  final Duration buildDuration;
  final Duration rasterDuration;
}

class MessageQueryJankMonitor {
  MessageQueryJankMonitor({
    required MessageQueryJankTelemetry telemetry,
    bool? enabled,
    this.buildThreshold = const Duration(milliseconds: 16),
    this.rasterThreshold = const Duration(milliseconds: 16),
    MessageQueryTimingsCallbackRegistrar? addTimingsCallback,
    MessageQueryTimingsCallbackRegistrar? removeTimingsCallback,
  }) : _telemetry = telemetry,
       _addTimingsCallback =
           addTimingsCallback ??
           ((callback) {
             SchedulerBinding.instance.addTimingsCallback(callback);
           }),
       _removeTimingsCallback =
           removeTimingsCallback ??
           ((callback) {
             SchedulerBinding.instance.removeTimingsCallback(callback);
           }),
       _enabled = enabled ?? !kReleaseMode;

  factory MessageQueryJankMonitor.forTesting({
    required MessageQueryJankTelemetry telemetry,
    required bool enabled,
    Duration buildThreshold = const Duration(milliseconds: 16),
    Duration rasterThreshold = const Duration(milliseconds: 16),
    required MessageQueryTimingsCallbackRegistrar addTimingsCallback,
    required MessageQueryTimingsCallbackRegistrar removeTimingsCallback,
  }) {
    return MessageQueryJankMonitor(
      telemetry: telemetry,
      enabled: enabled,
      buildThreshold: buildThreshold,
      rasterThreshold: rasterThreshold,
      addTimingsCallback: addTimingsCallback,
      removeTimingsCallback: removeTimingsCallback,
    );
  }

  final MessageQueryJankTelemetry _telemetry;
  final MessageQueryTimingsCallbackRegistrar _addTimingsCallback;
  final MessageQueryTimingsCallbackRegistrar _removeTimingsCallback;
  final bool _enabled;
  final Duration buildThreshold;
  final Duration rasterThreshold;

  bool _registered = false;
  TimingsCallback? _registeredCallback;

  bool get enabled => _enabled;

  void recordTimings(Iterable<MessageQueryFrameTiming> timings) {
    if (!_enabled) {
      return;
    }
    for (final timing in timings) {
      final buildDuration = timing.buildDuration > buildThreshold
          ? timing.buildDuration
          : null;
      final rasterDuration = timing.rasterDuration > rasterThreshold
          ? timing.rasterDuration
          : null;
      if (buildDuration == null && rasterDuration == null) {
        continue;
      }
      _telemetry.recordChatScrollJankFrame(
        buildDuration: buildDuration,
        rasterDuration: rasterDuration,
      );
    }
  }

  void register() {
    if (!_enabled || _registered) {
      return;
    }
    final callback = _handleFrameTimings;
    _registeredCallback = callback;
    _addTimingsCallback(callback);
    _registered = true;
  }

  void dispose() {
    final callback = _registeredCallback;
    if (!_registered || callback == null) {
      return;
    }
    _removeTimingsCallback(callback);
    _registeredCallback = null;
    _registered = false;
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    recordTimings(
      timings.map(
        (timing) => MessageQueryFrameTiming(
          buildDuration: timing.buildDuration,
          rasterDuration: timing.rasterDuration,
        ),
      ),
    );
  }
}
