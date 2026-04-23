import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('conversation message reconciliation', () {
    test('refresh upgrades the existing pending message in place', () {
      final newest = _buildMessage(
        clientSeq: 200,
        clientMsgNo: 'latest-msg',
        messageId: 'msg-latest',
        messageSeq: 20,
        orderSeq: 20000,
        status: WKSendMsgResult.sendSuccess,
        text: 'latest',
      );
      final pending = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
        text: 'hello',
      );
      final older = _buildMessage(
        clientSeq: 50,
        clientMsgNo: 'older-msg',
        messageId: 'msg-older',
        messageSeq: 10,
        orderSeq: 10000,
        status: WKSendMsgResult.sendSuccess,
        text: 'older',
      );
      final refreshed = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        messageId: 'msg-101',
        messageSeq: 11,
        orderSeq: 11000,
        status: WKSendMsgResult.sendSuccess,
        text: 'hello',
      );

      final messages = refreshConversationMessages([
        newest,
        pending,
        older,
      ], refreshed);

      expect(messages, hasLength(3));
      expect(messages[0].clientMsgNO, 'latest-msg');
      expect(messages[1].messageID, 'msg-101');
      expect(messages[1].status, WKSendMsgResult.sendSuccess);
      expect(messages[2].messageID, 'msg-older');
    });

    test(
      'merge keeps only one record when same client message is refreshed',
      () {
        final pending = _buildMessage(
          clientSeq: 101,
          clientMsgNo: 'client-101',
          status: WKSendMsgResult.sendLoading,
          text: 'hello',
        );
        final refreshed = _buildMessage(
          clientSeq: 101,
          clientMsgNo: 'client-101',
          messageId: 'msg-101',
          messageSeq: 11,
          orderSeq: 11000,
          status: WKSendMsgResult.sendSuccess,
          text: 'hello',
        );

        final messages = mergeConversationMessages([pending, refreshed]);

        expect(messages, hasLength(1));
        expect(messages.single.messageID, 'msg-101');
        expect(messages.single.status, WKSendMsgResult.sendSuccess);
      },
    );

    test('merge ignores deleted duplicate packets from the sdk', () {
      final pending = _buildMessage(
        clientSeq: 101,
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
        text: 'hello',
      );
      final deletedDuplicate = _buildMessage(
        clientSeq: 202,
        clientMsgNo: 'duplicate-202',
        messageId: 'msg-101',
        messageSeq: 11,
        orderSeq: 11000,
        status: WKSendMsgResult.sendSuccess,
        isDeleted: 1,
        text: 'hello',
      );

      final messages = mergeConversationMessages([deletedDuplicate, pending]);

      expect(messages, hasLength(1));
      expect(messages.single.clientMsgNO, 'client-101');
      expect(messages.single.messageID, isEmpty);
      expect(messages.single.status, WKSendMsgResult.sendLoading);
    });

    test('refresh prefers newer revoke extra version over cached body', () {
      final cached = _buildMessage(
        clientSeq: 301,
        clientMsgNo: 'client-301',
        messageId: 'msg-301',
        messageSeq: 31,
        orderSeq: 31000,
        status: WKSendMsgResult.sendSuccess,
        text: 'revoke-003',
      )..wkMsgExtra = (WKMsgExtra()
        ..messageID = 'msg-301'
        ..revoke = 0
        ..extraVersion = 100);

      final refreshed = _buildMessage(
        clientSeq: 301,
        clientMsgNo: 'client-301',
        messageId: 'msg-301',
        messageSeq: 31,
        orderSeq: 31000,
        status: WKSendMsgResult.sendSuccess,
        text: 'revoke-003',
      )..wkMsgExtra = (WKMsgExtra()
        ..messageID = 'msg-301'
        ..revoke = 1
        ..revoker = 'u_me'
        ..extraVersion = 200);

      final messages = refreshConversationMessages([cached], refreshed);

      expect(messages, hasLength(1));
      expect(messages.single.wkMsgExtra?.revoke, 1);
      expect(messages.single.wkMsgExtra?.extraVersion, 200);
    });
  });
}

WKMsg _buildMessage({
  required int clientSeq,
  required String clientMsgNo,
  String channelId = 'u_target',
  int channelType = WKChannelType.personal,
  String fromUid = 'u_me',
  String messageId = '',
  int messageSeq = 0,
  int orderSeq = 0,
  int status = WKSendMsgResult.sendLoading,
  int isDeleted = 0,
  required String text,
}) {
  return WKMsg()
    ..clientSeq = clientSeq
    ..clientMsgNO = clientMsgNo
    ..channelID = channelId
    ..channelType = channelType
    ..fromUID = fromUid
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..orderSeq = orderSeq
    ..status = status
    ..isDeleted = isDeleted
    ..contentType = WkMessageContentType.text
    ..content = '{"content":"$text","type":1}';
}
