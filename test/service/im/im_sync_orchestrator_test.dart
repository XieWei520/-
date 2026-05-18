import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/service/api/im_sync_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/service/api/reminder_api.dart';
import 'package:wukong_im_app/service/im/im_sync_orchestrator.dart';
import 'package:wukong_im_app/service/im/im_word_sync_models.dart';
import 'package:wukong_im_app/service/im/im_word_sync_store.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ImSyncOrchestrator planning', () {
    test('sync completed fans out all required background sync tasks', () {
      final plan = ImSyncOrchestrator.planForSyncCompleted();

      expect(plan.reason, 'sync_completed');
      expect(plan.syncReminders, isTrue);
      expect(plan.syncSensitiveWords, isTrue);
      expect(plan.syncProhibitWords, isTrue);
      expect(plan.syncConversationExtras, isTrue);
      expect(plan.syncOfflineCommandMessages, isTrue);
    });

    test(
      'conversation sync fans out conversation extras and offline commands',
      () {
        final plan = ImSyncOrchestrator.planForConversationSync();

        expect(plan.reason, 'conversation_sync');
        expect(plan.syncReminders, isFalse);
        expect(plan.syncSensitiveWords, isFalse);
        expect(plan.syncProhibitWords, isFalse);
        expect(plan.syncConversationExtras, isTrue);
        expect(plan.syncOfflineCommandMessages, isTrue);
      },
    );

    test('runFanOutPlan dispatches only enabled task handlers', () {
      final calls = <String>[];
      final orchestrator = _orchestrator();

      orchestrator.runFanOutPlan(
        const ImSyncFanOutPlan(
          reason: 'unit',
          syncReminders: true,
          syncConversationExtras: true,
        ),
        ImSyncTaskHandlers(
          syncReminders: ({reason}) async => calls.add('reminders:$reason'),
          syncSensitiveWords: ({reason}) async =>
              calls.add('sensitive:$reason'),
          syncProhibitWords: ({reason}) async => calls.add('prohibit:$reason'),
          syncConversationExtras: ({reason}) async =>
              calls.add('conversation:$reason'),
          syncOfflineCommandMessages: ({reason}) async =>
              calls.add('offline:$reason'),
        ),
      );

      expect(calls, <String>['reminders:unit', 'conversation:unit']);
    });

    test(
      'runExclusiveSyncTask replays a pending trigger after current run',
      () async {
        final orchestrator = _orchestrator();
        final calls = <String>[];
        final gate = Completer<void>();

        final first = orchestrator.runExclusiveSyncTask(
          ImSyncTaskSlot.reminders,
          reason: 'first',
          task: ({reason}) async {
            calls.add(reason ?? '');
            await gate.future;
          },
        );
        final second = orchestrator.runExclusiveSyncTask(
          ImSyncTaskSlot.reminders,
          reason: 'second',
          task: ({reason}) async {
            calls.add(reason ?? '');
          },
        );

        expect(orchestrator.status.isSyncingReminders, isTrue);
        gate.complete();
        await Future.wait(<Future<void>>[first, second]);

        expect(calls, <String>['first', 'second']);
        expect(orchestrator.status.isSyncingReminders, isFalse);
      },
    );

    test('runExclusiveMessageExtraTask deduplicates by channel key', () async {
      final orchestrator = _orchestrator();
      final calls = <String>[];
      final gate = Completer<void>();

      final first = orchestrator.runExclusiveMessageExtraTask(
        channelId: ' c1 ',
        channelType: 1,
        reason: 'first',
        task: ({required channelId, required channelType, reason}) async {
          calls.add('$channelId/$channelType:$reason');
          await gate.future;
        },
      );
      final second = orchestrator.runExclusiveMessageExtraTask(
        channelId: 'c1',
        channelType: 1,
        reason: 'second',
        task: ({required channelId, required channelType, reason}) async {
          calls.add('$channelId/$channelType:$reason');
        },
      );

      expect(orchestrator.status.activeMessageExtraKeys, <String>{'c1:1'});
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(calls, <String>['c1/1:first', 'c1/1:second']);
      expect(orchestrator.status.activeMessageExtraKeys, isEmpty);
    });
  });

  group('ImSyncOrchestrator transport callbacks', () {
    test(
      'syncConversation delegates to IMSyncApi with device identity',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'data': <String, dynamic>{
              'uid': 'u_self',
              'cmd_version': 12,
              'cmds': const <Map<String, dynamic>>[],
              'channel_status': const <Map<String, dynamic>>[],
              'conversations': const <Map<String, dynamic>>[],
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final orchestrator = _orchestrator();

        final result = await orchestrator.syncConversation(
          version: 7,
          lastMsgSeqs: '1:99',
          msgCount: 200,
          deviceUuid: 'device-01',
        );

        expect(result.cmdVersion, 12);
        expect(adapter.lastRequestOptions?.path, '/v1/conversation/sync');
        expect(adapter.lastRequestOptions?.data, <String, dynamic>{
          'version': 7,
          'last_msg_seqs': '1:99',
          'msg_count': 200,
          'device_uuid': 'device-01',
        });
      },
    );

    test('syncChannelMessages delegates channel bounds to IMSyncApi', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <String, dynamic>{
          'data': <String, dynamic>{
            'start_message_seq': 3,
            'end_message_seq': 9,
            'more': 0,
            'messages': const <Map<String, dynamic>>[],
          },
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final orchestrator = _orchestrator();

      final result = await orchestrator.syncChannelMessages(
        channelId: 'c1',
        channelType: 2,
        startMessageSeq: 3,
        endMessageSeq: 9,
        limit: 50,
        pullMode: 1,
        deviceUuid: 'device-01',
      );

      expect(result, isNotNull);
      expect(result!.startMessageSeq, 3);
      expect(result.endMessageSeq, 9);
      expect(adapter.lastRequestOptions?.path, '/v1/message/channel/sync');
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{
        'channel_id': 'c1',
        'channel_type': 2,
        'start_message_seq': 3,
        'end_message_seq': 9,
        'limit': 50,
        'pull_mode': 1,
        'device_uuid': 'device-01',
      });
    });

    test(
      'acknowledgeConversationSync posts the synced command version',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final orchestrator = _orchestrator();

        await orchestrator.acknowledgeConversationSync(
          cmdVersion: 12,
          deviceUuid: 'device-01',
        );

        expect(adapter.lastRequestOptions?.path, '/v1/conversation/syncack');
        expect(adapter.lastRequestOptions?.data, <String, dynamic>{
          'cmd_version': 12,
          'device_uuid': 'device-01',
        });
      },
    );

    test('acknowledgeConversationSync absorbs transport errors', () async {
      ApiClient.instance.dio.httpClientAdapter = _ThrowingPlainAdapter();
      final orchestrator = _orchestrator();

      await expectLater(
        orchestrator.acknowledgeConversationSync(
          cmdVersion: 12,
          deviceUuid: 'device-01',
        ),
        completes,
      );
    });
  });

  group('ImSyncOrchestrator reminder sync', () {
    test('syncReminders loads version and saves remote reminders', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 8,
              'message_id': 'm1',
              'channel_id': 'g1',
              'channel_type': 2,
              'message_seq': 99,
              'reminder_type': 1,
              'is_locate': 1,
              'uid': 'u1',
              'text': '@you',
              'version': 6,
              'done': 0,
              'publisher': 'u2',
            },
          ],
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final store = _FakeReminderStore(version: 5);
      final orchestrator = _orchestrator(
        reminderStore: store,
        reminderChannelIdsLoader: () async => <String>['g1', 'g2'],
      );

      await orchestrator.syncReminders(reason: 'unit');

      expect(adapter.lastRequestOptions?.path, '/v1/message/reminder/sync');
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{
        'version': 5,
        'limit': 200,
        'channel_ids': <String>['g1', 'g2'],
      });
      expect(store.saved, hasLength(1));
      expect(store.saved.single.reminderID, 8);
      expect(store.saved.single.channelID, 'g1');
    });

    test('syncReminders completes when remote sync fails', () async {
      ApiClient.instance.dio.httpClientAdapter = _ThrowingPlainAdapter();
      final store = _FakeReminderStore(version: 5);
      final orchestrator = _orchestrator(
        reminderStore: store,
        reminderChannelIdsLoader: () async => <String>['g1'],
      );

      await expectLater(
        orchestrator.syncReminders(reason: 'unit-failure'),
        completes,
      );
      expect(store.saved, isEmpty);
    });
  });

  group('ImSyncOrchestrator word sync', () {
    test(
      'syncSensitiveWords uses cached version and stores remote snapshot',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'tips': 'contains sensitive words',
            'version': 7,
            'list': <String>['bad', 'secret'],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final wordStore = _FakeWordSyncStore(
          sensitiveSnapshot: const SensitiveWordsSnapshot(version: 3),
        );
        final orchestrator = _orchestrator(wordStore: wordStore);

        await orchestrator.syncSensitiveWords(reason: 'unit');

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/message/sync/sensitivewords',
        );
        expect(adapter.lastRequestOptions?.queryParameters, <String, dynamic>{
          'version': 3,
        });
        expect(wordStore.savedSensitiveSnapshot?.version, 7);
        expect(
          wordStore.savedSensitiveSnapshot?.tips,
          'contains sensitive words',
        );
        expect(wordStore.savedSensitiveSnapshot?.list, <String>[
          'bad',
          'secret',
        ]);
      },
    );

    test('syncSensitiveWords ignores empty remote snapshot', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'tips': '',
          'version': 0,
          'list': <String>[],
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final wordStore = _FakeWordSyncStore(
        sensitiveSnapshot: const SensitiveWordsSnapshot(version: 3),
      );
      final orchestrator = _orchestrator(wordStore: wordStore);

      await orchestrator.syncSensitiveWords(reason: 'unit-empty');

      expect(wordStore.savedSensitiveSnapshot, isNull);
    });

    test('syncSensitiveWords completes when remote sync fails', () async {
      ApiClient.instance.dio.httpClientAdapter = _ThrowingPlainAdapter();
      final wordStore = _FakeWordSyncStore(
        sensitiveSnapshot: const SensitiveWordsSnapshot(version: 3),
      );
      final orchestrator = _orchestrator(wordStore: wordStore);

      await expectLater(
        orchestrator.syncSensitiveWords(reason: 'unit-failure'),
        completes,
      );
      expect(wordStore.savedSensitiveSnapshot, isNull);
    });

    test(
      'syncProhibitWords saves rows and refreshes masked messages',
      () async {
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
        var refreshCount = 0;
        final wordStore = _FakeWordSyncStore(maxProhibitWordVersion: 9);
        final orchestrator = _orchestrator(
          wordStore: wordStore,
          refreshMaskedMessagesAfterProhibitWordSync: () async {
            refreshCount++;
          },
        );

        await orchestrator.syncProhibitWords(reason: 'unit');

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/message/prohibit_words/sync',
        );
        expect(adapter.lastRequestOptions?.queryParameters, <String, dynamic>{
          'version': 9,
        });
        expect(wordStore.savedProhibitWords, hasLength(1));
        expect(wordStore.savedProhibitWords.single.sid, 101);
        expect(wordStore.savedProhibitWords.single.content, 'bad');
        expect(refreshCount, 1);
      },
    );

    test(
      'syncProhibitWords skips remote call when local persistence is disabled',
      () async {
        final adapter = _RecordingPlainAdapter(payload: const <dynamic>[]);
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final wordStore = _FakeWordSyncStore(useLocalPersistence: false);
        final orchestrator = _orchestrator(wordStore: wordStore);

        await orchestrator.syncProhibitWords(reason: 'unit-disabled');

        expect(adapter.lastRequestOptions, isNull);
        expect(wordStore.savedProhibitWords, isEmpty);
      },
    );

    test('syncProhibitWords completes when remote sync fails', () async {
      ApiClient.instance.dio.httpClientAdapter = _ThrowingPlainAdapter();
      final wordStore = _FakeWordSyncStore(maxProhibitWordVersion: 9);
      final orchestrator = _orchestrator(wordStore: wordStore);

      await expectLater(
        orchestrator.syncProhibitWords(reason: 'unit-failure'),
        completes,
      );
      expect(wordStore.savedProhibitWords, isEmpty);
    });
  });

  group('ImSyncOrchestrator conversation extra sync', () {
    test(
      'syncConversationExtras loads version and saves mapped extras',
      () async {
        final conversationDraftApi = _FakeConversationDraftStore(
          syncedExtras: const <RemoteConversationDraft>[
            RemoteConversationDraft(
              channelId: 'group_01',
              channelType: 2,
              browseTo: 1,
              keepMessageSeq: 88,
              keepOffsetY: 420,
              draft: 'draft_text',
              version: 12,
            ),
          ],
        );
        final store = _FakeConversationExtraStore(maxVersion: 9);
        final orchestrator = _orchestrator(
          conversationDraftApi: conversationDraftApi,
          conversationExtraStore: store,
        );

        await orchestrator.syncConversationExtras(reason: 'unit');

        expect(conversationDraftApi.syncExtraVersions, <int>[9]);
        expect(store.savedExtras, hasLength(1));
        final saved = store.savedExtras.single;
        expect(saved.channelID, 'group_01');
        expect(saved.channelType, 2);
        expect(saved.browseTo, 1);
        expect(saved.keepMessageSeq, 88);
        expect(saved.keepOffsetY, 420);
        expect(saved.draft, 'draft_text');
        expect(saved.version, 12);
      },
    );

    test(
      'syncConversationExtras skips save when remote list is empty',
      () async {
        final conversationDraftApi = _FakeConversationDraftStore(
          syncedExtras: const <RemoteConversationDraft>[],
        );
        final store = _FakeConversationExtraStore(maxVersion: 9);
        final orchestrator = _orchestrator(
          conversationDraftApi: conversationDraftApi,
          conversationExtraStore: store,
        );

        await orchestrator.syncConversationExtras(reason: 'unit-empty');

        expect(conversationDraftApi.syncExtraVersions, <int>[9]);
        expect(store.savedExtras, isEmpty);
      },
    );

    test('syncConversationExtras completes when remote sync fails', () async {
      final conversationDraftApi = _ThrowingConversationDraftStore();
      final store = _FakeConversationExtraStore(maxVersion: 9);
      final orchestrator = _orchestrator(
        conversationDraftApi: conversationDraftApi,
        conversationExtraStore: store,
      );

      await expectLater(
        orchestrator.syncConversationExtras(reason: 'unit-failure'),
        completes,
      );
      expect(store.savedExtras, isEmpty);
    });
  });

  group('ImSyncOrchestrator message extra sync', () {
    test(
      'syncMessageExtras loads local version, saves mapped extras, and refreshes realtime UI',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_id_str': 'msg_01',
                'readed': 1,
                'readed_count': 2,
                'unread_count': 3,
                'revoke': 1,
                'revoker': 'u_01',
                'extra_version': 18,
                'is_pinned': 1,
              },
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final store = _FakeMessageExtraStore(
          maxVersions: <String, int>{'group_01:2': 5},
          useLocalPersistence: false,
        );
        final refreshed = <WKMsgExtra>[];
        final delayDurations = <Duration>[];
        final orchestrator = _orchestrator(
          messageExtraStore: store,
          syncDelay: (duration) async {
            delayDurations.add(duration);
          },
        );

        await orchestrator.syncMessageExtras(
          channelId: ' group_01 ',
          channelType: 2,
          reason: 'unit',
          deviceUuidLoader: () async => 'device_uuid_01',
          publishRealtimeMessageExtraRefresh: (channelId, channelType, extras) {
            refreshed.addAll(extras);
          },
        );

        expect(adapter.lastRequestOptions?.path, '/v1/message/extra/sync');
        expect(adapter.lastRequestOptions?.data, <String, dynamic>{
          'channel_id': 'group_01',
          'channel_type': 2,
          'extra_version': 5,
          'source': 'device_uuid_01',
          'limit': 100,
        });
        expect(store.savedExtras, hasLength(1));
        expect(store.savedExtras.single.channelID, 'group_01');
        expect(store.savedExtras.single.channelType, 2);
        expect(store.savedExtras.single.messageID, 'msg_01');
        expect(store.savedExtras.single.revoke, 1);
        expect(store.savedExtras.single.extraVersion, 18);
        expect(refreshed, hasLength(1));
        expect(refreshed.single.messageID, 'msg_01');
        expect(delayDurations, <Duration>[const Duration(milliseconds: 500)]);
      },
    );

    test(
      'syncMessageExtras skips save and refresh when remote list is empty',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{'data': <Map<String, dynamic>>[]},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final store = _FakeMessageExtraStore(
          maxVersions: <String, int>{'group_01:2': 5},
          useLocalPersistence: false,
        );
        var refreshCount = 0;
        final orchestrator = _orchestrator(messageExtraStore: store);

        await orchestrator.syncMessageExtras(
          channelId: 'group_01',
          channelType: 2,
          reason: 'unit-empty',
          deviceUuidLoader: () async => 'device_uuid_01',
          publishRealtimeMessageExtraRefresh: (channelId, channelType, extras) {
            refreshCount++;
          },
        );

        expect(adapter.lastRequestOptions?.path, '/v1/message/extra/sync');
        expect(store.savedExtras, isEmpty);
        expect(refreshCount, 0);
      },
    );

    test('syncMessageExtras completes when remote sync fails', () async {
      ApiClient.instance.dio.httpClientAdapter = _ThrowingPlainAdapter();
      final store = _FakeMessageExtraStore(
        maxVersions: <String, int>{'group_01:2': 5},
      );
      final orchestrator = _orchestrator(messageExtraStore: store);

      await expectLater(
        orchestrator.syncMessageExtras(
          channelId: 'group_01',
          channelType: 2,
          reason: 'unit-failure',
          deviceUuidLoader: () async => 'device_uuid_01',
        ),
        completes,
      );
      expect(store.savedExtras, isEmpty);
    });
  });

  group('ImSyncOrchestrator offline command sync', () {
    test(
      'syncOfflineCommandMessages pulls pages, acks highest sequence, and dispatches commands',
      () async {
        final adapter = _QueuedPlainAdapter(
          payloads: <Object>[
            <String, dynamic>{
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  'message_seq': 11,
                  'channel_id': 'group_01',
                  'channel_type': 2,
                  'payload': <String, dynamic>{'cmd': 'syncMessageExtra'},
                },
                <String, dynamic>{
                  'message_seq': 27,
                  'channel_id': 'group_02',
                  'channel_type': 2,
                  'content': jsonEncode(<String, dynamic>{
                    'type': WkMessageContentType.insideMsg,
                    'cmd': 'wk_sync_conversation_extra',
                  }),
                },
                <String, dynamic>{
                  'message_seq': 19,
                  'payload': <String, dynamic>{
                    'type': WkMessageContentType.insideMsg,
                  },
                },
              ],
            },
            const <String, dynamic>{'code': 0},
            const <String, dynamic>{'messages': <Map<String, dynamic>>[]},
          ],
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final dispatched = <Map<String, dynamic>>[];
        final delayDurations = <Duration>[];
        final orchestrator = _orchestrator(
          syncDelay: (duration) async {
            delayDurations.add(duration);
          },
        );

        await orchestrator.syncOfflineCommandMessages(
          reason: 'unit',
          dispatchOfflineCommand: dispatched.add,
        );

        expect(adapter.requests.map((request) => request.path), <String>[
          '/v1/message/sync',
          '/v1/message/syncack/27',
          '/v1/message/sync',
        ]);
        expect(adapter.requests.first.data, <String, dynamic>{
          'max_message_seq': 0,
          'limit': 500,
        });
        expect(adapter.requests.last.data, <String, dynamic>{
          'max_message_seq': 27,
          'limit': 500,
        });
        expect(dispatched, hasLength(2));
        expect(dispatched.first['cmd'], 'syncMessageExtra');
        expect(dispatched.first['channel_id'], 'group_01');
        expect(dispatched.first['channel_type'], 2);
        expect(dispatched.last['cmd'], 'wk_sync_conversation_extra');
        expect(dispatched.last['channel_id'], 'group_02');
        expect(dispatched.last['channel_type'], 2);
        expect(delayDurations, <Duration>[const Duration(seconds: 1)]);
      },
    );

    test(
      'syncOfflineCommandMessages skips ack when remote list is empty',
      () async {
        final adapter = _QueuedPlainAdapter(
          payloads: const <Object>[
            <String, dynamic>{'messages': <Map<String, dynamic>>[]},
          ],
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final dispatched = <Map<String, dynamic>>[];
        final orchestrator = _orchestrator();

        await orchestrator.syncOfflineCommandMessages(
          reason: 'unit-empty',
          dispatchOfflineCommand: dispatched.add,
        );

        expect(adapter.requests.map((request) => request.path), <String>[
          '/v1/message/sync',
        ]);
        expect(dispatched, isEmpty);
      },
    );

    test(
      'syncOfflineCommandMessages dispatches pulled commands even when ack fails',
      () async {
        final adapter = _QueuedPlainAdapter(
          payloads: <Object>[
            <String, dynamic>{
              'messages': <Map<String, dynamic>>[
                <String, dynamic>{
                  'message_seq': 11,
                  'channel_id': 'group_01',
                  'channel_type': 2,
                  'payload': <String, dynamic>{'cmd': 'syncMessageExtra'},
                },
              ],
            },
          ],
          throwingRequestIndexes: const <int>{1},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final dispatched = <Map<String, dynamic>>[];
        final delayDurations = <Duration>[];
        final orchestrator = _orchestrator(
          syncDelay: (duration) async {
            delayDurations.add(duration);
          },
        );

        await expectLater(
          orchestrator.syncOfflineCommandMessages(
            reason: 'unit-ack-failure',
            dispatchOfflineCommand: dispatched.add,
          ),
          completes,
        );

        expect(adapter.requests.map((request) => request.path), <String>[
          '/v1/message/sync',
          '/v1/message/syncack/11',
        ]);
        expect(dispatched, hasLength(1));
        expect(dispatched.single['cmd'], 'syncMessageExtra');
        expect(delayDurations, isEmpty);
      },
    );
  });
}

ImSyncOrchestrator _orchestrator({
  ImReminderStore? reminderStore,
  ImReminderChannelIdsLoader? reminderChannelIdsLoader,
  ImWordSyncStore? wordStore,
  Future<void> Function()? refreshMaskedMessagesAfterProhibitWordSync,
  ConversationDraftRemoteStore? conversationDraftApi,
  ImConversationExtraStore? conversationExtraStore,
  ImMessageExtraStore? messageExtraStore,
  ImSyncDelay? syncDelay,
}) {
  return ImSyncOrchestrator(
    syncApi: IMSyncApi.instance,
    messageApi: MessageApi.instance,
    reminderApi: ReminderApi.instance,
    conversationDraftApi: conversationDraftApi ?? ConversationDraftApi.instance,
    reminderStore: reminderStore,
    reminderChannelIdsLoader: reminderChannelIdsLoader,
    wordStore: wordStore,
    refreshMaskedMessagesAfterProhibitWordSync:
        refreshMaskedMessagesAfterProhibitWordSync,
    conversationExtraStore: conversationExtraStore,
    messageExtraStore: messageExtraStore,
    syncDelay: syncDelay,
  );
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

class _ThrowingPlainAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'sync ack failed',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QueuedPlainAdapter implements HttpClientAdapter {
  _QueuedPlainAdapter({
    required List<Object> payloads,
    this.throwingRequestIndexes = const <int>{},
  }) : _payloads = List<Object>.from(payloads);

  final List<Object> _payloads;
  final Set<int> throwingRequestIndexes;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final requestIndex = requests.length;
    requests.add(options);
    if (throwingRequestIndexes.contains(requestIndex)) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'queued request failed',
      );
    }
    if (_payloads.isEmpty) {
      throw StateError('No queued payload for ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(_payloads.removeAt(0)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeReminderStore implements ImReminderStore {
  _FakeReminderStore({required this.version});

  final int version;
  final List<WKReminder> saved = <WKReminder>[];

  @override
  Future<int> getMaxVersion() async => version;

  @override
  Future<void> saveOrUpdateReminders(List<WKReminder> reminders) async {
    saved.addAll(reminders);
  }
}

class _FakeWordSyncStore implements ImWordSyncStore {
  _FakeWordSyncStore({
    this.sensitiveSnapshot = const SensitiveWordsSnapshot(),
    this.maxProhibitWordVersion = 0,
    this.useLocalPersistence = true,
  });

  SensitiveWordsSnapshot sensitiveSnapshot;
  SensitiveWordsSnapshot? savedSensitiveSnapshot;
  final int maxProhibitWordVersion;
  final bool useLocalPersistence;
  final List<ProhibitWordEntry> savedProhibitWords = <ProhibitWordEntry>[];

  @override
  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() {
    return sensitiveSnapshot;
  }

  @override
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {
    savedSensitiveSnapshot = snapshot;
    sensitiveSnapshot = snapshot;
  }

  @override
  Future<int> getMaxProhibitWordVersion() async => maxProhibitWordVersion;

  @override
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {
    savedProhibitWords.addAll(words);
  }

  @override
  Future<void> loadStoredWordCaches() async {}

  @override
  List<ProhibitWordEntry> resolveProhibitWords() {
    return savedProhibitWords;
  }

  @override
  bool get usesLocalPersistence => useLocalPersistence;
}

class _FakeConversationExtraStore implements ImConversationExtraStore {
  _FakeConversationExtraStore({required this.maxVersion});

  final int maxVersion;
  final List<WKSyncConvMsgExtra> savedExtras = <WKSyncConvMsgExtra>[];

  @override
  Future<int> getMaxVersion() async => maxVersion;

  @override
  Future<void> saveSyncExtras(List<WKSyncConvMsgExtra> extras) async {
    savedExtras.addAll(extras);
  }
}

class _FakeMessageExtraStore implements ImMessageExtraStore {
  _FakeMessageExtraStore({
    required this.maxVersions,
    this.useLocalPersistence = true,
  });

  final Map<String, int> maxVersions;
  final bool useLocalPersistence;
  final List<WKMsgExtra> savedExtras = <WKMsgExtra>[];

  @override
  Future<int> getMaxExtraVersionWithChannel(
    String channelId,
    int channelType,
  ) async {
    return maxVersions['$channelId:$channelType'] ?? 0;
  }

  @override
  WKMsgExtra toMessageExtra(
    String channelId,
    int channelType,
    WKSyncExtraMsg extra,
  ) {
    return WKMsgExtra()
      ..channelID = channelId
      ..channelType = channelType
      ..messageID = extra.messageIdStr
      ..readed = extra.readed
      ..readedCount = extra.readedCount
      ..unreadCount = extra.unreadCount
      ..revoke = extra.revoke
      ..revoker = extra.revoker
      ..extraVersion = extra.extraVersion
      ..isPinned = extra.isPinned;
  }

  @override
  Future<void> saveRemoteExtraMsg(List<WKMsgExtra> extras) async {
    savedExtras.addAll(extras);
  }

  @override
  bool get usesLocalPersistence => useLocalPersistence;
}

class _FakeConversationDraftStore implements ConversationDraftRemoteStore {
  _FakeConversationDraftStore({required this.syncedExtras});

  final List<RemoteConversationDraft> syncedExtras;
  final List<int> syncExtraVersions = <int>[];

  @override
  Future<List<RemoteConversationDraft>> syncExtras({
    required int version,
  }) async {
    syncExtraVersions.add(version);
    return syncedExtras;
  }

  @override
  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  }) async {
    return null;
  }

  @override
  Future<List<RemoteConversationDraft>> syncDrafts({
    required int version,
  }) async {
    return const <RemoteConversationDraft>[];
  }

  @override
  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  }) async {
    return null;
  }
}

class _ThrowingConversationDraftStore implements ConversationDraftRemoteStore {
  @override
  Future<List<RemoteConversationDraft>> syncExtras({required int version}) {
    throw StateError('conversation extra sync failed');
  }

  @override
  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  }) async {
    return null;
  }

  @override
  Future<List<RemoteConversationDraft>> syncDrafts({
    required int version,
  }) async {
    return const <RemoteConversationDraft>[];
  }

  @override
  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  }) async {
    return null;
  }
}
