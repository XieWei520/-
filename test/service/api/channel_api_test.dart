import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/channel_api.dart';

void main() {
  group('ChannelApi', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test(
      'getChannelInfo parses direct channel response and msg_auto_delete extra',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'channel': <String, dynamic>{
              'channel_id': 'u_auto_delete',
              'channel_type': 1,
            },
            'name': 'Auto Delete User',
            'extra': <String, dynamic>{'msg_auto_delete': 3600},
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final info = await ChannelApi.instance.getChannelInfo(
          channelId: 'u_auto_delete',
          channelType: 1,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/channels/u_auto_delete/1',
        );
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(info.channelId, 'u_auto_delete');
        expect(info.channelType, 1);
        expect(info.msgAutoDelete, 3600);
      },
    );

    test(
      'setMessageAutoDelete uses POST /v1/channels/:channel_id/:channel_type/message/autodelete',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await ChannelApi.instance.setMessageAutoDelete(
          channelId: 'g_auto_delete',
          channelType: 2,
          seconds: 86400,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/channels/g_auto_delete/2/message/autodelete',
        );
        expect(adapter.lastRequestOptions?.method, 'POST');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('msg_auto_delete', 86400),
        );
      },
    );
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
