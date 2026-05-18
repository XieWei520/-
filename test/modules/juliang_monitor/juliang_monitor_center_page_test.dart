import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_center_page.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

void main() {
  testWidgets('renders status routes and recent text events', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JuliangMonitorCenterPage(
          client: _FakeShellClient(status: _status()),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemorySettingsStore(
            initial: JuliangMonitorForwardingSettings(
              enabled: true,
              routes: <JuliangMonitorForwardingRoute>[
                _route(sourceConversationId: 'jl-alpha'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('聚合信息转发中心'), findsOneWidget);
    expect(find.textContaining('online'), findsWidgets);
    expect(find.textContaining('login_required'), findsWidgets);
    expect(find.textContaining('running'), findsWidgets);
    expect(find.textContaining('每次启动都需要手动登录'), findsOneWidget);
    expect(find.textContaining('Alpha'), findsWidgets);
    expect(find.textContaining('hello from Juliang'), findsOneWidget);
    expect(find.byKey(const ValueKey('juliang-forward-recent-button')), findsOneWidget);
  });

  testWidgets('creates a route from recent event and target group', (
    tester,
  ) async {
    final store = _MemorySettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: JuliangMonitorCenterPage(
          client: _FakeShellClient(status: _status()),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: store,
          loadTargetGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'wk_alpha', name: 'WuKong Alpha'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('juliang-route-source:jl-alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WuKong Alpha'));
    await tester.pumpAndSettle();

    expect(store.saved?.enabled, isTrue);
    expect(store.saved?.routes, hasLength(1));
    expect(store.saved?.routes.single.sourceConversationId, 'jl-alpha');
    expect(store.saved?.routes.single.targetGroupId, 'wk_alpha');
  });

  testWidgets('creates a route from observed source before messages arrive', (
    tester,
  ) async {
    final store = _MemorySettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: JuliangMonitorCenterPage(
          client: _FakeShellClient(
            status: _status(
              recentEvents: const <LocalMonitorMessageEvent>[],
            ),
          ),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: store,
          loadTargetGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'wk_alpha', name: 'WuKong Alpha'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('juliang-observed-source:jl-alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WuKong Alpha'));
    await tester.pumpAndSettle();

    expect(store.saved?.enabled, isTrue);
    expect(store.saved?.routes, hasLength(1));
    expect(store.saved?.routes.single.sourceConversationId, 'jl-alpha');
    expect(store.saved?.routes.single.sourceConversationName, 'Alpha');
    expect(store.saved?.routes.single.targetGroupId, 'wk_alpha');
  });

  testWidgets('manual forward sends recent text events with configured routes', (
    tester,
  ) async {
    final service = _FakeForwardingService();
    await tester.pumpWidget(
      MaterialApp(
        home: JuliangMonitorCenterPage(
          client: _FakeShellClient(status: _status()),
          forwardingService: service,
          forwardingSettingsStore: _MemorySettingsStore(
            initial: JuliangMonitorForwardingSettings(
              enabled: true,
              routes: <JuliangMonitorForwardingRoute>[
                _route(sourceConversationId: 'jl-alpha'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('juliang-forward-recent-button')),
    );
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.lastEvents.single.text, 'hello from Juliang');
    expect(find.textContaining('已转发 1 条'), findsWidgets);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

class _FakeShellClient implements JuliangMonitorShellClient {
  _FakeShellClient({required this.status});

  final JuliangMonitorShellStatus status;

  @override
  Future<JuliangMonitorShellStatus> fetchStatus() async => status;

  @override
  Future<void> reloadRuntime() async {}

  @override
  Future<void> startCapture() async {}

  @override
  Future<void> stopCapture() async {}

  @override
  Future<void> syncConfiguredSources(
    Iterable<JuliangMonitorRoutingSource> sources,
  ) async {}

  @override
  Stream<JuliangMonitorShellEvent> watchEvents() => const Stream.empty();
}

class _FakeForwardingService implements JuliangMonitorForwardingService {
  int callCount = 0;
  List<JuliangMonitorMessageEvent> lastEvents =
      const <JuliangMonitorMessageEvent>[];

  @override
  Future<JuliangMonitorForwardingResult> forwardRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {
    callCount += 1;
    lastEvents = events.toList(growable: false);
    return JuliangMonitorForwardingResult(sent: lastEvents.length, failed: 0);
  }

  @override
  Future<void> primeRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {}
}

class _MemorySettingsStore implements JuliangMonitorForwardingSettingsStore {
  _MemorySettingsStore({
    this.initial = const JuliangMonitorForwardingSettings(enabled: false),
  });

  final JuliangMonitorForwardingSettings initial;
  JuliangMonitorForwardingSettings? saved;

  @override
  Future<JuliangMonitorForwardingSettings> load() async => saved ?? initial;

  @override
  Future<void> save(JuliangMonitorForwardingSettings settings) async {
    saved = settings;
  }
}

JuliangMonitorShellStatus _status({
  List<LocalMonitorMessageEvent>? recentEvents,
}) {
  return JuliangMonitorShellStatus.fromLocal(
    LocalMonitorShellStatus(
      shellState: 'online',
      captureState: 'running',
      loginState: 'login_required',
      hookState: 'healthy',
      runtimeUrl: 'https://msg.juliang888.top/',
      pageTitle: '快飞面板',
      pageKind: 'workspace',
      webviewAvailable: true,
      shellMode: 'desktop_shell',
      queueDepth: 0,
      messagesToday: 1,
      deliveriesSucceededToday: 0,
      deliveriesFailedToday: 0,
      lastUpdatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      probeObservedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      observedConversations: <LocalMonitorObservedConversation>[
        LocalMonitorObservedConversation(
          id: 'jl-alpha',
          name: 'Alpha',
          type: 'group',
          lastMessagePreview: 'hello from Juliang',
          observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
        ),
      ],
      observedMessages: const <LocalMonitorObservedMessage>[],
      recentEvents: recentEvents ?? <LocalMonitorMessageEvent>[
        LocalMonitorMessageEvent(
          eventId: 'event-1',
          dedupeKey: 'jl-alpha:msg-1',
          accountId: '',
          conversationId: 'jl-alpha',
          conversationName: 'Alpha',
          conversationType: 'group',
          messageId: 'msg-1',
          senderId: '',
          senderName: 'Alice',
          messageType: 'text',
          text: 'hello from Juliang',
          sentAt: null,
          observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
          captureSource: 'network_api',
        ),
      ],
      workerId: 'worker-1',
      probeDiagnostics: const <String, dynamic>{},
      lastError: '',
    ),
  );
}

JuliangMonitorForwardingRoute _route({
  String sourceConversationId = 'jl-alpha',
}) {
  return JuliangMonitorForwardingRoute(
    id: 'route_1',
    enabled: true,
    sourceConversationId: sourceConversationId,
    sourceConversationName: 'Alpha',
    sourceConversationType: 'group',
    targetGroupId: 'wk_alpha',
    targetGroupName: 'WuKong Alpha',
    createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
  );
}
