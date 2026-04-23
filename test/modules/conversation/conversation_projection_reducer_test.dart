import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection_reducer.dart';

void main() {
  group('conversation projection reducer', () {
    test('applies unread and last message patch without replacing list', () {
      final reducer = ConversationProjectionReducer();
      final seed = [
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'old',
        ),
      ];

      final next = reducer.reduce(
        seed,
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 3,
          lastMessageDigest: 'new',
          sortTimestamp: 200,
        ),
      );

      expect(identical(seed, next), isFalse);
      expect(next.single.unreadCount, 3);
      expect(next.single.lastMessageDigest, 'new');
      expect(next.single.sortTimestamp, 200);
    });

    test('reorders by sort timestamp for non-top conversations', () {
      final reducer = ConversationProjectionReducer();
      final seed = [
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'a',
        ),
        const ConversationProjection(
          channelId: 'u_1002',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 300,
          lastMessageDigest: 'b',
        ),
      ];

      final next = reducer.reduce(
        seed,
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 1,
          lastMessageDigest: 'a2',
          sortTimestamp: 400,
        ),
      );

      expect(next.first.channelId, 'u_1001');
      expect(next.first.sortTimestamp, 400);
    });

    test('applies top and mute patch then keeps top item first', () {
      final reducer = ConversationProjectionReducer();
      final seed = [
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 500,
          lastMessageDigest: 'a',
        ),
        const ConversationProjection(
          channelId: 'u_1002',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'b',
        ),
      ];

      final next = reducer.reduce(
        seed,
        const ConversationPatch.flags(
          channelId: 'u_1002',
          channelType: 1,
          isTop: true,
          isMuted: true,
        ),
      );

      expect(next.first.channelId, 'u_1002');
      expect(next.first.isTop, isTrue);
      expect(next.first.isMuted, isTrue);
    });

    test('supports partial field patch without forcing old values', () {
      final reducer = ConversationProjectionReducer();
      final seed = [
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 4,
          sortTimestamp: 500,
          lastMessageDigest: 'digest',
          isTop: true,
          isMuted: false,
        ),
      ];

      final next = reducer.reduce(
        seed,
        const ConversationPatch(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 9,
        ),
      );

      expect(next.single.unreadCount, 9);
      expect(next.single.lastMessageDigest, 'digest');
      expect(next.single.sortTimestamp, 500);
      expect(next.single.isTop, isTrue);
      expect(next.single.isMuted, isFalse);
    });
  });
}
