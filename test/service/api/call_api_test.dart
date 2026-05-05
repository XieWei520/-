import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/call_api.dart';

void main() {
  group('CallApi.createRoom', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('parses room info from bootstrap response envelope', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingJsonAdapter(
        payload: <String, dynamic>{
          'status': 200,
          'data': <String, dynamic>{
            'room': <String, dynamic>{
              'room_id': 'room_bootstrap_01',
              'caller_uid': 'u_self',
              'caller_name': 'Self',
              'callee_uid': 'u_peer',
              'callee_name': 'Peer',
              'call_type': 1,
              'status': 0,
            },
            'ticket': <String, dynamic>{
              'token': 'jwt-token',
              'expires_at': 1711111111,
              'room_id': 'room_bootstrap_01',
              'participant': 'u_self',
            },
            'join': <String, dynamic>{
              'control_url':
                  'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
              'livekit_url': 'wss://infoequity.qingyunshe.top/livekit',
              'room_name': 'room_bootstrap_01',
            },
            'capabilities': <String, dynamic>{
              'platform': 'windows',
              'supports_video': true,
              'supports_audio': true,
              'prefers_audio': false,
              'is_safari': false,
              'is_mobile_web': false,
            },
          },
        },
      );

      final room = await CallApi.instance.createRoom(
        calleeUid: 'u_peer',
        calleeName: 'Peer',
        callType: CallType.video,
      );

      expect(room.roomId, 'room_bootstrap_01');
      expect(room.callerUid, 'u_self');
      expect(room.calleeUid, 'u_peer');
      expect(room.callType, CallType.video);
    });
  });
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

  final Object payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
