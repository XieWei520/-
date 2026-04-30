import 'package:wukongimfluttersdk/entity/msg.dart';

abstract interface class WebChatCacheStore {
  Future<List<WKMsg>> readMessages({
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  });

  Future<void> upsertMessages({
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
  });

  Future<void> clearUser({required String uid});
}
