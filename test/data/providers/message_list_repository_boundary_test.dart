import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/repositories/message_repository.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

void main() {
  test('MessageListNotifier loads pages through MessageRepository', () async {
    final repository = _RecordingMessageRepository();
    final notifier = MessageListNotifier(
      'c1',
      1,
      messageRepository: repository,
      autoLoad: false,
    );
    addTearDown(notifier.dispose);

    repository.latest = [
      WKMsg()
        ..messageID = 'm1'
        ..orderSeq = 1000
        ..contentType = 1,
      WKMsg()
        ..messageID = 'm2'
        ..orderSeq = 2000
        ..contentType = 1,
    ];

    await notifier.loadMessages();
    await notifier.loadAroundOrderSeq(1500);
    await notifier.loadMore();

    expect(repository.calls, <String>[
      'latest:c1:1:50',
      'around:c1:1:1500:50',
      'older:c1:1:1000:50',
    ]);
  });
}

class _RecordingMessageRepository implements MessageRepository {
  final List<String> calls = <String>[];
  List<WKMsg> latest = const <WKMsg>[];

  @override
  Future<List<WKMsg>> loadAround(MessagePageQuery query) async {
    calls.add(
      'around:${query.channelId}:${query.channelType}:${query.anchorOrderSeq}:${query.safeLimit}',
    );
    return latest;
  }

  @override
  Future<List<WKMsg>> loadLatest(MessagePageQuery query) async {
    calls.add(
      'latest:${query.channelId}:${query.channelType}:${query.safeLimit}',
    );
    return latest;
  }

  @override
  Future<List<WKMsg>> loadOlder(MessagePageQuery query) async {
    calls.add(
      'older:${query.channelId}:${query.channelType}:${query.anchorOrderSeq}:${query.safeLimit}',
    );
    return const <WKMsg>[];
  }
}
