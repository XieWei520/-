import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatMessageMapper', () {
    test('prefers messageID for stable identity', () {
      final message = WKMsg()
        ..messageID = 'msg-1'
        ..clientMsgNO = 'client-1'
        ..orderSeq = 10;

      expect(chatMessageIdentity(message), 'mid:msg-1');
    });

    test('falls back to clientMsgNO when messageID is empty', () {
      final message = WKMsg()
        ..messageID = ''
        ..clientMsgNO = 'client-1'
        ..orderSeq = 10;

      expect(chatMessageIdentity(message), 'cid:client-1');
    });

    test('falls back to seq identity when ids are empty', () {
      final message = WKMsg()
        ..messageID = ''
        ..clientMsgNO = ''
        ..orderSeq = 10
        ..messageSeq = 11
        ..timestamp = 12;

      expect(chatMessageIdentity(message), 'seq:10:11:12');
    });

    test('parses structured payload only once for equal revision', () {
      final message = WKMsg()
        ..messageID = 'msg-structured'
        ..contentType = WkMessageContentType.unknown
        ..messageContent = WKUnknownContent()
        ..content = '{"type":1001,"content":"hello"}'
        ..timestamp = 1700000000;

      final mapper = ChatMessageMapper();
      final first = mapper.map(message, currentUid: 'u_self');
      final second = mapper.map(message, currentUid: 'u_self');

      expect(first.revision, equals(second.revision));
      expect(first.preview, isNotEmpty);
      expect(first.system, isA<bool>());
      expect(first.self, isA<bool>());
      expect(identical(first.structured, second.structured), isTrue);
    });

    test('does not mark blank sender as self when current uid is blank', () {
      final message = WKMsg()
        ..fromUID = ''
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('hello');

      final mapper = ChatMessageMapper();
      final model = mapper.map(message, currentUid: '');

      expect(model.self, isFalse);
    });

    test(
      'invalidates structured cache when decode eligibility fields change',
      () {
        final message = WKMsg()
          ..messageID = 'msg-revision'
          ..contentType = WkMessageContentType.unknown
          ..messageContent = WKUnknownContent()
          ..content = '{"type":1001,"content":"hello"}';

        final mapper = ChatMessageMapper();
        final first = mapper.map(message, currentUid: 'u_self');
        expect(first.structured, isNotNull);

        message.contentType = WkMessageContentType.text;
        message.messageContent = WKTextContent('hello');
        final second = mapper.map(message, currentUid: 'u_self');
        expect(second.revision, isNot(equals(first.revision)));
        expect(second.structured, isNull);
      },
    );
  });
}
