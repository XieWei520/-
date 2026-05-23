import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_diagnostics.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';

void main() {
  test(
    'runOnce forwards recent native host events when routes are enabled',
    () async {
      final client = _FakeShellClient(
        status: _status(),
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'windows:alpha', text: 'live message'),
        ],
      );
      final service = _FakeForwardingService();
      final runner = DingTalkMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          DingTalkMonitorForwardingSettings(
            enabled: true,
            routes: <DingTalkMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'windows:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(client.fetchStatusCount, 1);
      expect(client.probeLatestCount, 0);
      expect(client.fetchEventsCount, 1);
      expect(service.callCount, 1);
      expect(service.lastEvents.single.text, 'live message');
      expect(result?.sent, 1);
    },
  );

  test('runOnce records redacted diagnostics for a successful poll', () async {
    final client = _FakeShellClient(
      status: _status(),
      events: <DingTalkMonitorMessageEvent>[
        _event(
          sourceConversationId: 'windows:secret-source',
          sourceConversationName: 'Sensitive Source',
          senderName: 'Sensitive Sender',
          text: 'secret message body',
        ),
      ],
    );
    final service = _FakeForwardingService();
    final diagnosticsStore = _MemoryDiagnosticsStore();
    final runner = DingTalkMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        DingTalkMonitorForwardingSettings(
          enabled: true,
          routes: <DingTalkMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'windows:secret-source',
              targetGroupId: 'secret-target-group',
            ),
          ],
        ),
      ),
      diagnosticsStore: diagnosticsStore,
    );

    await runner.runOnce();

    final snapshot = diagnosticsStore.lastSnapshot;
    expect(snapshot, isNotNull);
    expect(snapshot!.state, 'completed');
    expect(snapshot.recentEventCount, 1);
    expect(snapshot.forwardableTextEventCount, 1);
    expect(snapshot.matchedRouteCount, 1);
    expect(snapshot.sent, 1);
    expect(snapshot.routeSourceHashes, hasLength(1));
    expect(snapshot.recentSourceHashes, hasLength(1));
    final encoded = snapshot.toJson().toString();
    expect(encoded, isNot(contains('secret message body')));
    expect(encoded, isNot(contains('Sensitive Source')));
    expect(encoded, isNot(contains('Sensitive Sender')));
    expect(encoded, isNot(contains('secret-target-group')));
  });

  test(
    'runOnce records forwarding failure diagnostics without raw error text',
    () async {
      final client = _FakeShellClient(
        status: _status(),
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'windows:alpha', text: 'live message'),
        ],
      );
      final service = _FakeForwardingService(
        result: const DingTalkMonitorForwardingResult(
          sent: 0,
          failed: 1,
          lastErrorType: 'StateError',
          lastErrorMessageLength: 28,
        ),
      );
      final diagnosticsStore = _MemoryDiagnosticsStore();
      final runner = DingTalkMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          DingTalkMonitorForwardingSettings(
            enabled: true,
            routes: <DingTalkMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'windows:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
        diagnosticsStore: diagnosticsStore,
      );

      await runner.runOnce();

      final snapshot = diagnosticsStore.lastSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.state, 'completed');
      expect(snapshot.failed, 1);
      expect(snapshot.lastErrorType, 'StateError');
      expect(snapshot.lastErrorMessageLength, 28);
      expect(snapshot.toJson().toString(), isNot(contains('live message')));
    },
  );

  test(
    'runOnce keeps cumulative sent diagnostics after duplicate polls',
    () async {
      final client = _FakeShellClient(
        status: _status(),
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'windows:alpha', text: 'live message'),
        ],
      );
      final service = _FakeForwardingService(
        results: <DingTalkMonitorForwardingResult>[
          const DingTalkMonitorForwardingResult(sent: 1, failed: 0),
          const DingTalkMonitorForwardingResult(
            sent: 0,
            skippedDuplicate: 1,
            failed: 0,
          ),
        ],
      );
      final diagnosticsStore = _MemoryDiagnosticsStore();
      final runner = DingTalkMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          DingTalkMonitorForwardingSettings(
            enabled: true,
            routes: <DingTalkMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'windows:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
        diagnosticsStore: diagnosticsStore,
      );

      await runner.runOnce();
      await runner.runOnce();

      final snapshot = diagnosticsStore.lastSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.sent, 0);
      expect(snapshot.skippedDuplicate, 1);
      expect(snapshot.sessionSent, 1);
      expect(snapshot.lastSentAt, isNotNull);
    },
  );

  test('runOnce skips host fetch when no routes are enabled', () async {
    final client = _FakeShellClient(status: _status());
    final service = _FakeForwardingService();
    final runner = DingTalkMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        const DingTalkMonitorForwardingSettings(
          enabled: true,
          routes: <DingTalkMonitorForwardingRoute>[],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(result, isNull);
    expect(client.fetchStatusCount, 0);
    expect(client.probeLatestCount, 0);
    expect(client.fetchEventsCount, 0);
    expect(service.callCount, 0);
  });

  test(
    'runOnce restarts host capture before skipping stopped host',
    () async {
      final client = _FakeShellClient(
        status: _stoppedStatus(),
        statusAfterStart: _status(),
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'windows:alpha', text: 'live message'),
        ],
      );
      final service = _FakeForwardingService();
      final runner = DingTalkMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          DingTalkMonitorForwardingSettings(
            enabled: true,
            routes: <DingTalkMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'windows:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(client.fetchStatusCount, 2);
      expect(client.startCaptureCount, 1);
      expect(client.probeLatestCount, 0);
      expect(client.fetchEventsCount, 1);
      expect(service.callCount, 1);
      expect(result?.sent, 1);
    },
  );

  test('runOnce skips when host is not attached or not capturing', () async {
    final client = _FakeShellClient(
      status: _stoppedStatus(),
      events: <DingTalkMonitorMessageEvent>[
        _event(sourceConversationId: 'source:alpha'),
      ],
    );
    final service = _FakeForwardingService();
    final runner = DingTalkMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        DingTalkMonitorForwardingSettings(
          enabled: true,
          routes: <DingTalkMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'windows:alpha',
              targetGroupId: 'wk_alpha',
            ),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(result, isNull);
    expect(client.fetchStatusCount, 2);
    expect(client.startCaptureCount, 1);
    expect(client.probeLatestCount, 0);
    expect(client.fetchEventsCount, 0);
    expect(service.callCount, 0);
  });

  test('runOnce uses active latest probe only when explicitly enabled', () async {
    final client = _FakeShellClient(
      status: _status(),
      events: <DingTalkMonitorMessageEvent>[
        _event(sourceConversationId: 'windows:alpha', text: 'live message'),
      ],
    );
    final service = _FakeForwardingService();
    final runner = DingTalkMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        DingTalkMonitorForwardingSettings(
          enabled: true,
          routes: <DingTalkMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'windows:alpha',
              targetGroupId: 'wk_alpha',
            ),
          ],
        ),
      ),
      activeProbeEnabled: true,
    );

    final result = await runner.runOnce();

    expect(client.fetchStatusCount, 1);
    expect(client.probeLatestCount, 1);
    expect(client.fetchEventsCount, 1);
    expect(service.callCount, 1);
    expect(result?.sent, 1);
  });

  test('runOnce continues event fetch when active latest probe fails', () async {
    final errors = <Object>[];
    final client = _FakeShellClient(
      status: _status(),
      probeLatestError: StateError('probe failed'),
      events: <DingTalkMonitorMessageEvent>[
        _event(sourceConversationId: 'windows:alpha', text: 'live message'),
      ],
    );
    final service = _FakeForwardingService();
    final runner = DingTalkMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemorySettingsStore(
        DingTalkMonitorForwardingSettings(
          enabled: true,
          routes: <DingTalkMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'windows:alpha',
              targetGroupId: 'wk_alpha',
            ),
          ],
        ),
      ),
      activeProbeEnabled: true,
      onError: (error, _) => errors.add(error),
    );

    final result = await runner.runOnce();

    expect(client.fetchStatusCount, 1);
    expect(client.probeLatestCount, 1);
    expect(client.fetchEventsCount, 1);
    expect(service.callCount, 1);
    expect(result?.sent, 1);
    expect(errors.single, isA<StateError>());
  });

  test(
    'start primes old startup events before forwarding live polls',
    () async {
      final startAt = DateTime.parse('2026-05-16T01:00:00Z');
      final client = _FakeShellClient(
        status: _status(),
        events: <DingTalkMonitorMessageEvent>[
          _event(
            sourceConversationId: 'windows:alpha',
            observedAt: startAt.subtract(const Duration(seconds: 1)),
            text: 'old message',
          ),
        ],
      );
      final service = _FakeForwardingService();
      final runner = DingTalkMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemorySettingsStore(
          DingTalkMonitorForwardingSettings(
            enabled: true,
            routes: <DingTalkMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'windows:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
        clock: () => startAt,
      );

      await runner.runOnce(primeIfNeeded: true);
      client.events = <DingTalkMonitorMessageEvent>[
        _event(
          eventId: 'event-live',
          contentHash: 'hash-live',
          sourceConversationId: 'windows:alpha',
          observedAt: startAt.add(const Duration(seconds: 1)),
          text: 'live message',
        ),
      ];
      final result = await runner.runOnce(primeIfNeeded: true);

      expect(service.primeCount, 1);
      expect(service.lastPrimedEvents.single.text, 'old message');
      expect(service.callCount, 1);
      expect(service.lastEvents.single.text, 'live message');
      expect(result?.sent, 1);
      expect(client.probeLatestCount, 0);
    },
  );
}

DingTalkMonitorShellStatus _status() {
  return const DingTalkMonitorShellStatus(
    captureRunning: true,
    serverTime: null,
    version: 'm1',
    shellState: 'Attached',
    currentHwnd: '0x1',
    message: '',
    lastWindowEventAt: null,
    ocrEnabled: true,
    conversationReadiness: 'Ready',
    conversationReadinessMessage: '',
  );
}

DingTalkMonitorShellStatus _stoppedStatus() {
  return const DingTalkMonitorShellStatus(
    captureRunning: false,
    serverTime: null,
    version: 'm1',
    shellState: 'Stopped',
    currentHwnd: '',
    message: '',
    lastWindowEventAt: null,
    ocrEnabled: false,
    conversationReadiness: 'NoConversationList',
    conversationReadinessMessage: '',
  );
}

DingTalkMonitorMessageEvent _event({
  String eventId = 'event-1',
  String sourceConversationId = 'source:alpha',
  String sourceConversationName = 'Alpha',
  String senderName = 'Alice',
  String text = 'hello',
  String contentHash = 'hash-1',
  DateTime? observedAt,
}) {
  return DingTalkMonitorMessageEvent(
    eventId: eventId,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    embeddedSourceName: '',
    senderName: senderName,
    observedAt: observedAt ?? DateTime.parse('2026-05-16T01:00:01Z'),
    text: text,
    localImagePath: '',
    captureSource: DingTalkMonitorCaptureSource.uiaText,
    contentHash: contentHash,
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
    embeddedSourceName: '',
    targetGroupId: targetGroupId,
    targetGroupName: 'Target',
    createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-16T01:00:00Z'),
  );
}

class _FakeShellClient extends DingTalkMonitorShellClient {
  _FakeShellClient({
    required this.status,
    this.statusAfterStart,
    this.events = const <DingTalkMonitorMessageEvent>[],
    this.probeLatestError,
  });

  DingTalkMonitorShellStatus status;
  DingTalkMonitorShellStatus? statusAfterStart;
  List<DingTalkMonitorMessageEvent> events;
  Object? probeLatestError;
  int fetchStatusCount = 0;
  int startCaptureCount = 0;
  int probeLatestCount = 0;
  int fetchEventsCount = 0;

  @override
  Future<DingTalkMonitorShellStatus> fetchStatus() async {
    fetchStatusCount += 1;
    return status;
  }

  @override
  Future<void> startCapture() async {
    startCaptureCount += 1;
    final nextStatus = statusAfterStart;
    if (nextStatus != null) {
      status = nextStatus;
    }
  }

  @override
  Future<void> probeLatest() async {
    probeLatestCount += 1;
    final error = probeLatestError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<List<DingTalkMonitorMessageEvent>> fetchForwardableRecentEvents({
    int limit = 50,
  }) async {
    fetchEventsCount += 1;
    return events;
  }
}

class _FakeForwardingService extends DingTalkMonitorForwardingService {
  _FakeForwardingService({
    this.result,
    List<DingTalkMonitorForwardingResult>? results,
  }) : results = List<DingTalkMonitorForwardingResult>.from(
         results ?? const <DingTalkMonitorForwardingResult>[],
       ),
       super(sender: _NoopSender());

  final DingTalkMonitorForwardingResult? result;
  final List<DingTalkMonitorForwardingResult> results;

  int callCount = 0;
  int primeCount = 0;
  List<DingTalkMonitorMessageEvent> lastEvents =
      const <DingTalkMonitorMessageEvent>[];
  List<DingTalkMonitorMessageEvent> lastPrimedEvents =
      const <DingTalkMonitorMessageEvent>[];

  @override
  Future<void> primeRoutedRecentEvents({
    required DingTalkMonitorForwardingSettings settings,
    required List<DingTalkMonitorMessageEvent> events,
  }) async {
    primeCount += 1;
    lastPrimedEvents = List<DingTalkMonitorMessageEvent>.from(events);
  }

  @override
  Future<DingTalkMonitorForwardingResult> forwardRoutedRecentEvents({
    required DingTalkMonitorForwardingSettings settings,
    required List<DingTalkMonitorMessageEvent> events,
  }) async {
    callCount += 1;
    lastEvents = List<DingTalkMonitorMessageEvent>.from(events);
    if (results.isNotEmpty) {
      return results.removeAt(0);
    }
    return result ??
        DingTalkMonitorForwardingResult(
          sent: events.length,
          skippedUnmatched: 0,
          failed: 0,
        );
  }
}

class _MemoryDiagnosticsStore
    implements DingTalkMonitorAutoForwardDiagnosticsStore {
  DingTalkMonitorAutoForwardDiagnosticsSnapshot? lastSnapshot;

  @override
  Future<void> save(
    DingTalkMonitorAutoForwardDiagnosticsSnapshot snapshot,
  ) async {
    lastSnapshot = snapshot;
  }
}

class _MemorySettingsStore implements DingTalkMonitorForwardingSettingsStore {
  const _MemorySettingsStore(this.settings);

  final DingTalkMonitorForwardingSettings settings;

  @override
  Future<DingTalkMonitorForwardingSettings> load() async => settings;

  @override
  Future<void> save(DingTalkMonitorForwardingSettings settings) async {}
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
