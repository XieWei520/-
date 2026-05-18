import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_center_page.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_launch_service.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_models.dart';

void main() {
  testWidgets('xiaoe center renders WebView-first status and file guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: XiaoeMonitorCenterPage(
          client: _FakeShellClient(status: _status()),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemorySettingsStore(
            initial: XiaoeMonitorForwardingSettings(
              enabled: true,
              routes: <XiaoeMonitorForwardingRoute>[
                _route(
                  sourceConversationId: 'circle-alpha',
                  sourceConversationName: 'Alpha Circle',
                  targetGroupId: 'wk-alpha',
                  targetGroupName: 'WuKong Alpha',
                ),
              ],
            ),
          ),
          launchService: const XiaoeMonitorLaunchService.noop(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小鹅通信息转发中心'), findsOneWidget);
    expect(find.textContaining('muti_index'), findsWidgets);
    expect(find.textContaining('圈子/课程互动/直播评论'), findsWidgets);
    expect(find.textContaining('20 MB'), findsWidgets);
    expect(
      find.byKey(const ValueKey('xiaoe-monitor-start-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('xiaoe-monitor-forward-recent-button')),
      findsOneWidget,
    );
    expect(find.textContaining('Alpha Circle'), findsWidgets);
    expect(find.textContaining('hello from Xiaoe'), findsWidgets);
  });

  testWidgets('xiaoe source can be routed to a Wukong group', (tester) async {
    final store = _MemorySettingsStore();
    await tester.pumpWidget(
      MaterialApp(
        home: XiaoeMonitorCenterPage(
          client: _FakeShellClient(status: _status()),
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: store,
          launchService: const XiaoeMonitorLaunchService.noop(),
          loadTargetGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'wk-alpha', name: 'WuKong Alpha'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('xiaoe-route-configure-circle-alpha')),
    );
    await tester.tap(
      find.byKey(const ValueKey('xiaoe-route-configure-circle-alpha')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('WuKong Alpha'));
    await tester.pumpAndSettle();

    expect(store.saved, isNotNull);
    expect(store.saved!.enabled, isTrue);
    expect(store.saved!.routes, hasLength(1));
    expect(store.saved!.routes.single.sourceConversationId, 'circle-alpha');
    expect(store.saved!.routes.single.targetGroupId, 'wk-alpha');
  });

  testWidgets('manual forward sends text image and file events', (
    tester,
  ) async {
    final service = _FakeForwardingService();
    await tester.pumpWidget(
      MaterialApp(
        home: XiaoeMonitorCenterPage(
          client: _FakeShellClient(
            status: _status(
              recentEvents: <XiaoeMonitorMessageEvent>[
                _event(eventId: 'text-1', text: 'live text'),
                _event(
                  eventId: 'image-1',
                  dedupeKey: 'circle-alpha:image-1',
                  messageType: 'image',
                  text: '',
                  imageAttachments: const <XiaoeMonitorImageAttachment>[
                    XiaoeMonitorImageAttachment(
                      sourceUrl: 'https://cdn.example.com/a.png',
                      localPath: '',
                      width: 640,
                      height: 480,
                    ),
                  ],
                ),
                _event(
                  eventId: 'file-1',
                  dedupeKey: 'circle-alpha:file-1',
                  messageType: 'file',
                  text: '',
                  fileAttachments: const <XiaoeMonitorFileAttachment>[
                    XiaoeMonitorFileAttachment(
                      sourceUrl: 'https://cdn.example.com/a.pdf',
                      localPath: r'C:\tmp\a.pdf',
                      fileName: 'a.pdf',
                      mimeType: 'application/pdf',
                      sizeBytes: 1024,
                    ),
                  ],
                ),
              ],
            ),
          ),
          forwardingService: service,
          forwardingSettingsStore: _MemorySettingsStore(
            initial: XiaoeMonitorForwardingSettings(
              enabled: true,
              routes: <XiaoeMonitorForwardingRoute>[
                _route(sourceConversationId: 'circle-alpha'),
              ],
            ),
          ),
          launchService: const XiaoeMonitorLaunchService.noop(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('xiaoe-monitor-forward-recent-button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('xiaoe-monitor-forward-recent-button')),
    );
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.lastEvents, hasLength(3));
    expect(service.lastEvents[0].text, 'live text');
    expect(service.lastEvents[1].hasImageAttachments, isTrue);
    expect(service.lastEvents[2].hasFileAttachments, isTrue);
    expect(find.textContaining('已转发 3 条'), findsWidgets);
  });

  testWidgets('start action launches shell before starting capture', (
    tester,
  ) async {
    final launchService = _RecordingLaunchService();
    final client = _FakeShellClient(status: _status());
    await tester.pumpWidget(
      MaterialApp(
        home: XiaoeMonitorCenterPage(
          client: client,
          forwardingService: _FakeForwardingService(),
          forwardingSettingsStore: _MemorySettingsStore(),
          launchService: launchService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('xiaoe-monitor-start-button')));
    await tester.pumpAndSettle();

    expect(launchService.startCount, 1);
    expect(client.startCaptureCount, 1);
  });
}

class _FakeShellClient extends XiaoeMonitorShellClient {
  _FakeShellClient({required this.status});

  final XiaoeMonitorShellStatus status;
  int startCaptureCount = 0;

  @override
  Future<XiaoeMonitorShellStatus> fetchStatus() async => status;

  @override
  Future<void> startCapture() async {
    startCaptureCount += 1;
  }

  @override
  Future<void> stopCapture() async {}

  @override
  Future<void> reloadRuntime() async {}
}

class _FakeForwardingService extends XiaoeMonitorForwardingService {
  int callCount = 0;
  List<XiaoeMonitorMessageEvent> lastEvents =
      const <XiaoeMonitorMessageEvent>[];

  @override
  Future<XiaoeMonitorForwardingResult> forwardRoutedRecentEvents({
    required XiaoeMonitorForwardingSettings settings,
    required Iterable<XiaoeMonitorMessageEvent> events,
  }) async {
    callCount += 1;
    lastEvents = events.toList(growable: false);
    return XiaoeMonitorForwardingResult(sent: lastEvents.length, failed: 0);
  }
}

class _MemorySettingsStore implements XiaoeMonitorForwardingSettingsStore {
  _MemorySettingsStore({
    this.initial = const XiaoeMonitorForwardingSettings(enabled: false),
  });

  final XiaoeMonitorForwardingSettings initial;
  XiaoeMonitorForwardingSettings? saved;

  @override
  Future<XiaoeMonitorForwardingSettings> load() async => saved ?? initial;

  @override
  Future<void> save(XiaoeMonitorForwardingSettings settings) async {
    saved = settings;
  }
}

class _RecordingLaunchService extends XiaoeMonitorLaunchService {
  _RecordingLaunchService() : super.noop();

  int startCount = 0;

  @override
  Future<void> startShell() async {
    startCount += 1;
  }
}

XiaoeMonitorShellStatus _status({
  List<XiaoeMonitorMessageEvent>? recentEvents,
}) {
  final events =
      recentEvents ??
      <XiaoeMonitorMessageEvent>[
        _event(eventId: 'text-1', text: 'hello from Xiaoe'),
      ];
  return XiaoeMonitorShellStatus.fromLocal(
    LocalMonitorShellStatus(
      shellState: 'online',
      captureState: 'running',
      loginState: 'logged_in',
      hookState: 'healthy',
      runtimeUrl: 'https://study.xiaoe-tech.com/#/muti_index',
      pageTitle: 'Alpha Circle',
      pageKind: 'circle',
      webviewAvailable: true,
      shellMode: 'desktop_shell',
      queueDepth: 0,
      messagesToday: events.length,
      deliveriesSucceededToday: 0,
      deliveriesFailedToday: 0,
      lastUpdatedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      probeObservedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      observedConversations: <LocalMonitorObservedConversation>[
        LocalMonitorObservedConversation(
          id: 'circle-alpha',
          name: 'Alpha Circle',
          type: 'circle',
          lastMessagePreview: 'hello from Xiaoe',
          observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
        ),
      ],
      observedMessages: const <LocalMonitorObservedMessage>[],
      recentEvents: events.map((event) => event.toLocal()).toList(),
      workerId: 'worker-1',
      probeDiagnostics: const <String, dynamic>{
        'target_url': 'https://study.xiaoe-tech.com/#/muti_index',
        'manual_target_page_required': true,
        'file_size_limit_bytes': 20971520,
      },
      lastError: '',
    ),
  );
}

XiaoeMonitorMessageEvent _event({
  String eventId = 'event-1',
  String dedupeKey = 'circle-alpha:msg-1',
  String conversationId = 'circle-alpha',
  String conversationName = 'Alpha Circle',
  String conversationType = 'circle',
  String messageId = 'msg-1',
  String senderName = 'Alice',
  String messageType = 'text',
  String text = 'hello from Xiaoe',
  List<XiaoeMonitorImageAttachment> imageAttachments =
      const <XiaoeMonitorImageAttachment>[],
  List<XiaoeMonitorFileAttachment> fileAttachments =
      const <XiaoeMonitorFileAttachment>[],
}) {
  return XiaoeMonitorMessageEvent.fromLocal(
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
      observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
      captureSource: 'xiaoe_dom_probe',
      imageAttachments: imageAttachments,
      fileAttachments: fileAttachments,
    ),
  );
}

XiaoeMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'circle-alpha',
  String sourceConversationName = 'Alpha Circle',
  String sourceConversationType = 'circle',
  String targetGroupId = 'wk-alpha',
  String targetGroupName = 'WuKong Alpha',
}) {
  return XiaoeMonitorForwardingRoute(
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
