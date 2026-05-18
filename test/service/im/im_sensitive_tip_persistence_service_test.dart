import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_sensitive_tip_persistence_service.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ImSensitiveTipPersistenceService', () {
    test(
      'waits for delay and skips persistence when database is not ready',
      () async {
        final events = <String>[];
        final tip = _tipMessage();
        final service = ImSensitiveTipPersistenceService(
          delay: (duration) async {
            events.add('delay:${duration.inSeconds}');
          },
          ensureDatabaseReady: () async {
            events.add('ready');
            return false;
          },
          orderSeqLoader: (messageSeq, channelId, channelType) async =>
              throw StateError('unreachable'),
          messageSaver: (_) async => throw StateError('unreachable'),
          conversationSaver: (message, redDot) async =>
              throw StateError('unreachable'),
          insertedPublisher: (_) => throw StateError('unreachable'),
          conversationRefreshPublisher: (_) => throw StateError('unreachable'),
        );

        await service.insertSensitiveWordTipMessage(tip);

        expect(events, <String>['delay:2', 'ready']);
        expect(tip.orderSeq, 0);
        expect(tip.clientSeq, 0);
      },
    );

    test(
      'assigns order and client sequence then refreshes conversation UI',
      () async {
        final tip = _tipMessage();
        final savedMessages = <WKMsg>[];
        final inserted = <WKMsg>[];
        final refreshed = <List<WKUIConversationMsg>>[];
        final uiMsg = WKUIConversationMsg()
          ..channelID = 'group-1'
          ..channelType = WKChannelType.group
          ..clientMsgNo = 'tip-client';
        final service = ImSensitiveTipPersistenceService(
          delay: (_) async {},
          ensureDatabaseReady: () async => true,
          orderSeqLoader: (messageSeq, channelId, channelType) async {
            expect(messageSeq, 0);
            expect(channelId, 'group-1');
            expect(channelType, WKChannelType.group);
            return 41;
          },
          messageSaver: (message) async {
            savedMessages.add(message);
            return 77;
          },
          conversationSaver: (message, redDot) async {
            expect(message, same(tip));
            expect(redDot, 0);
            return uiMsg;
          },
          insertedPublisher: inserted.add,
          conversationRefreshPublisher: refreshed.add,
        );

        await service.insertSensitiveWordTipMessage(tip);

        expect(tip.orderSeq, 42);
        expect(tip.clientSeq, 77);
        expect(savedMessages, <WKMsg>[tip]);
        expect(inserted, <WKMsg>[tip]);
        expect(refreshed, <List<WKUIConversationMsg>>[
          <WKUIConversationMsg>[uiMsg],
        ]);
      },
    );

    test(
      'skips conversation refresh when conversation save returns null',
      () async {
        final tip = _tipMessage();
        final inserted = <WKMsg>[];
        final refreshed = <List<WKUIConversationMsg>>[];
        final service = ImSensitiveTipPersistenceService(
          delay: (_) async {},
          ensureDatabaseReady: () async => true,
          orderSeqLoader: (messageSeq, channelId, channelType) async => 10,
          messageSaver: (_) async => 3,
          conversationSaver: (message, redDot) async => null,
          insertedPublisher: inserted.add,
          conversationRefreshPublisher: refreshed.add,
        );

        await service.insertSensitiveWordTipMessage(tip);

        expect(tip.orderSeq, 11);
        expect(tip.clientSeq, 3);
        expect(inserted, <WKMsg>[tip]);
        expect(refreshed, isEmpty);
      },
    );
  });
}

WKMsg _tipMessage() {
  return WKMsg()
    ..channelID = 'group-1'
    ..channelType = WKChannelType.group
    ..contentType = 901
    ..messageContent = WKTextContent('sensitive tip');
}
