import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukong_im_app/core/repositories/message_repository.dart';
import 'package:wukong_im_app/data/repositories/wk_message_repository.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'WkImChatHistoryGateway waits for history messages after sync start',
    () async {
      final completer = Completer<List<WKMsg>>();
      final expected = <WKMsg>[
        WKMsg()
          ..channelID = 'c1'
          ..channelType = 1
          ..messageSeq = 45
          ..orderSeq = 45000
          ..contentType = 1
          ..content = 'target',
      ];

      final gateway = WkImChatHistoryGateway(
        requestHistoryMessages:
            ({
              required String channelId,
              required int channelType,
              required int oldestOrderSeq,
              required bool contain,
              required int pullMode,
              required int limit,
              required int aroundOrderSeq,
              required void Function(List<WKMsg>) onResult,
              required void Function() onSyncStart,
            }) {
              onSyncStart();
              Future<void>.microtask(() {
                onResult(expected);
              });
            },
      );

      completer.complete(
        gateway.loadAroundOrderSeq(
          channelId: 'c1',
          channelType: 1,
          limit: 50,
          aroundOrderSeq: 45000,
        ),
      );

      expect(await completer.future, same(expected));
    },
  );

  test(
    'web direct history sync returns messages oldest to newest like local history',
    () async {
      final calls = <Map<String, Object>>[];
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        authTokenProvider: () => 'token-123',
        deviceUuidProvider: () => 'device-web-test',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async {
              calls.add(<String, Object>{
                'channel_id': channelId,
                'channel_type': channelType,
                'start_message_seq': startMessageSeq,
                'end_message_seq': endMessageSeq,
                'limit': limit,
                'pull_mode': pullMode,
                'device_uuid': deviceUuid,
              });
              return WKSyncChannelMsg()
                ..messages = <WKSyncMsg>[
                  WKSyncMsg()
                    ..clientMsgNO = 'client-001'
                    ..messageID = '9001'
                    ..messageSeq = 1
                    ..fromUID = 'u_sender'
                    ..channelID = 'u_target'
                    ..channelType = WKChannelType.personal
                    ..timestamp = 1777184000
                    ..payload = <String, dynamic>{
                      'content': 'older',
                      'type': 1,
                    },
                  WKSyncMsg()
                    ..clientMsgNO = 'client-002'
                    ..messageID = '9002'
                    ..messageSeq = 2
                    ..fromUID = 'u_sender'
                    ..channelID = 'u_target'
                    ..channelType = WKChannelType.personal
                    ..timestamp = 1777184100
                    ..payload = <String, dynamic>{
                      'content': 'newer',
                      'type': 1,
                    },
                ];
            },
      );

      final messages = await gateway.loadLatest(
        channelId: 'u_target',
        channelType: WKChannelType.personal,
        limit: 50,
      );

      expect(calls, hasLength(1));
      expect(calls.single['start_message_seq'], 0);
      expect(calls.single['end_message_seq'], 0);
      expect(calls.single['pull_mode'], 0);
      expect(calls.single['device_uuid'], 'device-web-test');
      expect(messages.map((message) => message.messageSeq), [1, 2]);
      expect(messages.last.content, contains('newer'));
    },
  );

  test(
    'web direct history sync skips remote call without authenticated token',
    () async {
      var syncCalled = false;
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        authTokenProvider: () => '',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async {
              syncCalled = true;
              return WKSyncChannelMsg();
            },
      );

      final messages = await gateway.loadLatest(
        channelId: 'u_target',
        channelType: WKChannelType.personal,
        limit: 50,
      );

      expect(messages, isEmpty);
      expect(syncCalled, isFalse);
    },
  );

  test(
    'native older history loading requests messages before the anchor',
    () async {
      final calls = <Map<String, Object>>[];
      final expected = <WKMsg>[
        WKMsg()
          ..channelID = 'g1001'
          ..channelType = WKChannelType.group
          ..messageSeq = 49
          ..orderSeq = 49000
          ..contentType = WkMessageContentType.text,
      ];
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: false,
        requestHistoryMessages:
            ({
              required String channelId,
              required int channelType,
              required int oldestOrderSeq,
              required bool contain,
              required int pullMode,
              required int limit,
              required int aroundOrderSeq,
              required void Function(List<WKMsg>) onResult,
              required void Function() onSyncStart,
            }) {
              calls.add(<String, Object>{
                'channel_id': channelId,
                'channel_type': channelType,
                'oldest_order_seq': oldestOrderSeq,
                'contain': contain,
                'pull_mode': pullMode,
                'limit': limit,
                'around_order_seq': aroundOrderSeq,
              });
              onResult(expected);
            },
      );

      final messages = await gateway.loadMore(
        channelId: 'g1001',
        channelType: WKChannelType.group,
        oldestOrderSeq: 50000,
        limit: 50,
      );

      expect(messages, same(expected));
      expect(calls, hasLength(1));
      expect(calls.single['oldest_order_seq'], 50000);
      expect(calls.single['contain'], isFalse);
      expect(calls.single['pull_mode'], 0);
      expect(calls.single['around_order_seq'], 0);
    },
  );

  test(
    'web direct older history sync requests messages before the anchor sequence',
    () async {
      final calls = <Map<String, Object>>[];
      final gateway = WkImChatHistoryGateway(
        useDirectRemoteSync: true,
        authTokenProvider: () => 'token-123',
        deviceUuidProvider: () => 'device-web-test',
        syncChannelMessages:
            ({
              required channelId,
              required channelType,
              required startMessageSeq,
              required endMessageSeq,
              required limit,
              required pullMode,
              required deviceUuid,
            }) async {
              calls.add(<String, Object>{
                'channel_id': channelId,
                'channel_type': channelType,
                'start_message_seq': startMessageSeq,
                'end_message_seq': endMessageSeq,
                'limit': limit,
                'pull_mode': pullMode,
                'device_uuid': deviceUuid,
              });
              return WKSyncChannelMsg()
                ..messages = <WKSyncMsg>[
                  WKSyncMsg()
                    ..clientMsgNO = 'client-049'
                    ..messageID = '9049'
                    ..messageSeq = 49
                    ..fromUID = 'u_sender'
                    ..channelID = 'g1001'
                    ..channelType = WKChannelType.group
                    ..timestamp = 1777184000
                    ..payload = <String, dynamic>{
                      'content': 'older',
                      'type': 1,
                    },
                ];
            },
      );

      final messages = await gateway.loadMore(
        channelId: 'g1001',
        channelType: WKChannelType.group,
        oldestOrderSeq: 50000,
        limit: 50,
      );

      expect(calls, hasLength(1));
      expect(calls.single['start_message_seq'], 49);
      expect(calls.single['end_message_seq'], 0);
      expect(calls.single['pull_mode'], 0);
      expect(calls.single['device_uuid'], 'device-web-test');
      expect(messages.map((message) => message.messageSeq), [49]);
    },
  );

  test(
    'WkMessageRepository delegates paging queries directly to gateway',
    () async {
      final gateway = _RecordingHistoryGateway();
      final repository = WkMessageRepository(gateway: gateway);

      await repository.loadLatest(
        const MessagePageQuery(channelId: 'c1', channelType: 1, limit: 10),
      );
      await repository.loadOlder(
        const MessagePageQuery(
          channelId: 'c1',
          channelType: 1,
          limit: 11,
          anchorOrderSeq: 900,
        ),
      );
      await repository.loadAround(
        const MessagePageQuery(
          channelId: 'c1',
          channelType: 1,
          limit: 12,
          anchorOrderSeq: 800,
        ),
      );

      expect(gateway.calls, <String>[
        'latest:c1:1:10',
        'older:c1:1:900:11',
        'around:c1:1:800:12',
      ]);
    },
  );
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
