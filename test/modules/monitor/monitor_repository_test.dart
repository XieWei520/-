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
    expect(
      snapshot.browserStatus.loginStatus,
      MonitorBrowserLoginStatus.loggedIn,
    );
    expect(
      adapter.paths,
      contains('/v1/monitor/platforms/feishu/browser-status'),
    );
  });

  test('loadFeishuSnapshot deduplicates repeated local Agent cards', () async {
    adapter.agentPayload = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'agent_old',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'version': '0.1.0',
        'status': 'offline',
        'last_heartbeat_at': '2026-05-06T15:47:31Z',
      },
      <String, dynamic>{
        'id': 'agent_latest',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'version': '0.1.0',
        'status': 'online',
        'last_heartbeat_at': '2026-05-06T16:11:57Z',
      },
      <String, dynamic>{
        'id': 'agent_other',
        'device_name': 'OTHER-PC',
        'platform': 'windows',
        'version': '0.1.0',
        'status': 'offline',
        'last_heartbeat_at': '2026-05-06T15:00:00Z',
      },
    ];

    final snapshot = await MonitorRepository().loadFeishuSnapshot();

    expect(snapshot.agents.map((agent) => agent.id), <String>[
      'agent_latest',
      'agent_other',
    ]);
  });

  test(
    'loadDestinationGroups hides inactive duplicate groups and disambiguates names',
    () async {
      adapter.groupMyPayload = <Map<String, dynamic>>[
        <String, dynamic>{
          'group_no': 'old_group',
          'name': 'test1、平权客服、LD',
          'status': 2,
          'updated_at': '2026-04-27T13:34:17Z',
        },
        <String, dynamic>{
          'group_no': 'active_group',
          'name': 'test1、平权客服、LD',
          'status': 1,
          'updated_at': '2026-05-03T08:52:41Z',
        },
        <String, dynamic>{'group_no': 'news_group', 'name': '新闻群', 'status': 1},
      ];
      adapter.groupInfoPayloads = <String, Map<String, dynamic>>{
        'old_group': <String, dynamic>{
          'group_no': 'old_group',
          'name': 'test1、平权客服、LD',
          'status': 2,
          'updated_at': '2026-04-27T13:34:17Z',
        },
        'active_group': <String, dynamic>{
          'group_no': 'active_group',
          'name': 'test1、平权客服、LD',
          'status': 1,
          'updated_at': '2026-05-03T08:52:41Z',
        },
        'news_group': <String, dynamic>{
          'group_no': 'news_group',
          'name': '新闻群',
          'status': 1,
        },
      };

      final groups = await MonitorRepository().loadDestinationGroups();

      expect(groups.map((group) => group.groupNo), <String>[
        'active_group',
        'news_group',
      ]);
    expect(groups.first.label, 'test1、平权客服、LD（active_…）');
    },
  );
}

class _MonitorRepositoryAdapter implements HttpClientAdapter {
  final paths = <String>[];
  List<Map<String, dynamic>> agentPayload = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'agent_1',
      'device_name': 'COLORFUL-PC',
      'platform': 'windows',
      'version': '0.1.0',
      'status': 'online',
      'last_heartbeat_at': '??',
    },
  ];
  List<Map<String, dynamic>> groupMyPayload = const <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> groupInfoPayloads =
      const <String, Map<String, dynamic>>{};

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
    if (path == '/v1/group/my') {
      return <String, dynamic>{'code': 0, 'data': groupMyPayload};
    }
    const groupPrefix = '/v1/groups/';
    if (path.startsWith(groupPrefix)) {
      final groupNo = path.substring(groupPrefix.length);
      return <String, dynamic>{
        'code': 0,
        'data': groupInfoPayloads[groupNo] ?? <String, dynamic>{},
      };
    }
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
        return <String, dynamic>{'code': 0, 'data': agentPayload};
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
