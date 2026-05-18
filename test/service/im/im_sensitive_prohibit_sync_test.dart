import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/service/api/im_sync_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/service/api/reminder_api.dart';
import 'package:wukong_im_app/service/im/im_service.dart';
import 'package:wukong_im_app/service/im/im_sync_orchestrator.dart';
import 'package:wukong_im_app/service/im/im_word_sync_models.dart';
import 'package:wukong_im_app/service/im/im_word_sync_store.dart';
import 'package:wukong_im_app/wukong_base/db/db_helper.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
    await StorageUtils.setUid('u_self');
    final dynamic dbHelper = DBHelper.instance;
    await dbHelper.deleteDatabaseForTesting();
  });

  group('MessageApi Android word sync parity', () {
    test(
      'syncSensitiveWords parses Android tips version and list payload',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'tips': '该消息包含敏感词，仅自己可见',
            'version': 7,
            'list': <String>['bad', 'secret'],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final snapshot = await MessageApi.instance.syncSensitiveWords(
          version: 3,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/message/sync/sensitivewords',
        );
        expect(adapter.lastRequestOptions?.queryParameters, <String, dynamic>{
          'version': 3,
        });
        expect(snapshot.tips, '该消息包含敏感词，仅自己可见');
        expect(snapshot.version, 7);
        expect(snapshot.list, <String>['bad', 'secret']);
      },
    );

    test('syncProhibitWords parses Android prohibit word payload', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'content': 'bad',
            'is_deleted': 0,
            'version': 12,
            'created_at': '2026-04-11 12:00:00',
          },
        ],
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final words = await MessageApi.instance.syncProhibitWords(version: 9);

      expect(
        adapter.lastRequestOptions?.path,
        '/v1/message/prohibit_words/sync',
      );
      expect(adapter.lastRequestOptions?.queryParameters, <String, dynamic>{
        'version': 9,
      });
      expect(words, hasLength(1));
      expect(words.single.sid, 101);
      expect(words.single.content, 'bad');
      expect(words.single.isDeleted, 0);
      expect(words.single.version, 12);
      expect(words.single.createdAt, '2026-04-11 12:00:00');
    });
  });

  group('IMService Android word runtime parity', () {
    test(
      'sensitive word sync caches Android payload and builds local warning message',
      () async {
        final service = IMService();
        addTearDown(service.dispose);

        await service.applySensitiveWordsSync(
          const SensitiveWordsSnapshot(
            tips: '该消息包含敏感词，仅自己可见',
            version: 7,
            list: <String>['bad'],
          ),
        );

        final message = WKMsg()
          ..channelID = 'group_01'
          ..channelType = WKChannelType.group
          ..fromUID = 'u_self'
          ..contentType = WkMessageContentType.text
          ..content = jsonEncode(<String, dynamic>{
            'type': WkMessageContentType.text,
            'content': 'contains bad content',
          })
          ..messageContent = WKTextContent('contains bad content');

        final tip = service.buildSensitiveWordTipMessageIfNeeded(message);

        expect(tip, isNotNull);
        expect(tip!.channelID, 'group_01');
        expect(tip.channelType, WKChannelType.group);
        expect(tip.contentType, MsgContentType.sensitiveWord);
        expect(jsonDecode(tip.content), <String, dynamic>{
          'content': '该消息包含敏感词，仅自己可见',
          'type': MsgContentType.sensitiveWord,
        });
      },
    );

    test(
      'prohibit word sync persists Android rows and masks base text with same-length stars',
      () async {
        final service = IMService();
        addTearDown(service.dispose);

        await service.applyProhibitWordsSync(const <ProhibitWordEntry>[
          ProhibitWordEntry(
            sid: 101,
            content: 'bad',
            isDeleted: 0,
            version: 12,
            createdAt: '2026-04-11 12:00:00',
          ),
        ]);

        final rows = await DBHelper.instance.getProhibitWords();
        expect(rows, hasLength(1));
        expect(rows.single.sid, 101);
        expect(rows.single.content, 'bad');
        expect(rows.single.version, 12);

        final message = WKMsg()
          ..channelID = 'group_01'
          ..channelType = WKChannelType.group
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('bad content');

        final changed = service.applyProhibitWordsToMessage(message);

        expect(changed, isTrue);
        expect(
          (message.messageContent as WKTextContent).content,
          '*** content',
        );
      },
    );

    test(
      'prohibit word masking follows Android edited-content precedence',
      () async {
        final service = IMService();
        addTearDown(service.dispose);

        await service.applyProhibitWordsSync(const <ProhibitWordEntry>[
          ProhibitWordEntry(
            sid: 102,
            content: 'secret',
            isDeleted: 0,
            version: 13,
            createdAt: '2026-04-11 12:05:00',
          ),
        ]);

        final message = WKMsg()
          ..channelID = 'group_01'
          ..channelType = WKChannelType.group
          ..fromUID = 'u_other'
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('base text');
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
        expect((message.messageContent as WKTextContent).content, 'base text');
      },
    );

    test(
      'custom orchestrator shares word store with runtime filters',
      () async {
        final wordStore = _MemoryWordSyncStore();
        final orchestrator = ImSyncOrchestrator(
          syncApi: IMSyncApi.instance,
          messageApi: MessageApi.instance,
          reminderApi: ReminderApi.instance,
          conversationDraftApi: ConversationDraftApi.instance,
          wordStore: wordStore,
        );
        final service = IMService(syncOrchestrator: orchestrator);
        addTearDown(service.dispose);

        await orchestrator.applySensitiveWordsSync(
          const SensitiveWordsSnapshot(
            tips: 'local warning',
            version: 8,
            list: <String>['blocked'],
          ),
        );

        final message = WKMsg()
          ..channelID = 'group_01'
          ..channelType = WKChannelType.group
          ..fromUID = 'u_self'
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('contains blocked text');

        final tip = service.buildSensitiveWordTipMessageIfNeeded(message);

        expect(tip, isNotNull);
        expect(jsonDecode(tip!.content), <String, dynamic>{
          'content': 'local warning',
          'type': MsgContentType.sensitiveWord,
        });
      },
    );
  });
}

class _RecordingPlainAdapter implements HttpClientAdapter {
  _RecordingPlainAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryWordSyncStore implements ImWordSyncStore {
  SensitiveWordsSnapshot _snapshot = const SensitiveWordsSnapshot();
  List<ProhibitWordEntry> _prohibitWords = const <ProhibitWordEntry>[];

  @override
  bool get usesLocalPersistence => false;

  @override
  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() => _snapshot;

  @override
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> loadStoredWordCaches() async {}

  @override
  Future<int> getMaxProhibitWordVersion() async => 0;

  @override
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {
    _prohibitWords = words;
  }

  @override
  List<ProhibitWordEntry> resolveProhibitWords() => _prohibitWords;
}
