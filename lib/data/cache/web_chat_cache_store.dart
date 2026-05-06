import 'package:wukongimfluttersdk/entity/msg.dart';

abstract interface class WebChatCacheStore {
  Future<List<WKMsg>> readMessages({
    required String channelId,
    required int channelType,
    required int limit,
    String uid = '',
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  });

  Future<void> upsertMessages({
    required String channelId,
    required int channelType,
    required List<WKMsg> messages,
    String uid = '',
  });

  Future<void> clearUser({required String uid});
}
