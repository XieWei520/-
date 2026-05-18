import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_center_page.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_models.dart';

void main() {
  testWidgets('mengxia center renders a Feishu-style monitor console', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loggedInStatus()),
          forwardingSettingsStore: _MemorySettingsStore(
            initial: MengxiaMonitorForwardingSettings(
              enabled: true,
              routes: <MengxiaMonitorForwardingRoute>[
                _route(
                  sourceConversationId: 'mx-alpha',
                  sourceConversationName: '萌侠 Alpha',
                  targetGroupId: 'wk_alpha',
                  targetGroupName: '悟空 Alpha 群',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('状态总览'), findsOneWidget);
    expect(find.text('Shell 程序'), findsOneWidget);
    expect(find.text('萌侠账号'), findsOneWidget);
    expect(find.text('监听状态'), findsOneWidget);
    expect(find.text('今日捕获'), findsOneWidget);
    expect(find.text('今日成功'), findsOneWidget);
    expect(find.text('今日失败'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('运行日志'), findsWidgets);
    expect(find.text('转发规则'), findsWidgets);
    expect(find.text('萌侠来源'), findsWidgets);
    expect(find.text('系统设置'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mengxia-monitor-auto-forward-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mengxia-monitor-forward-recent-button')),
      findsOneWidget,
    );
  });

  testWidgets('mengxia center shows manual login and incognito guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loginRequiredStatus()),
          forwardingSettingsStore: _MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('萌侠信息转发中心'), findsOneWidget);
    expect(find.textContaining('人工登录'), findsWidgets);
    expect(find.textContaining('无痕'), findsWidgets);
    expect(find.textContaining('不会复用 Cookie'), findsWidgets);
  });

  testWidgets('mengxia logs do not ask for login after logged in', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loggedInStatus()),
          forwardingSettingsStore: _MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('运行日志').first);
    await tester.tap(find.text('运行日志').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('等待人工登录'), findsNothing);
    expect(find.textContaining('暂无可转发事件'), findsOneWidget);
  });

  testWidgets('mengxia source conversation can be routed to a WuKong group', (
    tester,
  ) async {
    final settingsStore = _MemorySettingsStore();

    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loggedInStatus()),
          forwardingSettingsStore: settingsStore,
          loadTargetGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'wk_alpha', name: '悟空 Alpha 群'),
            GroupInfo(groupNo: 'wk_beta', name: '悟空 Beta 群'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.tap(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('悟空 Alpha 群'));
    await tester.pumpAndSettle();

    final saved = settingsStore.saved;
    expect(saved, isNotNull);
    expect(saved!.enabled, isTrue);
    expect(saved.routes, hasLength(1));
    expect(saved.routes.single.sourceConversationId, 'mx-alpha');
    expect(saved.routes.single.sourceConversationName, '萌侠 Alpha');
    expect(saved.routes.single.targetGroupId, 'wk_alpha');
    expect(saved.routes.single.targetGroupName, '悟空 Alpha 群');
  });

  testWidgets('mengxia target group picker hides inactive or unsaved groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loggedInStatus()),
          forwardingSettingsStore: _MemorySettingsStore(),
          loadTargetGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'wk_active', name: '可用目标群', save: 1, status: 1),
            GroupInfo(groupNo: 'wk_unsaved', name: '未保存群', save: 0, status: 1),
            GroupInfo(groupNo: 'wk_inactive', name: '停用群', save: 1, status: 0),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.tap(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.pumpAndSettle();

    expect(find.text('可用目标群'), findsOneWidget);
    expect(find.text('未保存群'), findsNothing);
    expect(find.text('停用群'), findsNothing);
  });

  testWidgets('mengxia target group picker supports search and scrolling', (
    tester,
  ) async {
    final groups = List<GroupInfo>.generate(
      30,
      (index) => GroupInfo(
        groupNo: 'wk_${index.toString().padLeft(2, '0')}',
        name: index == 24 ? '核心转发目标群' : '普通目标群 $index',
        save: 1,
        status: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _FakeShellClient(_loggedInStatus()),
          forwardingSettingsStore: _MemorySettingsStore(),
          loadTargetGroups: () async => groups,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.tap(
      find.byKey(const ValueKey('mengxia-route-configure-mx-alpha')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mengxia-target-group-search-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('mengxia-target-group-search-field')),
      '核心',
    );
    await tester.pumpAndSettle();

    expect(find.text('核心转发目标群'), findsOneWidget);
    expect(find.text('普通目标群 1'), findsNothing);
  });

  testWidgets('mengxia center hides raw shell connection errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: _ThrowingShellClient(
            DioException(
              requestOptions: RequestOptions(
                path: 'http://127.0.0.1:62365/status',
              ),
              type: DioExceptionType.connectionError,
              error: 'Connection refused',
            ),
          ),
          forwardingSettingsStore: _MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('MX信息监控未连接'), findsWidgets);
    expect(find.textContaining('18786'), findsWidgets);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('62365'), findsNothing);
  });

  testWidgets('mengxia center refreshes discovered sources periodically', (
    tester,
  ) async {
    final client = _SequenceShellClient(<MengxiaMonitorShellStatus>[
      _loggedInStatus(),
      _loggedInStatus(
        conversations: <MengxiaMonitorObservedConversation>[
          _conversation(id: 'mx-alpha', name: '萌侠 Alpha'),
          _conversation(id: 'mx-beta', name: '萌侠 Beta'),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: MengxiaMonitorCenterPage(
          client: client,
          forwardingSettingsStore: _MemorySettingsStore(),
          statusPollInterval: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('萌侠 Beta'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(client.fetchCount, greaterThanOrEqualTo(2));
    expect(find.text('萌侠 Beta'), findsOneWidget);
  });
}

MengxiaMonitorShellStatus _loginRequiredStatus() {
  return const MengxiaMonitorShellStatus(
    shellState: 'online',
    captureState: 'stopped',
    loginState: 'login_required',
    hookState: 'healthy',
    runtimeUrl: 'https://mx.2026.naaifu.cn/#/pages/login/login',
    pageTitle: '萌侠登录',
    pageKind: 'login',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    queueDepth: 0,
    messagesToday: 0,
    deliveriesSucceededToday: 0,
    deliveriesFailedToday: 0,
    lastUpdatedAt: null,
    probeObservedAt: null,
    observedConversations: <MengxiaMonitorObservedConversation>[],
    observedMessages: <MengxiaMonitorObservedMessage>[],
    recentEvents: <MengxiaMonitorMessageEvent>[],
    workerId: 'worker-1',
    lastError: '',
  );
}

MengxiaMonitorShellStatus _loggedInStatus({
  List<MengxiaMonitorObservedConversation>? conversations,
}) {
  return MengxiaMonitorShellStatus(
    shellState: 'online',
    captureState: 'running',
    loginState: 'logged_in',
    hookState: 'healthy',
    runtimeUrl: 'https://mx.2026.naaifu.cn/#/pages/chat/index',
    pageTitle: '萌侠',
    pageKind: 'workspace',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    queueDepth: 0,
    messagesToday: 1,
    deliveriesSucceededToday: 0,
    deliveriesFailedToday: 0,
    lastUpdatedAt: null,
    probeObservedAt: DateTime.parse('2026-05-17T01:00:00Z'),
    observedConversations:
        conversations ?? <MengxiaMonitorObservedConversation>[_conversation()],
    observedMessages: const <MengxiaMonitorObservedMessage>[],
    recentEvents: const <MengxiaMonitorMessageEvent>[],
    workerId: 'worker-1',
    lastError: '',
  );
}

MengxiaMonitorObservedConversation _conversation({
  String id = 'mx-alpha',
  String name = '萌侠 Alpha',
}) {
  return MengxiaMonitorObservedConversation(
    id: id,
    name: name,
    type: 'group',
    lastMessagePreview: '新的萌侠消息',
    observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
  );
}

class _FakeShellClient extends MengxiaMonitorShellClient {
  _FakeShellClient(this.status);

  final MengxiaMonitorShellStatus status;

  @override
  Future<MengxiaMonitorShellStatus> fetchStatus() async => status;
}

class _SequenceShellClient extends MengxiaMonitorShellClient {
  _SequenceShellClient(this.statuses);

  final List<MengxiaMonitorShellStatus> statuses;
  int fetchCount = 0;

  @override
  Future<MengxiaMonitorShellStatus> fetchStatus() async {
    final index = fetchCount < statuses.length
        ? fetchCount
        : statuses.length - 1;
    fetchCount += 1;
    return statuses[index];
  }
}

class _ThrowingShellClient extends MengxiaMonitorShellClient {
  _ThrowingShellClient(this.error);

  final Object error;

  @override
  Future<MengxiaMonitorShellStatus> fetchStatus() async {
    throw error;
  }
}

class _MemorySettingsStore implements MengxiaMonitorForwardingSettingsStore {
  _MemorySettingsStore({
    this.initial = const MengxiaMonitorForwardingSettings(enabled: false),
  });

  final MengxiaMonitorForwardingSettings initial;
  MengxiaMonitorForwardingSettings? saved;

  @override
  Future<MengxiaMonitorForwardingSettings> load() async {
    return saved ?? initial;
  }

  @override
  Future<void> save(MengxiaMonitorForwardingSettings settings) async {
    saved = settings;
  }
}

MengxiaMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'mx-alpha',
  String sourceConversationName = '萌侠 Alpha',
  String sourceConversationType = 'group',
  String targetGroupId = 'wk_alpha',
  String targetGroupName = '悟空 Alpha 群',
}) {
  return MengxiaMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
  );
}
