import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_models.dart';

void main() {
  test('runOnce forwards recent configured live events', () async {
    final service = _FakeForwardingService();
    final runner = MengxiaMonitorAutoForwardRunner(
      client: _FakeShellClient(
        status: _status(<MengxiaMonitorMessageEvent>[
          _event(conversationId: 'mx-alpha'),
        ]),
      ),
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        MengxiaMonitorForwardingSettings(
          enabled: true,
          routes: <MengxiaMonitorForwardingRoute>[
            _route(sourceConversationId: 'mx-alpha'),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(result?.sent, 1);
    expect(service.callCount, 1);
    expect(service.lastEvents.single.conversationId, 'mx-alpha');
  });

  test('runOnce forwards recent configured image events', () async {
    final service = _FakeForwardingService();
    final runner = MengxiaMonitorAutoForwardRunner(
      client: _FakeShellClient(
        status: _status(<MengxiaMonitorMessageEvent>[
          _event(
            conversationId: 'mx-alpha',
            messageType: 'image',
            text: '',
            imageAttachments: const <MengxiaMonitorImageAttachment>[
              MengxiaMonitorImageAttachment(
                sourceUrl: 'https://mx.example.test/image.png',
                localPath: '',
                width: 320,
                height: 240,
              ),
            ],
          ),
        ]),
      ),
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        MengxiaMonitorForwardingSettings(
          enabled: true,
          routes: <MengxiaMonitorForwardingRoute>[
            _route(sourceConversationId: 'mx-alpha'),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(result?.sent, 1);
    expect(service.callCount, 1);
    expect(service.lastEvents.single.hasForwardableImage, isTrue);
  });

  test('runOnce syncs and forwards multiple configured source groups', () async {
    final service = _FakeForwardingService();
    final client = _FakeShellClient(
      status: _status(<MengxiaMonitorMessageEvent>[
        _event(
          eventId: 'event-alpha',
          dedupeKey: 'dedupe-alpha',
          conversationId: 'mx-alpha',
          conversationName: 'Alpha',
          text: 'alpha message',
        ),
        _event(
          eventId: 'event-beta',
          dedupeKey: 'dedupe-beta',
          conversationId: 'mx-beta',
          conversationName: 'Beta',
          text: 'beta message',
        ),
      ]),
    );
    final runner = MengxiaMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        MengxiaMonitorForwardingSettings(
          enabled: true,
          routes: <MengxiaMonitorForwardingRoute>[
            _route(
              id: 'route_alpha',
              sourceConversationId: 'mx-alpha',
              sourceConversationName: 'Alpha',
              targetGroupId: 'wk-alpha',
              targetGroupName: 'WuKong Alpha',
            ),
            _route(
              id: 'route_beta',
              sourceConversationId: 'mx-beta',
              sourceConversationName: 'Beta',
              targetGroupId: 'wk-beta',
              targetGroupName: 'WuKong Beta',
            ),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(result?.sent, 2);
    expect(service.callCount, 1);
    expect(
      client.syncedSources.map((source) => source.conversationId),
      <String>['mx-alpha', 'mx-beta'],
    );
    expect(
      service.lastEvents.map((event) => event.conversationId),
      <String>['mx-alpha', 'mx-beta'],
    );
    expect(
      findMengxiaMonitorRouteForEvent(
        routes: service.lastSettings!.routes,
        event: service.lastEvents.first,
      )?.targetGroupId,
      'wk-alpha',
    );
    expect(
      findMengxiaMonitorRouteForEvent(
        routes: service.lastSettings!.routes,
        event: service.lastEvents.last,
      )?.targetGroupId,
      'wk-beta',
    );
  });
}

MengxiaMonitorShellStatus _status(List<MengxiaMonitorMessageEvent> events) {
  return MengxiaMonitorShellStatus(
    shellState: 'online',
    captureState: 'running',
    loginState: 'logged_in',
    hookState: 'healthy',
    runtimeUrl: '',
    pageTitle: '萌侠',
    pageKind: 'workspace',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    queueDepth: 0,
    messagesToday: events.length,
    deliveriesSucceededToday: 0,
    deliveriesFailedToday: 0,
    lastUpdatedAt: null,
    probeObservedAt: null,
    observedConversations: const <MengxiaMonitorObservedConversation>[],
    observedMessages: const <MengxiaMonitorObservedMessage>[],
    recentEvents: events,
    workerId: 'worker-1',
    lastError: '',
  );
}

MengxiaMonitorMessageEvent _event({
  required String conversationId,
  String eventId = 'event-1',
  String dedupeKey = 'dedupe-1',
  String conversationName = 'Alpha',
  String messageType = 'text',
  String text = 'hello',
  List<MengxiaMonitorImageAttachment> imageAttachments =
      const <MengxiaMonitorImageAttachment>[],
}) {
  return MengxiaMonitorMessageEvent(
    eventId: eventId,
    dedupeKey: dedupeKey,
    accountId: '',
    conversationId: conversationId,
    conversationName: conversationName,
    conversationType: 'group',
    messageId: 'message-1',
    senderId: '',
    senderName: 'Alice',
    messageType: messageType,
    text: text,
    sentAt: null,
    observedAt: DateTime.parse('2026-05-16T01:00:00Z'),
    captureSource: 'network_api',
    imageAttachments: imageAttachments,
  );
}

MengxiaMonitorForwardingRoute _route({
  String id = 'route_1',
  required String sourceConversationId,
  String sourceConversationName = 'Alpha',
  String targetGroupId = 'wk-alpha',
  String targetGroupName = 'WuKong Alpha',
}) {
  return MengxiaMonitorForwardingRoute(
    id: id,
    enabled: true,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: 'group',
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-16T01:00:00Z'),
  );
}

class _FakeShellClient extends MengxiaMonitorShellClient {
  _FakeShellClient({required this.status});

  final MengxiaMonitorShellStatus status;
  List<MengxiaMonitorRoutingSource> syncedSources =
      const <MengxiaMonitorRoutingSource>[];

  @override
  Future<MengxiaMonitorShellStatus> fetchStatus() async => status;

  @override
  Future<void> syncConfiguredSources(
    Iterable<MengxiaMonitorRoutingSource> sources,
  ) async {
    syncedSources = List<MengxiaMonitorRoutingSource>.from(sources);
  }
}

class _FakeForwardingService extends MengxiaMonitorForwardingService {
  _FakeForwardingService() : super(sender: _NoopSender());

  int callCount = 0;
  MengxiaMonitorForwardingSettings? lastSettings;
  List<MengxiaMonitorMessageEvent> lastEvents =
      const <MengxiaMonitorMessageEvent>[];

  @override
  Future<MengxiaMonitorForwardingResult> forwardRoutedRecentEvents({
    required MengxiaMonitorForwardingSettings settings,
    required List<MengxiaMonitorMessageEvent> events,
  }) async {
    callCount += 1;
    lastSettings = settings;
    lastEvents = List<MengxiaMonitorMessageEvent>.from(events);
    return MengxiaMonitorForwardingResult(
      sent: events.length,
      skippedUnmatched: 0,
      failed: 0,
    );
  }
}

class _MemorySettingsStore implements MengxiaMonitorForwardingSettingsStore {
  const _MemorySettingsStore(this.settings);

  final MengxiaMonitorForwardingSettings settings;

  @override
  Future<MengxiaMonitorForwardingSettings> load() async => settings;

  @override
  Future<void> save(MengxiaMonitorForwardingSettings settings) async {}
}

class _NoopSender implements MengxiaMonitorMediaSender {
  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    MengxiaMonitorRelayIdentity? relayIdentity,
  }) async {}

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required MengxiaMonitorImageAttachment image,
    MengxiaMonitorRelayIdentity? relayIdentity,
  }) async {}
}
