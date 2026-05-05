import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry_provider.dart';

typedef ChatFrameTimingSampleReader =
    ChatFrameTimingSample Function(FrameTiming timing);

class ChatFrameTimingSample {
  const ChatFrameTimingSample({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalSpan,
  });

  factory ChatFrameTimingSample.fromFrameTiming(FrameTiming timing) {
    return ChatFrameTimingSample(
      buildDuration: timing.buildDuration,
      rasterDuration: timing.rasterDuration,
      totalSpan: timing.totalSpan,
    );
  }

  final Duration buildDuration;
  final Duration rasterDuration;
  final Duration totalSpan;
}

abstract class FrameTimingRegistrar {
  void addTimingsCallback(TimingsCallback callback);

  void removeTimingsCallback(TimingsCallback callback);
}

class SchedulerFrameTimingRegistrar implements FrameTimingRegistrar {
  const SchedulerFrameTimingRegistrar();

  @override
  void addTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.removeTimingsCallback(callback);
  }
}

final chatFrameTimingRegistrarProvider = Provider<FrameTimingRegistrar>((ref) {
  return const SchedulerFrameTimingRegistrar();
});

typedef ChatFrameJankMonitorFactory = ChatFrameJankMonitor Function();

final chatFrameJankMonitorFactoryProvider =
    Provider<ChatFrameJankMonitorFactory>((ref) {
      final telemetry = ref.watch(frameJankTelemetryProvider);
      final registrar = ref.watch(chatFrameTimingRegistrarProvider);
      return () =>
          ChatFrameJankMonitor(telemetry: telemetry, registrar: registrar);
    });

class ChatFrameJankMonitor {
  ChatFrameJankMonitor({
    required FrameJankTelemetry telemetry,
    required FrameTimingRegistrar registrar,
    ChatFrameTimingSampleReader sampleReader =
        ChatFrameTimingSample.fromFrameTiming,
    this.buildJankThreshold = const Duration(milliseconds: 8),
    this.rasterJankThreshold = const Duration(milliseconds: 16),
    this.totalJankThreshold = const Duration(milliseconds: 24),
  }) : _telemetry = telemetry,
       _registrar = registrar,
       _sampleReader = sampleReader;

  final FrameJankTelemetry _telemetry;
  final FrameTimingRegistrar _registrar;
  final ChatFrameTimingSampleReader _sampleReader;

  final Duration buildJankThreshold;
  final Duration rasterJankThreshold;
  final Duration totalJankThreshold;

  late final TimingsCallback _timingsCallback = _handleFrameTimings;
  bool _isStarted = false;

  void start() {
    if (_isStarted) {
      return;
    }
    _registrar.addTimingsCallback(_timingsCallback);
    _isStarted = true;
  }

  void stop() {
    if (!_isStarted) {
      return;
    }
    _registrar.removeTimingsCallback(_timingsCallback);
    _isStarted = false;
  }

  @visibleForTesting
  void recordSample(ChatFrameTimingSample sample) {
    _recordSample(sample);
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_isStarted) {
      return;
    }

    for (final timing in timings) {
      _recordSample(_sampleReader(timing));
    }
  }

  void _recordSample(ChatFrameTimingSample sample) {
    if (sample.buildDuration > buildJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.buildDuration,
        reason: FrameJankTelemetry.reasonBuild,
      );
    }
    if (sample.rasterDuration > rasterJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.rasterDuration,
        reason: FrameJankTelemetry.reasonRaster,
      );
    }
    if (sample.totalSpan > totalJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.totalSpan,
        reason: FrameJankTelemetry.reasonTotal,
      );
    }
  }
}
