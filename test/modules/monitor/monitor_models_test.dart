import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';

void main() {
  group('monitor models', () {
    test('MonitorRoute parses Feishu Web group route and exposes labels', () {
      final route = MonitorRoute.fromJson(const <String, dynamic>{
        'id': 'route_1',
        'platform': 'feishu',
        'connector_type': 'feishu_web_group',
        'route_type': 'feishu_web_group_to_wukong_im_group',
        'source_name': '飞书新闻群',
        'destination_name': '悟空 IM 新闻群',
        'status': 'running',
        'today_forwarded_count': 28,
        'last_forwarded_at': '2026-05-06 16:32',
        'agent_id': 'agent_1',
        'include_text': true,
        'include_links': true,
        'include_images': false,
        'include_files': false,
      });

      expect(route.id, 'route_1');
      expect(route.platform, MonitorPlatform.feishu);
      expect(route.connectorType, MonitorConnectorType.feishuWebGroup);
      expect(route.status, MonitorRouteStatus.running);
      expect(route.statusLabel, '运行中');
      expect(route.title, '飞书新闻群 → 悟空 IM 新闻群');
      expect(route.sourceTypeLabel, '飞书 Web 群');
      expect(route.todayForwardedCount, 28);
      expect(route.lastForwardedAt, '2026-05-06 16:32');
      expect(route.includeText, isTrue);
      expect(route.includeLinks, isTrue);
      expect(route.includeImages, isFalse);
      expect(route.includeFiles, isFalse);
    });

    test('MonitorAgent parses status and exposes display labels', () {
      final agent = MonitorAgent.fromJson(const <String, dynamic>{
        'id': 'agent_1',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'version': '0.1.0',
        'status': 'online',
        'last_heartbeat_at': '刚刚',
      });

      expect(agent.id, 'agent_1');
      expect(agent.deviceName, 'COLORFUL-PC');
      expect(agent.platformLabel, 'Windows');
      expect(agent.status, MonitorAgentStatus.online);
      expect(agent.statusLabel, '在线');
      expect(agent.lastHeartbeatAt, '刚刚');
    });

    test('MonitorStats tolerates missing payload values', () {
      final stats = MonitorStats.fromJson(const <String, dynamic>{});

      expect(stats.runningRoutes, 0);
      expect(stats.todayForwarded, 0);
      expect(stats.alerts, 0);
    });

    test('CreateFeishuMonitorRouteRequest serializes backend contract', () {
      const request = CreateFeishuMonitorRouteRequest(
        sourceChatName: '飞书新闻群',
        destinationGroupNo: 'group_1',
        destinationGroupName: '悟空 IM 新闻群',
        includeText: true,
        includeLinks: true,
        includeImages: false,
        includeFiles: false,
      );

      expect(request.toJson(), <String, dynamic>{
        'platform': 'feishu',
        'connector_type': 'feishu_web_group',
        'route_type': 'feishu_web_group_to_wukong_im_group',
        'source': <String, dynamic>{'chat_name': '飞书新闻群'},
        'destination': <String, dynamic>{
          'type': 'wukong_im_group',
          'group_no': 'group_1',
          'group_name': '悟空 IM 新闻群',
        },
        'message_policy': <String, dynamic>{
          'include_text': true,
          'include_links': true,
          'include_images': false,
          'include_files': false,
        },
      });
    });

    test('MonitorLogEntry uses readable fallback text', () {
      final log = MonitorLogEntry.fromJson(const <String, dynamic>{
        'id': 'log_1',
        'type': 'forwarded',
        'occurred_at': '16:32',
        'message': '已转发 飞书新闻群 → 悟空 IM 新闻群',
      });

      expect(log.id, 'log_1');
      expect(log.occurredAt, '16:32');
      expect(log.message, '已转发 飞书新闻群 → 悟空 IM 新闻群');
    });

    test('MonitorBrowserStatus parses browser status payload', () {
      final status = MonitorBrowserStatus.fromJson(const <String, dynamic>{
        'browser': 'chromium',
        'profile_mode': 'isolated_persistent',
        'login_status': 'logged_in',
        'observed_at': '2026-05-07T10:00:00Z',
        'error_message': '',
      });

      expect(status.browser, 'chromium');
      expect(status.profileMode, 'isolated_persistent');
      expect(status.loginStatus, MonitorBrowserLoginStatus.loggedIn);
      expect(status.loginStatusLabel, '已登录');
      expect(status.observedAt, '2026-05-07T10:00:00Z');
    });
  });
}
