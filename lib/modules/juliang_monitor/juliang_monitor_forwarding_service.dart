import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'juliang_monitor_shell_models.dart';

const String juliangMonitorDefaultRelayDisplayName = '聚合转发助手';
const int juliangMonitorForwardedMessageExpireSeconds =
    localMonitorForwardedMessageExpireSeconds;

typedef JuliangMonitorRelayIdentity = LocalMonitorRelayIdentity;
typedef JuliangMonitorForwardingDedupeStore =
    LocalMonitorForwardingDedupeStore;

abstract class JuliangMonitorTextSender implements LocalMonitorTextSender {}

class JuliangMonitorForwardingRoute {
  const JuliangMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.sourceConversationType,
    required this.targetGroupId,
    required this.targetGroupName,
    this.relayDisplayName = '',
    this.relayAvatar = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final bool enabled;
  final String sourceConversationId;
  final String sourceConversationName;
  final String sourceConversationType;
  final String targetGroupId;
  final String targetGroupName;
  final String relayDisplayName;
  final String relayAvatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory JuliangMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return JuliangMonitorForwardingRoute(
      id: (json['id'] ?? '').toString(),
      enabled: json['enabled'] == true,
      sourceConversationId:
          (json['source_conversation_id'] ?? json['sourceConversationId'] ?? '')
              .toString(),
      sourceConversationName:
          (json['source_conversation_name'] ??
                  json['sourceConversationName'] ??
                  '')
              .toString(),
      sourceConversationType:
          (json['source_conversation_type'] ??
                  json['sourceConversationType'] ??
                  '')
              .toString(),
      targetGroupId: (json['target_group_id'] ?? json['targetGroupId'] ?? '')
          .toString(),
      targetGroupName:
          (json['target_group_name'] ?? json['targetGroupName'] ?? '')
              .toString(),
      relayDisplayName:
          (json['relay_display_name'] ?? json['relayDisplayName'] ?? '')
              .toString(),
      relayAvatar: (json['relay_avatar'] ?? json['relayAvatar'] ?? '')
          .toString(),
      createdAt: _dateTimeFromJson(json['created_at'] ?? json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'enabled': enabled,
      'source_conversation_id': sourceConversationId,
      'source_conversation_name': sourceConversationName,
      'source_conversation_type': sourceConversationType,
      'target_group_id': targetGroupId,
      'target_group_name': targetGroupName,
      'relay_display_name': relayDisplayName,
      'relay_avatar': relayAvatar,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  JuliangMonitorRelayIdentity relayIdentity({
    String defaultDisplayName = juliangMonitorDefaultRelayDisplayName,
  }) {
    return JuliangMonitorRelayIdentity(
      provider: 'juliang',
      displayName: relayDisplayName.trim().isNotEmpty
          ? relayDisplayName.trim()
          : defaultDisplayName,
      avatar: relayAvatar.trim(),
    );
  }
}

class JuliangMonitorForwardingSettings {
  const JuliangMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <JuliangMonitorForwardingRoute>[],
  });

  final bool enabled;
  final List<JuliangMonitorForwardingRoute> routes;

  factory JuliangMonitorForwardingSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRoutes = json['routes'];
    return JuliangMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return JuliangMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return JuliangMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<JuliangMonitorForwardingRoute>()
                .toList(growable: false)
          : const <JuliangMonitorForwardingRoute>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
    };
  }

  JuliangMonitorForwardingSettings copyWith({
    bool? enabled,
    List<JuliangMonitorForwardingRoute>? routes,
  }) {
    return JuliangMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
    );
  }
}

abstract class JuliangMonitorForwardingSettingsStore {
  Future<JuliangMonitorForwardingSettings> load();
  Future<void> save(JuliangMonitorForwardingSettings settings);
}

class SharedPreferencesJuliangMonitorForwardingSettingsStore
    implements JuliangMonitorForwardingSettingsStore {
  const SharedPreferencesJuliangMonitorForwardingSettingsStore();

  static const String settingsKey = 'juliang_monitor_forwarding_settings_v1';

  @override
  Future<JuliangMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(settingsKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const JuliangMonitorForwardingSettings(enabled: false);
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return JuliangMonitorForwardingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return JuliangMonitorForwardingSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      return const JuliangMonitorForwardingSettings(enabled: false);
    } on TypeError {
      return const JuliangMonitorForwardingSettings(enabled: false);
    }
    return const JuliangMonitorForwardingSettings(enabled: false);
  }

  @override
  Future<void> save(JuliangMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }
}

class WkImJuliangMonitorTextSender implements JuliangMonitorTextSender {
  WkImJuliangMonitorTextSender() : _sender = WkImLocalMonitorTextSender();

  final LocalMonitorTextSender _sender;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    LocalMonitorRelayIdentity? relayIdentity,
  }) {
    return _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: text,
      relayIdentity: relayIdentity,
    );
  }
}

class JuliangMonitorForwardingResult {
  const JuliangMonitorForwardingResult({
    required this.sent,
    this.skippedDuplicate = 0,
    this.skippedUnmatched = 0,
    this.skippedDisabled = 0,
    required this.failed,
  });

  final int sent;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int failed;

  int get skipped => skippedDuplicate + skippedUnmatched + skippedDisabled;
}

class JuliangMonitorForwardingService {
  JuliangMonitorForwardingService({
    JuliangMonitorTextSender? sender,
    JuliangMonitorForwardingDedupeStore? dedupeStore,
  }) : _sender = sender ?? WkImJuliangMonitorTextSender(),
       _dedupeStore = dedupeStore;

  final JuliangMonitorTextSender _sender;
  final JuliangMonitorForwardingDedupeStore? _dedupeStore;
  final Set<String> _sentKeys = <String>{};
  bool _sentKeysLoaded = false;

  Future<JuliangMonitorForwardingResult> forwardRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {
    await _loadSentKeysIfNeeded();
    var sent = 0;
    var skippedDuplicate = 0;
    var skippedUnmatched = 0;
    var skippedDisabled = 0;
    var failed = 0;

    for (final event in events) {
      final route = findJuliangMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null || !event.isForwardableText) {
        skippedUnmatched += 1;
        continue;
      }
      if (!settings.enabled ||
          !route.enabled ||
          route.targetGroupId.trim().isEmpty) {
        skippedDisabled += 1;
        continue;
      }
      final dedupeKey = _eventDedupeKey(event);
      if (dedupeKey.isNotEmpty && _sentKeys.contains(dedupeKey)) {
        skippedDuplicate += 1;
        continue;
      }
      try {
        await _sender.sendText(
          channelId: route.targetGroupId.trim(),
          channelType: WKChannelType.group,
          channelName: route.targetGroupName.trim(),
          text: formatJuliangMonitorEventForForward(event),
          relayIdentity: route.relayIdentity(),
        );
        sent += 1;
        if (dedupeKey.isNotEmpty) {
          _sentKeys.add(dedupeKey);
        }
      } catch (_) {
        failed += 1;
      }
    }
    await _persistSentKeys();
    return JuliangMonitorForwardingResult(
      sent: sent,
      skippedDuplicate: skippedDuplicate,
      skippedUnmatched: skippedUnmatched,
      skippedDisabled: skippedDisabled,
      failed: failed,
    );
  }

  Future<void> primeRoutedRecentEvents({
    required JuliangMonitorForwardingSettings settings,
    required Iterable<JuliangMonitorMessageEvent> events,
  }) async {
    await _loadSentKeysIfNeeded();
    for (final event in events) {
      final route = findJuliangMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null || !event.isForwardableText) {
        continue;
      }
      final dedupeKey = _eventDedupeKey(event);
      if (dedupeKey.isNotEmpty) {
        _sentKeys.add(dedupeKey);
      }
    }
    await _persistSentKeys();
  }

  Future<void> _loadSentKeysIfNeeded() async {
    if (_sentKeysLoaded) {
      return;
    }
    _sentKeysLoaded = true;
    final keys = await _dedupeStore?.loadSentKeys();
    if (keys != null) {
      _sentKeys.addAll(keys);
    }
  }

  Future<void> _persistSentKeys() async {
    await _dedupeStore?.saveSentKeys(_sentKeys.toList(growable: false));
  }
}

JuliangMonitorForwardingRoute? findJuliangMonitorRouteForEvent({
  required Iterable<JuliangMonitorForwardingRoute> routes,
  required JuliangMonitorMessageEvent event,
}) {
  final eventConversationId = event.conversationId.trim();
  if (eventConversationId.isEmpty) {
    return null;
  }
  for (final route in routes) {
    if (route.sourceConversationId.trim() == eventConversationId) {
      return route;
    }
  }
  return null;
}

String formatJuliangMonitorEventForForward(JuliangMonitorMessageEvent event) {
  final sourceName = event.conversationName.trim().isNotEmpty
      ? event.conversationName.trim()
      : event.conversationId.trim();
  final sender = event.senderName.trim().isNotEmpty
      ? event.senderName.trim()
      : '未知发送者';
  return '[聚合转发] $sourceName\n$sender: ${event.text.trim()}';
}

String _eventDedupeKey(JuliangMonitorMessageEvent event) {
  return localMonitorMessageDedupeKey(
    dedupeKey: event.dedupeKey,
    eventId: event.eventId,
    messageId: event.messageId,
  );
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  return DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
