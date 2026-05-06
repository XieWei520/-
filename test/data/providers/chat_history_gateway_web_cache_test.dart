import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'web direct history sync writes successful remote latest page to cache',
    () async {
      final cache = MemoryWebChatCacheStore();
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        webCacheStore: cache,
        authTokenProvider: () => 'token',
        deviceUuidProvider: () => 'device-web-cache',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async => _syncResult('m1', 1),
      );

      await gateway.loadLatest(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );

      final cached = await cache.readMessages(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );
      expect(cached.single.messageID, 'm1');
    },
  );

  test(
    'web direct history sync writes successful remote page into active uid cache',
    () async {
      final cache = MemoryWebChatCacheStore();
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        webCacheStore: cache,
        uidProvider: () => 'u1',
        authTokenProvider: () => 'token',
        deviceUuidProvider: () => 'device-web-cache',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async => _syncResult('m1', 1),
      );

      await gateway.loadLatest(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );

      final activeUserCached = await cache.readMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );
      final legacyCached = await cache.readMessages(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );

      expect(activeUserCached.single.messageID, 'm1');
      expect(legacyCached, isEmpty);
    },
  );

  test(
    'web direct history sync falls back to cache when remote sync fails',
    () async {
      final cache = MemoryWebChatCacheStore();
      await cache.upsertMessages(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        messages: [
          WKMsg()
            ..messageID = 'cached'
            ..channelID = 'c1'
            ..channelType = WKChannelType.personal
            ..messageSeq = 7
            ..orderSeq = 7000
            ..contentType = 1,
        ],
      );
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        webCacheStore: cache,
        authTokenProvider: () => 'token',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async => throw StateError('network down'),
      );

      final messages = await gateway.loadLatest(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );

      expect(messages.single.messageID, 'cached');
    },
  );

  test(
    'web direct history sync falls back to active uid cache when remote sync fails',
    () async {
      final cache = MemoryWebChatCacheStore();
      await cache.upsertMessages(
        uid: 'u1',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        messages: [_cachedMessage('cached-u1', 7000)],
      );
      await cache.upsertMessages(
        uid: 'u2',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        messages: [_cachedMessage('cached-u2', 8000)],
      );
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        webCacheStore: cache,
        uidProvider: () => 'u2',
        authTokenProvider: () => 'token',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async => throw StateError('network down'),
      );

      final messages = await gateway.loadLatest(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );

      expect(messages.single.messageID, 'cached-u2');
    },
  );
}

WKMsg _cachedMessage(String messageId, int orderSeq) {
  return WKMsg()
    ..messageID = messageId
    ..channelID = 'c1'
    ..channelType = WKChannelType.personal
    ..messageSeq = orderSeq ~/ 1000
    ..orderSeq = orderSeq
    ..contentType = 1;
}

WKSyncChannelMsg _syncResult(String messageId, int messageSeq) {
  return WKSyncChannelMsg()
    ..messages = <WKSyncMsg>[
      WKSyncMsg()
        ..clientMsgNO = 'client-$messageId'
        ..messageID = messageId
        ..messageSeq = messageSeq
        ..fromUID = 'u_sender'
        ..channelID = 'c1'
        ..channelType = WKChannelType.personal
        ..timestamp = 1777184000
        ..payload = <String, dynamic>{'content': 'hello', 'type': 1},
    ];
}
