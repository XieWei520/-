import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';
import 'package:wukong_im_app/modules/monitor/monitor_local_agent_binder.dart';

void main() {
  testWidgets('Feishu center renders stats, route, agent, and logs', (
    tester,
  ) async {
    var downloadTapCount = 0;
    var pauseTapCount = 0;
    var logTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithData,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () => downloadTapCount++,
          onPauseRoute: (_) async => pauseTapCount++,
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) => logTapCount++,
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('飞书信息监控中心'), findsWidgets);
    expect(find.text('运行中规则'), findsOneWidget);
    expect(find.text('今日转发'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('异常提醒'), findsOneWidget);
    expect(find.text('飞书新闻群 → 悟空 IM 新闻群'), findsOneWidget);
    expect(find.text('来源：飞书 Web 群'), findsOneWidget);
    expect(find.text('状态：运行中'), findsOneWidget);
    expect(find.text('COLORFUL-PC'), findsOneWidget);
    expect(find.text('16:32 已转发 飞书新闻群 → 悟空 IM 新闻群'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-download-agent')),
    );
    await tester.pump();
    expect(downloadTapCount, 1);

    await tester.tap(find.byKey(const ValueKey('monitor-route-pause-route_1')));
    await tester.pumpAndSettle();
    expect(pauseTapCount, 1);

    await tester.tap(find.byKey(const ValueKey('monitor-route-logs-route_1')));
    await tester.pump();
    expect(logTapCount, 1);
  });

  testWidgets('Feishu center shows agent onboarding and pairing code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => FeishuMonitorSnapshot.empty,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有绑定 Windows Agent'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-create-pairing')),
    );
    await tester.pumpAndSettle();

    expect(find.text('配对码：ABCD-1234'), findsOneWidget);
    expect(find.text('有效期至：2026-05-06 18:00'), findsOneWidget);
  });

  testWidgets('Feishu center one-click binds local Agent and refreshes', (
    tester,
  ) async {
    var loadCount = 0;
    LocalAgentBindRequest? bindRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async {
            loadCount++;
            if (loadCount == 1) {
              return FeishuMonitorSnapshot.empty;
            }
            return const FeishuMonitorSnapshot(
              stats: MonitorStats.empty,
              agents: <MonitorAgent>[
                MonitorAgent(
                  id: 'agent_1',
                  deviceName: 'COLORFUL-PC',
                  platform: 'windows',
                  version: '0.1.0',
                  status: MonitorAgentStatus.online,
                  lastHeartbeatAt: '??',
                ),
              ],
              routes: <MonitorRoute>[],
              logs: <MonitorLogEntry>[],
            );
          },
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onBindLocalAgent: (request) async {
            bindRequest = request;
            return const LocalAgentBindResult(message: 'Agent 已绑定并上线');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
    );
    await tester.pumpAndSettle();

    expect(bindRequest, isNotNull);
    expect(bindRequest!.serverUrl, 'https://infoequity.qingyunshe.top');
    expect(bindRequest!.pairingCode, 'ABCD-1234');
    expect(loadCount, 2);
    expect(find.text('COLORFUL-PC'), findsOneWidget);
    expect(find.text('Agent 已绑定并上线'), findsOneWidget);
  });

  testWidgets('Feishu center one-click bind failure keeps pairing code', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async {
            loadCount++;
            return FeishuMonitorSnapshot.empty;
          },
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onBindLocalAgent: (_) async {
            throw const LocalAgentBindException(
              'Agent 心跳失败：Bearer *** failed',
              phase: LocalAgentBindPhase.heartbeat,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);
    expect(find.textContaining('ABCD-1234'), findsOneWidget);
    expect(find.textContaining('一键绑定失败'), findsOneWidget);
    expect(find.textContaining('Bearer ***'), findsOneWidget);
  });

  testWidgets('Feishu center aligns monitor action button sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => FeishuMonitorSnapshot.empty,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topNewRouteSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-new-route')),
    );
    final topDownloadSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-download-agent')),
    );
    final createPairingSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-create-pairing')),
    );
    final onboardingDownloadSize = tester.getSize(
      find.byKey(const ValueKey('feishu-monitor-onboarding-download-agent')),
    );

    expect(topNewRouteSize, equals(topDownloadSize));
    expect(topNewRouteSize, equals(createPairingSize));
    expect(topNewRouteSize, equals(onboardingDownloadSize));
  });

  testWidgets('Feishu center re-pair button shows onboarding actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithData,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onBindLocalAgent: (_) async =>
              const LocalAgentBindResult(message: 'Agent 已绑定并上线'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COLORFUL-PC'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-monitor-repair-agent')),
    );
    await tester.tap(find.byKey(const ValueKey('feishu-monitor-repair-agent')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('feishu-monitor-create-pairing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
      findsOneWidget,
    );
    expect(find.textContaining('已进入重新配对模式'), findsOneWidget);
  });

  testWidgets('Feishu center creates route from dialog input', (tester) async {
    CreateFeishuMonitorRouteRequest? created;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => const FeishuMonitorSnapshot(
            stats: MonitorStats.empty,
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
            routes: <MonitorRoute>[],
            logs: <MonitorLogEntry>[],
          ),
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[
            MonitorSelectableGroup(groupNo: 'group_1', name: '悟空 IM 新闻群'),
          ],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onCreateRoute: (request) async {
            created = request;
            return MonitorRoute.fromJson(const <String, dynamic>{
              'id': 'route_created',
              'platform': 'feishu',
              'connector_type': 'feishu_web_group',
              'route_type': 'feishu_web_group_to_wukong_im_group',
              'source_name': '飞书新闻群',
              'destination_name': '悟空 IM 新闻群',
              'status': 'paused',
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-new-route')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feishu-route-source-chat-input')),
      '飞书新闻群',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-route-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('feishu-route-submit')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sourceChatName, '飞书新闻群');
    expect(created!.destinationGroupNo, 'group_1');
    expect(created!.destinationGroupName, '悟空 IM 新闻群');
    expect(created!.includeText, isTrue);
    expect(created!.includeLinks, isTrue);
    expect(created!.includeImages, isFalse);
    expect(created!.includeFiles, isFalse);
  });
}

const _snapshotWithData = FeishuMonitorSnapshot(
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
);
