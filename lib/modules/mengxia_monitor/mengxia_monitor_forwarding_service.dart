import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart'
    show FeishuMonitorImageUploader, prepareFeishuMonitorImageForWkUpload;
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart'
    show FeishuMonitorImageAttachment;
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'mengxia_monitor_shell_models.dart';

const String mengxiaMonitorForwardingSettingsStorageKey =
    'mengxia_monitor_forwarding_settings_v1';
const String mengxiaMonitorForwardedDedupeStorageKey =
    'mengxia_monitor_forwarded_dedupe_keys_v1';

class MengxiaMonitorForwardingRoute {
  const MengxiaMonitorForwardingRoute({
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

  factory MengxiaMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return MengxiaMonitorForwardingRoute(
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

  MengxiaMonitorForwardingRoute copyWith({
    bool? enabled,
    String? targetGroupId,
    String? targetGroupName,
    String? relayDisplayName,
    String? relayAvatar,
    DateTime? updatedAt,
  }) {
    return MengxiaMonitorForwardingRoute(
      id: id,
      enabled: enabled ?? this.enabled,
      sourceConversationId: sourceConversationId,
      sourceConversationName: sourceConversationName,
      sourceConversationType: sourceConversationType,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
      relayDisplayName: relayDisplayName ?? this.relayDisplayName,
      relayAvatar: relayAvatar ?? this.relayAvatar,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  MengxiaMonitorRelayIdentity relayIdentity({
    String defaultDisplayName = '萌侠转发助手',
  }) {
    return MengxiaMonitorRelayIdentity(
      provider: 'mengxia',
      displayName: relayDisplayName.trim().isNotEmpty
          ? relayDisplayName.trim()
          : defaultDisplayName,
      avatar: relayAvatar.trim(),
    );
  }
}

class MengxiaMonitorForwardingSettings {
  const MengxiaMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <MengxiaMonitorForwardingRoute>[],
  });

  final bool enabled;
  final List<MengxiaMonitorForwardingRoute> routes;

  factory MengxiaMonitorForwardingSettings.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    return MengxiaMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return MengxiaMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return MengxiaMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<MengxiaMonitorForwardingRoute>()
                .toList(growable: false)
          : const <MengxiaMonitorForwardingRoute>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
    };
  }

  MengxiaMonitorForwardingSettings copyWith({
    bool? enabled,
    List<MengxiaMonitorForwardingRoute>? routes,
  }) {
    return MengxiaMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
    );
  }
}

class MengxiaMonitorForwardingResult {
  const MengxiaMonitorForwardingResult({
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

typedef MengxiaMonitorRelayIdentity = LocalMonitorRelayIdentity;
typedef MengxiaMonitorForwardingDedupeStore = LocalMonitorForwardingDedupeStore;

abstract class MengxiaMonitorTextSender implements LocalMonitorTextSender {}

abstract class MengxiaMonitorMediaSender
    implements MengxiaMonitorTextSender {
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required MengxiaMonitorImageAttachment image,
    MengxiaMonitorRelayIdentity? relayIdentity,
  });
}

class WkImMengxiaMonitorTextSender implements MengxiaMonitorTextSender {
  WkImMengxiaMonitorTextSender({ChatSceneGateway? gateway})
    : _sender = WkImLocalMonitorTextSender(gateway: gateway);

  final LocalMonitorTextSender _sender;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    MengxiaMonitorRelayIdentity? relayIdentity,
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

class WkImMengxiaMonitorMediaSender implements MengxiaMonitorMediaSender {
  WkImMengxiaMonitorMediaSender({
    ChatSceneGateway? gateway,
    LocalMonitorImagePreparer? prepareImage,
    FeishuMonitorImageUploader? uploadImage,
  }) : _textSender = WkImLocalMonitorTextSender(gateway: gateway),
       _imageSender = WkImLocalMonitorImageSender(
         gateway: gateway,
         prepareImage: prepareImage ?? _prepareMengxiaMonitorImageForWkUpload,
         uploadImage: uploadImage ?? _uploadMengxiaMonitorImageForWk,
       );

  final LocalMonitorTextSender _textSender;
  final LocalMonitorImageSender _imageSender;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    MengxiaMonitorRelayIdentity? relayIdentity,
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
    required MengxiaMonitorImageAttachment image,
    MengxiaMonitorRelayIdentity? relayIdentity,
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

class SharedPreferencesMengxiaMonitorForwardingDedupeStore
    implements MengxiaMonitorForwardingDedupeStore {
  const SharedPreferencesMengxiaMonitorForwardingDedupeStore();

  @override
  Future<List<String>> loadSentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(mengxiaMonitorForwardedDedupeStorageKey) ??
        const <String>[];
  }

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(mengxiaMonitorForwardedDedupeStorageKey, keys);
  }
}

abstract class MengxiaMonitorForwardingSettingsStore {
  Future<MengxiaMonitorForwardingSettings> load();
  Future<void> save(MengxiaMonitorForwardingSettings settings);
}

class SharedPreferencesMengxiaMonitorForwardingSettingsStore
    implements MengxiaMonitorForwardingSettingsStore {
  const SharedPreferencesMengxiaMonitorForwardingSettingsStore();

  @override
  Future<MengxiaMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(mengxiaMonitorForwardingSettingsStorageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const MengxiaMonitorForwardingSettings(enabled: false);
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return MengxiaMonitorForwardingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return MengxiaMonitorForwardingSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      return const MengxiaMonitorForwardingSettings(enabled: false);
    } on TypeError {
      return const MengxiaMonitorForwardingSettings(enabled: false);
    }
    return const MengxiaMonitorForwardingSettings(enabled: false);
  }

  @override
  Future<void> save(MengxiaMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      mengxiaMonitorForwardingSettingsStorageKey,
      jsonEncode(settings.toJson()),
    );
  }
}

class MengxiaMonitorForwardingService {
  MengxiaMonitorForwardingService({
    MengxiaMonitorMediaSender? sender,
    MengxiaMonitorForwardingDedupeStore? dedupeStore,
  }) : _sender = sender ?? WkImMengxiaMonitorMediaSender(),
       _dedupeStore =
           dedupeStore ??
           const SharedPreferencesMengxiaMonitorForwardingDedupeStore();

  final MengxiaMonitorMediaSender _sender;
  final MengxiaMonitorForwardingDedupeStore _dedupeStore;
  final Set<String> _sentKeys = <String>{};
  static final Set<String> _inFlightKeys = <String>{};
  static const int _maxPersistedSentKeys = 500;

  Future<void> primeRoutedRecentEvents({
    required MengxiaMonitorForwardingSettings settings,
    required List<MengxiaMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled || events.isEmpty) {
      return;
    }
    await _loadPersistedSentKeys();
    var changed = false;
    for (final event in events) {
      final route = findMengxiaMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null ||
          !route.enabled ||
          route.targetGroupId.trim().isEmpty ||
          !event.isForwardable) {
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

  Future<MengxiaMonitorForwardingResult> forwardRoutedRecentEvents({
    required MengxiaMonitorForwardingSettings settings,
    required List<MengxiaMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled) {
      return MengxiaMonitorForwardingResult(
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

    await _loadPersistedSentKeys();
    for (final event in events) {
      final route = findMengxiaMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null) {
        skippedUnmatched += 1;
        continue;
      }

      final targetGroupId = route.targetGroupId.trim();
      if (!route.enabled || targetGroupId.isEmpty) {
        skippedDisabled += 1;
        continue;
      }
      if (!event.isForwardable) {
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
      } catch (_) {
        failed += 1;
      } finally {
        _releaseInFlightKey(key);
      }
    }

    return MengxiaMonitorForwardingResult(
      sent: sent,
      skippedDuplicate: skippedDuplicate,
      skippedUnmatched: skippedUnmatched,
      skippedDisabled: skippedDisabled,
      failed: failed,
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

  Future<void> _persistSentKeys() {
    final keys = _sentKeys.toList(growable: false);
    final capped = keys.length <= _maxPersistedSentKeys
        ? keys
        : keys.sublist(keys.length - _maxPersistedSentKeys);
    return _dedupeStore.saveSentKeys(capped);
  }

  Future<void> _sendEventToTarget({
    required MengxiaMonitorMessageEvent event,
    required String channelId,
    required int channelType,
    required String channelName,
    MengxiaMonitorRelayIdentity? relayIdentity,
  }) async {
    final image = _firstUsableImageAttachment(event);
    if (image != null) {
      await _sender.sendImage(
        channelId: channelId,
        channelType: channelType,
        channelName: channelName,
        image: image,
        relayIdentity: relayIdentity,
      );
      return;
    }
    await _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: formatMengxiaMonitorEventForForward(event),
      relayIdentity: relayIdentity,
    );
  }

  MengxiaMonitorImageAttachment? _firstUsableImageAttachment(
    MengxiaMonitorMessageEvent event,
  ) {
    for (final image in event.imageAttachments) {
      if (image.hasUsableSource) {
        return image;
      }
    }
    return null;
  }
}

MengxiaMonitorForwardingRoute? findMengxiaMonitorRouteForEvent({
  required List<MengxiaMonitorForwardingRoute> routes,
  required MengxiaMonitorMessageEvent event,
}) {
  final conversationId = event.conversationId.trim();
  if (conversationId.isNotEmpty) {
    final idMatches = routes
        .where(
          (route) =>
              route.enabled &&
              route.targetGroupId.trim().isNotEmpty &&
              route.sourceConversationId.trim() == conversationId,
        )
        .toList(growable: false);
    if (idMatches.length == 1) {
      return idMatches.single;
    }
    if (idMatches.isNotEmpty) {
      return null;
    }
  }

  final allowsNameFallback =
      conversationId.isEmpty || conversationId.startsWith('fallback:');
  if (!allowsNameFallback) {
    return null;
  }

  final conversationName = event.conversationName.trim();
  if (conversationName.isEmpty) {
    return null;
  }
  final nameMatches = routes
      .where(
        (route) =>
            route.enabled &&
            route.targetGroupId.trim().isNotEmpty &&
            route.sourceConversationName.trim() == conversationName,
      )
      .toList(growable: false);
  return nameMatches.length == 1 ? nameMatches.single : null;
}

String formatMengxiaMonitorEventForForward(MengxiaMonitorMessageEvent event) {
  final text = event.text.trim();
  return text.isEmpty ? '(空消息)' : text;
}

String _eventDedupeKey(MengxiaMonitorMessageEvent event) {
  final normalizedDedupeKey = event.dedupeKey.trim();
  if (normalizedDedupeKey.isNotEmpty) {
    return 'mengxia:dedupe:$normalizedDedupeKey';
  }
  final eventId = event.eventId.trim();
  if (eventId.isNotEmpty) {
    return 'mengxia:event:$eventId';
  }
  final sourceScope = event.conversationId.trim();
  final body = '${event.messageId}\n${event.senderName}\n${event.text}'.trim();
  if (sourceScope.isEmpty || body.isEmpty) {
    return '';
  }
  return 'mengxia:$sourceScope:'
      '${crypto.sha1.convert(utf8.encode(body)).toString()}';
}

Future<LocalMonitorForwardableImage> _prepareMengxiaMonitorImageForWkUpload(
  LocalMonitorForwardableImage image,
) async {
  final prepared = await prepareFeishuMonitorImageForWkUpload(
    FeishuMonitorImageAttachment(
      sourceUrl: image.sourceUrl,
      localPath: image.localPath,
      width: image.width,
      height: image.height,
    ),
  );
  return LocalMonitorForwardableImage(
    sourceUrl: prepared.sourceUrl,
    localPath: prepared.localPath,
    width: prepared.width,
    height: prepared.height,
  );
}

Future<String> _uploadMengxiaMonitorImageForWk({
  required String filePath,
  required String channelId,
  required int channelType,
}) {
  return FileApi.instance.uploadChatFileAtPath(
    filePath: filePath,
    uploadPath: '/mengxia-monitor/$channelType/'
        '${_safeMengxiaMonitorObjectPathSegment(channelId)}/'
        '${DateTime.now().toUtc().millisecondsSinceEpoch}'
        '${_safeMengxiaMonitorImageExtension(filePath)}',
  );
}

String _safeMengxiaMonitorImageExtension(String filePath) {
  final dotIndex = filePath.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == filePath.length - 1) {
    return '.dat';
  }
  final extension = filePath.substring(dotIndex).toLowerCase();
  if (RegExp(r'^\.[a-z0-9]{1,16}$').hasMatch(extension)) {
    return extension;
  }
  return '.dat';
}

String _safeMengxiaMonitorObjectPathSegment(String value) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'[\\/]+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceFirst(RegExp(r'^[._-]+'), '')
      .replaceFirst(RegExp(r'[._-]+$'), '');
  return normalized.isEmpty ? 'channel' : normalized;
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  final raw = value?.toString().trim() ?? '';
  return DateTime.tryParse(raw)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
