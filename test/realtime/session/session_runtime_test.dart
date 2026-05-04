import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';
import 'package:wukong_im_app/realtime/session/session_event_gateway.dart';
import 'package:wukong_im_app/realtime/session/session_runtime.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  test(
    'runtime reconnects after stream error with latest ack sequence',
    () async {
      final firstController = StreamController<Object?>.broadcast();
      final secondController = StreamController<Object?>.broadcast();
      final controllers = <StreamController<Object?>>[
        firstController,
        secondController,
      ];
      final connectedUris = <Uri>[];
      var connectCount = 0;
      final runtime = SessionRuntime(
        gateway: SessionEventGateway(
          connect: (uri, {headers}) {
            connectedUris.add(uri);
            final controller = controllers[connectCount++];
            return _FakeSessionSocket(controller.stream);
          },
          ack: (_) async {},
        ),
        onDeviceInvalidated: () {},
        retryDelay: (_) => Duration.zero,
        delay: (_) async {},
      );
      addTearDown(() async {
        await runtime.stop();
        await firstController.close();
        await secondController.close();
      });

      await runtime.start(
        Uri.parse(
          'ws://example.com/v1/realtime/session/events/ws?device_session_id=device_01&last_acked_seq=0',
        ),
      );
      await runtime.handleFrame(
        const SessionEventFrame(
          eventId: 'evt_ack',
          userSeq: 1,
          serverTs: 1712000003,
          kind: 'call.invite',
          aggregateId: 'room_11',
          payload: <String, dynamic>{},
        ),
      );

      firstController.addError(StateError('socket closed'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(connectCount, 2);
      expect(runtime.isRunning, isTrue);
      expect(runtime.isGatewayDegraded, isFalse);
      expect(connectedUris.last.queryParameters['last_acked_seq'], '1');
    },
  );

  test('runtime retries again when reconnect handshake fails', () async {
    final firstController = StreamController<Object?>.broadcast();
    final thirdController = StreamController<Object?>.broadcast();
    final firstSocket = _ReadyAwareFakeSessionSocket(firstController.stream);
    final secondSocket = _ReadyAwareFakeSessionSocket(
      const Stream<Object?>.empty(),
      readyError: StateError('handshake failed'),
    );
    final thirdSocket = _ReadyAwareFakeSessionSocket(thirdController.stream);
    final sockets = <_ReadyAwareFakeSessionSocket>[
      firstSocket,
      secondSocket,
      thirdSocket,
    ];
    var connectCount = 0;
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) => sockets[connectCount++],
        ack: (_) async {},
      ),
      onDeviceInvalidated: () {},
      retryDelay: (_) => Duration.zero,
      delay: (_) async {},
    );
    addTearDown(() async {
      await runtime.stop();
      await firstController.close();
      await thirdController.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    firstController.addError(StateError('socket closed'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(connectCount, 3);
    expect(secondSocket.readyCalls, 1);
    expect(secondSocket.closeCalls, 1);
    expect(runtime.isRunning, isTrue);
    expect(runtime.isGatewayDegraded, isFalse);
  });

  test('runtime pauses when device session is invalidated', () async {
    final controller = StreamController<Object?>.broadcast();

    var invalidated = false;
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      ),
      onDeviceInvalidated: () {
        invalidated = true;
      },
    );
    addTearDown(() async {
      await runtime.stop();
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    await runtime.handleFrame(
      const SessionEventFrame(
        eventId: 'evt_invalid',
        userSeq: 8,
        serverTs: 1712000001,
        kind: 'device.invalidated',
        aggregateId: 'device_01',
        payload: <String, dynamic>{},
      ),
    );

    expect(runtime.isRunning, isFalse);
    expect(invalidated, isTrue);
  });

  test('runtime acknowledges processed frames', () async {
    final controller = StreamController<Object?>.broadcast();

    final acked = <int>[];
    final handled = <String>[];
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          acked.add(lastAckedSeq);
        },
      ),
      onDeviceInvalidated: () {},
      onFrame: (frame) async {
        handled.add(frame.eventId);
      },
    );
    addTearDown(() async {
      await runtime.stop();
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    await runtime.handleFrame(
      const SessionEventFrame(
        eventId: 'evt_ok',
        userSeq: 1,
        serverTs: 1712000002,
        kind: 'call.invite',
        aggregateId: 'room_11',
        payload: <String, dynamic>{'room_id': 'room_11'},
      ),
    );

    expect(handled, <String>['evt_ok']);
    expect(acked, <int>[1]);
  });

  test('runtime pauses when session is kicked without acking frame', () async {
    final controller = StreamController<Object?>.broadcast();

    final acked = <int>[];
    final handled = <String>[];
    var invalidated = false;
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          acked.add(lastAckedSeq);
        },
      ),
      onDeviceInvalidated: () {
        invalidated = true;
      },
      onFrame: (frame) async {
        handled.add(frame.eventId);
      },
    );
    addTearDown(() async {
      await runtime.stop();
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    await runtime.handleFrame(
      const SessionEventFrame(
        eventId: 'evt_kicked',
        userSeq: 12,
        serverTs: 1712000004,
        kind: 'session.kicked',
        aggregateId: 'u_12',
        payload: <String, dynamic>{},
      ),
    );

    expect(runtime.isRunning, isFalse);
    expect(invalidated, isTrue);
    expect(handled, isEmpty);
    expect(acked, isEmpty);
  });

  test('runtime marks gateway degraded after stream error', () async {
    final controller = StreamController<Object?>.broadcast();

    var now = DateTime.utc(2026, 4, 2, 19, 30, 0);
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (_) async {},
      ),
      onDeviceInvalidated: () {},
      now: () => now,
    );
    addTearDown(() async {
      await runtime.stop();
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    controller.addError(StateError('socket closed'));
    await Future<void>.delayed(Duration.zero);

    expect(runtime.isGatewayDegraded, isTrue);
    expect(runtime.isGatewayDegradedFor(const Duration(seconds: 10)), isFalse);

    now = now.add(const Duration(seconds: 11));
    expect(runtime.isGatewayDegradedFor(const Duration(seconds: 10)), isTrue);
  });

  test('runtime snapshot exposes current observability state', () async {
    final controller = StreamController<Object?>.broadcast();
    final recoveryDelayStarted = Completer<void>();
    final releaseRecovery = Completer<void>();
    final ackCommittedSeq = Completer<int>();
    final now = DateTime.utc(2026, 4, 17, 0, 0, 0);
    final gateway = _AckAwareSessionEventGateway(
      connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      ack: (_) async {},
      onAckCommitted: (seq) {
        if (!ackCommittedSeq.isCompleted) {
          ackCommittedSeq.complete(seq);
        }
      },
    );
    final runtime = SessionRuntime(
      gateway: gateway,
      onDeviceInvalidated: () {},
      now: () => now,
      retryDelay: (_) => Duration.zero,
      delay: (_) {
        if (!recoveryDelayStarted.isCompleted) {
          recoveryDelayStarted.complete();
        }
        return releaseRecovery.future;
      },
    );
    addTearDown(() async {
      await runtime.stop();
      if (!releaseRecovery.isCompleted) {
        releaseRecovery.complete();
      }
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    controller.add(
      '{"event_id":"evt_snapshot_01","user_seq":1,"server_ts":1712000023,"kind":"call.invite","aggregate_id":"room_01","payload":{"room_id":"room_01"}}',
    );
    expect(await ackCommittedSeq.future.timeout(const Duration(seconds: 1)), 1);

    final stableSnapshot = runtime.snapshot;
    expect(stableSnapshot.retryAttempt, 0);
    expect(stableSnapshot.lastAckedSeq, 1);
    expect(stableSnapshot.lastReceivedSeq, 1);
    expect(stableSnapshot.gatewayDegradedSince, isNull);

    controller.addError(StateError('socket closed'));
    await recoveryDelayStarted.future.timeout(const Duration(seconds: 1));

    final degradedSnapshot = runtime.snapshot;
    expect(degradedSnapshot.retryAttempt, 1);
    expect(degradedSnapshot.lastAckedSeq, 1);
    expect(degradedSnapshot.lastReceivedSeq, 1);
    expect(degradedSnapshot.gatewayDegradedSince, now);
  });

  test('runtime stop cancels pending recovery work', () async {
    final controller = StreamController<Object?>.broadcast();
    final pauseRecovery = Completer<void>();
    var connectCount = 0;
    final runtime = SessionRuntime(
      gateway: SessionEventGateway(
        connect: (uri, {headers}) {
          connectCount += 1;
          return _FakeSessionSocket(controller.stream);
        },
      ),
      onDeviceInvalidated: () {},
      retryDelay: (_) => const Duration(milliseconds: 10),
      delay: (_) => pauseRecovery.future,
    );
    addTearDown(() async {
      await runtime.stop();
      if (!pauseRecovery.isCompleted) {
        pauseRecovery.complete();
      }
      await controller.close();
    });

    await runtime.start(Uri.parse('ws://example.com'));
    controller.addError(StateError('socket closed'));
    await Future<void>.delayed(Duration.zero);
    await runtime.stop();
    pauseRecovery.complete();
    await Future<void>.delayed(Duration.zero);

    expect(connectCount, 1);
    expect(runtime.isRunning, isFalse);
  });

  test(
    'runtime requests delta and replays missing seqs before processing a gapped frame',
    () async {
      final controller = StreamController<Object?>.broadcast();
      final pulled = <(int afterSeq, int limit)>[];
      final handledSeqs = <int>[];
      final ackedSeqs = <int>[];
      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          ackedSeqs.add(lastAckedSeq);
        },
      );
      gateway.lastAckedSeq = 10;
      gateway.lastReceivedSeq = 10;
      final runtime = SessionRuntime(
        gateway: gateway,
        onDeviceInvalidated: () {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          pulled.add((afterSeq, limit));
          return <SessionEventFrame>[
            _frame(seq: 11, eventId: 'evt_11'),
            _frame(seq: 12, eventId: 'evt_12'),
          ];
        },
        onFrame: (frame) async {
          handledSeqs.add(frame.userSeq);
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await controller.close();
      });

      await runtime.start(Uri.parse('ws://example.com'));
      await runtime.handleFrame(_frame(seq: 13, eventId: 'evt_13'));

      expect(pulled, <(int, int)>[(10, 200)]);
      expect(handledSeqs, <int>[11, 12, 13]);
      expect(ackedSeqs, <int>[11, 12, 13]);
      expect(gateway.lastAckedSeq, 13);
    },
  );

  test(
    'runtime stops replay when a pulled delta invalidates the session',
    () async {
      final controller = StreamController<Object?>.broadcast();
      final handledSeqs = <int>[];
      final ackedSeqs = <int>[];
      var invalidatedCount = 0;
      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          ackedSeqs.add(lastAckedSeq);
        },
      );
      gateway.lastAckedSeq = 10;
      gateway.lastReceivedSeq = 10;
      final runtime = SessionRuntime(
        gateway: gateway,
        onDeviceInvalidated: () {
          invalidatedCount += 1;
        },
        pullAfterSeq: ({required afterSeq, required limit}) async {
          return <SessionEventFrame>[
            const SessionEventFrame(
              eventId: 'evt_kicked_11',
              userSeq: 11,
              serverTs: 1712000011,
              kind: 'session.kicked',
              aggregateId: 'u_self',
              payload: <String, dynamic>{},
            ),
            _frame(seq: 12, eventId: 'evt_should_not_replay'),
          ];
        },
        onFrame: (frame) async {
          handledSeqs.add(frame.userSeq);
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await controller.close();
      });

      await runtime.start(Uri.parse('ws://example.com'));
      await runtime.handleFrame(_frame(seq: 13, eventId: 'evt_live_13'));

      expect(runtime.isRunning, isFalse);
      expect(invalidatedCount, 1);
      expect(handledSeqs, isEmpty);
      expect(ackedSeqs, isEmpty);
      expect(gateway.lastAckedSeq, 10);
    },
  );

  test(
    'runtime does not call delta pull for contiguous or duplicate seq',
    () async {
      final controller = StreamController<Object?>.broadcast();
      final pulled = <(int afterSeq, int limit)>[];
      final acked = <int>[];
      final handled = <String>[];
      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          acked.add(lastAckedSeq);
        },
      );
      gateway.lastAckedSeq = 5;
      gateway.lastReceivedSeq = 8;
      final runtime = SessionRuntime(
        gateway: gateway,
        onDeviceInvalidated: () {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          pulled.add((afterSeq, limit));
          return const <SessionEventFrame>[];
        },
        onFrame: (frame) async {
          handled.add(frame.eventId);
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await controller.close();
      });

      await runtime.start(Uri.parse('ws://example.com'));
      await runtime.handleFrame(_frame(seq: 6, eventId: 'evt_contiguous'));
      await runtime.handleFrame(_frame(seq: 6, eventId: 'evt_duplicate'));

      expect(pulled, isEmpty);
      expect(handled, <String>['evt_contiguous']);
      expect(acked, <int>[6]);
    },
  );

  test(
    'runtime does not ack jumped frame when delta pull fails or is incomplete',
    () async {
      final failureController = StreamController<Object?>.broadcast();
      final failureAcked = <int>[];
      final failureGateway = SessionEventGateway(
        connect: (uri, {headers}) =>
            _FakeSessionSocket(failureController.stream),
        ack: (lastAckedSeq) async {
          failureAcked.add(lastAckedSeq);
        },
      );
      failureGateway.lastAckedSeq = 10;
      final failingRuntime = SessionRuntime(
        gateway: failureGateway,
        onDeviceInvalidated: () {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          throw StateError('pull failed');
        },
        onFrame: (_) async {},
      );
      addTearDown(() async {
        await failingRuntime.stop();
        await failureController.close();
      });

      await failingRuntime.start(Uri.parse('ws://example.com'));
      await expectLater(
        failingRuntime.handleFrame(_frame(seq: 13, eventId: 'evt_jump_fail')),
        throwsStateError,
      );
      expect(failureAcked, isEmpty);
      expect(failureGateway.lastAckedSeq, 10);

      final incompleteController = StreamController<Object?>.broadcast();
      final incompleteAcked = <int>[];
      final incompleteGateway = SessionEventGateway(
        connect: (uri, {headers}) =>
            _FakeSessionSocket(incompleteController.stream),
        ack: (lastAckedSeq) async {
          incompleteAcked.add(lastAckedSeq);
        },
      );
      incompleteGateway.lastAckedSeq = 10;
      final incompleteHandled = <int>[];
      final incompleteRuntime = SessionRuntime(
        gateway: incompleteGateway,
        onDeviceInvalidated: () {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          return <SessionEventFrame>[_frame(seq: 11, eventId: 'evt_11_only')];
        },
        onFrame: (frame) async {
          incompleteHandled.add(frame.userSeq);
        },
      );
      addTearDown(() async {
        await incompleteRuntime.stop();
        await incompleteController.close();
      });

      await incompleteRuntime.start(Uri.parse('ws://example.com'));
      await expectLater(
        incompleteRuntime.handleFrame(
          _frame(seq: 13, eventId: 'evt_jump_incomplete'),
        ),
        throwsStateError,
      );
      expect(incompleteHandled, <int>[11]);
      expect(incompleteAcked, <int>[11]);
      expect(incompleteGateway.lastAckedSeq, 11);
      expect(incompleteAcked.contains(13), isFalse);
    },
  );

  test(
    'runtime serializes frame processing so async handlers cannot invert order',
    () async {
      final controller = StreamController<Object?>.broadcast();
      final releaseFirst = Completer<void>();
      final secondStarted = Completer<void>();
      final callOrder = <String>[];
      final runtime = SessionRuntime(
        gateway: SessionEventGateway(
          connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
          ack: (_) async {},
        ),
        onDeviceInvalidated: () {},
        onFrame: (frame) async {
          callOrder.add('start_${frame.userSeq}');
          if (frame.userSeq == 1) {
            await releaseFirst.future;
          } else if (!secondStarted.isCompleted) {
            secondStarted.complete();
          }
          callOrder.add('end_${frame.userSeq}');
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await controller.close();
      });

      await runtime.start(Uri.parse('ws://example.com'));
      controller.add(jsonForFrame(_frame(seq: 1, eventId: 'evt_first')));
      controller.add(jsonForFrame(_frame(seq: 2, eventId: 'evt_second')));
      await Future<void>.delayed(Duration.zero);
      expect(secondStarted.isCompleted, isFalse);

      releaseFirst.complete();
      await Future<void>.delayed(Duration.zero);
      await secondStarted.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);

      expect(callOrder, <String>['start_1', 'end_1', 'start_2', 'end_2']);
    },
  );

  test(
    'runtime pulls multiple delta pages until the gap is fully repaired',
    () async {
      final controller = StreamController<Object?>.broadcast();
      final pulled = <(int afterSeq, int limit)>[];
      final acked = <int>[];
      final handled = <int>[];
      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
        ack: (lastAckedSeq) async {
          acked.add(lastAckedSeq);
        },
      );
      gateway.lastAckedSeq = 10;
      final runtime = SessionRuntime(
        gateway: gateway,
        onDeviceInvalidated: () {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          pulled.add((afterSeq, limit));
          if (afterSeq == 10) {
            return List<SessionEventFrame>.generate(
              200,
              (index) => _frame(seq: 11 + index, eventId: 'evt_${11 + index}'),
            );
          }
          if (afterSeq == 210) {
            return <SessionEventFrame>[
              _frame(seq: 211, eventId: 'evt_211'),
              _frame(seq: 212, eventId: 'evt_212'),
            ];
          }
          return const <SessionEventFrame>[];
        },
        onFrame: (frame) async {
          handled.add(frame.userSeq);
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await controller.close();
      });

      await runtime.start(Uri.parse('ws://example.com'));
      await runtime.handleFrame(_frame(seq: 213, eventId: 'evt_live_213'));

      expect(pulled, <(int afterSeq, int limit)>[(10, 200), (210, 200)]);
      expect(handled.first, 11);
      expect(handled.last, 213);
      expect(handled.length, 203);
      expect(acked.first, 11);
      expect(acked.last, 213);
      expect(acked.length, 203);
      expect(gateway.lastAckedSeq, 213);
    },
  );

  test(
    'runtime records reconnect and gap-repair telemetry while tracking running state',
    () async {
      final firstController = StreamController<Object?>.broadcast();
      final secondController = StreamController<Object?>.broadcast();
      final controllers = <StreamController<Object?>>[
        firstController,
        secondController,
      ];
      final telemetry = _RecordingRuntimeTelemetry();
      var connectCount = 0;
      final gateway = SessionEventGateway(
        connect: (uri, {headers}) =>
            _FakeSessionSocket(controllers[connectCount++].stream),
        ack: (_) async {},
      );
      gateway.lastAckedSeq = 10;
      gateway.lastReceivedSeq = 10;
      final runtime = SessionRuntime(
        gateway: gateway,
        onDeviceInvalidated: () {},
        telemetry: telemetry,
        retryDelay: (_) => Duration.zero,
        delay: (_) async {},
        pullAfterSeq: ({required afterSeq, required limit}) async {
          return <SessionEventFrame>[
            _frame(seq: 11, eventId: 'evt_11'),
            _frame(seq: 12, eventId: 'evt_12'),
          ];
        },
      );
      addTearDown(() async {
        await runtime.stop();
        await firstController.close();
        await secondController.close();
      });

      await runtime.start(
        Uri.parse(
          'ws://example.com/v1/realtime/session/events/ws?device_session_id=sess_runtime_01',
        ),
      );
      await runtime.handleFrame(_frame(seq: 13, eventId: 'evt_13'));
      firstController.addError(StateError('socket closed'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(telemetry.boundSessionIds, <String>['sess_runtime_01']);
      expect(telemetry.gapRepairCount, 1);
      expect(telemetry.reconnectCount, 1);
      expect(telemetry.runningStates, <bool>[true, false, true]);
    },
  );
}

class _AckAwareSessionEventGateway extends SessionEventGateway {
  _AckAwareSessionEventGateway({
    required super.connect,
    super.ack,
    this.onAckCommitted,
  });

  final void Function(int seq)? onAckCommitted;

  @override
  Future<void> ack(int seq) async {
    await super.ack(seq);
    onAckCommitted?.call(lastAckedSeq);
  }
}

class _FakeSessionSocket implements SessionSocket {
  _FakeSessionSocket(this.stream);

  @override
  final Stream<Object?> stream;

  @override
  Future<void> ready() async {}

  @override
  Future<void> close([int? code, String? reason]) async {}
}

class _ReadyAwareFakeSessionSocket implements SessionSocket {
  _ReadyAwareFakeSessionSocket(this.stream, {this.readyError});

  final Object? readyError;
  int readyCalls = 0;
  int closeCalls = 0;

  @override
  final Stream<Object?> stream;

  @override
  Future<void> ready() async {
    readyCalls += 1;
    if (readyError != null) {
      throw readyError!;
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCalls += 1;
  }
}

class _RecordingRuntimeTelemetry implements SessionRuntimeTelemetry {
  final List<String> boundSessionIds = <String>[];
  final List<bool> runningStates = <bool>[];
  int reconnectCount = 0;
  int gapRepairCount = 0;

  @override
  void bindSessionId(String sessionId) {
    boundSessionIds.add(sessionId);
  }

  @override
  void recordGapRepairPull() {
    gapRepairCount += 1;
  }

  @override
  void recordGatewayReconnect() {
    reconnectCount += 1;
  }

  @override
  void setSessionRunning(bool isRunning) {
    runningStates.add(isRunning);
  }
}

SessionEventFrame _frame({required int seq, required String eventId}) {
  return SessionEventFrame(
    eventId: eventId,
    userSeq: seq,
    serverTs: 1712000000 + seq,
    kind: 'call.invite',
    aggregateId: 'room_$seq',
    payload: <String, dynamic>{'room_id': 'room_$seq'},
  );
}

String jsonForFrame(SessionEventFrame frame) {
  return '{"event_id":"${frame.eventId}","user_seq":${frame.userSeq},"server_ts":${frame.serverTs},"kind":"${frame.kind}","aggregate_id":"${frame.aggregateId}","payload":{"room_id":"${frame.aggregateId}"}}';
}
