import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';

void main() {
  group('Conversation extra parity api', () {
    test('syncExtras parses browse_to keep_message_seq keep_offset_y draft and version', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'channel_id': 'group_01',
              'channel_type': 2,
              'browse_to': 1,
              'keep_message_seq': 88,
              'keep_offset_y': 420,
              'draft': 'draft_text',
              'version': 12,
            },
          ],
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = ConversationDraftApi.instance;

      final items = await api.syncExtras(version: 9) as List<dynamic>;

      expect(adapter.lastRequestOptions?.path, '/v1/conversation/extra/sync');
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{'version': 9});
      expect(items, hasLength(1));
      expect(items.single.channelId, 'group_01');
      expect(items.single.channelType, 2);
      expect(items.single.browseTo, 1);
      expect(items.single.keepMessageSeq, 88);
      expect(items.single.keepOffsetY, 420);
      expect(items.single.draft, 'draft_text');
      expect(items.single.version, 12);
    });

    test('updateExtra posts Android-aligned body and returns version', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'data': <String, dynamic>{'version': 15},
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = ConversationDraftApi.instance;

      final version = await api.updateExtra(
        channelId: 'group_01',
        channelType: 2,
        browseTo: 1,
        keepMessageSeq: 99,
        keepOffsetY: 256,
        draft: 'hello',
      ) as int?;

      expect(
        adapter.lastRequestOptions?.path,
        '/v1/conversations/group_01/2/extra',
      );
      expect(
        adapter.lastRequestOptions?.data,
        <String, dynamic>{
          'browse_to': 1,
          'keep_message_seq': 99,
          'keep_offset_y': 256,
          'draft': 'hello',
        },
      );
      expect(version, 15);
    });
  });

  group('Message sync parity api', () {
    test('clearUnread uses Android clearUnread endpoint and unread payload', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = MessageApi.instance;

      await api.clearUnread(
        channelId: 'group_01',
        channelType: 2,
        unread: 7,
      );

      expect(adapter.lastRequestOptions?.method, 'PUT');
      expect(adapter.lastRequestOptions?.path, '/v1/conversation/clearUnread');
      expect(
        adapter.lastRequestOptions?.data,
        <String, dynamic>{
          'channel_id': 'group_01',
          'channel_type': 2,
          'unread': 7,
        },
      );
    });

    test('syncMessageExtras posts source device_uuid and extra_version', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'message_id_str': 'msg_01',
              'revoke': 1,
              'extra_version': 18,
            },
          ],
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = MessageApi.instance;

      final result = await api.syncMessageExtras(
        channelId: 'group_01',
        channelType: 2,
        extraVersion: 5,
        deviceUuid: 'device_uuid_01',
        limit: 100,
      ) as List<dynamic>;

      expect(adapter.lastRequestOptions?.path, '/v1/message/extra/sync');
      expect(
        adapter.lastRequestOptions?.data,
        <String, dynamic>{
          'channel_id': 'group_01',
          'channel_type': 2,
          'extra_version': 5,
          'source': 'device_uuid_01',
          'limit': 100,
        },
      );
      expect(result, hasLength(1));
      expect(result.single.messageIdStr, 'msg_01');
      expect(result.single.revoke, 1);
      expect(result.single.extraVersion, 18);
    });

    test('syncAck uses last_message_seq path parameter', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = MessageApi.instance;

      await api.syncAck(lastMessageSeq: 88);

      expect(adapter.lastRequestOptions?.path, '/v1/message/syncack/88');
      expect(adapter.lastRequestOptions?.method, 'POST');
    });

    test('syncCommandMessages posts max_message_seq for offline cmd sync', () async {
      final adapter = _RecordingPlainAdapter(
        payload: <String, dynamic>{
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'message_seq': 101},
          ],
          'last_message_seq': 101,
          'code': 0,
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = MessageApi.instance;

      final dynamic result = await api.syncCommandMessages(
        maxMessageSeq: 77,
        limit: 50,
      );

      expect(adapter.lastRequestOptions?.path, '/v1/message/sync');
      expect(
        adapter.lastRequestOptions?.data,
        <String, dynamic>{
          'max_message_seq': 77,
          'limit': 50,
        },
      );
      expect(result.lastMessageSeq, 101);
      expect(result.messages, hasLength(1));
    });
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
