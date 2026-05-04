import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/telemetry/message_query_jank_monitor.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry_provider.dart';

void main() {
  test('recordTimings counts frames over build or raster thresholds', () {
    final telemetry = _RecordingJankTelemetry();
    final monitor = MessageQueryJankMonitor(
      telemetry: telemetry,
      enabled: true,
      buildThreshold: const Duration(milliseconds: 8),
      rasterThreshold: const Duration(milliseconds: 8),
    );

    monitor.recordTimings(const <MessageQueryFrameTiming>[
      MessageQueryFrameTiming(
        buildDuration: Duration(milliseconds: 4),
        rasterDuration: Duration(milliseconds: 4),
      ),
      MessageQueryFrameTiming(
        buildDuration: Duration(milliseconds: 9),
        rasterDuration: Duration(milliseconds: 4),
      ),
      MessageQueryFrameTiming(
        buildDuration: Duration(milliseconds: 4),
        rasterDuration: Duration(milliseconds: 10),
      ),
      MessageQueryFrameTiming(
        buildDuration: Duration(milliseconds: 12),
        rasterDuration: Duration(milliseconds: 14),
      ),
    ]);

    expect(telemetry.buildDurations, <Duration>[
      const Duration(milliseconds: 9),
      const Duration(milliseconds: 12),
    ]);
    expect(telemetry.rasterDurations, <Duration>[
      const Duration(milliseconds: 10),
      const Duration(milliseconds: 14),
    ]);
  });

  test('recordTimings stays quiet when disabled', () {
    final telemetry = _RecordingJankTelemetry();
    final monitor = MessageQueryJankMonitor(
      telemetry: telemetry,
      enabled: false,
      buildThreshold: const Duration(milliseconds: 8),
      rasterThreshold: const Duration(milliseconds: 8),
    );

    monitor.recordTimings(const <MessageQueryFrameTiming>[
      MessageQueryFrameTiming(
        buildDuration: Duration(milliseconds: 20),
        rasterDuration: Duration(milliseconds: 20),
      ),
    ]);

    expect(telemetry.buildDurations, isEmpty);
    expect(telemetry.rasterDurations, isEmpty);
  });

  test('register attaches frame timings callback and dispose removes it', () {
    final telemetry = _RecordingJankTelemetry();
    final addedCallbacks = <TimingsCallback>[];
    final removedCallbacks = <TimingsCallback>[];
    final monitor = MessageQueryJankMonitor.forTesting(
      telemetry: telemetry,
      enabled: true,
      addTimingsCallback: addedCallbacks.add,
      removeTimingsCallback: removedCallbacks.add,
    );

    monitor.register();
    monitor.dispose();

    expect(addedCallbacks, hasLength(1));
    expect(removedCallbacks, hasLength(1));
    expect(identical(addedCallbacks.single, removedCallbacks.single), isTrue);
  });

  test(
    'messageQueryJankMonitorProvider registers and unregisters the monitor',
    () {
      final addedCallbacks = <TimingsCallback>[];
      final removedCallbacks = <TimingsCallback>[];
      final container = ProviderContainer(
        overrides: [
          messageQueryJankMonitorFactoryProvider.overrideWithValue(
            (telemetry, {enabled}) => MessageQueryJankMonitor.forTesting(
              telemetry: telemetry,
              enabled: enabled ?? true,
              addTimingsCallback: addedCallbacks.add,
              removeTimingsCallback: removedCallbacks.add,
            ),
          ),
        ],
      );

      container.read(messageQueryJankMonitorProvider);
      expect(addedCallbacks, hasLength(1));

      container.dispose();

      expect(removedCallbacks, hasLength(1));
      expect(identical(addedCallbacks.single, removedCallbacks.single), isTrue);
    },
  );

  test('messageQueryJankMonitorProvider forwards explicit enabled setting', () {
    final enabledValues = <bool?>[];
    final container = ProviderContainer(
      overrides: [
        messageQueryJankMonitorEnabledProvider.overrideWithValue(true),
        messageQueryJankMonitorFactoryProvider.overrideWithValue((
          telemetry, {
          enabled,
        }) {
          enabledValues.add(enabled);
          return MessageQueryJankMonitor.forTesting(
            telemetry: telemetry,
            enabled: enabled ?? false,
            addTimingsCallback: (_) {},
            removeTimingsCallback: (_) {},
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(messageQueryJankMonitorProvider);

    expect(enabledValues, <bool?>[true]);
  });
}

class _RecordingJankTelemetry implements MessageQueryJankTelemetry {
  final List<Duration> buildDurations = <Duration>[];
  final List<Duration> rasterDurations = <Duration>[];

  @override
  void recordChatScrollJankFrame({
    Duration? buildDuration,
    Duration? rasterDuration,
  }) {
    if (buildDuration != null) {
      buildDurations.add(buildDuration);
    }
    if (rasterDuration != null) {
      rasterDurations.add(rasterDuration);
    }
  }
}
