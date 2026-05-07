import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/call_telemetry_reporter.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  test(
    'call telemetry reporter posts standard event payload to extra API',
    () async {
      final firstFetch = Completer<void>();
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'ok': true},
        onFetch: () {
          if (!firstFetch.isCompleted) {
            firstFetch.complete();
          }
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final reporter = CallTelemetryReporter(maxBufferedEvents: 3);

      reporter.recordCallEvent(
        roomId: 'room_report_01',
        callId: 'call_report_01',
        uid: 'u_self',
        event: 'call.failed',
        state: CallLifecycleStatus.failed,
        reason: CallFailureReason.tokenInvalid,
        duration: const Duration(milliseconds: 345),
        stats: const <String, dynamic>{'participant_count': 2},
      );
      await firstFetch.future.timeout(const Duration(seconds: 1));
      await reporter.flush();

      expect(adapter.lastRequestOptions?.path, '/v1/extra/call/telemetry');
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{
        'room_id': 'room_report_01',
        'call_id': 'call_report_01',
        'uid': 'u_self',
        'event': 'call.failed',
        'state': 'failed',
        'reason': 'token_invalid',
        'duration_ms': 345,
        'sdk': 'livekit_client',
        'platform': 'flutter',
        'stats': <String, dynamic>{'participant_count': 2},
      });
    },
  );

  test(
    'call telemetry reporter automatically flushes recorded events',
    () async {
      final firstFetch = Completer<void>();
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'ok': true},
        onFetch: () {
          if (!firstFetch.isCompleted) {
            firstFetch.complete();
          }
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final reporter = CallTelemetryReporter(maxBufferedEvents: 3);

      reporter.recordCallEvent(
        roomId: 'room_auto_flush_01',
        event: 'call.dial.started',
        state: CallLifecycleStatus.connected,
      );

      await firstFetch.future.timeout(const Duration(seconds: 1));
      await reporter.flush();

      expect(adapter.paths, <String>['/v1/extra/call/telemetry']);
      expect(reporter.pendingCount, 0);
    },
  );

  test(
    'call telemetry reporter buffers failures and caps pending events',
    () async {
      var fetchCount = 0;
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'ok': true},
        failFetch: true,
        onFetch: () {
          fetchCount += 1;
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final reporter = CallTelemetryReporter(maxBufferedEvents: 2);

      for (var index = 0; index < 3; index += 1) {
        reporter.recordCallEvent(
          roomId: 'room_$index',
          event: 'call.livekit.connected',
          state: CallLifecycleStatus.connected,
        );
      }

      for (var attempt = 0; attempt < 50; attempt += 1) {
        if (fetchCount >= 3 && reporter.pendingCount == 2) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(reporter.pendingCount, 2);
      adapter.failFetch = false;
      await reporter.flush();
      await reporter.flush();

      expect(reporter.pendingCount, 0);
      expect(adapter.paths, <String>[
        '/v1/extra/call/telemetry',
        '/v1/extra/call/telemetry',
        '/v1/extra/call/telemetry',
        '/v1/extra/call/telemetry',
        '/v1/extra/call/telemetry',
      ]);
    },
  );
}

class _RecordingPlainAdapter implements HttpClientAdapter {
  _RecordingPlainAdapter({
    required this.payload,
    this.failFetch = false,
    this.onFetch,
  });

  final Object payload;
  bool failFetch;
  final void Function()? onFetch;
  RequestOptions? lastRequestOptions;
  final List<String> paths = <String>[];
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;
    paths.add(options.path);
    lastRequestOptions = options;
    onFetch?.call();
    if (failFetch) {
      throw DioException(
        requestOptions: options,
        error: StateError('network down'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
