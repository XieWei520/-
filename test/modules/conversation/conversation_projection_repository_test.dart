import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection_reducer.dart';
import 'package:wukong_im_app/modules/conversation/conversation_projection_repository.dart';

void main() {
  group('conversation projection repository', () {
    test('seed stores sorted snapshot', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );

      repository.seed([
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
      ]);

      expect(repository.snapshot.first.channelId, 'u_1002');
      expect(repository.snapshot.last.channelId, 'u_1001');
    });

    test('apply updates unread and digest on snapshot', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );
      repository.seed([
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'old',
        ),
      ]);

      repository.apply(
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 8,
          lastMessageDigest: 'new',
          sortTimestamp: 200,
        ),
      );

      final item = repository.snapshot.single;
      expect(item.unreadCount, 8);
      expect(item.lastMessageDigest, 'new');
      expect(item.sortTimestamp, 200);
    });

    test('apply top and mute patch keeps top item before others', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );
      repository.seed([
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
      ]);

      repository.apply(
        const ConversationPatch.flags(
          channelId: 'u_1002',
          channelType: 1,
          isTop: true,
          isMuted: true,
        ),
      );

      expect(repository.snapshot.first.channelId, 'u_1002');
      expect(repository.snapshot.first.isTop, isTrue);
      expect(repository.snapshot.first.isMuted, isTrue);
    });

    test('snapshot is immutable to callers', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );
      repository.seed([
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'a',
        ),
      ]);

      expect(
        () => repository.snapshot.add(
          const ConversationProjection(
            channelId: 'u_1002',
            channelType: 1,
            unreadCount: 0,
            sortTimestamp: 200,
            lastMessageDigest: 'b',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(repository.snapshot.length, 1);
    });

    test('unknown conversation patch is replayed after seed', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );

      repository.apply(
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 5,
          lastMessageDigest: 'new',
          sortTimestamp: 300,
        ),
      );

      expect(repository.snapshot, isEmpty);

      repository.seed([
        const ConversationProjection(
          channelId: 'u_1001',
          channelType: 1,
          unreadCount: 0,
          sortTimestamp: 100,
          lastMessageDigest: 'old',
        ),
      ]);

      final item = repository.snapshot.single;
      expect(item.unreadCount, 5);
      expect(item.lastMessageDigest, 'new');
      expect(item.sortTimestamp, 300);
    });

    test(
      'creates projection immediately for bootstrap patch after first seed',
      () {
        final repository = ConversationProjectionRepository(
          ConversationProjectionReducer(),
        );
        repository.seed(const []);

        repository.apply(
          const ConversationPatch.unreadAndDigest(
            channelId: 'u_2001',
            channelType: 1,
            unreadCount: 2,
            lastMessageDigest: 'hello',
            sortTimestamp: 500,
          ),
        );

        final item = repository.snapshot.single;
        expect(item.channelId, 'u_2001');
        expect(item.channelType, 1);
        expect(item.unreadCount, 2);
        expect(item.lastMessageDigest, 'hello');
        expect(item.sortTimestamp, 500);
      },
    );

    test('replays same-key pending patches after bootstrap creation', () {
      final repository = ConversationProjectionRepository(
        ConversationProjectionReducer(),
      );
      repository.seed(const []);

      repository.apply(
        const ConversationPatch.flags(
          channelId: 'u_3001',
          channelType: 1,
          isTop: true,
          isMuted: true,
        ),
      );

      repository.apply(
        const ConversationPatch.unreadAndDigest(
          channelId: 'u_3001',
          channelType: 1,
          unreadCount: 7,
          lastMessageDigest: 'digest',
          sortTimestamp: 800,
        ),
      );

      final item = repository.snapshot.single;
      expect(item.channelId, 'u_3001');
      expect(item.unreadCount, 7);
      expect(item.lastMessageDigest, 'digest');
      expect(item.sortTimestamp, 800);
      expect(item.isTop, isTrue);
      expect(item.isMuted, isTrue);
    });
  });
}
