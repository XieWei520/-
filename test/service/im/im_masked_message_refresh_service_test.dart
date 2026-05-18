import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/im_masked_message_refresh_service.dart';
import 'package:wukong_im_app/service/im/im_word_runtime_filter_service.dart';
import 'package:wukong_im_app/service/im/im_word_sync_models.dart';
import 'package:wukong_im_app/service/im/im_word_sync_store.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ImMaskedMessageRefreshService', () {
    test('skips refresh when the local database is not ready', () async {
      var loadedClientMsgNos = false;
      final service = ImMaskedMessageRefreshService(
        wordRuntimeFilterService: _runtimeFilterService(),
        ensureDatabaseReady: () async => false,
        loadTextMessageClientMsgNos: () async {
          loadedClientMsgNos = true;
          return const <String>['client-1'];
        },
        loadMessageByClientMsgNo: (_) async => throw StateError('unreachable'),
        publishMessageRefresh: (_) => throw StateError('unreachable'),
      );

      await service.refreshAfterProhibitWordSync();

      expect(loadedClientMsgNos, isFalse);
    });

    test(
      'publishes refresh only for text messages changed by prohibit words',
      () async {
        final messages = <String, WKMsg>{
          'client-1': _textMessage('client-1', 'hello secret'),
          'client-2': _textMessage('client-2', 'already clean'),
          'client-3': _textMessage('client-3', 'another secret'),
        };
        final published = <WKMsg>[];
        final service = ImMaskedMessageRefreshService(
          wordRuntimeFilterService: _runtimeFilterService(),
          ensureDatabaseReady: () async => true,
          loadTextMessageClientMsgNos: () async {
            return const <String>[
              'client-1',
              '',
              'client-missing',
              'client-2',
              'client-3',
            ];
          },
          loadMessageByClientMsgNo: (clientMsgNo) async {
            return messages[clientMsgNo];
          },
          publishMessageRefresh: published.add,
        );

        await service.refreshAfterProhibitWordSync();

        expect(published.map((message) => message.clientMsgNO), <String>[
          'client-1',
          'client-3',
        ]);
        expect(
          (messages['client-1']!.messageContent as WKTextContent).content,
          'hello ******',
        );
        expect(
          (messages['client-2']!.messageContent as WKTextContent).content,
          'already clean',
        );
        expect(
          (messages['client-3']!.messageContent as WKTextContent).content,
          'another ******',
        );
      },
    );
  });
}

ImWordRuntimeFilterService _runtimeFilterService() {
  return ImWordRuntimeFilterService(
    wordStore: _MemoryWordSyncStore(
      prohibitWords: const <ProhibitWordEntry>[
        ProhibitWordEntry(
          sid: 1,
          content: 'secret',
          isDeleted: 0,
          version: 1,
          createdAt: '2026-05-18 10:00:00',
        ),
      ],
    ),
  );
}

WKMsg _textMessage(String clientMsgNo, String text) {
  return WKMsg()
    ..clientMsgNO = clientMsgNo
    ..contentType = WkMessageContentType.text
    ..channelID = 'group-1'
    ..channelType = WKChannelType.group
    ..messageContent = WKTextContent(text);
}

class _MemoryWordSyncStore implements ImWordSyncStore {
  const _MemoryWordSyncStore({
    this.prohibitWords = const <ProhibitWordEntry>[],
  });

  final List<ProhibitWordEntry> prohibitWords;

  @override
  bool get usesLocalPersistence => false;

  @override
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {}

  @override
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {}

  @override
  Future<int> getMaxProhibitWordVersion() async => 0;

  @override
  Future<void> loadStoredWordCaches() async {}

  @override
  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() {
    return const SensitiveWordsSnapshot();
  }

  @override
  List<ProhibitWordEntry> resolveProhibitWords() => prohibitWords;
}
