import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/control/control_proto_codec.dart';
import 'package:wukong_im_app/realtime/session/session_event_gateway.dart';

void main() {
  test(
    'decodes protobuf envelope with shared schema fields for conversation.updated',
    () {
      final payload = utf8.encode(
        jsonEncode(<String, dynamic>{
          'aggregate_id': '1:u_2001',
          'channel_id': 'u_2001',
          'channel_type': 1,
          'unread_count': 2,
          'last_message_digest': 'protobuf',
          'sort_timestamp': 18888,
        }),
      );

      final encoded = ControlProtoCodec.encodeEnvelope(
        eventSeq: 42,
        eventType: 'conversation.updated',
        payload: Uint8List.fromList(payload),
        ackSeq: 21,
        deviceId: 'android-device-01',
        issuedAtMs: 1712000000123,
      );

      final envelope = ControlProtoCodec.decodeEnvelope(encoded);
      final frame = ControlProtoCodec.toSessionEventFrame(envelope);
      final event = mapSessionControlEvent(frame);

      expect(envelope.eventSeq, 42);
      expect(envelope.eventType, 'conversation.updated');
      expect(envelope.ackSeq, 21);
      expect(envelope.deviceId, 'android-device-01');
      expect(envelope.issuedAtMs, 1712000000123);
      expect(frame.userSeq, 42);
      expect(frame.kind, 'conversation.updated');
      expect(event, isA<ConversationUpdatedEvent>());
      final updated = event! as ConversationUpdatedEvent;
      expect(updated.channelId, 'u_2001');
      expect(updated.channelType, 1);
      expect(updated.unreadCount, 2);
      expect(updated.lastMessageDigest, 'protobuf');
      expect(updated.sortTimestamp, 18888);
    },
  );

  test('maps protobuf issued_at_ms to session frame serverTs fallback', () {
    final payload = utf8.encode(
      jsonEncode(<String, dynamic>{
        'aggregate_id': '1:u_2001',
        'channel_id': 'u_2001',
        'channel_type': 1,
        'unread_count': 2,
        'last_message_digest': 'protobuf',
        'sort_timestamp': 18888,
      }),
    );

    final encoded = ControlProtoCodec.encodeEnvelope(
      eventSeq: 42,
      eventType: 'conversation.updated',
      payload: Uint8List.fromList(payload),
      ackSeq: 21,
      deviceId: 'ios-device-01',
      issuedAtMs: 1712000005123,
    );

    final envelope = ControlProtoCodec.decodeEnvelope(encoded);
    final frame = ControlProtoCodec.toSessionEventFrame(envelope);

    expect(frame.eventId, 'proto_42_conversation.updated');
    expect(frame.userSeq, 42);
    expect(frame.serverTs, 1712000005);
  });

  test(
    'prefers protobuf v2 top-level identity fields over payload aliases',
    () {
      final payload = utf8.encode(
        jsonEncode(<String, dynamic>{
          'event_id': 'evt_from_payload',
          'aggregate_id': '1:u_from_payload',
          'server_ts': 1712000008,
          'channel_id': 'u_2002',
          'channel_type': 1,
        }),
      );

      final encoded = ControlProtoCodec.encodeEnvelope(
        eventSeq: 44,
        eventType: 'conversation.updated',
        payload: Uint8List.fromList(payload),
        ackSeq: 23,
        eventId: 'evt_top_level',
        aggregateId: '1:u_top_level',
        schemaVersion: 2,
      );

      final envelope = ControlProtoCodec.decodeEnvelope(encoded);
      final frame = ControlProtoCodec.toSessionEventFrame(envelope);

      expect(envelope.eventId, 'evt_top_level');
      expect(envelope.aggregateId, '1:u_top_level');
      expect(envelope.schemaVersion, 2);
      expect(frame.eventId, 'evt_top_level');
      expect(frame.aggregateId, '1:u_top_level');
      expect(frame.payload['event_id'], 'evt_from_payload');
    },
  );

  test('decodes protobuf envelope for session.kicked kind', () {
    final payload = utf8.encode(
      jsonEncode(<String, dynamic>{
        'aggregate_id': 'u_2001',
        'reason': 'inactive',
      }),
    );

    final encoded = ControlProtoCodec.encodeEnvelope(
      eventSeq: 43,
      eventType: 'session.kicked',
      payload: Uint8List.fromList(payload),
      ackSeq: 22,
    );

    final envelope = ControlProtoCodec.decodeEnvelope(encoded);
    final frame = ControlProtoCodec.toSessionEventFrame(envelope);

    expect(envelope.eventType, 'session.kicked');
    expect(frame.userSeq, 43);
    expect(frame.kind, 'session.kicked');
  });
}
