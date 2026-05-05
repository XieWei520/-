import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/domain/call_bootstrap_models.dart';
import 'package:wukong_im_app/modules/video_call/infrastructure/call_bootstrap_api.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  group('CallBootstrap', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('parses call bootstrap payload with ticket and join descriptor', () {
      final bootstrap = CallBootstrap.fromJson({
        'room': {
          'room_id': 'room_01',
          'caller_uid': 'u1',
          'caller_name': 'Caller',
          'callee_uid': 'u2',
          'callee_name': 'Peer',
          'room_name': '研发群多人通话',
          'channel_id': 'g_demo',
          'channel_type': 2,
          'participants': [
            {'uid': 'u1', 'name': 'Caller', 'role': 0, 'invite_status': 1},
            {'uid': 'u2', 'name': 'Peer', 'role': 1, 'invite_status': 0},
          ],
          'call_type': 1,
          'status': 0,
        },
        'ticket': {
          'token': 'jwt-token',
          'expires_at': 1711111111,
          'room_id': 'room_01',
          'participant': 'u1',
        },
        'join': {
          'control_url': 'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
          'livekit_url': 'wss://infoequity.qingyunshe.top/livekit',
          'room_name': 'room_01',
        },
        'capabilities': {
          'platform': 'web',
          'supports_video': true,
          'supports_audio': true,
          'prefers_audio': false,
          'is_safari': false,
          'is_mobile_web': false,
        },
      });

      expect(bootstrap.ticket.token, 'jwt-token');
      expect(
        bootstrap.join.controlUrl,
        'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
      );
      expect(bootstrap.capabilities.platform, 'web');
      expect(bootstrap.room.callType, CallType.video);
      expect(bootstrap.room.roomName, '研发群多人通话');
      expect(bootstrap.room.channelId, 'g_demo');
      expect(bootstrap.room.channelType, 2);
      expect(bootstrap.room.participants.map((item) => item.uid), <String>[
        'u1',
        'u2',
      ]);
    });

    test(
      'createRoom sends capabilities and parses bootstrap envelope',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'status': 200,
            'data': <String, dynamic>{
              'room': <String, dynamic>{
                'room_id': 'room_01',
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
                'room_id': 'room_01',
                'participant': 'u_self',
              },
              'join': <String, dynamic>{
                'control_url':
                    'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
                'livekit_url': 'wss://infoequity.qingyunshe.top/livekit',
                'room_name': 'room_01',
              },
              'capabilities': <String, dynamic>{
                'platform': 'web',
                'supports_video': true,
                'supports_audio': true,
                'prefers_audio': false,
                'is_safari': false,
                'is_mobile_web': false,
              },
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final api = CallBootstrapApi(client: ApiClient.instance);

        final bootstrap = await api.createRoom(
          calleeUid: 'u_peer',
          calleeName: 'Peer',
          callType: CallType.video,
          capabilities: const CallMediaCapabilities(
            platform: 'web',
            supportsVideo: true,
            supportsAudio: true,
            prefersAudio: false,
            isSafari: false,
            isMobileWeb: false,
          ),
        );

        expect(adapter.lastRequestOptions?.path, '/v1/extra/call/room');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('callee_uid', 'u_peer'),
        );
        expect(adapter.lastRequestOptions?.data, containsPair('call_type', 1));
        expect(
          adapter.lastRequestOptions?.data['capabilities'],
          containsPair('platform', 'web'),
        );
        expect(bootstrap.room.roomId, 'room_01');
        expect(bootstrap.ticket.participant, 'u_self');
      },
    );

    test(
      'createRoom sends participants and room context for group calls',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'status': 200,
            'data': <String, dynamic>{
              'room': <String, dynamic>{
                'room_id': 'room_group_01',
                'caller_uid': 'u_self',
                'caller_name': 'Self',
                'callee_uid': '',
                'callee_name': '',
                'room_name': '研发群多人通话',
                'channel_id': 'g_demo',
                'channel_type': 2,
                'participants': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'uid': 'u_alice',
                    'name': 'Alice',
                    'role': 1,
                    'invite_status': 0,
                  },
                  <String, dynamic>{
                    'uid': 'u_bob',
                    'name': 'Bob',
                    'role': 1,
                    'invite_status': 0,
                  },
                ],
                'call_type': 1,
                'status': 0,
              },
              'ticket': <String, dynamic>{
                'token': 'jwt-token',
                'expires_at': 1711111111,
                'room_id': 'room_group_01',
                'participant': 'u_self',
              },
              'join': <String, dynamic>{
                'control_url':
                    'wss://infoequity.qingyunshe.top/v1/callgateway/ws',
                'livekit_url': 'wss://infoequity.qingyunshe.top/livekit',
                'room_name': 'room_group_01',
              },
              'capabilities': <String, dynamic>{
                'platform': 'android',
                'supports_video': true,
                'supports_audio': true,
                'prefers_audio': false,
                'is_safari': false,
                'is_mobile_web': false,
              },
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;
        final api = CallBootstrapApi(client: ApiClient.instance);

        final bootstrap = await api.createRoom(
          calleeUid: '',
          calleeName: '',
          callType: CallType.video,
          capabilities: const CallMediaCapabilities(
            platform: 'android',
            supportsVideo: true,
            supportsAudio: true,
            prefersAudio: false,
            isSafari: false,
            isMobileWeb: false,
          ),
          roomName: '研发群多人通话',
          channelId: 'g_demo',
          channelType: 2,
          participants: const <CallParticipant>[
            CallParticipant(
              uid: 'u_alice',
              name: 'Alice',
              role: 1,
              inviteStatus: 0,
            ),
            CallParticipant(
              uid: 'u_bob',
              name: 'Bob',
              role: 1,
              inviteStatus: 0,
            ),
          ],
        );

        expect(adapter.lastRequestOptions?.data['room_name'], '研发群多人通话');
        expect(adapter.lastRequestOptions?.data['channel_id'], 'g_demo');
        expect(adapter.lastRequestOptions?.data['channel_type'], 2);
        expect(
          (adapter.lastRequestOptions?.data['participants'] as List<dynamic>),
          hasLength(2),
        );
        expect(bootstrap.room.roomName, '研发群多人通话');
        expect(bootstrap.room.channelId, 'g_demo');
        expect(bootstrap.room.channelType, 2);
        expect(bootstrap.room.participants.map((item) => item.uid), <String>[
          'u_alice',
          'u_bob',
        ]);
      },
    );

    test('createRoom surfaces backend envelope errors', () async {
      final adapter = _RecordingJsonAdapter(
        payload: <String, dynamic>{'status': 403, 'msg': 'forbidden'},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final api = CallBootstrapApi(client: ApiClient.instance);

      expect(
        () => api.createRoom(
          calleeUid: 'u_peer',
          calleeName: 'Peer',
          callType: CallType.video,
          capabilities: const CallMediaCapabilities(
            platform: 'web',
            supportsVideo: true,
            supportsAudio: true,
            prefersAudio: false,
            isSafari: false,
            isMobileWeb: false,
          ),
        ),
        throwsA(
          isA<CallBootstrapApiException>().having(
            (error) => error.message,
            'message',
            'forbidden',
          ),
        ),
      );
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
