import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/juliang_monitor/juliang_monitor_shell_models.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('forwarding route round trips through json', () {
    final route = JuliangMonitorForwardingRoute(
      id: 'route_1',
      enabled: true,
      sourceConversationId: 'jl-alpha',
      sourceConversationName: 'Alpha',
      sourceConversationType: 'group',
      targetGroupId: 'wk_alpha',
      targetGroupName: 'WuKong Alpha',
      relayDisplayName: 'Custom Juliang Relay',
      relayAvatar: 'https://cdn.example.com/juliang.png',
      createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
      updatedAt: DateTime.parse('2026-05-17T02:00:00Z'),
    );

    final json = route.toJson();
    final decoded = JuliangMonitorForwardingRoute.fromJson(json);

    expect(json['source_conversation_id'], 'jl-alpha');
    expect(decoded.id, 'route_1');
    expect(decoded.enabled, isTrue);
    expect(decoded.sourceConversationId, 'jl-alpha');
    expect(decoded.sourceConversationName, 'Alpha');
    expect(decoded.sourceConversationType, 'group');
    expect(decoded.targetGroupId, 'wk_alpha');
    expect(decoded.targetGroupName, 'WuKong Alpha');
    expect(decoded.relayDisplayName, 'Custom Juliang Relay');
    expect(decoded.relayAvatar, 'https://cdn.example.com/juliang.png');
    expect(decoded.createdAt, DateTime.parse('2026-05-17T01:00:00Z'));
    expect(decoded.updatedAt, DateTime.parse('2026-05-17T02:00:00Z'));
  });

  test('forwarding settings default to disabled with no routes', () {
    final settings = JuliangMonitorForwardingSettings.fromJson(
      const <String, dynamic>{},
    );

    expect(settings.enabled, isFalse);
    expect(settings.routes, isEmpty);
    expect(settings.toJson(), <String, dynamic>{
      'enabled': false,
      'routes': <Object>[],
    });
  });

  test('route relay identity defaults to Juliang provider and display name', () {
    final identity = _route().relayIdentity();

    expect(identity.provider, 'juliang');
    expect(identity.displayName, '聚合转发助手');
    expect(identity.avatar, '');
  });

  test('settings store saves and loads isolated Juliang route list', () async {
    const store = SharedPreferencesJuliangMonitorForwardingSettingsStore();
    final settings = JuliangMonitorForwardingSettings(
      enabled: true,
      routes: <JuliangMonitorForwardingRoute>[
        _route(
          id: 'route_alpha',
          sourceConversationId: 'jl-alpha',
          targetGroupId: 'wk_alpha',
          targetGroupName: 'WuKong Alpha',
        ),
      ],
    );

    await store.save(settings);
    final loaded = await store.load();
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.enabled, isTrue);
    expect(loaded.routes, hasLength(1));
    expect(loaded.routes.single.sourceConversationId, 'jl-alpha');
    expect(loaded.routes.single.targetGroupId, 'wk_alpha');
    expect(
      prefs.getString('juliang_monitor_forwarding_settings_v1'),
      isNotNull,
    );
    expect(prefs.getString('feishu_monitor_forwarding_settings_v2'), isNull);
    expect(prefs.getString('dingtalk_monitor_forwarding_settings_v1'), isNull);
  });

  test('forwardRoutedRecentEvents sends matching text with header', () async {
    final sender = _RecordingSender();
    final service = JuliangMonitorForwardingService(sender: sender);
    final settings = JuliangMonitorForwardingSettings(
      enabled: true,
      routes: <JuliangMonitorForwardingRoute>[
        _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <JuliangMonitorMessageEvent>[
        _event(conversationId: 'jl-alpha', text: 'hello from aggregate'),
      ],
    );

    expect(result.sent, 1);
    expect(result.skippedDuplicate, 0);
    expect(result.skippedUnmatched, 0);
    expect(result.skippedDisabled, 0);
    expect(result.failed, 0);
    expect(sender.targetGroupIds, <String>['wk_alpha']);
    expect(sender.channelTypes, <int>[WKChannelType.group]);
    expect(sender.sentTexts.single, contains('[聚合转发] Alpha'));
    expect(sender.sentTexts.single, contains('Alice: hello from aggregate'));
    expect(sender.relayProviders, <String>['juliang']);
    expect(sender.relayDisplayNames, <String>['聚合转发助手']);
  });

  test('forwardRoutedRecentEvents skips duplicate events', () async {
    final sender = _RecordingSender();
    final service = JuliangMonitorForwardingService(sender: sender);
    final settings = JuliangMonitorForwardingSettings(
      enabled: true,
      routes: <JuliangMonitorForwardingRoute>[
        _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <JuliangMonitorMessageEvent>[
        _event(conversationId: 'jl-alpha', dedupeKey: 'same-key'),
        _event(conversationId: 'jl-alpha', dedupeKey: 'same-key'),
      ],
    );

    expect(result.sent, 1);
    expect(result.skippedDuplicate, 1);
    expect(sender.sentTexts, hasLength(1));
  });

  test(
    'forwardRoutedRecentEvents skips unmatched disabled and non-text events',
    () async {
      final sender = _RecordingSender();
      final service = JuliangMonitorForwardingService(sender: sender);
      final settings = JuliangMonitorForwardingSettings(
        enabled: true,
        routes: <JuliangMonitorForwardingRoute>[
          _route(sourceConversationId: 'jl-alpha', targetGroupId: 'wk_alpha'),
          _route(
            id: 'disabled',
            enabled: false,
            sourceConversationId: 'jl-disabled',
            targetGroupId: 'wk_disabled',
          ),
        ],
      );

      final result = await service.forwardRoutedRecentEvents(
        settings: settings,
        events: <JuliangMonitorMessageEvent>[
          _event(conversationId: 'jl-unmatched'),
          _event(conversationId: 'jl-disabled'),
          _event(
            conversationId: 'jl-alpha',
            messageId: 'image-1',
            messageType: 'image',
            text: '',
          ),
        ],
      );

      expect(result.sent, 0);
      expect(result.skippedDuplicate, 0);
      expect(result.skippedUnmatched, 2);
      expect(result.skippedDisabled, 1);
      expect(result.failed, 0);
      expect(sender.sentTexts, isEmpty);
    },
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
      observedAt: DateTime.parse('2026-05-17T01:00:00Z'),
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
  String relayDisplayName = '',
  String relayAvatar = '',
}) {
  return JuliangMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    relayDisplayName: relayDisplayName,
    relayAvatar: relayAvatar,
    createdAt: DateTime.parse('2026-05-17T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-17T02:00:00Z'),
  );
}

class _RecordingSender implements JuliangMonitorTextSender {
  final targetGroupIds = <String>[];
  final channelTypes = <int>[];
  final sentTexts = <String>[];
  final relayProviders = <String>[];
  final relayDisplayNames = <String>[];

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    targetGroupIds.add(channelId);
    channelTypes.add(channelType);
    sentTexts.add(text);
    relayProviders.add(relayIdentity?.provider ?? '');
    relayDisplayNames.add(relayIdentity?.displayName ?? '');
  }
}
