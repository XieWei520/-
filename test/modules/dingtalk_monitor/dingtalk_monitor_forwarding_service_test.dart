import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/dingtalk_monitor/dingtalk_monitor_shell_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('route round trips through json', () {
    final route = DingTalkMonitorForwardingRoute(
      id: 'route_1',
      enabled: true,
      sourceConversationId: 'source:alpha',
      sourceConversationName: 'Alpha',
      embeddedSourceName: 'Embedded Alpha',
      targetGroupId: 'wk_alpha',
      targetGroupName: 'WuKong Alpha',
      relayDisplayName: 'DingTalk Relay',
      relayAvatar: 'https://cdn.example.com/dingtalk.png',
      createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
      updatedAt: DateTime.parse('2026-05-16T02:00:00Z'),
    );

    final decoded = DingTalkMonitorForwardingRoute.fromJson(route.toJson());

    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'source:alpha');
    expect(decoded.sourceConversationName, 'Alpha');
    expect(decoded.embeddedSourceName, 'Embedded Alpha');
    expect(decoded.targetGroupId, 'wk_alpha');
    expect(decoded.relayDisplayName, 'DingTalk Relay');
  });

  test('findRouteForEvent prefers conversation id', () {
    final route = _route(
      sourceConversationId: 'source:alpha',
      sourceConversationName: 'Wrong Name',
      targetGroupId: 'wk_alpha',
    );

    final matched = findDingTalkMonitorRouteForEvent(
      routes: <DingTalkMonitorForwardingRoute>[route],
      event: _event(
        sourceConversationId: 'source:alpha',
        sourceConversationName: 'Alpha',
      ),
    );

    expect(matched?.targetGroupId, 'wk_alpha');
  });

  test('findRouteForEvent prefers embedded source name before outer name', () {
    final routes = <DingTalkMonitorForwardingRoute>[
      _route(
        id: 'outer',
        sourceConversationId: '',
        sourceConversationName: 'DingTalk Screenshot',
        targetGroupId: 'wk_outer',
      ),
      _route(
        id: 'embedded',
        sourceConversationId: '',
        sourceConversationName: '',
        embeddedSourceName: 'Alpha Embedded',
        targetGroupId: 'wk_embedded',
      ),
    ];

    final matched = findDingTalkMonitorRouteForEvent(
      routes: routes,
      event: _event(
        sourceConversationId: '',
        sourceConversationName: 'DingTalk Screenshot',
        embeddedSourceName: ' alpha   embedded ',
      ),
    );

    expect(matched?.targetGroupId, 'wk_embedded');
  });

  test('findRouteForEvent does not map generic screenshot OCR to a route', () {
    final routes = <DingTalkMonitorForwardingRoute>[
      _route(
        sourceConversationId: 'windows:fb61ccc7',
        sourceConversationName: '信息平权',
        targetGroupId: 'wk_test2',
      ),
    ];

    final matched = findDingTalkMonitorRouteForEvent(
      routes: routes,
      event: _event(
        sourceConversationId: 'source:dingtalk-screenshot',
        sourceConversationName: 'DingTalk Screenshot',
        senderName: 'OCR',
        captureSource: DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
      ),
    );

    expect(matched, isNull);
  });

  test(
    'findRouteForEvent does not guess generic screenshot when routes are ambiguous',
    () {
      final routes = <DingTalkMonitorForwardingRoute>[
        _route(
          id: 'one',
          sourceConversationId: 'windows:one',
          targetGroupId: 'wk_one',
        ),
        _route(
          id: 'two',
          sourceConversationId: 'windows:two',
          targetGroupId: 'wk_two',
        ),
      ];

      final matched = findDingTalkMonitorRouteForEvent(
        routes: routes,
        event: _event(
          sourceConversationId: 'source:dingtalk-screenshot',
          sourceConversationName: 'DingTalk Screenshot',
          senderName: 'OCR',
          captureSource: DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
        ),
      );

      expect(matched, isNull);
    },
  );

  test(
    'forwardRoutedRecentEvents sends text into matched WuKong group',
    () async {
      final sender = _RecordingSender();
      final service = DingTalkMonitorForwardingService(sender: sender);
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'windows:alpha',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'windows:alpha', text: 'hello'),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 0);
      expect(sender.targetGroupIds, <String>['wk_alpha']);
      expect(sender.sentTexts, <String>['hello']);
      expect(sender.relayProviders, <String>['dingtalk']);
    },
  );

  test('forwardRoutedRecentEvents skips screenshot OCR events', () async {
    final sender = _RecordingSender();
    final service = DingTalkMonitorForwardingService(sender: sender);
    final settings = DingTalkMonitorForwardingSettings(
      enabled: true,
      routes: <DingTalkMonitorForwardingRoute>[
        _route(
          sourceConversationId: 'windows:alpha',
          targetGroupId: 'wk_alpha',
        ),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <DingTalkMonitorMessageEvent>[
        _event(
          sourceConversationId: 'source:alpha',
          sourceConversationName: 'Alpha',
          senderName: 'OCR',
          text: 'low confidence OCR body',
          captureSource: DingTalkMonitorCaptureSource.chatAreaScreenshotOcr,
        ),
      ],
    );

    expect(result.sent, 0);
    expect(result.skippedUnmatched, 1);
    expect(sender.sentTexts, isEmpty);
  });

  test('forwardRoutedRecentEvents requires explicit source id match', () async {
    final sender = _RecordingSender();
    final service = DingTalkMonitorForwardingService(sender: sender);
    final settings = DingTalkMonitorForwardingSettings(
      enabled: true,
      routes: <DingTalkMonitorForwardingRoute>[
        _route(
          sourceConversationId: 'windows:fb61ccc7',
          sourceConversationName: 'Alpha',
          targetGroupId: 'wk_alpha',
        ),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <DingTalkMonitorMessageEvent>[
        _event(
          sourceConversationId: '',
          sourceConversationName: 'Alpha',
          text: 'name-only match should not send',
        ),
      ],
    );

    expect(result.sent, 0);
    expect(sender.sentTexts, isEmpty);
  });

  test(
    'forwardRoutedRecentEvents allows active chat source for a single enabled route',
    () async {
      final sender = _RecordingSender();
      final service = DingTalkMonitorForwardingService(sender: sender);
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'windows:bound',
            sourceConversationName: 'Bound',
            targetGroupId: 'wk_bound',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(
            sourceConversationId: 'windows:clipboard-active',
            sourceConversationName: '(clipboard active chat)',
            text: 'active chat body',
          ),
        ],
      );

      expect(result.sent, 1);
      expect(result.skippedDuplicate, 0);
      expect(sender.targetGroupIds, <String>['wk_bound']);
      expect(sender.sentTexts, <String>['active chat body']);
    },
  );

  test(
    'forwardRoutedRecentEvents does not guess active chat source across multiple routes',
    () async {
      final sender = _RecordingSender();
      final service = DingTalkMonitorForwardingService(sender: sender);
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            id: 'one',
            sourceConversationId: 'windows:one',
            targetGroupId: 'wk_one',
          ),
          _route(
            id: 'two',
            sourceConversationId: 'windows:two',
            targetGroupId: 'wk_two',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(
            sourceConversationId: 'windows:clipboard-active',
            sourceConversationName: '(clipboard active chat)',
            text: 'active chat body',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedUnmatched, 1);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test(
    'forwardRoutedRecentEvents skips known non-chat UIA text sources',
    () async {
      final sender = _RecordingSender();
      final service = DingTalkMonitorForwardingService(sender: sender);
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'source:unknown',
            sourceConversationName: '',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(
            sourceConversationId: 'source:unknown',
            sourceConversationName: '',
            text: '当前检测出钉钉异常，请点击确定',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 1);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test('forwardRoutedRecentEvents dedupes repeated event id', () async {
    final sender = _RecordingSender();
    final dedupeStore = _MemoryDedupeStore();
    final service = DingTalkMonitorForwardingService(
      sender: sender,
      dedupeStore: dedupeStore,
    );
    final settings = DingTalkMonitorForwardingSettings(
      enabled: true,
      routes: <DingTalkMonitorForwardingRoute>[
        _route(
          sourceConversationId: 'windows:alpha',
          targetGroupId: 'wk_alpha',
        ),
      ],
    );
    final event = _event(
      eventId: 'event-1',
      sourceConversationId: 'windows:alpha',
      contentHash: 'same-hash',
      text: 'hello',
    );

    final first = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <DingTalkMonitorMessageEvent>[event],
    );
    final second = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <DingTalkMonitorMessageEvent>[
        _event(
          eventId: 'event-1',
          sourceConversationId: 'windows:alpha',
          contentHash: 'same-hash',
          text: 'hello',
        ),
      ],
    );

    expect(first.sent, 1);
    expect(second.sent, 0);
    expect(second.skippedDuplicate, 1);
    expect(sender.sentTexts, <String>['hello']);
  });

  test(
    'forwardRoutedRecentEvents dedupes repeated content with distinct event ids',
    () async {
      final sender = _RecordingSender();
      final dedupeStore = _MemoryDedupeStore();
      final service = DingTalkMonitorForwardingService(
        sender: sender,
        dedupeStore: dedupeStore,
      );
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            sourceConversationId: 'windows:alpha',
            targetGroupId: 'wk_alpha',
          ),
        ],
      );

      final first = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(
            eventId: 'event-1',
            sourceConversationId: 'windows:alpha',
            contentHash: 'same-hash',
            text: 'hello',
          ),
        ],
      );
      final second = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(
            eventId: 'event-2',
            sourceConversationId: 'windows:alpha',
            contentHash: 'same-hash',
            text: 'hello',
          ),
        ],
      );

      expect(first.sent, 1);
      expect(second.sent, 0);
      expect(second.skippedDuplicate, 1);
      expect(sender.sentTexts, <String>['hello']);
    },
  );

  test(
    'forwardRoutedRecentEvents counts disabled and unmatched routes',
    () async {
      final sender = _RecordingSender();
      final service = DingTalkMonitorForwardingService(sender: sender);
      final settings = DingTalkMonitorForwardingSettings(
        enabled: true,
        routes: <DingTalkMonitorForwardingRoute>[
          _route(
            enabled: false,
            sourceConversationId: 'source:disabled',
            targetGroupId: 'wk_disabled',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <DingTalkMonitorMessageEvent>[
          _event(sourceConversationId: 'source:disabled'),
          _event(sourceConversationId: 'source:missing'),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDisabled, 1);
      expect(result.skippedUnmatched, 1);
      expect(sender.sentTexts, isEmpty);
    },
  );

  test('settings store saves and loads routes', () async {
    const store = SharedPreferencesDingTalkMonitorForwardingSettingsStore();
    final settings = DingTalkMonitorForwardingSettings(
      enabled: true,
      routes: <DingTalkMonitorForwardingRoute>[
        _route(sourceConversationId: 'source:alpha', targetGroupId: 'wk_alpha'),
      ],
    );

    await store.save(settings);
    final loaded = await store.load();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes, hasLength(1));
    expect(loaded.routes.single.sourceConversationId, 'source:alpha');
    expect(loaded.routes.single.targetGroupId, 'wk_alpha');
  });

  test('settings store imports legacy monitor settings as disabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'dingtalk_monitor_settings_v1':
          '{"enabled":true,"routes":[{"id":"legacy_1","enabled":true,'
          '"source_conversation_id":"windows:fb61ccc7",'
          '"source_conversation_name":"信息平权",'
          '"target_group_id":"wk_test2",'
          '"target_group_name":"test2",'
          '"created_at":"2026-05-15T01:00:00Z",'
          '"updated_at":"2026-05-15T01:00:00Z"}]}',
    });
    const store = SharedPreferencesDingTalkMonitorForwardingSettingsStore();

    final loaded = await store.load();

    expect(loaded.enabled, isFalse);
    expect(loaded.routes, hasLength(1));
    expect(loaded.routes.single.sourceConversationId, 'windows:fb61ccc7');
    expect(loaded.routes.single.sourceConversationName, '信息平权');
    expect(loaded.routes.single.targetGroupId, 'wk_test2');
    expect(loaded.routes.single.targetGroupName, 'test2');
  });

  test(
    'settings store prefers new forwarding settings over legacy key',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'dingtalk_monitor_settings_v1':
            '{"enabled":true,"routes":[{"id":"legacy_1","enabled":true,'
            '"source_conversation_id":"source:legacy",'
            '"target_group_id":"wk_legacy",'
            '"created_at":"2026-05-15T01:00:00Z",'
            '"updated_at":"2026-05-15T01:00:00Z"}]}',
        'dingtalk_monitor_forwarding_settings_v1':
            '{"enabled":true,"routes":[{"id":"new_1","enabled":true,'
            '"source_conversation_id":"source:new",'
            '"target_group_id":"wk_new",'
            '"created_at":"2026-05-16T01:00:00Z",'
            '"updated_at":"2026-05-16T01:00:00Z"}]}',
      });
      const store = SharedPreferencesDingTalkMonitorForwardingSettingsStore();

      final loaded = await store.load();

      expect(loaded.routes, hasLength(1));
      expect(loaded.routes.single.sourceConversationId, 'source:new');
      expect(loaded.routes.single.targetGroupId, 'wk_new');
    },
  );
}

DingTalkMonitorMessageEvent _event({
  String eventId = 'event-1',
  String sourceConversationId = 'source:alpha',
  String sourceConversationName = 'Alpha',
  String embeddedSourceName = '',
  String senderName = 'Alice',
  String text = 'hello from DingTalk',
  String contentHash = 'hash-1',
  DingTalkMonitorCaptureSource captureSource =
      DingTalkMonitorCaptureSource.uiaText,
}) {
  return DingTalkMonitorMessageEvent(
    eventId: eventId,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    embeddedSourceName: embeddedSourceName,
    senderName: senderName,
    observedAt: DateTime.parse('2026-05-16T01:33:16Z'),
    text: text,
    localImagePath: '',
    captureSource: captureSource,
    contentHash: contentHash,
  );
}

DingTalkMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'source:alpha',
  String sourceConversationName = 'Alpha',
  String embeddedSourceName = '',
  String targetGroupId = 'wk_alpha',
  String targetGroupName = 'WuKong Alpha',
  String relayDisplayName = '',
  String relayAvatar = '',
}) {
  return DingTalkMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    embeddedSourceName: embeddedSourceName,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    relayDisplayName: relayDisplayName,
    relayAvatar: relayAvatar,
    createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-16T01:00:00Z'),
  );
}

class _RecordingSender implements DingTalkMonitorTextSender {
  final sentTexts = <String>[];
  final targetGroupIds = <String>[];
  final relayProviders = <String>[];

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) async {
    targetGroupIds.add(channelId);
    sentTexts.add(text);
    relayProviders.add(relayIdentity?.provider ?? '');
  }
}

class _MemoryDedupeStore implements DingTalkMonitorForwardingDedupeStore {
  final keys = <String>[];

  @override
  Future<List<String>> loadSentKeys() async => List<String>.from(keys);

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    this.keys
      ..clear()
      ..addAll(keys);
  }
}
