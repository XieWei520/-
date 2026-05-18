import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/app.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart';

void main() {
  test('app auto-forward runners include Juliang with existing platforms', () {
    final runners = createLocalMonitorAutoForwardRunners();
    addTearDown(() {
      for (final runner in runners) {
        runner.dispose();
      }
    });

    expect(runners.whereType<FeishuMonitorAutoForwardRunner>(), hasLength(1));
    expect(runners.whereType<DingTalkMonitorAutoForwardRunner>(), hasLength(1));
    expect(runners.whereType<MengxiaMonitorAutoForwardRunner>(), hasLength(1));
    expect(runners.whereType<JuliangMonitorAutoForwardRunner>(), hasLength(1));
  });

  test('runOnce forwards routed live events when enabled', () async {
    final client = _FakeShellClient(
      status: _status(
        recentEvents: <JuliangMonitorMessageEvent>[
          _event(conversationId: 'jl-alpha', text: 'live message'),
        ],
      ),
    );
    final service = _FakeForwardingService();
    final runner = JuliangMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        JuliangMonitorForwardingSettings(
          enabled: true,
          routes: <JuliangMonitorForwardingRoute>[
            _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(client.fetchStatusCount, 1);
    expect(client.syncedSources, <String>['jl-alpha']);
    expect(service.forwardCallCount, 1);
    expect(service.lastForwardedEvents.single.text, 'live message');
    expect(result?.sent, 1);
  });

  test(
    'runOnce skips shell fetch when auto-forwarding has no enabled route',
    () async {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = JuliangMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          const JuliangMonitorForwardingSettings(enabled: true),
        ),
      );

      final result = await runner.runOnce();

      expect(result, isNull);
      expect(client.fetchStatusCount, 0);
      expect(service.forwardCallCount, 0);
    },
  );

  test('runOnce primes startup events without forwarding them', () async {
    final client = _FakeShellClient(
      status: _status(
        recentEvents: <JuliangMonitorMessageEvent>[
          _event(
            conversationId: 'jl-alpha',
            text: 'old startup message',
            observedAt: DateTime.parse('2026-05-17T00:59:59Z'),
          ),
        ],
      ),
    );
    final service = _FakeForwardingService();
    final runner = JuliangMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        JuliangMonitorForwardingSettings(
          enabled: true,
          routes: <JuliangMonitorForwardingRoute>[
            _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
          ],
        ),
      ),
      clock: () => DateTime.parse('2026-05-17T01:00:00Z'),
    );

    final result = await runner.runOnce(primeIfNeeded: true);

    expect(result, isNull);
    expect(service.primeCallCount, 1);
    expect(service.lastPrimedEvents.single.text, 'old startup message');
    expect(service.forwardCallCount, 0);
  });

  test('runOnce forwards live events during startup prime', () async {
    final client = _FakeShellClient(
      status: _status(
        recentEvents: <JuliangMonitorMessageEvent>[
          _event(
            conversationId: 'jl-alpha',
            text: 'new live message',
            observedAt: DateTime.parse('2026-05-17T01:00:01Z'),
          ),
        ],
      ),
    );
    final service = _FakeForwardingService();
    final runner = JuliangMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        JuliangMonitorForwardingSettings(
          enabled: true,
          routes: <JuliangMonitorForwardingRoute>[
            _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
          ],
        ),
      ),
      clock: () => DateTime.parse('2026-05-17T01:00:00Z'),
    );

    final result = await runner.runOnce(primeIfNeeded: true);

    expect(service.primeCallCount, 0);
    expect(service.forwardCallCount, 1);
    expect(service.lastForwardedEvents.single.text, 'new live message');
    expect(result?.sent, 1);
  });
}

class _FakeShellClient implements JuliangMonitorShellClient {
  _FakeShellClient({required this.status});

  JuliangMonitorShellStatus status;
  int fetchStatusCount = 0;
  final syncedSources = <String>[];

  @override
  Future<JuliangMonitorShellStatus> fetchStatus() async {
    fetchStatusCount += 1;
    return status;
  }

  @override
  Future<void> syncConfiguredSources(
    Iterable<JuliangMonitorRoutingSource> sources,
  ) async {
    syncedSources
      ..clear()
      ..addAll(sources.map((source) => source.conversationId));
  }

  @override
  Future<void> reloadRuntime() async {}

  @override
  Future<void> startCapture() async {}

  @override
  Future<void> stopCapture() async {}

  @override
  Stream<JuliangMonitorShellEvent> watchEvents() => const Stream.empty();
}

class _FakeForwardingService implements JuliangMonitorForwardingService {
  int forwardCallCount = 0;
  int primeCallCount = 0;
  List<JuliangMonitorMessageEvent> lastForwardedEvents =
      <JuliangMonitorMessageEvent>[];
  List<JuliangMonitorMessageEvent> lastPrimedEvents =
      <JuliangMonitorMessageEvent>[];

  @override
  Future<JuliangMonitorForwardingResult> forwardRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {
    forwardCallCount += 1;
    lastForwardedEvents = events.toList(growable: false);
    return JuliangMonitorForwardingResult(
      sent: lastForwardedEvents.length,
      failed: 0,
    );
  }

  @override
  Future<void> primeRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {
    primeCallCount += 1;
    lastPrimedEvents = events.toList(growable: false);
  }
}

class _MemorySettingsStore implements JuliangMonitorForwardingSettingsStore {
  _MemorySettingsStore(this.settings);

  JuliangMonitorForwardingSettings settings;

  @override
  Future<JuliangMonitorForwardingSettings> load() async => settings;

  @override
  Future<void> save(JuliangMonitorForwardingSettings settings) async {
    this.settings = settings;
  }
}

JuliangMonitorShellStatus _status({
  List<JuliangMonitorMessageEvent> recentEvents =
      const <JuliangMonitorMessageEvent>[],
}) {
  return JuliangMonitorShellStatus.fromLocal(
    LocalMonitorShellStatus(
      shellState: 'online',
      captureState: 'running',
      loginState: 'logged_in',
      hookState: 'healthy',
      runtimeUrl: 'https://msg.juliang888.top/',
      pageTitle: '快飞面板',
      pageKind: 'workspace',
      webviewAvailable: true,
      shellMode: 'desktop_shell',
      queueDepth: 0,
      messagesToday: recentEvents.length,
      deliveriesSucceededToday: 0,
      deliveriesFailedToday: 0,
      lastUpdatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      probeObservedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      observedConversations: const <LocalMonitorObservedConversation>[],
      observedMessages: const <LocalMonitorObservedMessage>[],
      recentEvents: recentEvents
          .map((event) => event.toLocal())
          .toList(growable: false),
      workerId: 'worker-1',
      probeDiagnostics: const <String, dynamic>{},
      lastError: '',
    ),
  );
}

JuliangMonitorMessageEvent _event({
  String eventId = 'event_msg_1',
  String dedupeKey = 'jl-alpha:msg_1',
  String conversationId = 'jl-alpha',
  String conversationName = 'Alpha',
  String conversationType = 'group',
  String messageId = 'msg_1',
  String senderName = 'Alice',
  String messageType = 'text',
  String text = 'hello',
  DateTime? observedAt,
}) {
  return JuliangMonitorMessageEvent.fromLocal(
    LocalMonitorMessageEvent(
      eventId: eventId,
      dedupeKey: dedupeKey,
      accountId: '',
      conversationId: conversationId,
      conversationName: conversationName,
      conversationType: conversationType,
      messageId: messageId,
      senderId: '',
      senderName: senderName,
      messageType: messageType,
      text: text,
      sentAt: null,
      observedAt: observedAt ?? DateTime.parse('2026-05-17T01:00:01Z'),
      captureSource: 'network_api',
    ),
  );
}

JuliangMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'jl-alpha',
  String sourceConversationName = 'Alpha',
  String sourceConversationType = 'group',
  String targetGroupId = 'wk_alpha',
  String targetGroupName = 'WuKong Alpha',
}) {
  return JuliangMonitorForwardingRoute(
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
