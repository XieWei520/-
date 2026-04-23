import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/chat_history_gateway.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

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
        requestHistoryMessages: ({
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
}
