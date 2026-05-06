import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/monitor/monitor_local_agent_binder.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';

void main() {
  testWidgets('Feishu center shows browser status card for existing agent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithBrowserStatus,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onOpenBrowserLogin: () async =>
              const LocalAgentActionResult(message: '已打开 Chromium 飞书登录窗口，请扫码登录。'),
          onCheckBrowserStatus: () async =>
              const LocalAgentActionResult(message: '飞书浏览器状态已同步。'),
          onClearBrowserProfile: () async =>
              const LocalAgentActionResult(message: '已清除飞书登录状态，请重新打开飞书登录并扫码。'),
          onListenOnce: () async =>
              const LocalAgentActionResult(message: '监听完成。'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('飞书信息监控中心 · 浏览器状态'), findsOneWidget);
    expect(find.text('Browser: Chromium'), findsOneWidget);
    expect(find.text('Environment: 专属隔离环境'), findsOneWidget);
    expect(find.text('登录状态：已登录'), findsOneWidget);
    expect(find.text('最后检测：2026-05-07T10:00:00Z'), findsOneWidget);
  });

  testWidgets('Browser action buttons call matching callbacks once', (
    tester,
  ) async {
    var openCount = 0;
    var checkCount = 0;
    var clearCount = 0;
    var listenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithBrowserStatus,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onOpenBrowserLogin: () async {
            openCount += 1;
            return const LocalAgentActionResult(
              message: '已打开 Chromium 飞书登录窗口，请扫码登录。',
            );
          },
          onCheckBrowserStatus: () async {
            checkCount += 1;
            return const LocalAgentActionResult(message: '飞书浏览器状态已同步。');
          },
          onClearBrowserProfile: () async {
            clearCount += 1;
            return const LocalAgentActionResult(
              message: '已清除飞书登录状态，请重新打开飞书登录并扫码。',
            );
          },
          onListenOnce: () async {
            listenCount += 1;
            return const LocalAgentActionResult(message: '监听完成。');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-open-browser-login')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-check-browser-status')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feishu-monitor-listen-once')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-monitor-clear-browser-profile')),
    );
    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-clear-browser-profile')),
    );
    await tester.pumpAndSettle();

    expect(openCount, 1);
    expect(checkCount, 1);
    expect(listenCount, 1);
    expect(clearCount, 1);
  });

  testWidgets('Browser action buttons keep aligned sizes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithBrowserStatus,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onOpenBrowserLogin: () async =>
              const LocalAgentActionResult(message: '已打开 Chromium 飞书登录窗口，请扫码登录。'),
          onCheckBrowserStatus: () async =>
              const LocalAgentActionResult(message: '飞书浏览器状态已同步。'),
          onClearBrowserProfile: () async =>
              const LocalAgentActionResult(message: '已清除飞书登录状态，请重新打开飞书登录并扫码。'),
          onListenOnce: () async =>
              const LocalAgentActionResult(message: '监听完成。'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topNewRouteSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-new-route')),
    );
    final openSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-open-browser-login')),
    );
    final checkSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-check-browser-status')),
    );
    final listenSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-listen-once')),
    );
    final clearSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-clear-browser-profile')),
    );

    expect(openSize, equals(topNewRouteSize));
    expect(checkSize, equals(topNewRouteSize));
    expect(listenSize, equals(topNewRouteSize));
    expect(clearSize, equals(topNewRouteSize));
  });
}

const _snapshotWithBrowserStatus = FeishuMonitorSnapshot(
  stats: MonitorStats(runningRoutes: 1, todayForwarded: 28, alerts: 0),
  agents: <MonitorAgent>[
    MonitorAgent(
      id: 'agent_1',
      deviceName: 'COLORFUL-PC',
      platform: 'windows',
      version: '0.1.0',
      status: MonitorAgentStatus.online,
      lastHeartbeatAt: '刚刚',
    ),
  ],
  routes: <MonitorRoute>[
    MonitorRoute(
      id: 'route_1',
      platform: MonitorPlatform.feishu,
      connectorType: MonitorConnectorType.feishuWebGroup,
      routeType: 'feishu_web_group_to_wukong_im_group',
      sourceName: '飞书新闻群',
      destinationName: '悟空 IM 新闻群',
      status: MonitorRouteStatus.running,
      todayForwardedCount: 28,
      lastForwardedAt: '2026-05-06 16:32',
      agentId: 'agent_1',
      includeText: true,
      includeLinks: true,
      includeImages: false,
      includeFiles: false,
    ),
  ],
  logs: <MonitorLogEntry>[
    MonitorLogEntry(
      id: 'log_1',
      type: 'forwarded',
      occurredAt: '16:32',
      message: '已转发 飞书新闻群 → 悟空 IM 新闻群',
    ),
  ],
  browserStatus: MonitorBrowserStatus(
    browser: 'chromium',
    profileMode: 'isolated_persistent',
    loginStatus: MonitorBrowserLoginStatus.loggedIn,
    observedAt: '2026-05-07T10:00:00Z',
    errorMessage: '',
  ),
);
