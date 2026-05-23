import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'dingtalk_monitor_shell_models.dart';

const int dingtalkMonitorForwardedMessageExpireSeconds =
    localMonitorForwardedMessageExpireSeconds;

class DingTalkMonitorForwardingRoute {
  const DingTalkMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    this.embeddedSourceName = '',
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
  final String embeddedSourceName;
  final String targetGroupId;
  final String targetGroupName;
  final String relayDisplayName;
  final String relayAvatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DingTalkMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return DingTalkMonitorForwardingRoute(
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
      embeddedSourceName:
          (json['embedded_source_name'] ?? json['embeddedSourceName'] ?? '')
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
      'embedded_source_name': embeddedSourceName,
      'target_group_id': targetGroupId,
      'target_group_name': targetGroupName,
      'relay_display_name': relayDisplayName,
      'relay_avatar': relayAvatar,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  DingTalkMonitorForwardingRoute copyWith({
    bool? enabled,
    String? targetGroupId,
    String? targetGroupName,
    String? relayDisplayName,
    String? relayAvatar,
    DateTime? updatedAt,
  }) {
    return DingTalkMonitorForwardingRoute(
      id: id,
      enabled: enabled ?? this.enabled,
      sourceConversationId: sourceConversationId,
      sourceConversationName: sourceConversationName,
      embeddedSourceName: embeddedSourceName,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
      relayDisplayName: relayDisplayName ?? this.relayDisplayName,
      relayAvatar: relayAvatar ?? this.relayAvatar,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DingTalkMonitorRelayIdentity relayIdentity({
    String defaultDisplayName = '钉钉转发助手',
  }) {
    return DingTalkMonitorRelayIdentity(
      provider: 'dingtalk',
      displayName: relayDisplayName.trim().isNotEmpty
          ? relayDisplayName.trim()
          : defaultDisplayName,
      avatar: relayAvatar.trim(),
    );
  }
}

class DingTalkMonitorForwardingSettings {
  const DingTalkMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <DingTalkMonitorForwardingRoute>[],
  });

  final bool enabled;
  final List<DingTalkMonitorForwardingRoute> routes;

  factory DingTalkMonitorForwardingSettings.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRoutes = json['routes'];
    return DingTalkMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return DingTalkMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return DingTalkMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<DingTalkMonitorForwardingRoute>()
                .toList(growable: false)
          : const <DingTalkMonitorForwardingRoute>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
    };
  }

  DingTalkMonitorForwardingSettings copyWith({
    bool? enabled,
    List<DingTalkMonitorForwardingRoute>? routes,
  }) {
    return DingTalkMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
    );
  }
}

class DingTalkMonitorForwardingResult {
  const DingTalkMonitorForwardingResult({
    required this.sent,
    this.skippedDuplicate = 0,
    this.skippedUnmatched = 0,
    this.skippedDisabled = 0,
    required this.failed,
    this.lastErrorType = '',
    this.lastErrorMessageLength = 0,
  });

  final int sent;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int failed;
  final String lastErrorType;
  final int lastErrorMessageLength;

  int get skipped => skippedDuplicate + skippedUnmatched + skippedDisabled;
}

typedef DingTalkMonitorRelayIdentity = LocalMonitorRelayIdentity;

typedef DingTalkMonitorForwardingDedupeStore =
    LocalMonitorForwardingDedupeStore;

abstract class DingTalkMonitorTextSender implements LocalMonitorTextSender {
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    DingTalkMonitorRelayIdentity? relayIdentity,
  });
}

class WkImDingTalkMonitorTextSender implements DingTalkMonitorTextSender {
  WkImDingTalkMonitorTextSender({ChatSceneGateway? gateway})
    : _textSender = WkImLocalMonitorTextSender(gateway: gateway),
      _imageSender = WkImLocalMonitorImageSender(
        gateway: gateway,
        prepareImage: _identityDingTalkMonitorImagePreparer,
        uploadImage: _uploadDingTalkMonitorImageForWk,
      );

  final LocalMonitorTextSender _textSender;
  final LocalMonitorImageSender _imageSender;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) {
    return _textSender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: text,
      relayIdentity: relayIdentity,
    );
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) {
    return _imageSender.sendImage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      image: image,
      relayIdentity: relayIdentity,
    );
  }
}

Future<LocalMonitorForwardableImage> _identityDingTalkMonitorImagePreparer(
  LocalMonitorForwardableImage image,
) async {
  return image;
}

Future<String> _uploadDingTalkMonitorImageForWk({
  required String filePath,
  required String channelId,
  required int channelType,
}) {
  return FileApi.instance.uploadChatFile(
    filePath: filePath,
    channelId: channelId,
    channelType: channelType,
  );
}

class SharedPreferencesDingTalkMonitorForwardingDedupeStore
    implements DingTalkMonitorForwardingDedupeStore {
  const SharedPreferencesDingTalkMonitorForwardingDedupeStore();

  static const String _sentKeysKey =
      'dingtalk_monitor_forwarded_dedupe_keys_v1';

  @override
  Future<List<String>> loadSentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_sentKeysKey) ?? const <String>[];
  }

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sentKeysKey, keys);
  }
}

abstract class DingTalkMonitorForwardingSettingsStore {
  Future<DingTalkMonitorForwardingSettings> load();
  Future<void> save(DingTalkMonitorForwardingSettings settings);
}

class SharedPreferencesDingTalkMonitorForwardingSettingsStore
    implements DingTalkMonitorForwardingSettingsStore {
  const SharedPreferencesDingTalkMonitorForwardingSettingsStore();

  static const String _settingsKey = 'dingtalk_monitor_forwarding_settings_v1';
  static const String _legacySettingsKey = 'dingtalk_monitor_settings_v1';

  @override
  Future<DingTalkMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_settingsKey);
    final fromLegacy = encoded == null;
    final effectiveEncoded = encoded ?? prefs.getString(_legacySettingsKey);
    if (effectiveEncoded == null || effectiveEncoded.trim().isEmpty) {
      return const DingTalkMonitorForwardingSettings(enabled: false);
    }
    try {
      final decoded = jsonDecode(effectiveEncoded);
      if (decoded is Map<String, dynamic>) {
        return _normalizeLoadedSettings(
          DingTalkMonitorForwardingSettings.fromJson(decoded),
          fromLegacy: fromLegacy,
        );
      }
      if (decoded is Map) {
        return _normalizeLoadedSettings(
          DingTalkMonitorForwardingSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
          fromLegacy: fromLegacy,
        );
      }
    } on FormatException {
      return const DingTalkMonitorForwardingSettings(enabled: false);
    } on TypeError {
      return const DingTalkMonitorForwardingSettings(enabled: false);
    }
    return const DingTalkMonitorForwardingSettings(enabled: false);
  }

  @override
  Future<void> save(DingTalkMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}

DingTalkMonitorForwardingSettings _normalizeLoadedSettings(
  DingTalkMonitorForwardingSettings settings, {
  required bool fromLegacy,
}) {
  return fromLegacy ? settings.copyWith(enabled: false) : settings;
}

class DingTalkMonitorForwardingService {
  DingTalkMonitorForwardingService({
    DingTalkMonitorTextSender? sender,
    DingTalkMonitorForwardingDedupeStore? dedupeStore,
  }) : _sender = sender ?? WkImDingTalkMonitorTextSender(),
       _dedupeStore =
           dedupeStore ??
           const SharedPreferencesDingTalkMonitorForwardingDedupeStore();

  final DingTalkMonitorTextSender _sender;
  final DingTalkMonitorForwardingDedupeStore _dedupeStore;
  final Set<String> _sentKeys = <String>{};
  static final Set<String> _inFlightKeys = <String>{};
  static const int _maxPersistedSentKeys = 500;

  Future<void> primeRoutedRecentEvents({
    required DingTalkMonitorForwardingSettings settings,
    required List<DingTalkMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled || events.isEmpty) {
      return;
    }
    await _loadPersistedSentKeys();
    var changed = false;
    for (final event in events) {
      final route = findDingTalkMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null ||
          !route.enabled ||
          route.targetGroupId.trim().isEmpty ||
          !event.isForwardablePayload ||
          !_hasExplicitRouteSourceMatch(route, event)) {
        continue;
      }
      final key = _eventDedupeKey(event);
      if (key.isNotEmpty) {
        changed = _sentKeys.add(key) || changed;
      }
    }
    if (changed) {
      await _persistSentKeys();
    }
  }

  Future<DingTalkMonitorForwardingResult> forwardRoutedRecentEvents({
    required DingTalkMonitorForwardingSettings settings,
    required List<DingTalkMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled) {
      return DingTalkMonitorForwardingResult(
        sent: 0,
        skippedDisabled: events.length,
        failed: 0,
      );
    }

    var sent = 0;
    var skippedDuplicate = 0;
    var skippedUnmatched = 0;
    var skippedDisabled = 0;
    var failed = 0;
    var lastErrorType = '';
    var lastErrorMessageLength = 0;

    await _loadPersistedSentKeys();
    for (final event in events) {
      final route = findDingTalkMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null) {
        final candidate = _findDingTalkMonitorRouteCandidateForEvent(
          routes: settings.routes,
          event: event,
        );
        if (candidate == null) {
          skippedUnmatched += 1;
        } else {
          skippedDisabled += 1;
        }
        continue;
      }

      final targetGroupId = route.targetGroupId.trim();
      if (!route.enabled || targetGroupId.isEmpty) {
        skippedDisabled += 1;
        continue;
      }
      if (!event.isForwardablePayload ||
          !_hasAllowedRouteSourceMatch(settings.routes, route, event)) {
        skippedDuplicate += 1;
        continue;
      }

      final key = _eventDedupeKey(event);
      if (key.isEmpty || _sentKeys.contains(key)) {
        skippedDuplicate += 1;
        continue;
      }
      if (!_tryAcquireInFlightKey(key)) {
        skippedDuplicate += 1;
        continue;
      }

      try {
        await _sendEventToTarget(
          event: event,
          channelId: targetGroupId,
          channelType: WKChannelType.group,
          channelName: route.targetGroupName,
          relayIdentity: route.relayIdentity(),
        );
        _sentKeys.add(key);
        await _persistSentKeys();
        sent += 1;
      } catch (error) {
        failed += 1;
        lastErrorType = error.runtimeType.toString();
        lastErrorMessageLength = error.toString().length;
      } finally {
        _releaseInFlightKey(key);
      }
    }

    return DingTalkMonitorForwardingResult(
      sent: sent,
      skippedDuplicate: skippedDuplicate,
      skippedUnmatched: skippedUnmatched,
      skippedDisabled: skippedDisabled,
      failed: failed,
      lastErrorType: lastErrorType,
      lastErrorMessageLength: lastErrorMessageLength,
    );
  }

  Future<void> _loadPersistedSentKeys() async {
    _sentKeys.addAll(await _dedupeStore.loadSentKeys());
  }

  bool _tryAcquireInFlightKey(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return true;
    }
    return _inFlightKeys.add(normalized);
  }

  void _releaseInFlightKey(String key) {
    final normalized = key.trim();
    if (normalized.isNotEmpty) {
      _inFlightKeys.remove(normalized);
    }
  }

  Future<void> _sendEventToTarget({
    required DingTalkMonitorMessageEvent event,
    required String channelId,
    required int channelType,
    required String channelName,
    DingTalkMonitorRelayIdentity? relayIdentity,
  }) {
    final image = _forwardableImageForEvent(event);
    if (image != null) {
      return _sender.sendImage(
        channelId: channelId,
        channelType: channelType,
        channelName: channelName,
        image: image,
        relayIdentity: relayIdentity,
      );
    }
    return _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: formatDingTalkMonitorEventForForward(event),
      relayIdentity: relayIdentity,
    );
  }

  Future<void> _persistSentKeys() {
    final keys = _sentKeys.toList(growable: false);
    final capped = keys.length <= _maxPersistedSentKeys
        ? keys
        : keys.sublist(keys.length - _maxPersistedSentKeys);
    return _dedupeStore.saveSentKeys(capped);
  }
}

LocalMonitorForwardableImage? _forwardableImageForEvent(
  DingTalkMonitorMessageEvent event,
) {
  if (!event.isForwardableImage) {
    return null;
  }
  return LocalMonitorForwardableImage(
    sourceUrl: '',
    localPath: event.localImagePath.trim(),
    width: 0,
    height: 0,
  );
}

DingTalkMonitorForwardingRoute? findDingTalkMonitorRouteForEvent({
  required List<DingTalkMonitorForwardingRoute> routes,
  required DingTalkMonitorMessageEvent event,
}) {
  final eligible = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final byId = _findRouteByConversationId(eligible, event);
  if (byId != null) {
    return byId;
  }
  final byEmbedded = _findRouteByEmbeddedName(eligible, event);
  if (byEmbedded != null) {
    return byEmbedded;
  }
  final activeChatFallback = _findSingleRouteForActiveChatEvent(
    eligible,
    event,
  );
  if (activeChatFallback != null) {
    return activeChatFallback;
  }
  if (event.sourceConversationId.trim().isNotEmpty) {
    return null;
  }
  return _findRouteByConversationName(eligible, event);
}

DingTalkMonitorForwardingRoute? _findDingTalkMonitorRouteCandidateForEvent({
  required List<DingTalkMonitorForwardingRoute> routes,
  required DingTalkMonitorMessageEvent event,
}) {
  final byId = _findRouteByConversationId(routes, event);
  if (byId != null || event.sourceConversationId.trim().isNotEmpty) {
    return byId;
  }
  return _findRouteByEmbeddedName(routes, event) ??
      _findRouteByConversationName(routes, event);
}

DingTalkMonitorForwardingRoute? _findRouteByConversationId(
  List<DingTalkMonitorForwardingRoute> routes,
  DingTalkMonitorMessageEvent event,
) {
  final sourceId = event.sourceConversationId.trim();
  if (sourceId.isEmpty) {
    return null;
  }
  final matches = routes
      .where((route) => route.sourceConversationId.trim() == sourceId)
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

bool _hasExplicitRouteSourceMatch(
  DingTalkMonitorForwardingRoute route,
  DingTalkMonitorMessageEvent event,
) {
  final routeSourceId = route.sourceConversationId.trim();
  return routeSourceId.isNotEmpty &&
      routeSourceId == event.sourceConversationId.trim();
}

bool _hasAllowedRouteSourceMatch(
  List<DingTalkMonitorForwardingRoute> routes,
  DingTalkMonitorForwardingRoute route,
  DingTalkMonitorMessageEvent event,
) {
  return _hasExplicitRouteSourceMatch(route, event) ||
      _findSingleRouteForActiveChatEvent(routes, event) == route;
}

DingTalkMonitorForwardingRoute? _findSingleRouteForActiveChatEvent(
  List<DingTalkMonitorForwardingRoute> routes,
  DingTalkMonitorMessageEvent event,
) {
  if (!_isActiveChatStructuredEvent(event)) {
    return null;
  }
  final eligible = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  return eligible.length == 1 ? eligible.single : null;
}

bool _isActiveChatStructuredEvent(DingTalkMonitorMessageEvent event) {
  return event.captureSource == DingTalkMonitorCaptureSource.uiaText &&
      event.sourceConversationId.trim().toLowerCase() ==
          'windows:clipboard-active';
}

DingTalkMonitorForwardingRoute? _findRouteByEmbeddedName(
  List<DingTalkMonitorForwardingRoute> routes,
  DingTalkMonitorMessageEvent event,
) {
  final embeddedName = normalizeDingTalkMonitorRouteName(
    event.embeddedSourceName,
  );
  if (embeddedName.isEmpty) {
    return null;
  }
  final matches = routes
      .where(
        (route) =>
            normalizeDingTalkMonitorRouteName(route.embeddedSourceName) ==
            embeddedName,
      )
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

DingTalkMonitorForwardingRoute? _findRouteByConversationName(
  List<DingTalkMonitorForwardingRoute> routes,
  DingTalkMonitorMessageEvent event,
) {
  final sourceName = normalizeDingTalkMonitorRouteName(
    event.sourceConversationName,
  );
  if (sourceName.isEmpty) {
    return null;
  }
  final matches = routes
      .where(
        (route) =>
            normalizeDingTalkMonitorRouteName(route.sourceConversationName) ==
            sourceName,
      )
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

String formatDingTalkMonitorEventForForward(DingTalkMonitorMessageEvent event) {
  final text = event.text.trim();
  return text.isEmpty ? '(空消息)' : text;
}

String normalizeDingTalkMonitorRouteName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _eventDedupeKey(DingTalkMonitorMessageEvent event) {
  final sourceScope = event.sourceConversationId.trim().isNotEmpty
      ? event.sourceConversationId.trim()
      : normalizeDingTalkMonitorRouteName(event.sourceConversationName);
  final contentHash = event.contentHash.trim();
  if (sourceScope.isNotEmpty && contentHash.isNotEmpty) {
    final sourceHash = crypto.sha1.convert(utf8.encode(sourceScope)).toString();
    final senderScope = event.senderName.trim().isNotEmpty
        ? event.senderName.trim()
        : 'unknown-sender';
    final senderHash = crypto.sha1.convert(utf8.encode(senderScope)).toString();
    return 'dingtalk:content:$sourceHash:$senderHash:$contentHash';
  }

  final eventId = event.eventId.trim();
  if (eventId.isNotEmpty) {
    return 'dingtalk:event:$eventId';
  }
  final body = '${event.senderName}\n${event.text}'.trim();
  if (sourceScope.isEmpty || body.isEmpty) {
    return '';
  }
  return 'dingtalk:$sourceScope:'
      '${crypto.sha1.convert(utf8.encode(body)).toString()}';
}

DateTime _dateTimeFromJson(Object? value) {
  return dingTalkMonitorDateTime(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
