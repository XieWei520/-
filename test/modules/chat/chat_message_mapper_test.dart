import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/wukong_crypto/e2ee/e2ee_message_codec.dart';
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

    test('does not cache non-structured text message revisions', () {
      final mapper = ChatMessageMapper(maxStructuredPayloadCacheEntries: 4);

      for (var i = 0; i < 10; i++) {
        final message = WKMsg()
          ..messageID = 'text-$i'
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('hello $i');

        mapper.map(message, currentUid: 'u_self');
      }

      expect(mapper.structuredPayloadCacheSizeForTesting, 0);
    });

    test('evicts least recently used structured payload cache entries', () {
      final mapper = ChatMessageMapper(maxStructuredPayloadCacheEntries: 2);
      final first = _structuredMessage('m1');
      final second = _structuredMessage('m2');
      final third = _structuredMessage('m3');

      final firstModel = mapper.map(first, currentUid: 'u_self');
      final secondModel = mapper.map(second, currentUid: 'u_self');
      final cachedFirstModel = mapper.map(first, currentUid: 'u_self');

      expect(
        identical(firstModel.structured, cachedFirstModel.structured),
        isTrue,
      );

      mapper.map(third, currentUid: 'u_self');
      final remappedSecondModel = mapper.map(second, currentUid: 'u_self');

      expect(mapper.structuredPayloadCacheSizeForTesting, 2);
      expect(
        identical(secondModel.structured, remappedSecondModel.structured),
        isFalse,
      );
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

    test('uses encrypted message fallback for E2EE structured payloads', () {
      final message = WKMsg()
        ..messageID = 'msg-e2ee'
        ..contentType = WkMessageContentType.unknown
        ..messageContent = WKUnknownContent()
        ..content =
            '{"type":${E2eeMessageCodec.encryptedContentType},'
            '"kind":"${E2eeMessageCodec.encryptedPayloadKind}",'
            '"fallback":"${E2eeMessageCodec.fallbackText}",'
            '"e2ee":{"v":1,"alg":"AES-256-GCM","kid":"kid","nonce":"n","ciphertext":"c","tag":"t"}}';

      final mapper = ChatMessageMapper();
      final model = mapper.map(message, currentUid: 'u_self');

      expect(model.preview, E2eeMessageCodec.fallbackText);
      expect(model.structured, isNotNull);
    });
  });
}

WKMsg _structuredMessage(String id) {
  return WKMsg()
    ..messageID = id
    ..contentType = WkMessageContentType.unknown
    ..messageContent = WKUnknownContent()
    ..content = '{"type":1001,"content":"hello $id"}';
}
