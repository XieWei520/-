import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/telemetry/message_query_jank_monitor.dart';
import '../../service/api/im_sync_api.dart';
import 'realtime_rollout_telemetry.dart';

final realtimeRolloutTelemetryProvider = Provider<RealtimeRolloutTelemetry>((
  ref,
) {
  final telemetry = RealtimeRolloutTelemetry(
    transport: IMSyncApi.instance.uploadRealtimeRolloutTelemetry,
  );
  ref.onDispose(() {
    unawaited(telemetry.flush());
    telemetry.dispose();
  });
  return telemetry;
});

final conversationPatchTelemetryProvider = Provider<ConversationPatchTelemetry>(
  (ref) {
    return ref.watch(realtimeRolloutTelemetryProvider);
  },
);

final messageQueryTelemetryProvider = Provider<MessageQueryTelemetry>((ref) {
  return ref.watch(realtimeRolloutTelemetryProvider);
});

final frameJankTelemetryProvider = Provider<FrameJankTelemetry>((ref) {
  return ref.watch(realtimeRolloutTelemetryProvider);
});

typedef MessageQueryJankMonitorFactory =
    MessageQueryJankMonitor Function(
      MessageQueryJankTelemetry telemetry, {
      bool? enabled,
    });

final messageQueryJankMonitorFactoryProvider =
    Provider<MessageQueryJankMonitorFactory>((ref) {
      return (telemetry, {enabled}) =>
          MessageQueryJankMonitor(telemetry: telemetry, enabled: enabled);
    });

final messageQueryJankMonitorEnabledProvider = Provider<bool?>((ref) {
  return null;
});

final messageQueryJankMonitorProvider =
    Provider.autoDispose<MessageQueryJankMonitor>((ref) {
      final monitor = ref.watch(messageQueryJankMonitorFactoryProvider)(
        ref.watch(realtimeRolloutTelemetryProvider),
        enabled: ref.watch(messageQueryJankMonitorEnabledProvider),
      );
      monitor.register();
      ref.onDispose(monitor.dispose);
      return monitor;
    });
