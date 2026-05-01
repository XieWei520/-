import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageApi pinned contracts', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('syncMessageExtras keeps is_pinned from server payload', () async {
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'POST' &&
            options.uri.path == '/v1/message/extra/sync') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'message_id': 123,
                'message_id_str': '123',
                'extra_version': 77,
                'readed': 1,
                'is_pinned': 1,
              },
            ],
          });
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final extras = await MessageApi.instance.syncMessageExtras(
        channelId: 'g_pinned_contract',
        channelType: WKChannelType.group,
        extraVersion: 0,
        deviceUuid: 'device-01',
      );

      expect(extras, hasLength(1));
      final dynamic extra = extras.single;
      expect(extra.isPinned, 1);
    });

    test(
      'syncPinnedMessages returns pinned rows and resolved messages',
      () async {
        final adapter = _RoutingJsonAdapter((options) {
          if (options.method.toUpperCase() == 'POST' &&
              options.uri.path == '/v1/message/pinned/sync') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <String, dynamic>{
                'pinned_messages': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'message_id': '123',
                    'message_seq': 9,
                    'channel_id': 'g_pinned_contract',
                    'channel_type': WKChannelType.group,
                    'is_deleted': 0,
                    'version': 11,
                    'created_at': '2026-04-16T00:00:00Z',
                    'updated_at': '2026-04-16T00:00:00Z',
                  },
                ],
                'messages': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'message_id': '123',
                    'message_seq': 9,
                    'client_msg_no': 'client-123',
                    'from_uid': 'u_owner',
                    'channel_id': 'g_pinned_contract',
                    'channel_type': WKChannelType.group,
                    'timestamp': 1713225600,
                    'payload': <String, dynamic>{
                      'type': WkMessageContentType.text,
                      'content': 'Pinned hello',
                    },
                    'message_extra': <String, dynamic>{
                      'message_id': 123,
                      'message_id_str': '123',
                      'extra_version': 11,
                      'is_pinned': 1,
                    },
                  },
                ],
              },
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic api = MessageApi.instance;
        final dynamic snapshot = await api.syncPinnedMessages(
          channelId: 'g_pinned_contract',
          channelType: WKChannelType.group,
          version: 0,
        );

        expect(snapshot.pinnedMessages, hasLength(1));
        expect(snapshot.messages, hasLength(1));
        expect(snapshot.pinnedMessages.single.messageId, '123');
        expect(snapshot.messages.single.messageID, '123');
      },
    );

    test('clearUnread falls back to legacy coversation route on 404', () async {
      final requestedPaths = <String>[];
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'PUT') {
          requestedPaths.add(options.uri.path);
          final data = options.data as Map<String, dynamic>;
          expect(data['channel_id'], 'u_fallback');
          expect(data['channel_type'], WKChannelType.personal);
          expect(data['unread'], 0);

          if (options.uri.path == '/v1/conversation/clearUnread') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 404,
              'msg': 'missing canonical route',
            }, statusCode: 404);
          }
          if (options.uri.path == '/v1/coversation/clearUnread') {
            return _MockJsonResponse(<String, dynamic>{'code': 0});
          }
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await MessageApi.instance.clearUnread(
        channelId: 'u_fallback',
        channelType: WKChannelType.personal,
        unread: -8,
      );

      expect(requestedPaths, <String>[
        '/v1/conversation/clearUnread',
        '/v1/coversation/clearUnread',
      ]);
    });

    test('clearUnread does not fall back on non-404 failures', () async {
      final requestedPaths = <String>[];
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'PUT' &&
            options.uri.path == '/v1/conversation/clearUnread') {
          requestedPaths.add(options.uri.path);
          return _MockJsonResponse(<String, dynamic>{
            'code': 500,
            'msg': 'upstream failure',
          }, statusCode: 500);
        }

        requestedPaths.add(options.uri.path);
        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        MessageApi.instance.clearUnread(
          channelId: 'u_failure',
          channelType: WKChannelType.personal,
          unread: 3,
        ),
        throwsA(isA<Exception>()),
      );

      expect(requestedPaths, <String>['/v1/conversation/clearUnread']);
    });

    test('markAsRead treats missing remote messages as idempotent', () async {
      RequestOptions? capturedOptions;
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'POST' &&
            options.uri.path == '/v1/message/readed') {
          capturedOptions = options;
          return _MockJsonResponse(<String, dynamic>{
            'code': 400,
            'msg': '没有读取到消息！',
          }, statusCode: 400);
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await MessageApi.instance.markAsRead(
        channelId: 'u_stale_receipt',
        channelType: WKChannelType.personal,
        messageIds: <String>[' 2048641330791223300 ', '2048641330791223300'],
      );

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.data['message_ids'], <String>[
        '2048641330791223300',
      ]);
    });

    test(
      'revokeMessage sends revoke identity and channel coordinates as query params',
      () async {
        RequestOptions? capturedOptions;
        final adapter = _RoutingJsonAdapter((options) {
          if (options.method.toUpperCase() == 'POST' &&
              options.uri.path == '/v1/message/revoke') {
            capturedOptions = options;
            return _MockJsonResponse(<String, dynamic>{'status': 200});
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await MessageApi.instance.revokeMessage(
          clientMsgNo: 'client-revoke-1',
          channelId: 'u-revoke-target',
          channelType: WKChannelType.personal,
        );

        expect(capturedOptions, isNotNull);
        expect(
          capturedOptions!.queryParameters['client_msg_no'],
          'client-revoke-1',
        );
        expect(
          capturedOptions!.queryParameters['channel_id'],
          'u-revoke-target',
        );
        expect(
          '${capturedOptions!.queryParameters['channel_type']}',
          '${WKChannelType.personal}',
        );
      },
    );

    test(
      'deleteMessage sends delete-msg array contract expected by server',
      () async {
        RequestOptions? capturedOptions;
        final adapter = _RoutingJsonAdapter((options) {
          if (options.method.toUpperCase() == 'DELETE' &&
              options.uri.path == '/v1/message') {
            capturedOptions = options;
            return _MockJsonResponse(<String, dynamic>{'code': 0});
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final dynamic api = MessageApi.instance;
        await api.deleteMessage(
          messageId: '1046196978106142720',
          messageSeq: 77,
          channelId: 'u-delete-target',
          channelType: WKChannelType.personal,
        );

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.data, isA<List<dynamic>>());
        final payload = (capturedOptions!.data as List<dynamic>).single as Map;
        expect(payload['message_id'], '1046196978106142720');
        expect(payload['message_seq'], 77);
        expect(payload['channel_id'], 'u-delete-target');
        expect(payload['channel_type'], WKChannelType.personal);
        expect(payload.containsKey('client_msg_no'), isFalse);
      },
    );
  });
}

class _RoutingJsonAdapter implements HttpClientAdapter {
  _RoutingJsonAdapter(this._handler);

  final _MockJsonResponse Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.payload),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockJsonResponse {
  const _MockJsonResponse(this.payload, {this.statusCode = 200});

  final Object payload;
  final int statusCode;
}
