import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import '../../widgets/liquid_glass_performance.dart';

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

final chatLiquidGlassFallbackIsWebProvider = Provider<bool>((ref) {
  return kIsWeb;
});

final chatLiquidGlassFallbackControllerProvider =
    StateNotifierProvider<ChatLiquidGlassFallbackController, bool>((ref) {
      return ChatLiquidGlassFallbackController();
    });

final chatLiquidGlassFallbackProvider = Provider<bool>((ref) {
  return ref.watch(chatLiquidGlassFallbackControllerProvider);
});

class ChatLiquidGlassFallbackController extends StateNotifier<bool> {
  ChatLiquidGlassFallbackController() : super(false);

  int _rasterJankCount = 0;
  int _totalJankCount = 0;

  void recordRasterJank({
    required bool isWeb,
    required bool disableAnimations,
  }) {
    if (!isWeb) {
      return;
    }
    _rasterJankCount += 1;
    _syncState(isWeb: isWeb, disableAnimations: disableAnimations);
  }

  void recordTotalJank({required bool isWeb, required bool disableAnimations}) {
    if (!isWeb) {
      return;
    }
    _totalJankCount += 1;
    _syncState(isWeb: isWeb, disableAnimations: disableAnimations);
  }

  void _syncState({required bool isWeb, required bool disableAnimations}) {
    state = shouldDisableLiquidGlassBlur(
      isWeb: isWeb,
      disableAnimations: disableAnimations,
      rasterJankCount: _rasterJankCount,
      totalJankCount: _totalJankCount,
    );
  }
}

typedef ChatFrameJankMonitorFactory = ChatFrameJankMonitor Function();

final chatFrameJankMonitorFactoryProvider =
    Provider<ChatFrameJankMonitorFactory>((ref) {
      final telemetry = ref.watch(frameJankTelemetryProvider);
      final registrar = ref.watch(chatFrameTimingRegistrarProvider);
      final liquidGlassFallback = ref.watch(
        chatLiquidGlassFallbackControllerProvider.notifier,
      );
      final isWeb = ref.watch(chatLiquidGlassFallbackIsWebProvider);
      return () => ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: registrar,
        liquidGlassFallback: liquidGlassFallback,
        isWeb: isWeb,
      );
    });

class ChatFrameJankMonitor {
  ChatFrameJankMonitor({
    required FrameJankTelemetry telemetry,
    required FrameTimingRegistrar registrar,
    ChatFrameTimingSampleReader sampleReader =
        ChatFrameTimingSample.fromFrameTiming,
    ChatLiquidGlassFallbackController? liquidGlassFallback,
    bool isWeb = kIsWeb,
    bool disableAnimations = false,
    this.buildJankThreshold = const Duration(milliseconds: 8),
    this.rasterJankThreshold = const Duration(milliseconds: 16),
    this.totalJankThreshold = const Duration(milliseconds: 24),
  }) : _telemetry = telemetry,
       _registrar = registrar,
       _sampleReader = sampleReader,
       _liquidGlassFallback = liquidGlassFallback,
       _isWeb = isWeb,
       _disableAnimations = disableAnimations;

  final FrameJankTelemetry _telemetry;
  final FrameTimingRegistrar _registrar;
  final ChatFrameTimingSampleReader _sampleReader;
  final ChatLiquidGlassFallbackController? _liquidGlassFallback;
  final bool _isWeb;
  final bool _disableAnimations;

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
      _liquidGlassFallback?.recordRasterJank(
        isWeb: _isWeb,
        disableAnimations: _disableAnimations,
      );
    }
    if (sample.totalSpan > totalJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.totalSpan,
        reason: FrameJankTelemetry.reasonTotal,
      );
      _liquidGlassFallback?.recordTotalJank(
        isWeb: _isWeb,
        disableAnimations: _disableAnimations,
      );
    }
  }
}
