import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';
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

    test('fetchUserConnectRoute parses preferred transport contract', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'tcp_addr': 'wemx.cc:5100',
          'ws_addr': 'ws://wemx.cc:5200',
          'wss_addr': 'wss://wemx.cc/ws',
          'preferred_transport': 'wss',
          'preferred_addr': 'wss://wemx.cc/ws',
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final route = await IMSyncApi.instance.fetchUserConnectRoute(
        uid: 'u_self',
      );

      expect(adapter.lastRequestOptions?.path, '/v1/users/u_self/im');
      expect(route.tcpAddr, 'wemx.cc:5100');
      expect(route.wsAddr, 'ws://wemx.cc:5200');
      expect(route.wssAddr, 'wss://wemx.cc/ws');
      expect(route.preferredTransport, 'wss');
      expect(route.preferredAddr, 'wss://wemx.cc/ws');
    });

    test('fetchUserConnectRoute parses preferred transport contract', () async {
      final adapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'tcp_addr': 'infoequity.cn:5100',
          'ws_addr': 'ws://infoequity.cn:5200',
          'wss_addr': 'wss://infoequity.cn/ws',
          'preferred_transport': 'wss',
          'preferred_addr': 'wss://infoequity.cn/ws',
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final route = await IMSyncApi.instance.fetchUserConnectRoute(
        uid: 'u_self',
      );

      expect(adapter.lastRequestOptions?.path, '/v1/users/u_self/im');
      expect(route, isA<ImRouteInfo>());
      expect(route.tcpAddr, 'infoequity.cn:5100');
      expect(route.wsAddr, 'ws://infoequity.cn:5200');
      expect(route.wssAddr, 'wss://infoequity.cn/ws');
      expect(route.preferredTransport, 'wss');
      expect(route.preferredAddr, 'wss://infoequity.cn/ws');
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

    test(
      'pullAfterSeq parses wrapped event lists and clamps query bounds',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: <String, dynamic>{
            'data': <String, dynamic>{
              'events': <Map<String, dynamic>>[
                <String, dynamic>{
                  'event_id': 'evt_delta_01',
                  'user_seq': 9,
                  'server_ts': 1712000009,
                  'kind': 'conversation.updated',
                  'aggregate_id': '1:u_1001',
                  'payload': <String, dynamic>{'channel_id': 'u_1001'},
                },
              ],
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final frames = await IMSyncApi.instance.pullAfterSeq(
          afterSeq: -10,
          limit: 999,
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/realtime/session/events/pull_after_seq',
        );
        expect(adapter.lastRequestOptions?.queryParameters, <String, dynamic>{
          'after_seq': 0,
          'limit': 200,
        });
        expect(frames, hasLength(1));
        expect(frames.single.eventId, 'evt_delta_01');
        expect(frames.single.userSeq, 9);
        expect(frames.single.payload['channel_id'], 'u_1001');
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
