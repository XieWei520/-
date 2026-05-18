import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_word_runtime_filter_service.dart';
import 'package:wukong_im_app/service/im/im_word_sync_models.dart';
import 'package:wukong_im_app/service/im/im_word_sync_store.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ImWordRuntimeFilterService', () {
    test(
      'builds a local sensitive-word warning message from cached snapshot',
      () {
        final service = ImWordRuntimeFilterService(
          wordStore: _MemoryWordSyncStore(
            sensitiveSnapshot: const SensitiveWordsSnapshot(
              tips: 'local warning',
              version: 7,
              list: <String>['blocked'],
            ),
          ),
        );
        final message = WKMsg()
          ..channelID = 'group_01'
          ..channelType = WKChannelType.group
          ..fromUID = 'u_sender'
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('contains blocked text');

        final tip = service.buildSensitiveWordTipMessageIfNeeded(
          message,
          currentUid: 'u_self',
        );

        expect(tip, isNotNull);
        expect(tip!.channelID, 'group_01');
        expect(tip.channelType, WKChannelType.group);
        expect(tip.fromUID, 'u_self');
        expect(tip.contentType, MsgContentType.sensitiveWord);
        expect(tip.status, WKSendMsgResult.sendSuccess);
        expect(tip.header.redDot, isFalse);
        expect(jsonDecode(tip.content), <String, dynamic>{
          'content': 'local warning',
          'type': MsgContentType.sensitiveWord,
        });
      },
    );

    test('masks edited text before base text when prohibit words match', () {
      final service = ImWordRuntimeFilterService(
        wordStore: _MemoryWordSyncStore(
          prohibitWords: const <ProhibitWordEntry>[
            ProhibitWordEntry(
              sid: 101,
              content: 'secret',
              isDeleted: 0,
              version: 12,
              createdAt: '2026-04-11 12:00:00',
            ),
          ],
        ),
      );
      final message = WKMsg()
        ..channelID = 'group_01'
        ..channelType = WKChannelType.group
        ..fromUID = 'u_sender'
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('base secret');
      message.wkMsgExtra = WKMsgExtra()
        ..contentEdit = jsonEncode(<String, dynamic>{
          'type': WkMessageContentType.text,
          'content': 'secret edit',
        })
        ..messageContent = WKTextContent('secret edit');

      final changed = service.applyProhibitWordsToMessage(message);

      expect(changed, isTrue);
      expect(
        (message.wkMsgExtra!.messageContent as WKTextContent).content,
        '****** edit',
      );
      expect((message.messageContent as WKTextContent).content, 'base secret');
    });

    test('leaves non-text messages unchanged', () {
      final service = ImWordRuntimeFilterService(
        wordStore: _MemoryWordSyncStore(
          prohibitWords: const <ProhibitWordEntry>[
            ProhibitWordEntry(
              sid: 101,
              content: 'secret',
              isDeleted: 0,
              version: 12,
              createdAt: '2026-04-11 12:00:00',
            ),
          ],
        ),
      );
      final message = WKMsg()
        ..contentType = WkMessageContentType.image
        ..messageContent = WKTextContent('secret');

      expect(service.applyProhibitWordsToMessage(message), isFalse);
      expect(
        service.buildSensitiveWordTipMessageIfNeeded(
          message,
          currentUid: 'u_self',
        ),
        isNull,
      );
    });
  });
}

class _MemoryWordSyncStore implements ImWordSyncStore {
  _MemoryWordSyncStore({
    this.sensitiveSnapshot = const SensitiveWordsSnapshot(),
    this.prohibitWords = const <ProhibitWordEntry>[],
  });

  final SensitiveWordsSnapshot sensitiveSnapshot;
  final List<ProhibitWordEntry> prohibitWords;

  @override
  bool get usesLocalPersistence => false;

  @override
  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() => sensitiveSnapshot;

  @override
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {}

  @override
  Future<void> loadStoredWordCaches() async {}

  @override
  Future<int> getMaxProhibitWordVersion() async => 0;

  @override
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {}

  @override
  List<ProhibitWordEntry> resolveProhibitWords() => prohibitWords;
}
