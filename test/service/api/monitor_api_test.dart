import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/monitor_api.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late _MonitorApiAdapter adapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    adapter = _MonitorApiAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test('fetchStats calls Feishu stats endpoint', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'running_routes': 1,
        'today_forwarded': 28,
        'alerts': 0,
      },
    };

    final stats = await MonitorApi.instance.fetchStats(
      platform: MonitorPlatform.feishu,
    );

    expect(adapter.lastMethod, 'GET');
    expect(adapter.lastPath, '/v1/monitor/platforms/feishu/stats');
    expect(stats.runningRoutes, 1);
    expect(stats.todayForwarded, 28);
    expect(stats.alerts, 0);
  });

  test('fetchRoutes maps route list payload', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'route_1',
          'platform': 'feishu',
          'connector_type': 'feishu_web_group',
          'route_type': 'feishu_web_group_to_wukong_im_group',
          'source_name': '飞书新闻群',
          'destination_name': '悟空 IM 新闻群',
          'status': 'running',
        },
      ],
    };

    final routes = await MonitorApi.instance.fetchRoutes(
      platform: MonitorPlatform.feishu,
    );

    expect(adapter.lastPath, '/v1/monitor/routes');
    expect(adapter.lastQueryParameters, <String, dynamic>{'platform': 'feishu'});
    expect(routes.single.id, 'route_1');
    expect(routes.single.sourceName, '飞书新闻群');
  });

  test('createFeishuRoute posts serialized route request', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'id': 'route_1',
        'platform': 'feishu',
        'connector_type': 'feishu_web_group',
        'route_type': 'feishu_web_group_to_wukong_im_group',
        'source_name': '飞书新闻群',
        'destination_name': '悟空 IM 新闻群',
        'status': 'paused',
      },
    };

    final route = await MonitorApi.instance.createFeishuRoute(
      const CreateFeishuMonitorRouteRequest(
        sourceChatName: '飞书新闻群',
        destinationGroupNo: 'group_1',
        destinationGroupName: '悟空 IM 新闻群',
      ),
    );

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/v1/monitor/routes');
    expect(adapter.lastBody, containsPair('platform', 'feishu'));
    expect(route.id, 'route_1');
    expect(route.status, MonitorRouteStatus.paused);
  });

  test('createPairingCode posts device name and parses code', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'pairing_code': 'ABCD-1234',
        'expires_at': '2026-05-06 18:00',
      },
    };

    final code = await MonitorApi.instance.createPairingCode('COLORFUL-PC');

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/v1/monitor/agent-pairing-codes');
    expect(adapter.lastBody, <String, dynamic>{
      'device_name': 'COLORFUL-PC',
      'platform': 'windows',
    });
    expect(code.code, 'ABCD-1234');
    expect(code.expiresAt, '2026-05-06 18:00');
  });
}

class _MonitorApiAdapter implements HttpClientAdapter {
  Object payload = const <String, dynamic>{'code': 0, 'data': null};
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;
  dynamic lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.path;
    lastQueryParameters = Map<String, dynamic>.from(options.queryParameters);
    lastBody = options.data;
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
