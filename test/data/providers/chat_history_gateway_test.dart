import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
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
}
