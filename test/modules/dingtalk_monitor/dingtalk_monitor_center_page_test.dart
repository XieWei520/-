import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_center_page.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';

void main() {
  testWidgets('renders native host status and recent events', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DingTalkMonitorCenterPage(
          client: _FakeShellClient(
            status: _status(),
            events: <DingTalkMonitorMessageEvent>[
              _event(text: 'hello from DingTalk'),
            ],
          ),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemorySettingsStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('钉钉信息转发中心'), findsOneWidget);
    expect(find.textContaining('Attached'), findsWidgets);
    expect(find.textContaining('Ready'), findsWidgets);
    expect(find.textContaining('hello from DingTalk'), findsOneWidget);
  });

  testWidgets('creates a route from recent event and target group', (
    tester,
  ) async {
    final store = _MemorySettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: DingTalkMonitorCenterPage(
          client: _FakeShellClient(
            status: _status(),
            events: <DingTalkMonitorMessageEvent>[
              _event(sourceConversationId: 'source:alpha'),
            ],
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
      find.byKey(const ValueKey('dingtalk-route-source:source:alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WuKong Alpha'));
    await tester.pumpAndSettle();

    expect(store.saved?.routes, hasLength(1));
    expect(store.saved?.routes.single.sourceConversationId, 'source:alpha');
    expect(store.saved?.routes.single.targetGroupId, 'wk_alpha');
  });

  testWidgets('manual forward sends recent events with configured routes', (
    tester,
  ) async {
    final service = _FakeForwardingService();
    await tester.pumpWidget(
      MaterialApp(
        home: DingTalkMonitorCenterPage(
          client: _FakeShellClient(
            status: _status(),
            events: <DingTalkMonitorMessageEvent>[
              _event(sourceConversationId: 'source:alpha', text: 'manual'),
            ],
          ),
          forwardingService: service,
          forwardingSettingsStore: _MemorySettingsStore(
            initial: DingTalkMonitorForwardingSettings(
              enabled: true,
              routes: <DingTalkMonitorForwardingRoute>[
                _route(sourceConversationId: 'source:alpha', targetGroupId: 'wk_alpha'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('dingtalk-forward-recent-button')),
    );
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.lastEvents.single.text, 'manual');
    expect(find.textContaining('已转发 1 条'), findsWidgets);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

DingTalkMonitorShellStatus _status() {
  return const DingTalkMonitorShellStatus(
    captureRunning: true,
    serverTime: null,
    version: 'm1',
    shellState: 'Attached',
    currentHwnd: '0x1',
    message: 'attached',
    lastWindowEventAt: null,
    ocrEnabled: true,
    conversationReadiness: 'Ready',
    conversationReadinessMessage: 'ready',
  );
}

DingTalkMonitorMessageEvent _event({
  String eventId = 'event-1',
  String sourceConversationId = 'source:alpha',
  String sourceConversationName = 'Alpha',
  String text = 'hello',
}) {
  return DingTalkMonitorMessageEvent(
    eventId: eventId,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    embeddedSourceName: '',
    senderName: 'Alice',
    observedAt: DateTime.parse('2026-05-16T01:00:00Z'),
    text: text,
    localImagePath: '',
    captureSource: DingTalkMonitorCaptureSource.uiaText,
    contentHash: 'hash-$eventId',
  );
}

DingTalkMonitorForwardingRoute _route({
  String sourceConversationId = 'source:alpha',
  String targetGroupId = 'wk_alpha',
}) {
  return DingTalkMonitorForwardingRoute(
    id: 'route_1',
    enabled: true,
    sourceConversationId: sourceConversationId,
    sourceConversationName: 'Alpha',
    targetGroupId: targetGroupId,
    targetGroupName: 'Target',
    createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-16T01:00:00Z'),
  );
}

class _FakeShellClient extends DingTalkMonitorShellClient {
  _FakeShellClient({required this.status, required this.events});

  final DingTalkMonitorShellStatus status;
  final List<DingTalkMonitorMessageEvent> events;

  @override
  Future<DingTalkMonitorShellStatus> fetchStatus() async => status;

  @override
  Future<List<DingTalkMonitorMessageEvent>> fetchForwardableRecentEvents({
    int limit = 50,
  }) async {
    return events;
  }
}

class _FakeForwardingService extends DingTalkMonitorForwardingService {
  _FakeForwardingService() : super(sender: _NoopSender());

  int callCount = 0;
  List<DingTalkMonitorMessageEvent> lastEvents =
      const <DingTalkMonitorMessageEvent>[];

  @override
  Future<DingTalkMonitorForwardingResult> forwardRoutedRecentEvents({
    required DingTalkMonitorForwardingSettings settings,
    required List<DingTalkMonitorMessageEvent> events,
  }) async {
    callCount += 1;
    lastEvents = List<DingTalkMonitorMessageEvent>.from(events);
    return DingTalkMonitorForwardingResult(
      sent: events.length,
      skippedUnmatched: 0,
      failed: 0,
    );
  }
}

class _MemorySettingsStore implements DingTalkMonitorForwardingSettingsStore {
  _MemorySettingsStore({
    this.initial = const DingTalkMonitorForwardingSettings(enabled: false),
  });

  final DingTalkMonitorForwardingSettings initial;
  DingTalkMonitorForwardingSettings? saved;

  @override
  Future<DingTalkMonitorForwardingSettings> load() async => saved ?? initial;

  @override
  Future<void> save(DingTalkMonitorForwardingSettings settings) async {
    saved = settings;
  }
}

class _NoopSender implements DingTalkMonitorTextSender {
  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) async {}

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) async {}
}
