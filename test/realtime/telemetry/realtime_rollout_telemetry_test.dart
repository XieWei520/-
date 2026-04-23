import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  test('flushes buffered events together with active session heartbeat', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        batches.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.bindSessionId('sess_rollout_01');
    telemetry.setSessionRunning(true);
    telemetry.recordGatewayReconnect();
    telemetry.recordGapRepairPull();

    await telemetry.flush();

    expect(batches, hasLength(1));
    final names = batches.single.map((event) => event.name).toList();
    expect(
      names,
      containsAll(<String>[
        'gateway_reconnect_count',
        'pull_after_seq_repair_count',
        'active_realtime_session_count',
      ]),
    );
    expect(
      batches.single.every((event) => event.sessionId == 'sess_rollout_01'),
      isTrue,
    );
  });

  test('failed flush keeps buffered events for retry', () async {
    final flushed = <List<RealtimeTelemetryEvent>>[];
    var attempt = 0;
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        attempt += 1;
        if (attempt == 1) {
          throw StateError('network down');
        }
        flushed.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.bindSessionId('sess_retry_01');
    telemetry.recordControlFrameDecodeError();

    await telemetry.flush();
    expect(flushed, isEmpty);

    await telemetry.flush();

    expect(flushed, hasLength(1));
    expect(
      flushed.single.map((event) => event.name),
      contains('control_frame_decode_error_count'),
    );
  });
}
