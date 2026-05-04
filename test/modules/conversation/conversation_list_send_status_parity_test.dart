import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('Android conversation send status parity', () {
    test(
      'uses single tick when receipt is disabled even if readed count is greater than zero',
      () {
        final msg = _buildSelfMessage(
          status: WKSendMsgResult.sendSuccess,
          receipt: 0,
          readedCount: 3,
        );

        final sendStatus = resolveConversationSendStatus(
          msg,
          currentUid: 'u_self',
        );

        expect(sendStatus.showSingleTick, isTrue);
        expect(sendStatus.showDoubleTick, isFalse);
        expect(sendStatus.showSending, isFalse);
        expect(sendStatus.showSendFailed, isFalse);
      },
    );

    test('uses double tick only when receipt is enabled and the message is read', () {
      final msg = _buildSelfMessage(
        status: WKSendMsgResult.sendSuccess,
        receipt: 1,
        readedCount: 2,
      );

      final sendStatus = resolveConversationSendStatus(
        msg,
        currentUid: 'u_self',
      );

      expect(sendStatus.showSingleTick, isFalse);
      expect(sendStatus.showDoubleTick, isTrue);
        expect(sendStatus.showSending, isFalse);
      expect(sendStatus.showSendFailed, isFalse);
    });

    test('hides send status for received or deleted messages', () {
      final received = _buildSelfMessage(
        fromUid: 'u_other',
        status: WKSendMsgResult.sendSuccess,
        receipt: 1,
        readedCount: 5,
      );
      final deleted = _buildSelfMessage(
        status: WKSendMsgResult.sendSuccess,
        receipt: 1,
        readedCount: 5,
        isDeleted: 1,
      );

      final receivedStatus = resolveConversationSendStatus(
        received,
        currentUid: 'u_self',
      );
      final deletedStatus = resolveConversationSendStatus(
        deleted,
        currentUid: 'u_self',
      );

      expect(receivedStatus.showSingleTick, isFalse);
      expect(receivedStatus.showDoubleTick, isFalse);
      expect(receivedStatus.showSending, isFalse);
      expect(receivedStatus.showSendFailed, isFalse);
      expect(deletedStatus.showSingleTick, isFalse);
      expect(deletedStatus.showDoubleTick, isFalse);
      expect(deletedStatus.showSending, isFalse);
      expect(deletedStatus.showSendFailed, isFalse);
    });
  });
}

WKMsg _buildSelfMessage({
  String fromUid = 'u_self',
  required int status,
  required int receipt,
  required int readedCount,
  int isDeleted = 0,
}) {
  return WKMsg()
    ..fromUID = fromUid
    ..status = status
    ..isDeleted = isDeleted
    ..setting.receipt = receipt
    ..wkMsgExtra = (WKMsgExtra()..readedCount = readedCount);
}
