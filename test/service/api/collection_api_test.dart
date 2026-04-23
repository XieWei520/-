import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/collection_api.dart';

void main() {
  group('CollectionApi', () {
    test('add sends favorite metadata when provided', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'status': 200},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await CollectionApi.instance.add(
        clientMsgNo: 'client-1',
        messageId: 'message-1',
        messageSeq: 101,
        orderSeq: 202,
        content: 'hello',
        contentType: 1,
        channelId: 'group-1',
        channelType: 2,
        senderUid: 'u-sender',
        senderName: 'Alice',
      );

      expect(adapter.lastRequestOptions?.path, ApiConfig.favorite);
      expect(adapter.lastRequestOptions?.method, 'POST');
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('client_msg_no', 'client-1'),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('message_id', 'message-1'),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('channel_id', 'group-1'),
      );
      expect(adapter.lastRequestOptions?.data, containsPair('channel_type', 2));
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('sender_uid', 'u-sender'),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('sender_name', 'Alice'),
      );
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('message_seq', 101),
      );
      expect(adapter.lastRequestOptions?.data, containsPair('order_seq', 202));
    });

    test(
      'getList uses favorites endpoint with paging query parameters',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'fav-1'},
            ],
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final records = await CollectionApi.instance.getList(
          page: 3,
          pageSize: 40,
        );

        expect(adapter.lastRequestOptions?.path, ApiConfig.favorites);
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('page', 3),
        );
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('page_size', 40),
        );
        expect(records.single['id'], 'fav-1');
      },
    );

    test('search uses the favorites search endpoint', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{
          'count': 0,
          'data': <dynamic>[],
          'page': 1,
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await CollectionApi.instance.search(
        keyword: 'hello',
        page: 2,
        pageSize: 30,
      );

      expect(adapter.lastRequestOptions?.path, '${ApiConfig.favorites}/search');
      expect(
        adapter.lastRequestOptions?.data,
        containsPair('keyword', 'hello'),
      );
      expect(adapter.lastRequestOptions?.data, containsPair('page', 2));
      expect(adapter.lastRequestOptions?.data, containsPair('page_size', 30));
    });

    test('delete uses favorite delete endpoint with id path', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'data': <dynamic>[]},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await CollectionApi.instance.delete('fav-99');

      expect(adapter.lastRequestOptions?.path, '${ApiConfig.favorite}/fav-99');
      expect(adapter.lastRequestOptions?.method, 'DELETE');
    });
  });
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

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
