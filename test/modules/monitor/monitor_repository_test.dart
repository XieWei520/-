import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';
import 'package:wukong_im_app/modules/monitor/monitor_repository.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late _MonitorRepositoryAdapter adapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    adapter = _MonitorRepositoryAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test('loadFeishuSnapshot includes browser status', () async {
    final snapshot = await MonitorRepository().loadFeishuSnapshot();

    expect(snapshot.stats.runningRoutes, 2);
    expect(snapshot.agents, hasLength(1));
    expect(snapshot.routes, hasLength(1));
    expect(snapshot.logs, hasLength(1));
    expect(snapshot.browserStatus.browser, 'chromium');
    expect(snapshot.browserStatus.loginStatus, MonitorBrowserLoginStatus.loggedIn);
    expect(
      adapter.paths,
      contains('/v1/monitor/platforms/feishu/browser-status'),
    );
  });
}

class _MonitorRepositoryAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode(_payloadForPath(options.path)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _payloadForPath(String path) {
    switch (path) {
      case '/v1/monitor/platforms/feishu/stats':
        return <String, dynamic>{
          'code': 0,
          'data': <String, dynamic>{
            'running_routes': 2,
            'today_forwarded': 18,
            'alerts': 0,
          },
        };
      case '/v1/monitor/agents':
        return <String, dynamic>{
          'code': 0,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'agent_1',
              'device_name': 'COLORFUL-PC',
              'platform': 'windows',
              'version': '0.1.0',
              'status': 'online',
              'last_heartbeat_at': '刚刚',
            },
          ],
        };
      case '/v1/monitor/routes':
        return <String, dynamic>{
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
      case '/v1/monitor/events':
        return <String, dynamic>{
          'code': 0,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'log_1',
              'type': 'forwarded',
              'occurred_at': '16:32',
              'message': '已转发 飞书新闻群 → 悟空 IM 新闻群',
            },
          ],
        };
      case '/v1/monitor/platforms/feishu/browser-status':
        return <String, dynamic>{
          'code': 0,
          'data': <String, dynamic>{
            'browser': 'chromium',
            'profile_mode': 'isolated_persistent',
            'login_status': 'logged_in',
            'observed_at': '2026-05-07T10:00:00Z',
            'error_message': '',
          },
        };
      default:
        return <String, dynamic>{'code': 0, 'data': <String, dynamic>{}};
    }
  }

  @override
  void close({bool force = false}) {}
}
