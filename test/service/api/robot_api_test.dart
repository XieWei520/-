import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/robot_api.dart';

void main() {
  group('RobotApi', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test(
      'syncRobots sends Android-style robot descriptors with version fields',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0, 'data': <dynamic>[]},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await RobotApi.instance.syncRobots(const <RobotSyncTarget>[
          RobotSyncTarget(robotId: 'robot-gif', version: 7),
          RobotSyncTarget(username: 'weather', version: 2),
        ]);

        expect(adapter.lastRequestOptions?.path, '/v1/robot/sync');
        expect(adapter.lastRequestOptions?.data, <Map<String, dynamic>>[
          <String, dynamic>{'robot_id': 'robot-gif', 'version': 7},
          <String, dynamic>{'username': 'weather', 'version': 2},
        ]);
      },
    );

    test(
      'inlineQuery forwards username and channel_type when provided',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0, 'results': <dynamic>[]},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await RobotApi.instance.inlineQuery(
          robotId: 'robot-gif',
          username: 'gif',
          query: 'hello',
          channelId: 'g1',
          channelType: 2,
          offset: 10,
        );

        expect(adapter.lastRequestOptions?.path, '/v1/robot/inline_query');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('username', 'gif'),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('channel_type', 2),
        );
      },
    );

    test(
      'searchGifs forwards username and channel_type to inline query payload',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{'code': 0, 'results': <dynamic>[]},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await RobotApi.instance.searchGifs(
          query: 'wave',
          offset: 4,
          username: 'gif',
          channelId: 'g1',
          channelType: 2,
        );

        expect(adapter.lastRequestOptions?.path, '/v1/robot/inline_query');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('username', 'gif'),
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('channel_type', 2),
        );
      },
    );

    test(
      'startStream posts to the verified robot stream start route and returns stream number',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{
            'code': 0,
            'stream_no': 'stream-001',
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final response = await RobotApi.instance.startStream(
          robotId: 'robot-ai',
          appKey: 'app-key',
          request: const RobotStreamStartRequest(
            clientMsgNo: 'client-001',
            fromUid: 'robot-ai',
            channelId: 'u_target',
            channelType: 1,
            payload: <String, dynamic>{'type': 'markdown', 'content': 'hi'},
          ),
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/robots/robot-ai/app-key/stream/start',
        );
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('client_msg_no', 'client-001'),
        );
        expect(response.streamNo, 'stream-001');
      },
    );

    test('endStream posts to the verified robot stream end route', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'status': 200},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await RobotApi.instance.endStream(
        robotId: 'robot-ai',
        appKey: 'app-key',
        request: const RobotStreamEndRequest(
          streamNo: 'stream-001',
          channelId: 'u_target',
          channelType: 1,
        ),
      );

      expect(
        adapter.lastRequestOptions?.path,
        '/v1/robots/robot-ai/app-key/stream/end',
      );
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{
        'stream_no': 'stream-001',
        'channel_id': 'u_target',
        'channel_type': 1,
      });
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
