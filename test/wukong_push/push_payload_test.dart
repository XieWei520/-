import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/models/push_models.dart';

void main() {
  group('PushPayload parsing', () {
    test('parses channel metadata regardless of key casing', () {
      final payload = PushPayload.fromMap({
        'channel_id': 'g_123',
        'channelType': '2',
        'messageId': 'mid_1',
        'sender_uid': 'u_1',
        'title': 'Title',
        'body': 'Body',
      });

      expect(payload.channelId, 'g_123');
      expect(payload.channelType, 2);
      expect(payload.messageId, 'mid_1');
      expect(payload.senderUid, 'u_1');
      expect(payload.hasConversationTarget, isTrue);
    });

    test('roundtrips through encode/decode', () {
      final source = PushPayload.fromMap({
        'channel_id': 'c1',
        'channel_type': 1,
        'message_id': 'm1',
        'title': 'Hello',
        'body': 'World',
      });

      final encoded = source.encode();
      final decoded = PushPayload.fromEncoded(encoded);

      expect(decoded.channelId, source.channelId);
      expect(decoded.channelType, source.channelType);
      expect(decoded.messageId, source.messageId);
      expect(decoded.title, source.title);
      expect(decoded.body, source.body);
      expect(decoded.raw, source.raw);
    });

    test('trims text fields and treats blank identifiers as absent', () {
      final payload = PushPayload.fromMap({
        'channel_id': '   ',
        'channel_type': '1',
        'message_id': ' mid_2 ',
        'sender_uid': ' u_2 ',
        'title': '  Alice  ',
        'body': '   ',
      });

      expect(payload.channelId, isNull);
      expect(payload.channelType, 1);
      expect(payload.messageId, 'mid_2');
      expect(payload.senderUid, 'u_2');
      expect(payload.title, 'Alice');
      expect(payload.body, isNull);
      expect(payload.hasConversationTarget, isFalse);
    });
  });

  group('PushMessageEvent', () {
    test('openedFromNotification only true for tap/initial triggers', () {
      final payload = PushPayload.fromMap({
        'channel_id': 'c1',
        'channel_type': 1,
      });

      final foreground = PushMessageEvent(
        payload: payload,
        data: payload.raw,
        trigger: PushMessageTrigger.foreground,
      );
      final tap = PushMessageEvent(
        payload: payload,
        data: payload.raw,
        trigger: PushMessageTrigger.tap,
      );

      expect(foreground.openedFromNotification, isFalse);
      expect(tap.openedFromNotification, isTrue);
    });
  });
}
