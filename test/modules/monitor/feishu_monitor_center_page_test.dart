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

    await tester.ensureVisible(
      find.byKey(const ValueKey('monitor-route-pause-route_1')),
    );
    await tester.tap(find.byKey(const ValueKey('monitor-route-pause-route_1')));
    await tester.pumpAndSettle();
    expect(pauseTapCount, 1);

    await tester.ensureVisible(
      find.byKey(const ValueKey('monitor-route-logs-route_1')),
    );
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
                  lastHeartbeatAt: '刚刚',
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
    expect(bindRequest!.serverUrl, 'https://infoequity.cn');
    expect(bindRequest!.pairingCode, 'ABCD-1234');
    expect(bindRequest!.forcePair, isFalse);
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

  testWidgets('Feishu center one-click bind refreshes stale pairing code', (
    tester,
  ) async {
    final createdCodes = <String>[];
    LocalAgentBindRequest? bindRequest;
    final pairingCodes = <MonitorPairingCode>[
      const MonitorPairingCode(code: 'STALE-1', expiresAt: '2026-05-06 18:00'),
      const MonitorPairingCode(code: 'FRESH-2', expiresAt: '2026-05-06 18:05'),
    ];
    var nextPairingCode = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => FeishuMonitorSnapshot.empty,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async {
            final code = pairingCodes[nextPairingCode++];
            createdCodes.add(code.code);
            return code;
          },
          onBindLocalAgent: (request) async {
            bindRequest = request;
            return const LocalAgentBindResult(message: 'Agent 已绑定并上线');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-create-pairing')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('STALE-1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
    );
    await tester.pumpAndSettle();

    expect(createdCodes, <String>['STALE-1', 'FRESH-2']);
    expect(bindRequest, isNotNull);
    expect(bindRequest!.pairingCode, 'FRESH-2');
    expect(find.textContaining('FRESH-2'), findsNothing);
    expect(
      find.textContaining('Agent \u5df2\u7ed1\u5b9a\u5e76\u4e0a\u7ebf'),
      findsOneWidget,
    );
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
    expect(find.text('重新配对 Windows Agent'), findsOneWidget);
    expect(find.text('还没有绑定 Windows Agent'), findsNothing);
    final newRouteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('feishu-monitor-new-route')),
    );
    expect(newRouteButton.onPressed, isNull);
    expect(find.textContaining('已进入重新配对模式'), findsOneWidget);
  });

  testWidgets('Feishu center re-pair mode forces local Agent to pair again', (
    tester,
  ) async {
    LocalAgentBindRequest? bindRequest;

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
            code: 'FORCE-2',
            expiresAt: '2026-05-06 18:05',
          ),
          onBindLocalAgent: (request) async {
            bindRequest = request;
            return const LocalAgentBindResult(message: 'Agent ??????');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-monitor-repair-agent')),
    );
    await tester.tap(find.byKey(const ValueKey('feishu-monitor-repair-agent')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
    );
    await tester.pumpAndSettle();

    expect(bindRequest, isNotNull);
    expect(bindRequest!.pairingCode, 'FORCE-2');
    expect(bindRequest!.forcePair, isTrue);
  });

  testWidgets(
    'Feishu center exits re-pair mode after one-click bind succeeds',
    (tester) async {
      var loadCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FeishuMonitorCenterPage(
            loadSnapshot: () async {
              loadCount++;
              if (loadCount == 1) {
                return _snapshotWithData;
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
                    lastHeartbeatAt: '\u521a\u521a',
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
              code: 'FRESH-2',
              expiresAt: '2026-05-06 18:05',
            ),
            onBindLocalAgent: (_) async =>
                const LocalAgentBindResult(message: 'Agent 已绑定并上线'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('feishu-monitor-repair-agent')),
      );
      await tester.tap(
        find.byKey(const ValueKey('feishu-monitor-repair-agent')),
      );
      await tester.pumpAndSettle();
      expect(find.text('重新配对 Windows Agent'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('feishu-monitor-one-click-bind')),
      );
      await tester.pumpAndSettle();

      expect(loadCount, 2);
      expect(find.text('重新配对 Windows Agent'), findsNothing);
      expect(find.text('Windows Agent'), findsOneWidget);
      expect(find.text('COLORFUL-PC'), findsOneWidget);
    },
  );

  testWidgets('Feishu center refreshes Agent status with local heartbeat', (
    tester,
  ) async {
    var loadCount = 0;
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async {
            loadCount++;
            return FeishuMonitorSnapshot(
              stats: MonitorStats.empty,
              agents: <MonitorAgent>[
                MonitorAgent(
                  id: 'agent_1',
                  deviceName: 'COLORFUL-PC',
                  platform: 'windows',
                  version: '0.1.0',
                  status: loadCount == 1
                      ? MonitorAgentStatus.offline
                      : MonitorAgentStatus.online,
                  lastHeartbeatAt: loadCount == 1 ? '旧心跳' : '刚刚',
                ),
              ],
              routes: const <MonitorRoute>[],
              logs: const <MonitorLogEntry>[],
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
          onRefreshAgentStatus: () async {
            refreshCount++;
            return const LocalAgentBindResult(message: 'Agent 状态已更新，页面已刷新。');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('状态：离线'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-monitor-refresh-agent-status')),
    );
    await tester.tap(
      find.byKey(const ValueKey('feishu-monitor-refresh-agent-status')),
    );
    await tester.pumpAndSettle();

    expect(refreshCount, 1);
    expect(loadCount, 2);
    expect(find.text('状态：在线'), findsOneWidget);
    expect(find.textContaining('Agent 状态已更新'), findsOneWidget);
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
          loadFeishuChats: () async => const <String>[],
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
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

  testWidgets('Feishu route dialog can select auto detected Feishu chat', (
    tester,
  ) async {
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
                lastHeartbeatAt: '2026-05-06 17:00',
              ),
            ],
            routes: <MonitorRoute>[],
            logs: <MonitorLogEntry>[],
          ),
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[
            MonitorSelectableGroup(groupNo: 'group_1', name: '悟空 IM 新闻群'),
          ],
          loadFeishuChats: () async => const <String>['飞书新闻群', '产品交流群'],
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
              'source_name': '产品交流群',
              'destination_name': '悟空 IM 新闻群',
              'status': 'paused',
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-new-route')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('feishu-route-source-chat-list')),
      findsOneWidget,
    );
    expect(find.text('飞书新闻群'), findsOneWidget);

    await tester.tap(find.text('产品交流群'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-route-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('feishu-route-submit')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sourceChatName, '产品交流群');
    expect(created!.destinationGroupNo, 'group_1');
  });

  testWidgets('Feishu route dialog supports scrolling many detected chats', (
    tester,
  ) async {
    CreateFeishuMonitorRouteRequest? created;
    final chats = List<String>.generate(
      80,
      (index) => '飞书群 ${index.toString().padLeft(3, '0')}',
    );

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
                lastHeartbeatAt: '2026-05-06 17:00',
              ),
            ],
            routes: <MonitorRoute>[],
            logs: <MonitorLogEntry>[],
          ),
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[
            MonitorSelectableGroup(groupNo: 'group_1', name: '悟空 IM 新闻群'),
          ],
          loadFeishuChats: () async => chats,
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
            return MonitorRoute.fromJson(<String, dynamic>{
              'id': 'route_created',
              'platform': 'feishu',
              'connector_type': 'feishu_web_group',
              'route_type': 'feishu_web_group_to_wukong_im_group',
              'source_name': request.sourceChatName,
              'destination_name': request.destinationGroupName,
              'status': 'paused',
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-new-route')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('已自动识别 80 个会话'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('feishu-route-source-chat-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('feishu-route-source-chat-list')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('feishu-route-source-chat-search')),
      '079',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('飞书群 079'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('feishu-route-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('feishu-route-submit')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sourceChatName, '飞书群 079');
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
