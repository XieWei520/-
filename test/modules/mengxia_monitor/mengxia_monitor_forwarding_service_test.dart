import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('route round trips through json with Mengxia-specific fields', () {
    final route = MengxiaMonitorForwardingRoute(
      id: 'route_1',
      enabled: true,
      sourceConversationId: 'mx-alpha',
      sourceConversationName: 'Alpha',
      sourceConversationType: 'group',
      targetGroupId: 'wk-alpha',
      targetGroupName: 'WuKong Alpha',
      relayDisplayName: '萌侠转发助手',
      relayAvatar: 'https://cdn.example.test/mx.png',
      createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
      updatedAt: DateTime.parse('2026-05-16T02:00:00Z'),
    );

    final decoded = MengxiaMonitorForwardingRoute.fromJson(route.toJson());

    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'mx-alpha');
    expect(decoded.targetGroupId, 'wk-alpha');
    expect(decoded.relayIdentity().provider, 'mengxia');
  });

  test('findRouteForEvent uses explicit source conversation id first', () {
    final route = _route(sourceConversationId: 'mx-alpha');

    final matched = findMengxiaMonitorRouteForEvent(
      routes: <MengxiaMonitorForwardingRoute>[route],
      event: _event(conversationId: 'mx-alpha', conversationName: 'Alpha'),
    );
    final differentId = findMengxiaMonitorRouteForEvent(
      routes: <MengxiaMonitorForwardingRoute>[route],
      event: _event(conversationId: 'mx-beta', conversationName: 'Alpha'),
    );

    expect(matched?.targetGroupId, 'wk-alpha');
    expect(differentId, isNull);
  });

  test('findRouteForEvent falls back to a unique source conversation name', () {
    final route = _route(
      sourceConversationId: 'source:nav:alpha',
      sourceConversationName: '藏龙岛',
    );

    final matched = findMengxiaMonitorRouteForEvent(
      routes: <MengxiaMonitorForwardingRoute>[route],
      event: _event(conversationId: '', conversationName: '藏龙岛'),
    );

    expect(matched?.targetGroupId, 'wk-alpha');
  });

  test('forwardRoutedRecentEvents sends only configured sources', () async {
    final sender = _RecordingSender();
    final service = MengxiaMonitorForwardingService(
      sender: sender,
      dedupeStore: _MemoryDedupeStore(),
    );
    final settings = MengxiaMonitorForwardingSettings(
      enabled: true,
      routes: <MengxiaMonitorForwardingRoute>[
        _route(sourceConversationId: 'mx-alpha', targetGroupId: 'wk-alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <MengxiaMonitorMessageEvent>[
        _event(conversationId: 'mx-alpha', text: 'send me'),
        _event(
          eventId: 'event-2',
          conversationId: 'mx-beta',
          text: 'do not send',
        ),
      ],
    );

    expect(result.sent, 1);
    expect(result.skippedUnmatched, 1);
    expect(sender.targetGroupIds, <String>['wk-alpha']);
    expect(sender.sentTexts, <String>['send me']);
    expect(sender.relayProviders, <String>['mengxia']);
  });

  test('forwardRoutedRecentEvents sends image attachments to configured route', () async {
    final sender = _RecordingSender();
    final service = MengxiaMonitorForwardingService(
      sender: sender,
      dedupeStore: _MemoryDedupeStore(),
    );
    final settings = MengxiaMonitorForwardingSettings(
      enabled: true,
      routes: <MengxiaMonitorForwardingRoute>[
        _route(sourceConversationId: 'mx-alpha', targetGroupId: 'wk-alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <MengxiaMonitorMessageEvent>[
        _event(
          conversationId: 'mx-alpha',
          messageType: 'image',
          text: '',
          imageAttachments: const <MengxiaMonitorImageAttachment>[
            MengxiaMonitorImageAttachment(
              sourceUrl: 'data:image/png;base64,iVBORw0KGgo=',
              localPath: '',
              width: 640,
              height: 480,
            ),
          ],
        ),
      ],
    );

    expect(result.sent, 1);
    expect(sender.sentTexts, isEmpty);
    expect(sender.sentImageUrls, <String>['data:image/png;base64,iVBORw0KGgo=']);
    expect(sender.targetGroupIds, <String>['wk-alpha']);
  });

  test('settings store uses Mengxia-specific key', () async {
    const store = SharedPreferencesMengxiaMonitorForwardingSettingsStore();
    final settings = MengxiaMonitorForwardingSettings(
      enabled: true,
      routes: <MengxiaMonitorForwardingRoute>[
        _route(sourceConversationId: 'mx-alpha', targetGroupId: 'wk-alpha'),
      ],
    );

    await store.save(settings);
    final loaded = await store.load();
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes.single.sourceConversationId, 'mx-alpha');
    expect(
      prefs.containsKey(mengxiaMonitorForwardingSettingsStorageKey),
      isTrue,
    );
  });
}

MengxiaMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'mx-alpha',
  String sourceConversationName = 'Alpha',
  String sourceConversationType = 'group',
  String targetGroupId = 'wk-alpha',
  String targetGroupName = 'WuKong Alpha',
}) {
  return MengxiaMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-16T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-16T01:00:00Z'),
  );
}

MengxiaMonitorMessageEvent _event({
  String eventId = 'event-1',
  String dedupeKey = '',
  String conversationId = 'mx-alpha',
  String conversationName = 'Alpha',
  String conversationType = 'group',
  String messageId = 'message-1',
  String senderName = 'Alice',
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
    conversationType: conversationType,
    messageId: messageId,
    senderId: '',
    senderName: senderName,
    messageType: messageType,
    text: text,
    sentAt: null,
    observedAt: DateTime.parse('2026-05-16T01:00:00Z'),
    captureSource: 'network_api',
    imageAttachments: imageAttachments,
  );
}

class _RecordingSender implements MengxiaMonitorMediaSender {
  final sentTexts = <String>[];
  final sentImageUrls = <String>[];
  final targetGroupIds = <String>[];
  final relayProviders = <String>[];

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    MengxiaMonitorRelayIdentity? relayIdentity,
  }) async {
    targetGroupIds.add(channelId);
    sentTexts.add(text);
    relayProviders.add(relayIdentity?.provider ?? '');
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required MengxiaMonitorImageAttachment image,
    MengxiaMonitorRelayIdentity? relayIdentity,
  }) async {
    targetGroupIds.add(channelId);
    sentImageUrls.add(image.sourceUrl);
    relayProviders.add(relayIdentity?.provider ?? '');
  }
}

class _MemoryDedupeStore implements MengxiaMonitorForwardingDedupeStore {
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
