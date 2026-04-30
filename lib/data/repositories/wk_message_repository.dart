import '../../core/repositories/message_repository.dart';
import '../providers/chat_history_gateway.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class WkMessageRepository implements MessageRepository {
  WkMessageRepository({ChatHistoryGateway? gateway})
    : _gateway = gateway ?? WkImChatHistoryGateway();

  final ChatHistoryGateway _gateway;

  @override
  Future<List<WKMsg>> loadLatest(MessagePageQuery query) {
    return _gateway.loadLatest(
      channelId: query.channelId,
      channelType: query.channelType,
      limit: query.safeLimit,
    );
  }

  @override
  Future<List<WKMsg>> loadOlder(MessagePageQuery query) {
    return _gateway.loadMore(
      channelId: query.channelId,
      channelType: query.channelType,
      oldestOrderSeq: query.anchorOrderSeq,
      limit: query.safeLimit,
    );
  }

  @override
  Future<List<WKMsg>> loadAround(MessagePageQuery query) {
    return _gateway.loadAroundOrderSeq(
      channelId: query.channelId,
      channelType: query.channelType,
      aroundOrderSeq: query.anchorOrderSeq,
      limit: query.safeLimit,
    );
  }
}
