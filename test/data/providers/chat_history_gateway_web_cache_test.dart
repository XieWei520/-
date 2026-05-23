import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/cache/web_chat_cache_store_memory.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestWidgetsFlutterBinding.ensureInitialized();
    await StorageUtils.init();
  });

  test(
    'web direct history sync writes successful remote latest page to cache for the current uid',
    () async {
      await StorageUtils.setUid('uid-a');
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

      final cachedForCurrentUid = await cache.readMessages(
        uid: 'uid-a',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );
      final cachedForOtherUid = await cache.readMessages(
        uid: 'uid-b',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        limit: 20,
      );
      expect(cachedForCurrentUid.single.messageID, 'm1');
      expect(cachedForOtherUid, isEmpty);
    },
  );

  test(
    'web direct history sync falls back to cache when remote sync fails for the current uid',
    () async {
      await StorageUtils.setUid('uid-a');
      final cache = MemoryWebChatCacheStore();
      await cache.upsertMessages(
        uid: 'uid-a',
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
    'web direct older history fallback reads cached messages before the oldest visible message',
    () async {
      await StorageUtils.setUid('uid-a');
      final cache = MemoryWebChatCacheStore();
      await cache.upsertMessages(
        uid: 'uid-a',
        channelId: 'c1',
        channelType: WKChannelType.personal,
        messages: [
          for (final seq in <int>[48, 49, 50, 51])
            WKMsg()
              ..messageID = 'm$seq'
              ..channelID = 'c1'
              ..channelType = WKChannelType.personal
              ..messageSeq = seq
              ..orderSeq = seq * 1000
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

      final messages = await gateway.loadMore(
        channelId: 'c1',
        channelType: WKChannelType.personal,
        oldestOrderSeq: 50000,
        limit: 20,
      );

      expect(messages.map((message) => message.messageSeq), [48, 49]);
    },
  );
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
