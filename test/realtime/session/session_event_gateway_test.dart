import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/control/control_proto_codec.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';
import 'package:wukong_im_app/realtime/session/session_event_gateway.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  test('frame parsing preserves ordering fields', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_01',
      'user_seq': 7,
      'server_ts': 1712000000,
      'kind': 'call.invite',
      'aggregate_id': 'room_01',
      'payload': <String, dynamic>{'room_id': 'room_01'},
    });

    expect(frame.userSeq, 7);
    expect(frame.kind, 'call.invite');
    expect(frame.aggregateId, 'room_01');
    expect(frame.payload['room_id'], 'room_01');
  });

  test('frame parsing decodes string payload from realtime gateway', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_02',
      'user_seq': 8,
      'kind': 'call.signal',
      'aggregate_id': 'room_02',
      'created_at': '2026-04-02T19:27:04Z',
      'payload': '{"room_id":"room_02","signal_type":"offer"}',
    });

    expect(frame.serverTs, 1775158024);
    expect(frame.payload['room_id'], 'room_02');
    expect(frame.payload['signal_type'], 'offer');
  });

  test('gateway open parses frames and tracks received sequence', () async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);

    final gateway = SessionEventGateway(
      connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
    );

    final frameFuture = (await gateway.open(
      Uri.parse('ws://example.com'),
    )).first;
    controller.add(
      '{"event_id":"evt_03","user_seq":9,"server_ts":1712000001,"kind":"call.invite","aggregate_id":"room_03","payload":{"room_id":"room_03"}}',
    );

    final frame = await frameFuture;
    expect(frame.eventId, 'evt_03');
    expect(gateway.lastReceivedSeq, 9);
    expect(gateway.lastAckedSeq, 0);
  });

  test('gateway still parses JSON frames delivered as bytes', () async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);

    final gateway = SessionEventGateway(
      connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
    );

    final frameFuture = (await gateway.open(
      Uri.parse('ws://example.com'),
    )).first;
    controller.add(
      Uint8List.fromList(
        utf8.encode(
          '{"event_id":"evt_03_bytes","user_seq":10,"server_ts":1712000002,"kind":"call.invite","aggregate_id":"room_03","payload":{"room_id":"room_03"}}',
        ),
      ),
    );

    final frame = await frameFuture;
    expect(frame.eventId, 'evt_03_bytes');
    expect(frame.userSeq, 10);
    expect(frame.kind, 'call.invite');
    expect(gateway.lastReceivedSeq, 10);
  });

  test(
    'gateway accepts protobuf binary frame while keeping JSON compatibility',
    () async {
      final controller = StreamController<Object?>.broadcast();
      addTearDown(controller.close);

      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      );

      final frameFuture = (await gateway.open(
        Uri.parse('ws://example.com'),
      )).first;

      final payload = utf8.encode(
        jsonEncode(<String, dynamic>{
          'aggregate_id': '1:u_3001',
          'channel_id': 'u_3001',
          'channel_type': 1,
          'unread_count': 12,
          'last_message_digest': 'proto',
          'sort_timestamp': 19000,
        }),
      );

      controller.add(
        ControlProtoCodec.encodeEnvelope(
          eventSeq: 55,
          eventType: 'conversation.updated',
          payload: Uint8List.fromList(payload),
          ackSeq: 41,
        ),
      );

      final frame = await frameFuture;
      expect(frame.userSeq, 55);
      expect(frame.kind, 'conversation.updated');
      expect(frame.aggregateId, '1:u_3001');
      expect(frame.payload['channel_id'], 'u_3001');
      expect(gateway.lastReceivedSeq, 55);
    },
  );

  test(
    'gateway maps protobuf issued_at_ms when payload omits server_ts',
    () async {
      final controller = StreamController<Object?>.broadcast();
      addTearDown(controller.close);

      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      );

      final frameFuture = (await gateway.open(
        Uri.parse('ws://example.com'),
      )).first;

      final payload = utf8.encode(
        jsonEncode(<String, dynamic>{
          'aggregate_id': '1:u_4001',
          'channel_id': 'u_4001',
          'channel_type': 1,
        }),
      );

      controller.add(
        ControlProtoCodec.encodeEnvelope(
          eventSeq: 77,
          eventType: 'conversation.updated',
          payload: Uint8List.fromList(payload),
          ackSeq: 66,
          deviceId: 'android-device-02',
          issuedAtMs: 1712000010123,
        ),
      );

      final frame = await frameFuture;
      expect(frame.userSeq, 77);
      expect(frame.serverTs, 1712000010);
      expect(frame.kind, 'conversation.updated');
      expect(gateway.lastReceivedSeq, 77);
    },
  );

  test(
    'gateway accepts protobuf session.kicked frame and tracks sequence',
    () async {
      final controller = StreamController<Object?>.broadcast();
      addTearDown(controller.close);

      final gateway = SessionEventGateway(
        connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      );

      final frameFuture = (await gateway.open(
        Uri.parse('ws://example.com'),
      )).first;

      final payload = utf8.encode(
        jsonEncode(<String, dynamic>{
          'aggregate_id': 'u_5001',
          'reason': 'inactive',
        }),
      );

      controller.add(
        ControlProtoCodec.encodeEnvelope(
          eventSeq: 78,
          eventType: 'session.kicked',
          payload: Uint8List.fromList(payload),
          ackSeq: 67,
        ),
      );

      final frame = await frameFuture;
      expect(frame.userSeq, 78);
      expect(frame.kind, 'session.kicked');
      expect(frame.aggregateId, 'u_5001');
      expect(gateway.lastReceivedSeq, 78);
    },
  );

  test(
    'gateway waits for socket readiness before exposing the stream',
    () async {
      final socket = _ReadyAwareFakeSessionSocket();
      final gateway = SessionEventGateway(connect: (uri, {headers}) => socket);

      await gateway.open(Uri.parse('ws://example.com'));

      expect(socket.readyCalls, 1);
    },
  );

  test(
    'gateway closes socket and rethrows when socket readiness fails',
    () async {
      final socket = _ReadyAwareFakeSessionSocket(
        readyError: StateError('handshake failed'),
      );
      final gateway = SessionEventGateway(connect: (uri, {headers}) => socket);

      await expectLater(
        () async => await gateway.open(Uri.parse('ws://example.com')),
        throwsA(isA<StateError>()),
      );
      expect(socket.readyCalls, 1);
      expect(socket.closeCalls, 1);
    },
  );

  test(
    'maps conversation.updated frame to conversation patch control event',
    () {
      final frame = SessionEventFrame.fromJson(<String, dynamic>{
        'event_id': 'evt_conversation_01',
        'user_seq': 18,
        'server_ts': 1712000018,
        'kind': 'conversation.updated',
        'aggregate_id': '1:u_1001',
        'payload': <String, dynamic>{
          'channel_id': 'u_1001',
          'channel_type': 1,
          'unread_count': 9,
          'last_message_digest': 'ping',
          'sort_timestamp': 999,
        },
      });

      final event = mapSessionControlEvent(frame);

      expect(event, isA<ConversationUpdatedEvent>());
      final updated = event! as ConversationUpdatedEvent;
      expect(updated.channelId, 'u_1001');
      expect(updated.channelType, 1);
      expect(updated.unreadCount, 9);
      expect(updated.lastMessageDigest, 'ping');
      expect(updated.sortTimestamp, 999);
    },
  );

  test('maps conversation.updated aliases and aggregate fallback', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_conversation_02',
      'user_seq': 19,
      'server_ts': 1712000019,
      'kind': 'conversation.updated',
      'aggregate_id': '2:g_team_01',
      'payload': <String, dynamic>{
        'channelId': 'g_team_01',
        'channelType': 2,
        'unreadCount': 3,
        'lastMessageDigest': 'hello',
        'sortTimestamp': 1888,
      },
    });

    final event = mapSessionControlEvent(frame);

    expect(event, isA<ConversationUpdatedEvent>());
    final updated = event! as ConversationUpdatedEvent;
    expect(updated.channelId, 'g_team_01');
    expect(updated.channelType, 2);
    expect(updated.unreadCount, 3);
    expect(updated.lastMessageDigest, 'hello');
    expect(updated.sortTimestamp, 1888);
  });

  test('uses aggregate id as final fallback for missing payload channel', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_conversation_03',
      'user_seq': 20,
      'server_ts': 1712000020,
      'kind': 'conversation.updated',
      'aggregate_id': '1:u_aggregate',
      'payload': <String, dynamic>{
        'unread_count': 7,
        'last_message_digest': 'fallback',
        'sort_timestamp': 2001,
      },
    });

    final event = mapSessionControlEvent(frame);

    expect(event, isA<ConversationUpdatedEvent>());
    final updated = event! as ConversationUpdatedEvent;
    expect(updated.channelId, 'u_aggregate');
    expect(updated.channelType, 1);
  });

  test('returns null for unsupported session frame kinds', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_other_01',
      'user_seq': 21,
      'server_ts': 1712000021,
      'kind': 'call.invite',
      'aggregate_id': 'room_01',
      'payload': <String, dynamic>{'room_id': 'room_01'},
    });

    final event = mapSessionControlEvent(frame);

    expect(event, isNull);
  });

  test('defaults digest to empty string when payload digest is missing', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_conversation_04',
      'user_seq': 22,
      'server_ts': 1712000022,
      'kind': 'conversation.updated',
      'aggregate_id': '1:u_digest_missing',
      'payload': <String, dynamic>{
        'channel_id': 'u_digest_missing',
        'channel_type': 1,
        'unread_count': 1,
        'sort_timestamp': 3001,
      },
    });

    final event = mapSessionControlEvent(frame);

    expect(event, isA<ConversationUpdatedEvent>());
    final updated = event! as ConversationUpdatedEvent;
    expect(updated.lastMessageDigest, '');
  });

  test('defaults digest to empty string when payload digest is blank', () {
    final frame = SessionEventFrame.fromJson(<String, dynamic>{
      'event_id': 'evt_conversation_05',
      'user_seq': 23,
      'server_ts': 1712000023,
      'kind': 'conversation.updated',
      'aggregate_id': '1:u_digest_blank',
      'payload': <String, dynamic>{
        'channel_id': 'u_digest_blank',
        'channel_type': 1,
        'unread_count': 1,
        'last_message_digest': '   ',
        'sort_timestamp': 3002,
      },
    });

    final event = mapSessionControlEvent(frame);

    expect(event, isA<ConversationUpdatedEvent>());
    final updated = event! as ConversationUpdatedEvent;
    expect(updated.lastMessageDigest, '');
  });

  test('gateway records inbound and decode-error telemetry for malformed frames', () async {
    final controller = StreamController<Object?>.broadcast();
    addTearDown(controller.close);
    final telemetry = _RecordingGatewayTelemetry();

    final gateway = SessionEventGateway(
      connect: (uri, {headers}) => _FakeSessionSocket(controller.stream),
      telemetry: telemetry,
    );

    final stream = await gateway.open(
      Uri.parse('ws://example.com?v=1&device_session_id=sess_decode_01'),
    );
    final failure = Completer<void>();
    final subscription = stream.listen(
      (_) {},
      onError: (_) {
        if (!failure.isCompleted) {
          failure.complete();
        }
      },
    );
    addTearDown(subscription.cancel);

    controller.add(Uint8List.fromList(<int>[0x01, 0x02, 0x03]));
    await failure.future.timeout(const Duration(seconds: 1));

    expect(telemetry.boundSessionIds, <String>['sess_decode_01']);
    expect(telemetry.inboundControlFrames, 1);
    expect(telemetry.decodeErrors, 1);
  });
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
  _ReadyAwareFakeSessionSocket({this.readyError})
    : stream = const Stream<Object?>.empty();

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

class _RecordingGatewayTelemetry implements SessionEventGatewayTelemetry {
  final List<String> boundSessionIds = <String>[];
  int inboundControlFrames = 0;
  int decodeErrors = 0;

  @override
  void bindSessionId(String sessionId) {
    boundSessionIds.add(sessionId);
  }

  @override
  void recordControlFrameDecodeError() {
    decodeErrors += 1;
  }

  @override
  void recordInboundControlFrame() {
    inboundControlFrames += 1;
  }
}
