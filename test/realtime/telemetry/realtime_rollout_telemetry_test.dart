import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  test(
    'flushes buffered events together with active session heartbeat',
    () async {
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
    },
  );

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

  test('flush keeps events recorded while transport is in flight', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final firstTransportStarted = Completer<void>();
    final releaseFirstTransport = Completer<void>();
    var attempt = 0;
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        attempt += 1;
        batches.add(List<RealtimeTelemetryEvent>.from(events));
        if (attempt == 1) {
          firstTransportStarted.complete();
          await releaseFirstTransport.future;
        }
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.recordGatewayReconnect();
    final firstFlush = telemetry.flush();
    await firstTransportStarted.future;

    telemetry.recordGapRepairPull();
    releaseFirstTransport.complete();
    await firstFlush;
    await telemetry.flush();

    expect(batches, hasLength(2));
    expect(
      batches.first.map((event) => event.name),
      contains('gateway_reconnect_count'),
    );
    expect(
      batches.last.map((event) => event.name),
      contains('pull_after_seq_repair_count'),
    );
  });

  test(
    'caps buffered events while telemetry uploads are unavailable',
    () async {
      final batches = <List<RealtimeTelemetryEvent>>[];
      var failTransport = true;
      final telemetry = RealtimeRolloutTelemetry(
        transport: (events) async {
          if (failTransport) {
            throw StateError('telemetry endpoint unavailable');
          }
          batches.add(List<RealtimeTelemetryEvent>.from(events));
        },
        flushInterval: const Duration(hours: 1),
        maxBufferedEvents: 3,
      );
      addTearDown(telemetry.dispose);

      for (var index = 0; index < 5; index += 1) {
        telemetry.recordSqlitePageQuery(
          Duration(milliseconds: index),
          mode: 'page-$index',
        );
      }

      await telemetry.flush();
      failTransport = false;
      await telemetry.flush();

      expect(batches, hasLength(1));
      expect(batches.single.map((event) => event.rawValue), <int>[2, 3, 4]);
      expect(batches.single.map((event) => event.tags['mode']), <String>[
        'page-2',
        'page-3',
        'page-4',
      ]);
    },
  );

  test(
    'records build chat frame jank with safe low-cardinality tags',
    () async {
      final batches = <List<RealtimeTelemetryEvent>>[];
      final telemetry = RealtimeRolloutTelemetry(
        transport: (events) async {
          batches.add(List<RealtimeTelemetryEvent>.from(events));
        },
        flushInterval: const Duration(hours: 1),
      );
      addTearDown(telemetry.dispose);

      telemetry.bindSessionId('sess_jank_01');
      telemetry.recordChatFrameJank(
        duration: const Duration(milliseconds: 13),
        reason: FrameJankTelemetry.reasonBuild,
      );

      await telemetry.flush();

      expect(batches, hasLength(1));
      expect(batches.single, hasLength(1));
      final event = batches.single.single;
      expect(event.name, RealtimeRolloutTelemetry.metricChatFrameBuildJankMs);
      expect(event.rawValue, 13);
      expect(event.sessionId, 'sess_jank_01');
      expect(event.tags, <String, String>{
        'surface': 'chat',
        'reason': 'build',
      });
    },
  );

  test('records raster and total chat frame jank metrics', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        batches.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 21),
      reason: FrameJankTelemetry.reasonRaster,
    );
    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 33),
      reason: FrameJankTelemetry.reasonTotal,
    );

    await telemetry.flush();

    expect(batches, hasLength(1));
    expect(batches.single.map((event) => event.name), <String>[
      RealtimeRolloutTelemetry.metricChatFrameRasterJankMs,
      RealtimeRolloutTelemetry.metricChatFrameTotalJankMs,
    ]);
    expect(batches.single.map((event) => event.rawValue), <int>[21, 33]);
    expect(batches.single.map((event) => event.tags), <Map<String, String>>[
      <String, String>{'surface': 'chat', 'reason': 'raster'},
      <String, String>{'surface': 'chat', 'reason': 'total'},
    ]);
  });

  test(
    'ignores unknown chat frame jank reasons to prevent high-cardinality tags',
    () async {
      final batches = <List<RealtimeTelemetryEvent>>[];
      final telemetry = RealtimeRolloutTelemetry(
        transport: (events) async {
          batches.add(List<RealtimeTelemetryEvent>.from(events));
        },
        flushInterval: const Duration(hours: 1),
      );
      addTearDown(telemetry.dispose);

      telemetry.recordChatFrameJank(
        duration: const Duration(milliseconds: 99),
        reason: 'channel-12345',
      );

      await telemetry.flush();

      expect(batches, isEmpty);
    },
  );
}
