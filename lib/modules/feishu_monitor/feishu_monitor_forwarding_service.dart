import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'feishu_monitor_shell_models.dart';

class FeishuMonitorForwardingRoute {
  const FeishuMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.sourceConversationType,
    required this.targetGroupId,
    required this.targetGroupName,
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
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeishuMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorForwardingRoute(
      id: (json['id'] as String?) ?? '',
      enabled: (json['enabled'] as bool?) ?? false,
      sourceConversationId: (json['source_conversation_id'] as String?) ?? '',
      sourceConversationName:
          (json['source_conversation_name'] as String?) ?? '',
      sourceConversationType:
          (json['source_conversation_type'] as String?) ?? '',
      targetGroupId: (json['target_group_id'] as String?) ?? '',
      targetGroupName: (json['target_group_name'] as String?) ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
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
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  FeishuMonitorForwardingRoute copyWith({
    bool? enabled,
    String? targetGroupId,
    String? targetGroupName,
    DateTime? updatedAt,
  }) {
    return FeishuMonitorForwardingRoute(
      id: id,
      enabled: enabled ?? this.enabled,
      sourceConversationId: sourceConversationId,
      sourceConversationName: sourceConversationName,
      sourceConversationType: sourceConversationType,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  FeishuMonitorForwardingRule toSingleTargetRule() {
    return FeishuMonitorForwardingRule(
      enabled: enabled,
      targetGroupId: targetGroupId,
      targetGroupName: targetGroupName,
    );
  }
}

class FeishuMonitorForwardingRule {
  const FeishuMonitorForwardingRule({
    required this.enabled,
    required this.targetGroupId,
    this.targetGroupName = '',
    this.targetChannelType = WKChannelType.group,
  });

  final bool enabled;
  final String targetGroupId;
  final String targetGroupName;
  final int targetChannelType;
}

class FeishuMonitorForwardingResult {
  const FeishuMonitorForwardingResult({
    required this.sent,
    int? skipped,
    this.skippedDuplicate = 0,
    this.skippedUnmatched = 0,
    this.skippedDisabled = 0,
    required this.failed,
  }) : _legacySkipped = skipped;

  final int sent;
  final int? _legacySkipped;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int failed;

  int get skipped =>
      _legacySkipped ?? skippedDuplicate + skippedUnmatched + skippedDisabled;
}

abstract class FeishuMonitorTextSender {
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
  });

  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
  });
}

abstract class FeishuMonitorForwardingDedupeStore {
  Future<List<String>> loadSentKeys();
  Future<void> saveSentKeys(List<String> keys);
}

typedef FeishuMonitorImagePreparer =
    Future<FeishuMonitorImageAttachment> Function(
      FeishuMonitorImageAttachment image,
    );
typedef FeishuMonitorImageUploader =
    Future<String> Function({
      required String filePath,
      required String channelId,
      required int channelType,
    });

class SharedPreferencesFeishuMonitorForwardingDedupeStore
    implements FeishuMonitorForwardingDedupeStore {
  const SharedPreferencesFeishuMonitorForwardingDedupeStore();

  static const String _sentKeysKey = 'feishu_monitor_forwarded_dedupe_keys_v1';

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

class WkImFeishuMonitorTextSender implements FeishuMonitorTextSender {
  WkImFeishuMonitorTextSender({
    ChatSceneGateway? gateway,
    FeishuMonitorImagePreparer? prepareImage,
    FeishuMonitorImageUploader? uploadImage,
  }) : _gateway = gateway ?? ApiChatSceneGateway(),
       _prepareImage = prepareImage ?? prepareFeishuMonitorImageForWkUpload,
       _uploadImage = uploadImage ?? _uploadFeishuMonitorImageForWk;

  final ChatSceneGateway _gateway;
  final FeishuMonitorImagePreparer _prepareImage;
  final FeishuMonitorImageUploader _uploadImage;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
  }) {
    return _gateway.sendMessageContent(
      WKTextContent(text),
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
  }) async {
    final prepared = await _prepareImage(image);
    if (prepared.localPath.trim().isEmpty) {
      throw StateError('Feishu image was not prepared as a local file.');
    }
    final remoteUrl = await _uploadImage(
      filePath: prepared.localPath.trim(),
      channelId: channelId,
      channelType: channelType,
    );
    if (remoteUrl.trim().isEmpty) {
      throw StateError('Feishu image upload returned an empty url.');
    }
    final content = WKImageContent(prepared.width, prepared.height)
      ..localPath = prepared.localPath.trim()
      ..url = remoteUrl.trim();
    return _gateway.sendMessageContent(
      content,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}

Future<String> _uploadFeishuMonitorImageForWk({
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

Future<FeishuMonitorImageAttachment> prepareFeishuMonitorImageForWkUpload(
  FeishuMonitorImageAttachment image, {
  Directory? imageDirectory,
}) async {
  final localPath = image.localPath.trim();
  if (localPath.isNotEmpty && await File(localPath).exists()) {
    return image;
  }

  final sourceUrl = image.sourceUrl.trim();
  if (sourceUrl.toLowerCase().startsWith('data:image/')) {
    return _prepareDataUrlImageForWkUpload(
      image,
      imageDirectory: imageDirectory,
    );
  }

  final uri = Uri.tryParse(sourceUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return image;
  }

  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return image;
    }
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    if (bytes.isEmpty) {
      return image;
    }
    final directory = await _feishuMonitorImageDirectory(imageDirectory);
    final digest = crypto.sha1.convert(sourceUrl.codeUnits).toString();
    final extension = _imageFileExtension(
      uri: uri,
      contentType: response.headers.contentType?.mimeType,
    );
    final file = File(path.join(directory.path, '$digest.$extension'));
    await file.writeAsBytes(bytes, flush: true);
    return FeishuMonitorImageAttachment(
      sourceUrl: image.sourceUrl,
      localPath: file.path,
      width: image.width,
      height: image.height,
    );
  } finally {
    client.close(force: true);
  }
}

Future<FeishuMonitorImageAttachment> _prepareDataUrlImageForWkUpload(
  FeishuMonitorImageAttachment image, {
  Directory? imageDirectory,
}) async {
  final sourceUrl = image.sourceUrl.trim();
  final commaIndex = sourceUrl.indexOf(',');
  if (commaIndex <= 5) {
    return image;
  }
  final metadata = sourceUrl.substring(5, commaIndex).toLowerCase();
  if (!metadata.startsWith('image/') || !metadata.contains(';base64')) {
    return image;
  }
  final encoded = sourceUrl
      .substring(commaIndex + 1)
      .replaceAll(RegExp(r'\s+'), '');
  List<int> bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    return image;
  }
  if (bytes.isEmpty) {
    return image;
  }

  final directory = await _feishuMonitorImageDirectory(imageDirectory);
  final digest = crypto.sha1.convert(bytes).toString();
  final extension = _imageFileExtensionFromMimeType(metadata.split(';').first);
  final file = File(path.join(directory.path, '$digest.$extension'));
  await file.writeAsBytes(bytes, flush: true);
  return FeishuMonitorImageAttachment(
    sourceUrl: image.sourceUrl,
    localPath: file.path,
    width: image.width,
    height: image.height,
  );
}

Future<Directory> _feishuMonitorImageDirectory(
  Directory? imageDirectory,
) async {
  final directory =
      imageDirectory ??
      Directory(
        path.join(
          (await getTemporaryDirectory()).path,
          'feishu_monitor_images',
        ),
      );
  await directory.create(recursive: true);
  return directory;
}

class FeishuMonitorForwardingService {
  FeishuMonitorForwardingService({
    FeishuMonitorTextSender? sender,
    FeishuMonitorForwardingDedupeStore? dedupeStore,
  }) : _sender = sender ?? WkImFeishuMonitorTextSender(),
       _dedupeStore =
           dedupeStore ??
           const SharedPreferencesFeishuMonitorForwardingDedupeStore();

  final FeishuMonitorTextSender _sender;
  final FeishuMonitorForwardingDedupeStore _dedupeStore;
  final Set<String> _sentKeys = <String>{};
  final Map<String, int> _deferredBlobAttempts = <String, int>{};
  static final Set<String> _inFlightKeys = <String>{};
  static const int _maxPersistedSentKeys = 500;
  static const int _maxDeferredBlobAttempts = 5;

  Future<void> primeRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled || events.isEmpty) {
      return;
    }

    await _loadPersistedSentKeys();
    var changed = false;
    for (final event in events) {
      final route = findFeishuMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null ||
          !route.enabled ||
          route.targetGroupId.trim().isEmpty) {
        continue;
      }
      if (_shouldSkipProbeTextEvent(event)) {
        continue;
      }

      final key = _eventDedupeKey(event);
      if (key.isEmpty) {
        continue;
      }
      changed = _sentKeys.add(key) || changed;
      final mediaKey = _eventMediaDedupeKey(event, key);
      if (mediaKey.isNotEmpty &&
          _canPrepareEventMediaOutsideFeishuWebView(event)) {
        changed = _sentKeys.add(mediaKey) || changed;
      }
    }

    if (changed) {
      await _persistSentKeys();
    }
  }

  Future<FeishuMonitorForwardingResult> forwardRecentEvents({
    required FeishuMonitorForwardingRule rule,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    var sent = 0;
    var skippedDuplicate = 0;
    var failed = 0;
    final targetGroupId = rule.targetGroupId.trim();
    if (!rule.enabled || targetGroupId.isEmpty) {
      return FeishuMonitorForwardingResult(
        sent: 0,
        skippedDisabled: events.length,
        failed: 0,
      );
    }

    await _loadPersistedSentKeys();
    for (final event in events) {
      if (_shouldSkipProbeTextEvent(event)) {
        skippedDuplicate += 1;
        continue;
      }
      final key = _eventDedupeKey(event);
      if (_shouldDeferPendingBlobImage(event, key)) {
        skippedDuplicate += 1;
        continue;
      }
      final mediaKey = _eventMediaDedupeKey(event, key);
      final retryMediaOnly =
          key.isNotEmpty &&
          _sentKeys.contains(key) &&
          _shouldRetryMediaAfterBaseEvent(event, mediaKey, _sentKeys);
      if (key.isEmpty || _sentKeys.contains(key)) {
        if (retryMediaOnly) {
          // A previous feed-list pass may have forwarded only "[图片]".
          // Let a later enriched event send the real attachment once.
        } else {
          skippedDuplicate += 1;
          continue;
        }
      }
      try {
        final delivery = await _sendEventToTarget(
          event: event,
          channelId: targetGroupId,
          channelType: rule.targetChannelType,
          channelName: rule.targetGroupName,
          allowTextFallback: !retryMediaOnly,
        );
        _sentKeys.add(key);
        if (mediaKey.isNotEmpty && delivery.sentMedia) {
          _sentKeys.add(mediaKey);
        }
        await _persistSentKeys();
        sent += 1;
      } catch (_) {
        failed += 1;
      }
    }

    return FeishuMonitorForwardingResult(
      sent: sent,
      skippedDuplicate: skippedDuplicate,
      failed: failed,
    );
  }

  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled) {
      return FeishuMonitorForwardingResult(
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
    final forwardedMediaFingerprints = <String>{};

    await _loadPersistedSentKeys();
    for (final event in events) {
      final route = findFeishuMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null) {
        final candidate = _findFeishuMonitorRouteCandidateForEvent(
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

      if (_shouldSkipProbeTextEvent(event)) {
        skippedDuplicate += 1;
        continue;
      }
      final key = _eventDedupeKey(event);
      if (_shouldDeferPendingBlobImage(event, key)) {
        skippedDuplicate += 1;
        continue;
      }

      final mediaKey = _eventMediaDedupeKey(event, key);
      final retryMediaOnly =
          key.isNotEmpty &&
          _sentKeys.contains(key) &&
          _shouldRetryMediaAfterBaseEvent(event, mediaKey, _sentKeys);
      final mediaFingerprint = _eventMediaFingerprint(event);
      if (key.isEmpty || _sentKeys.contains(key)) {
        if (retryMediaOnly) {
          // A previous feed-list pass may have forwarded only "[图片]".
          // Let a later enriched event send the real attachment once.
        } else {
          skippedDuplicate += 1;
          continue;
        }
      }
      if (!_tryAcquireInFlightKey(key)) {
        skippedDuplicate += 1;
        continue;
      }
      if (mediaFingerprint.isNotEmpty &&
          (_sentKeys.contains(mediaFingerprint) ||
              forwardedMediaFingerprints.contains(mediaFingerprint))) {
        _releaseInFlightKey(key);
        skippedDuplicate += 1;
        continue;
      }

      try {
        final delivery = await _sendEventToTarget(
          event: event,
          channelId: targetGroupId,
          channelType: WKChannelType.group,
          channelName: route.targetGroupName,
          allowTextFallback: !retryMediaOnly,
        );
        _sentKeys.add(key);
        if (mediaKey.isNotEmpty && delivery.sentMedia) {
          _sentKeys.add(mediaKey);
          if (mediaFingerprint.isNotEmpty) {
            _sentKeys.add(mediaFingerprint);
            forwardedMediaFingerprints.add(mediaFingerprint);
          }
        }
        await _persistSentKeys();
        sent += 1;
      } catch (_) {
        failed += 1;
      } finally {
        _releaseInFlightKey(key);
      }
    }

    return FeishuMonitorForwardingResult(
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
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return true;
    }
    return _inFlightKeys.add(normalizedKey);
  }

  void _releaseInFlightKey(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isNotEmpty) {
      _inFlightKeys.remove(normalizedKey);
    }
  }

  Future<_FeishuMonitorEventDelivery> _sendEventToTarget({
    required FeishuMonitorMessageEvent event,
    required String channelId,
    required int channelType,
    required String channelName,
    bool allowTextFallback = true,
  }) async {
    final image = _firstUsableImageAttachment(event);
    if (image != null) {
      try {
        await _sender.sendImage(
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
          image: image,
        );
        return const _FeishuMonitorEventDelivery(sentMedia: true);
      } catch (_) {
        if (!allowTextFallback) {
          rethrow;
        }
        // Keep the monitor lossless: if media extraction/upload fails, forward
        // the textual Feishu placeholder instead of dropping the event.
      }
    }
    await _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: formatFeishuMonitorEventForForward(event),
    );
    return const _FeishuMonitorEventDelivery(sentMedia: false);
  }

  FeishuMonitorImageAttachment? _firstUsableImageAttachment(
    FeishuMonitorMessageEvent event,
  ) {
    return _firstUsableImageAttachmentForEvent(event);
  }

  bool _shouldDeferPendingBlobImage(
    FeishuMonitorMessageEvent event,
    String key,
  ) {
    final image = _firstUsableImageAttachmentForEvent(event);
    if (image == null) {
      return false;
    }
    if (_canPrepareImageOutsideFeishuWebView(image)) {
      if (key.trim().isNotEmpty) {
        _deferredBlobAttempts.remove(key.trim());
      }
      return false;
    }
    final normalizedKey = key.trim().isNotEmpty
        ? key.trim()
        : _eventDedupeKey(event);
    final attempts = (_deferredBlobAttempts[normalizedKey] ?? 0) + 1;
    _deferredBlobAttempts[normalizedKey] = attempts;
    return attempts <= _maxDeferredBlobAttempts;
  }

  Future<void> _persistSentKeys() {
    final keys = _sentKeys.toList(growable: false);
    final capped = keys.length <= _maxPersistedSentKeys
        ? keys
        : keys.sublist(keys.length - _maxPersistedSentKeys);
    return _dedupeStore.saveSentKeys(capped);
  }
}

class _FeishuMonitorEventDelivery {
  const _FeishuMonitorEventDelivery({required this.sentMedia});

  final bool sentMedia;
}

class FeishuMonitorForwardingSettings {
  const FeishuMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <FeishuMonitorForwardingRoute>[],
    String legacyTargetGroupId = '',
    String? targetGroupId,
  }) : legacyTargetGroupId = targetGroupId ?? legacyTargetGroupId;

  final bool enabled;
  final List<FeishuMonitorForwardingRoute> routes;
  final String legacyTargetGroupId;

  String get targetGroupId => legacyTargetGroupId;

  FeishuMonitorForwardingSettings copyWith({
    bool? enabled,
    List<FeishuMonitorForwardingRoute>? routes,
    String? legacyTargetGroupId,
  }) {
    return FeishuMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
      legacyTargetGroupId: legacyTargetGroupId ?? this.legacyTargetGroupId,
    );
  }

  FeishuMonitorForwardingRule toRule() {
    return FeishuMonitorForwardingRule(
      enabled: enabled,
      targetGroupId: targetGroupId,
    );
  }

  factory FeishuMonitorForwardingSettings.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    return FeishuMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return FeishuMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return FeishuMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<FeishuMonitorForwardingRoute>()
                .toList(growable: false)
          : const <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: (json['legacy_target_group_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
      'legacy_target_group_id': legacyTargetGroupId,
    };
  }
}

abstract class FeishuMonitorForwardingSettingsStore {
  Future<FeishuMonitorForwardingSettings> load();
  Future<void> save(FeishuMonitorForwardingSettings settings);
}

class SharedPreferencesFeishuMonitorForwardingSettingsStore
    implements FeishuMonitorForwardingSettingsStore {
  const SharedPreferencesFeishuMonitorForwardingSettingsStore();

  static const String _settingsV2Key = 'feishu_monitor_forwarding_settings_v2';
  static const String _enabledKey = 'feishu_monitor_forwarding_enabled';
  static const String _targetGroupIdKey = 'feishu_monitor_target_group_id';

  @override
  Future<FeishuMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedSettings = prefs.getString(_settingsV2Key);
    if (encodedSettings != null) {
      try {
        final decoded = jsonDecode(encodedSettings);
        if (decoded is Map<String, dynamic>) {
          return FeishuMonitorForwardingSettings.fromJson(decoded);
        }
        if (decoded is Map) {
          return FeishuMonitorForwardingSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } on FormatException {
        return _loadLegacySettings(prefs);
      } on TypeError {
        return _loadLegacySettings(prefs);
      }
    }
    return _loadLegacySettings(prefs);
  }

  FeishuMonitorForwardingSettings _loadLegacySettings(SharedPreferences prefs) {
    return FeishuMonitorForwardingSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      routes: const <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: prefs.getString(_targetGroupIdKey) ?? '',
    );
  }

  @override
  Future<void> save(FeishuMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsV2Key, jsonEncode(settings.toJson()));
  }
}

String formatFeishuMonitorEventForForward(FeishuMonitorMessageEvent event) {
  final conversationName = event.conversationName.trim();
  final senderName = event.senderName.trim();
  final text = _forwardableEventText(event);
  final lines = <String>[
    if (conversationName.isNotEmpty) '飞书群：$conversationName',
    if (senderName.isNotEmpty) '发送人：$senderName',
    text.isEmpty ? '(空消息)' : text,
  ];
  return lines.join('\n');
}

String _forwardableEventText(FeishuMonitorMessageEvent event) {
  final captureSource = event.captureSource.trim();
  final hasImage = _firstUsableImageAttachmentForEvent(event) != null;
  if (hasImage &&
      (captureSource == 'dom_probe' || captureSource == 'body_text_probe')) {
    return '[图片]';
  }
  return event.text.trim();
}

String _eventDedupeKey(FeishuMonitorMessageEvent event) {
  if (event.captureSource.trim() == 'feed_card_probe') {
    final feedCardKey = _feedCardProbeDedupeKey(event);
    if (feedCardKey.isNotEmpty) {
      return feedCardKey;
    }
  }
  final dedupeKey = event.dedupeKey.trim();
  if (dedupeKey.isNotEmpty) {
    return dedupeKey;
  }
  final eventId = event.eventId.trim();
  if (eventId.isNotEmpty) {
    return eventId;
  }
  return event.messageId.trim();
}

String _eventMediaDedupeKey(FeishuMonitorMessageEvent event, String baseKey) {
  final normalizedBaseKey = baseKey.trim();
  if (normalizedBaseKey.isEmpty) {
    return '';
  }
  final image = _firstUsableImageAttachmentForEvent(event);
  if (image == null) {
    return '';
  }
  return '$normalizedBaseKey:media';
}

String _eventMediaFingerprint(FeishuMonitorMessageEvent event) {
  final image = _firstUsableImageAttachmentForEvent(event);
  if (image == null) {
    return '';
  }
  final source = image.localPath.trim().isNotEmpty
      ? 'local:${image.localPath.trim()}'
      : 'source:${image.sourceUrl.trim()}';
  if (source == 'source:') {
    return '';
  }
  final dimensions = image.width > 0 && image.height > 0
      ? '${image.width}x${image.height}'
      : 'unknown_size';
  final digest = crypto.sha1.convert(utf8.encode(source)).toString();
  return 'media_fingerprint:$dimensions:$digest';
}

String _feedCardProbeDedupeKey(FeishuMonitorMessageEvent event) {
  final conversationScope = event.conversationId.trim().isNotEmpty
      ? event.conversationId.trim()
      : normalizeFeishuMonitorRouteName(event.conversationName);
  final senderName = event.senderName.trim();
  final normalizedText = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (conversationScope.isEmpty || normalizedText.isEmpty) {
    return '';
  }
  final dedupeKey = event.dedupeKey.trim();
  if (dedupeKey.isNotEmpty) {
    return dedupeKey;
  }
  final messageId = event.messageId.trim();
  if (messageId.isNotEmpty) {
    return '$conversationScope:$messageId';
  }
  return 'feed_card_probe:$conversationScope:$senderName:$normalizedText';
}

bool _shouldSkipProbeTextEvent(FeishuMonitorMessageEvent event) {
  final captureSource = event.captureSource.trim();
  if (captureSource == 'feed_card_probe' &&
      _isFeishuMonitorMediaPlaceholderText(event.text)) {
    return _firstUsableImageAttachmentForEvent(event) == null;
  }
  if (captureSource == 'network_original_image' &&
      _isFeishuMonitorMediaPlaceholderText(event.text)) {
    return _firstUsableImageAttachmentForEvent(event) == null;
  }
  if (_eventHasDomFallbackMedia(event)) {
    return true;
  }
  if (!_isDomFallbackCaptureSource(captureSource)) {
    return false;
  }
  return _firstUsableImageAttachmentForEvent(event) == null;
}

bool _isDomFallbackCaptureSource(String captureSource) {
  final normalized = captureSource.trim();
  return normalized == 'dom_probe' || normalized == 'body_text_probe';
}

bool _eventHasDomFallbackMedia(FeishuMonitorMessageEvent event) {
  return _isDomFallbackCaptureSource(event.captureSource) &&
      _rawFirstUsableImageAttachmentForEvent(event) != null;
}

bool _isFeishuMonitorMediaPlaceholderText(String value) {
  final normalized = value.trim();
  return normalized == '[图片]' ||
      normalized == '[鍥剧墖]' ||
      normalized == '[Image]' ||
      normalized == '[Video]' ||
      normalized == '[File]' ||
      normalized == '[视频]' ||
      normalized == '[文件]';
}

bool _shouldRetryMediaAfterBaseEvent(
  FeishuMonitorMessageEvent event,
  String mediaKey,
  Set<String> sentKeys,
) {
  if (mediaKey.trim().isEmpty || sentKeys.contains(mediaKey)) {
    return false;
  }
  final image = _firstUsableImageAttachmentForEvent(event);
  if (image == null) {
    return false;
  }
  return _canPrepareImageOutsideFeishuWebView(image);
}

bool _canPrepareEventMediaOutsideFeishuWebView(
  FeishuMonitorMessageEvent event,
) {
  final image = _firstUsableImageAttachmentForEvent(event);
  if (image == null) {
    return false;
  }
  return _canPrepareImageOutsideFeishuWebView(image);
}

bool _canPrepareImageOutsideFeishuWebView(FeishuMonitorImageAttachment image) {
  if (image.localPath.trim().isNotEmpty) {
    return true;
  }
  final sourceUrl = image.sourceUrl.trim().toLowerCase();
  if (sourceUrl.isEmpty || sourceUrl.startsWith('blob:')) {
    return false;
  }
  return true;
}

FeishuMonitorImageAttachment? _firstUsableImageAttachmentForEvent(
  FeishuMonitorMessageEvent event,
) {
  if (_isDomFallbackCaptureSource(event.captureSource)) {
    return null;
  }
  final image = _rawFirstUsableImageAttachmentForEvent(event);
  if (event.captureSource.trim() == 'network_original_image' &&
      (image == null || image.localPath.trim().isEmpty)) {
    return null;
  }
  return image;
}

FeishuMonitorImageAttachment? _rawFirstUsableImageAttachmentForEvent(
  FeishuMonitorMessageEvent event,
) {
  for (final image in event.imageAttachments) {
    if (image.hasUsableSource) {
      return image;
    }
  }
  return null;
}

String _imageFileExtension({required Uri uri, String? contentType}) {
  final fromPath = path.extension(uri.path).replaceFirst('.', '').toLowerCase();
  if (RegExp(r'^[a-z0-9]{1,8}$').hasMatch(fromPath)) {
    return fromPath;
  }

  return _imageFileExtensionFromMimeType(contentType);
}

String _imageFileExtensionFromMimeType(String? contentType) {
  switch ((contentType ?? '').trim().toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/gif':
      return 'gif';
    case 'image/webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

FeishuMonitorForwardingRoute? findFeishuMonitorRouteForEvent({
  required List<FeishuMonitorForwardingRoute> routes,
  required FeishuMonitorMessageEvent event,
}) {
  final eligibleRoutes = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final conversationId = event.conversationId.trim();
  if (conversationId.isNotEmpty) {
    final matches = eligibleRoutes
        .where((route) => route.sourceConversationId.trim() == conversationId)
        .toList(growable: false);
    if (matches.length == 1) {
      return matches.single;
    }
    if (matches.length > 1) {
      return null;
    }
  }

  final conversationName = normalizeFeishuMonitorRouteName(
    event.conversationName,
  );
  if (conversationName.isEmpty) {
    return null;
  }
  final matches = eligibleRoutes
      .where(
        (route) =>
            normalizeFeishuMonitorRouteName(route.sourceConversationName) ==
            conversationName,
      )
      .toList(growable: false);
  if (matches.length == 1) {
    return matches.single;
  }
  return null;
}

FeishuMonitorForwardingRoute? _findFeishuMonitorRouteCandidateForEvent({
  required List<FeishuMonitorForwardingRoute> routes,
  required FeishuMonitorMessageEvent event,
}) {
  final conversationId = event.conversationId.trim();
  if (conversationId.isNotEmpty) {
    final matches = routes
        .where((route) => route.sourceConversationId.trim() == conversationId)
        .toList(growable: false);
    if (matches.length == 1) {
      return matches.single;
    }
    if (matches.length > 1) {
      return null;
    }
  }

  final conversationName = normalizeFeishuMonitorRouteName(
    event.conversationName,
  );
  if (conversationName.isEmpty) {
    return null;
  }
  final matches = routes
      .where(
        (route) =>
            normalizeFeishuMonitorRouteName(route.sourceConversationName) ==
            conversationName,
      )
      .toList(growable: false);
  if (matches.length == 1) {
    return matches.single;
  }
  return null;
}

String normalizeFeishuMonitorRouteName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
