import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/repositories/message_repository.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukong_im_app/data/repositories/wk_message_repository.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test(
    'WkMessageRepository delegates latest, older, and around queries',
    () async {
      final gateway = _RecordingHistoryGateway();
      final repository = WkMessageRepository(gateway: gateway);

      await repository.loadLatest(
        const MessagePageQuery(channelId: 'u1', channelType: 1, limit: 20),
      );
      await repository.loadOlder(
        const MessagePageQuery(
          channelId: 'u1',
          channelType: 1,
          limit: 30,
          anchorOrderSeq: 9000,
        ),
      );
      await repository.loadAround(
        const MessagePageQuery(
          channelId: 'u1',
          channelType: 1,
          limit: 40,
          anchorOrderSeq: 8800,
        ),
      );

      expect(gateway.calls, <String>[
        'latest:u1:1:20',
        'older:u1:1:9000:30',
        'around:u1:1:8800:40',
      ]);
    },
  );

  test('MessagePageQuery normalizes unsafe limits for repository callers', () {
    const query = MessagePageQuery(channelId: 'u1', channelType: 1, limit: -1);

    expect(query.safeLimit, 20);
  });
}

class _RecordingHistoryGateway implements ChatHistoryGateway {
  final List<String> calls = <String>[];

  @override
  Future<List<WKMsg>> loadAroundOrderSeq({
    required String channelId,
    required int channelType,
    required int limit,
    required int aroundOrderSeq,
  }) async {
    calls.add('around:$channelId:$channelType:$aroundOrderSeq:$limit');
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadLatest({
    required String channelId,
    required int channelType,
    required int limit,
  }) async {
    calls.add('latest:$channelId:$channelType:$limit');
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadMore({
    required String channelId,
    required int channelType,
    required int oldestOrderSeq,
    required int limit,
  }) async {
    calls.add('older:$channelId:$channelType:$oldestOrderSeq:$limit');
    return const <WKMsg>[];
  }
}
