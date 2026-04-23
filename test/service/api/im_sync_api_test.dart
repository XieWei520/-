import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/im_sync_api.dart';

void main() {
  group('IMSyncApi', () {
    test(
      'syncConversation parses Android cmds and channel_status payloads',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'data': <String, dynamic>{
              'uid': 'u_self',
              'cmd_version': 9,
              'cmds': <Map<String, dynamic>>[
                <String, dynamic>{
                  'cmd': 'friendAccept',
                  'param': <String, dynamic>{'uid': 'u_other'},
                },
              ],
              'channel_status': <Map<String, dynamic>>[
                <String, dynamic>{
                  'channel_id': 'group_01',
                  'channel_type': 2,
                  'calling': 1,
                },
              ],
              'conversations': const <Map<String, dynamic>>[],
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final result = await IMSyncApi.instance.syncConversation(
          version: 3,
          lastMsgSeqs: '',
          msgCount: 200,
          deviceUuid: 'device_uuid_01',
        );

        expect(result.cmdVersion, 9);
        expect(result.cmds, isNotNull);
        expect(result.cmds, hasLength(1));
        expect(result.cmds!.single.cmd, 'friendAccept');
        expect(result.cmds!.single.param, isA<Map>());

        final dynamic dynamicResult = result;
        expect(dynamicResult.channelStatus, isNotNull);
        expect(dynamicResult.channelStatus, hasLength(1));
        expect(dynamicResult.channelStatus.first.channelID, 'group_01');
        expect(dynamicResult.channelStatus.first.channelType, 2);
        expect(dynamicResult.channelStatus.first.calling, 1);

        expect(adapter.lastRequestOptions?.path, '/v1/conversation/sync');
        expect(
          (adapter.lastRequestOptions?.data
              as Map<String, dynamic>)['device_uuid'],
          'device_uuid_01',
        );
      },
    );

    test('fetchUserConnectAddr reads Android tcp_addr route payload', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'tcp_addr': '42.194.218.158:5100',
          'ws_addr': 'ws://42.194.218.158:5200',
          'wss_addr': '',
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = IMSyncApi.instance;

      final addr = await api.fetchUserConnectAddr(uid: 'u_self');

      expect(adapter.lastRequestOptions?.path, '/v1/users/u_self/im');
      expect(addr, '42.194.218.158:5100');
    });

    test('ackConversationSync posts cmd_version and device_uuid', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{'code': 0},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final dynamic api = IMSyncApi.instance;

      await api.ackConversationSync(
        cmdVersion: 12,
        deviceUuid: 'device_uuid_01',
      );

      expect(adapter.lastRequestOptions?.path, '/v1/conversation/syncack');
      expect(adapter.lastRequestOptions?.data, <String, dynamic>{
        'cmd_version': 12,
        'device_uuid': 'device_uuid_01',
      });
    });

    test(
      'uploadRealtimeRolloutTelemetry posts event batches to rollout endpoint',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await IMSyncApi.instance.uploadRealtimeRolloutTelemetry(
          <RealtimeTelemetryEvent>[
            RealtimeTelemetryEvent(
              name: RealtimeRolloutTelemetry.metricGatewayReconnectCount,
              value: 1,
              recordedAt: DateTime.fromMillisecondsSinceEpoch(1713345600000),
              sessionId: 'sess_upload_01',
            ),
            RealtimeTelemetryEvent(
              name: RealtimeRolloutTelemetry.metricSqlitePageQueryP95Ms,
              value: 18,
              recordedAt: DateTime.fromMillisecondsSinceEpoch(1713345600500),
              sessionId: 'sess_upload_01',
              tags: const <String, String>{'mode': 'older_page'},
            ),
          ],
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/realtime/session/rollout/telemetry',
        );
        expect(adapter.lastRequestOptions?.data, <String, dynamic>{
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'gateway_reconnect_count',
              'value': 1,
              'recorded_at_ms': 1713345600000,
              'session_id': 'sess_upload_01',
            },
            <String, dynamic>{
              'name': 'sqlite_page_query_p95_ms',
              'value': 18,
              'recorded_at_ms': 1713345600500,
              'session_id': 'sess_upload_01',
              'tags': <String, String>{'mode': 'older_page'},
            },
          ],
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
