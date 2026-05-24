import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_frame_jank_monitor.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  group('ChatFrameJankMonitor thresholds', () {
    test('records nothing below all thresholds', () {
      final telemetry = _SpyFrameJankTelemetry();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: _FakeFrameTimingRegistrar(),
      );

      monitor.recordSample(
        const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 8),
          rasterDuration: Duration(milliseconds: 16),
          totalSpan: Duration(milliseconds: 24),
        ),
      );

      expect(telemetry.records, isEmpty);
    });

    test('records build raster and total threshold breaches', () {
      final telemetry = _SpyFrameJankTelemetry();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: _FakeFrameTimingRegistrar(),
      );

      monitor.recordSample(
        const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 9),
          rasterDuration: Duration(milliseconds: 17),
          totalSpan: Duration(milliseconds: 25),
        ),
      );

      expect(telemetry.records, <_JankRecord>[
        const _JankRecord(
          duration: Duration(milliseconds: 9),
          reason: FrameJankTelemetry.reasonBuild,
        ),
        const _JankRecord(
          duration: Duration(milliseconds: 17),
          reason: FrameJankTelemetry.reasonRaster,
        ),
        const _JankRecord(
          duration: Duration(milliseconds: 25),
          reason: FrameJankTelemetry.reasonTotal,
        ),
      ]);
    });
  });

  group('Chat liquid glass fallback', () {
    test('repeated Web raster jank disables liquid glass blur fallback', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final monitor = ChatFrameJankMonitor(
        telemetry: _SpyFrameJankTelemetry(),
        registrar: _FakeFrameTimingRegistrar(),
        liquidGlassFallback: container.read(
          chatLiquidGlassFallbackControllerProvider.notifier,
        ),
        isWeb: true,
      );

      expect(container.read(chatLiquidGlassFallbackProvider), isFalse);
      for (var i = 0; i < 3; i += 1) {
        monitor.recordSample(
          const ChatFrameTimingSample(
            buildDuration: Duration.zero,
            rasterDuration: Duration(milliseconds: 17),
            totalSpan: Duration.zero,
          ),
        );
        expect(container.read(chatLiquidGlassFallbackProvider), i == 2);
      }
    });

    test('repeated Web total jank disables liquid glass blur fallback', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final monitor = ChatFrameJankMonitor(
        telemetry: _SpyFrameJankTelemetry(),
        registrar: _FakeFrameTimingRegistrar(),
        liquidGlassFallback: container.read(
          chatLiquidGlassFallbackControllerProvider.notifier,
        ),
        isWeb: true,
      );

      expect(container.read(chatLiquidGlassFallbackProvider), isFalse);
      for (var i = 0; i < 3; i += 1) {
        monitor.recordSample(
          const ChatFrameTimingSample(
            buildDuration: Duration.zero,
            rasterDuration: Duration.zero,
            totalSpan: Duration(milliseconds: 25),
          ),
        );
        expect(container.read(chatLiquidGlassFallbackProvider), i == 2);
      }
    });

    test('repeated non-Web total jank keeps liquid glass blur enabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final monitor = ChatFrameJankMonitor(
        telemetry: _SpyFrameJankTelemetry(),
        registrar: _FakeFrameTimingRegistrar(),
        liquidGlassFallback: container.read(
          chatLiquidGlassFallbackControllerProvider.notifier,
        ),
        isWeb: false,
      );

      for (var i = 0; i < 3; i += 1) {
        monitor.recordSample(
          const ChatFrameTimingSample(
            buildDuration: Duration.zero,
            rasterDuration: Duration.zero,
            totalSpan: Duration(milliseconds: 25),
          ),
        );
      }

      expect(container.read(chatLiquidGlassFallbackProvider), isFalse);
    });

    test('factory-created Web monitor toggles fallback provider', () {
      final container = ProviderContainer(
        overrides: <Override>[
          chatLiquidGlassFallbackIsWebProvider.overrideWithValue(true),
          chatFrameTimingRegistrarProvider.overrideWithValue(
            _FakeFrameTimingRegistrar(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final monitor = container.read(chatFrameJankMonitorFactoryProvider)();

      for (var i = 0; i < 3; i += 1) {
        monitor.recordSample(
          const ChatFrameTimingSample(
            buildDuration: Duration.zero,
            rasterDuration: Duration(milliseconds: 17),
            totalSpan: Duration.zero,
          ),
        );
      }

      expect(container.read(chatLiquidGlassFallbackProvider), isTrue);
    });
  });

  group('ChatFrameJankMonitor lifecycle', () {
    test('start is idempotent and stop unregisters once', () {
      final registrar = _FakeFrameTimingRegistrar();
      final monitor = ChatFrameJankMonitor(
        telemetry: _SpyFrameJankTelemetry(),
        registrar: registrar,
      );

      monitor.start();
      monitor.start();
      monitor.stop();
      monitor.stop();

      expect(registrar.addCount, 1);
      expect(registrar.removeCount, 1);
      expect(registrar.activeCallbackCount, 0);
    });

    test('callback records while started and ignores frames after stop', () {
      final telemetry = _SpyFrameJankTelemetry();
      final registrar = _FakeFrameTimingRegistrar();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: registrar,
        sampleReader: (_) => const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 10),
          rasterDuration: Duration(milliseconds: 1),
          totalSpan: Duration(milliseconds: 1),
        ),
      );

      monitor.start();
      registrar.fire(<FrameTiming>[_frameTiming()]);
      monitor.stop();
      registrar.fire(<FrameTiming>[_frameTiming()]);

      expect(telemetry.records, <_JankRecord>[
        const _JankRecord(
          duration: Duration(milliseconds: 10),
          reason: FrameJankTelemetry.reasonBuild,
        ),
      ]);
    });
  });
}

FrameTiming _frameTiming() {
  return FrameTiming(
    vsyncStart: 0,
    buildStart: 0,
    buildFinish: 0,
    rasterStart: 0,
    rasterFinish: 0,
    rasterFinishWallTime: 0,
  );
}

class _FakeFrameTimingRegistrar implements FrameTimingRegistrar {
  final Set<TimingsCallback> _callbacks = <TimingsCallback>{};
  int addCount = 0;
  int removeCount = 0;

  int get activeCallbackCount => _callbacks.length;

  @override
  void addTimingsCallback(TimingsCallback callback) {
    addCount += 1;
    _callbacks.add(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    removeCount += 1;
    _callbacks.remove(callback);
  }

  void fire(List<FrameTiming> timings) {
    for (final callback in List<TimingsCallback>.of(_callbacks)) {
      callback(timings);
    }
  }
}

class _SpyFrameJankTelemetry implements FrameJankTelemetry {
  final List<_JankRecord> records = <_JankRecord>[];

  @override
  void recordChatFrameJank({
    required Duration duration,
    required String reason,
  }) {
    records.add(_JankRecord(duration: duration, reason: reason));
  }
}

class _JankRecord {
  const _JankRecord({required this.duration, required this.reason});

  final Duration duration;
  final String reason;

  @override
  bool operator ==(Object other) {
    return other is _JankRecord &&
        other.duration == duration &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(duration, reason);

  @override
  String toString() {
    return '_JankRecord(duration: $duration, reason: $reason)';
  }
}
