import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('conversation list message resolution', () {
    test('prefers a fresh database message over a cached sending snapshot', () {
      final cached = _buildMessage(
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendLoading,
      );
      final fresh = _buildMessage(
        clientMsgNo: 'client-101',
        status: WKSendMsgResult.sendSuccess,
        messageId: 'msg-101',
        messageSeq: 101,
        orderSeq: 10001,
      );

      final resolved = resolveConversationListMessageSnapshot(
        cachedMessage: cached,
        freshMessage: fresh,
      );

      expect(resolved, isNotNull);
      expect(resolved!.status, WKSendMsgResult.sendSuccess);
      expect(resolved.messageID, 'msg-101');
    });

    test('falls back to the cached snapshot when no fresh message exists', () {
      final cached = _buildMessage(
        clientMsgNo: 'client-102',
        status: WKSendMsgResult.sendLoading,
      );

      final resolved = resolveConversationListMessageSnapshot(
        cachedMessage: cached,
        freshMessage: null,
      );

      expect(resolved, same(cached));
      expect(resolved!.status, WKSendMsgResult.sendLoading);
    });
  });
}

WKMsg _buildMessage({
  required String clientMsgNo,
  required int status,
  String messageId = '',
  int messageSeq = 0,
  int orderSeq = 0,
}) {
  return WKMsg()
    ..clientMsgNO = clientMsgNo
    ..channelID = 'u_target'
    ..channelType = WKChannelType.personal
    ..fromUID = 'u_self'
    ..status = status
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..orderSeq = orderSeq
    ..contentType = WkMessageContentType.text
    ..content = '{"content":"hello","type":1}';
}
