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
    test('syncConversation delegates to IMSyncApi with device identity', () async {
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
    });

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

    test('acknowledgeConversationSync posts the synced command version', () async {
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
    });

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
}

ImSyncOrchestrator _orchestrator() {
  return ImSyncOrchestrator(
    syncApi: IMSyncApi.instance,
    messageApi: MessageApi.instance,
    reminderApi: ReminderApi.instance,
    conversationDraftApi: ConversationDraftApi.instance,
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
