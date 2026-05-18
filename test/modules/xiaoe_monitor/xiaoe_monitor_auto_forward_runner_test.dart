import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/app.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/xiaoe_monitor/xiaoe_monitor_shell_models.dart';

void main() {
  test('app auto-forward runners include Xiaoe with existing platforms', () {
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
    expect(runners.whereType<XiaoeMonitorAutoForwardRunner>(), hasLength(1));
  });

  test('runOnce forwards routed live text and syncs sources', () async {
    final client = _FakeShellClient(
      status: _status(
        recentEvents: <XiaoeMonitorMessageEvent>[
          _event(conversationId: 'live-alpha', text: 'live message'),
        ],
      ),
    );
    final service = _FakeForwardingService();
    final runner = XiaoeMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        XiaoeMonitorForwardingSettings(
          enabled: true,
          routes: <XiaoeMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'live-alpha',
              targetGroupId: 'wk-live',
            ),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(client.fetchStatusCount, 1);
    expect(client.syncedSources, <String>['live-alpha']);
    expect(service.forwardCallCount, 1);
    expect(service.lastForwardedEvents.single.text, 'live message');
    expect(result?.sent, 1);
  });

  test(
    'runOnce forwards image and file events as forwardable payloads',
    () async {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <XiaoeMonitorMessageEvent>[
            _event(
              eventId: 'image-event',
              dedupeKey: 'circle-alpha:image-1',
              messageType: 'image',
              text: '',
              imageAttachments: const <XiaoeMonitorImageAttachment>[
                XiaoeMonitorImageAttachment(
                  sourceUrl: 'https://cdn.example.com/image.png',
                  localPath: '',
                  width: 640,
                  height: 480,
                ),
              ],
            ),
            _event(
              eventId: 'file-event',
              dedupeKey: 'circle-alpha:file-1',
              messageType: 'file',
              text: '',
              fileAttachments: const <XiaoeMonitorFileAttachment>[
                XiaoeMonitorFileAttachment(
                  sourceUrl: 'https://cdn.example.com/lesson.pdf',
                  localPath: r'C:\tmp\lesson.pdf',
                  fileName: 'lesson.pdf',
                  mimeType: 'application/pdf',
                  sizeBytes: 1024,
                ),
              ],
            ),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = XiaoeMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          XiaoeMonitorForwardingSettings(
            enabled: true,
            routes: <XiaoeMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'circle-alpha',
                targetGroupId: 'wk-alpha',
              ),
            ],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(result?.sent, 2);
      expect(service.lastForwardedEvents, hasLength(2));
      expect(service.lastForwardedEvents.first.hasImageAttachments, isTrue);
      expect(service.lastForwardedEvents.last.hasFileAttachments, isTrue);
    },
  );

  test(
    'runOnce skips shell fetch when auto-forwarding has no enabled route',
    () async {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = XiaoeMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          const XiaoeMonitorForwardingSettings(enabled: true),
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
        recentEvents: <XiaoeMonitorMessageEvent>[
          _event(
            conversationId: 'circle-alpha',
            text: 'old startup message',
            observedAt: DateTime.parse('2026-05-17T00:59:59Z'),
          ),
        ],
      ),
    );
    final service = _FakeForwardingService();
    final runner = XiaoeMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        XiaoeMonitorForwardingSettings(
          enabled: true,
          routes: <XiaoeMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'circle-alpha',
              targetGroupId: 'wk-alpha',
            ),
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

  test('snapshot update SSE triggers forwarding run', () async {
    final events = StreamController<XiaoeMonitorShellEvent>();
    final client = _FakeShellClient(
      status: _status(
        recentEvents: <XiaoeMonitorMessageEvent>[
          _event(conversationId: 'circle-alpha', text: 'new from sse'),
        ],
      ),
      events: events.stream,
    );
    final service = _FakeForwardingService();
    final runner = XiaoeMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        XiaoeMonitorForwardingSettings(
          enabled: true,
          routes: <XiaoeMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'circle-alpha',
              targetGroupId: 'wk-alpha',
            ),
          ],
        ),
      ),
    );
    addTearDown(() async {
      runner.dispose();
      await events.close();
    });

    runner.start();
    await Future<void>.delayed(Duration.zero);
    final baseline = service.forwardCallCount;
    events.add(
      XiaoeMonitorShellEvent.fromLocal(
        LocalMonitorShellEvent(
          type: 'snapshot_updated',
          reason: 'xiaoe_probe',
          updatedAt: DateTime.parse('2026-05-17T01:00:01Z'),
          recentEvents: 1,
          observedConversations: 1,
          error: '',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.forwardCallCount, greaterThan(baseline));
  });
}

class _FakeShellClient implements XiaoeMonitorShellClient {
  _FakeShellClient({
    required this.status,
    Stream<XiaoeMonitorShellEvent>? events,
  }) : _events = events ?? const Stream<XiaoeMonitorShellEvent>.empty();

  XiaoeMonitorShellStatus status;
  final Stream<XiaoeMonitorShellEvent> _events;
  int fetchStatusCount = 0;
  final syncedSources = <String>[];

  @override
  Future<XiaoeMonitorShellStatus> fetchStatus() async {
    fetchStatusCount += 1;
    return status;
  }

  @override
  Future<void> syncConfiguredSources(
    Iterable<XiaoeMonitorRoutingSource> sources,
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
  Stream<XiaoeMonitorShellEvent> watchEvents() => _events;
}

class _FakeForwardingService implements XiaoeMonitorForwardingService {
  int forwardCallCount = 0;
  int primeCallCount = 0;
  List<XiaoeMonitorMessageEvent> lastForwardedEvents =
      <XiaoeMonitorMessageEvent>[];
  List<XiaoeMonitorMessageEvent> lastPrimedEvents =
      <XiaoeMonitorMessageEvent>[];

  @override
  Future<XiaoeMonitorForwardingResult> forwardRoutedRecentEvents({
    required XiaoeMonitorForwardingSettings settings,
    required Iterable<XiaoeMonitorMessageEvent> events,
  }) async {
    forwardCallCount += 1;
    lastForwardedEvents = events.toList(growable: false);
    return XiaoeMonitorForwardingResult(
      sent: lastForwardedEvents.length,
      failed: 0,
    );
  }

  @override
  Future<void> primeRoutedRecentEvents({
    required XiaoeMonitorForwardingSettings settings,
    required Iterable<XiaoeMonitorMessageEvent> events,
  }) async {
    primeCallCount += 1;
    lastPrimedEvents = events.toList(growable: false);
  }
}

class _MemorySettingsStore implements XiaoeMonitorForwardingSettingsStore {
  _MemorySettingsStore(this.settings);

  XiaoeMonitorForwardingSettings settings;

  @override
  Future<XiaoeMonitorForwardingSettings> load() async => settings;

  @override
  Future<void> save(XiaoeMonitorForwardingSettings settings) async {
    this.settings = settings;
  }
}

XiaoeMonitorShellStatus _status({
  List<XiaoeMonitorMessageEvent> recentEvents =
      const <XiaoeMonitorMessageEvent>[],
}) {
  return XiaoeMonitorShellStatus.fromLocal(
    LocalMonitorShellStatus(
      shellState: 'online',
      captureState: 'running',
      loginState: 'logged_in',
      hookState: 'healthy',
      runtimeUrl: 'https://study.xiaoe-tech.com/#/muti_index',
      pageTitle: 'Xiaoe',
      pageKind: 'circle',
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

XiaoeMonitorMessageEvent _event({
  String eventId = 'event-msg-1',
  String dedupeKey = 'circle-alpha:msg-1',
  String conversationId = 'circle-alpha',
  String conversationName = 'Alpha Circle',
  String conversationType = 'circle',
  String messageId = 'msg-1',
  String senderName = 'Alice',
  String messageType = 'text',
  String text = 'hello',
  DateTime? observedAt,
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
      observedAt: observedAt ?? DateTime.parse('2026-05-17T01:00:01Z'),
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
