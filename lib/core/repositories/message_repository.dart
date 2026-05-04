import 'package:wukongimfluttersdk/entity/msg.dart';

class MessagePageQuery {
  const MessagePageQuery({
    required this.channelId,
    required this.channelType,
    required this.limit,
    this.anchorOrderSeq = 0,
  });

  final String channelId;
  final int channelType;
  final int limit;
  final int anchorOrderSeq;

  int get safeLimit => limit <= 0 ? 20 : limit;
}

abstract interface class MessageRepository {
  Future<List<WKMsg>> loadLatest(MessagePageQuery query);

  Future<List<WKMsg>> loadOlder(MessagePageQuery query);

  Future<List<WKMsg>> loadAround(MessagePageQuery query);
}
