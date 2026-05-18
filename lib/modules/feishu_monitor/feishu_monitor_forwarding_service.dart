import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'feishu_monitor_shell_models.dart';
import 'feishu_monitor_worker_config.dart';

const int feishuMonitorForwardedMessageExpireSeconds =
    localMonitorForwardedMessageExpireSeconds;
const Duration feishuMonitorForwardedImageCacheRetention = Duration(hours: 24);
const String feishuMonitorForwardedImageUploadPrefix = 'feishu-monitor';

class FeishuMonitorForwardingRoute {
  const FeishuMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.sourceConversationType,
    required this.targetGroupId,
    required this.targetGroupName,
    this.workerId = '',
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
  final String workerId;
  final String relayDisplayName;
  final String relayAvatar;
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
      workerId: (json['worker_id'] ?? json['workerId'] ?? '').toString(),
      relayDisplayName: (json['relay_display_name'] as String?) ?? '',
      relayAvatar: (json['relay_avatar'] as String?) ?? '',
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
      'worker_id': workerId,
      'relay_display_name': relayDisplayName,
      'relay_avatar': relayAvatar,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  FeishuMonitorForwardingRoute copyWith({
    bool? enabled,
    String? targetGroupId,
    String? targetGroupName,
    String? workerId,
    String? relayDisplayName,
    String? relayAvatar,
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
      workerId: workerId ?? this.workerId,
      relayDisplayName: relayDisplayName ?? this.relayDisplayName,
      relayAvatar: relayAvatar ?? this.relayAvatar,
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

  FeishuMonitorRelayIdentity relayIdentity({
    String defaultDisplayName = '飞书转发助手',
  }) {
    final displayName = relayDisplayName.trim().isNotEmpty
        ? relayDisplayName.trim()
        : defaultDisplayName;
    return FeishuMonitorRelayIdentity(
      provider: 'feishu',
      displayName: displayName,
      avatar: relayAvatar.trim(),
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

abstract class FeishuMonitorTextSender implements LocalMonitorTextSender {
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
    FeishuMonitorRelayIdentity? relayIdentity,
  });
}

typedef FeishuMonitorRelayIdentity = LocalMonitorRelayIdentity;

typedef FeishuMonitorForwardingDedupeStore = LocalMonitorForwardingDedupeStore;

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
  }) : this._(gateway ?? ApiChatSceneGateway(), prepareImage, uploadImage);

  WkImFeishuMonitorTextSender._(
    ChatSceneGateway gateway,
    FeishuMonitorImagePreparer? prepareImage,
    FeishuMonitorImageUploader? uploadImage,
  ) : _gateway = gateway,
      _textSender = WkImLocalMonitorTextSender(gateway: gateway),
      _prepareImage = prepareImage ?? prepareFeishuMonitorImageForWkUpload,
      _uploadImage = uploadImage ?? _uploadFeishuMonitorImageForWk;

  final ChatSceneGateway _gateway;
  final LocalMonitorTextSender _textSender;
  final FeishuMonitorImagePreparer _prepareImage;
  final FeishuMonitorImageUploader _uploadImage;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    FeishuMonitorRelayIdentity? relayIdentity,
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
    required FeishuMonitorImageAttachment image,
    FeishuMonitorRelayIdentity? relayIdentity,
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
    final content =
        _FeishuMonitorRelayImageContent(
            prepared.width,
            prepared.height,
            relayIdentity: relayIdentity,
          )
          ..localPath = prepared.localPath.trim()
          ..url = remoteUrl.trim();
    return _gateway.sendMessageContent(
      content,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      expireSeconds: feishuMonitorForwardedMessageExpireSeconds,
    );
  }
}

class _FeishuMonitorRelayImageContent extends WKImageContent {
  _FeishuMonitorRelayImageContent(
    super.width,
    super.height, {
    FeishuMonitorRelayIdentity? relayIdentity,
  }) : _relayIdentity = relayIdentity;

  final FeishuMonitorRelayIdentity? _relayIdentity;

  @override
  Map<String, dynamic> encodeJson() {
    return withLocalMonitorRelayIdentity(super.encodeJson(), _relayIdentity);
  }
}

Future<String> _uploadFeishuMonitorImageForWk({
  required String filePath,
  required String channelId,
  required int channelType,
}) {
  return FileApi.instance.uploadChatFileAtPath(
    filePath: filePath,
    uploadPath: feishuMonitorForwardedImageUploadPath(
      channelId: channelId,
      channelType: channelType,
      filePath: filePath,
      now: DateTime.now().toUtc(),
    ),
  );
}

String feishuMonitorForwardedImageUploadPath({
  required String channelId,
  required int channelType,
  required String filePath,
  required DateTime now,
}) {
  final channelSegment = _safeFeishuMonitorObjectPathSegment(
    channelId,
    fallback: 'channel',
  );
  final extension = _safeFeishuMonitorImageExtension(filePath);
  return '/$feishuMonitorForwardedImageUploadPrefix/'
      '$channelType/$channelSegment/'
      '${now.toUtc().millisecondsSinceEpoch}.$extension';
}

Future<FeishuMonitorImageAttachment> prepareFeishuMonitorImageForWkUpload(
  FeishuMonitorImageAttachment image, {
  Directory? imageDirectory,
}) async {
  final localPath = image.localPath.trim();
  if (localPath.isNotEmpty && await File(localPath).exists()) {
    return image;
  }
  await cleanupFeishuMonitorForwardedImageCache(imageDirectory: imageDirectory);

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

Future<int> cleanupFeishuMonitorForwardedImageCache({
  Directory? imageDirectory,
  DateTime? now,
  Duration retention = feishuMonitorForwardedImageCacheRetention,
}) async {
  final directory =
      imageDirectory ??
      Directory(
        path.join(
          (await getTemporaryDirectory()).path,
          'feishu_monitor_images',
        ),
      );
  if (!await directory.exists()) {
    return 0;
  }
  final cutoff = (now ?? DateTime.now().toUtc()).toUtc().subtract(retention);
  var deleted = 0;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final modifiedAt = await entity.lastModified();
    if (!modifiedAt.toUtc().isBefore(cutoff)) {
      continue;
    }
    try {
      await entity.delete();
      deleted += 1;
    } on FileSystemException {
      // Best-effort cleanup; locked files can be retried next time.
    }
  }
  return deleted;
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

String _safeFeishuMonitorImageExtension(String filePath) {
  final extension = path
      .extension(filePath.trim())
      .replaceFirst('.', '')
      .trim()
      .toLowerCase();
  if (RegExp(r'^[a-z0-9]{1,16}$').hasMatch(extension)) {
    return extension;
  }
  return 'dat';
}

String _safeFeishuMonitorObjectPathSegment(
  String value, {
  required String fallback,
}) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'[\\/]+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceFirst(RegExp(r'^[._-]+'), '')
      .replaceFirst(RegExp(r'[._-]+$'), '');
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized;
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
      final feedCardTextPayloadDedupeKey = _feedCardTextPayloadDedupeKeyFor(
        event,
      );
      if (event.captureSource.trim() == 'feed_card_probe' &&
          feedCardTextPayloadDedupeKey.isNotEmpty) {
        changed = _sentKeys.add(feedCardTextPayloadDedupeKey) || changed;
      }
      final feedCardTextBodyDedupeKey = _feedCardTextBodyDedupeKeyFor(event);
      if (event.captureSource.trim() == 'feed_card_probe' &&
          feedCardTextBodyDedupeKey.isNotEmpty) {
        changed = _sentKeys.add(feedCardTextBodyDedupeKey) || changed;
      }
      final routeTextReplayKey = _eventRouteTextReplayKey(route, event);
      final globalDomTextReplayKey = _eventGlobalDomTextReplayKey(event);
      final routeDomTextBodyKey = _eventRouteDomTextBodyKey(route, event);
      if (routeTextReplayKey.isNotEmpty) {
        changed = _sentKeys.add(routeTextReplayKey) || changed;
      }
      if (globalDomTextReplayKey.isNotEmpty) {
        changed = _sentKeys.add(globalDomTextReplayKey) || changed;
      }
      if (_isDomFallbackCaptureSource(event.captureSource) &&
          routeDomTextBodyKey.isNotEmpty) {
        changed = _sentKeys.add(routeDomTextBodyKey) || changed;
      }
      final mediaKey = _eventMediaDedupeKey(event, key);
      if (mediaKey.isNotEmpty &&
          _canPrepareEventMediaOutsideFeishuWebView(event)) {
        changed = _sentKeys.add(mediaKey) || changed;
        final routeMediaBodyKey = _eventRouteMediaBodyKey(route, event);
        if (routeMediaBodyKey.isNotEmpty) {
          changed = _sentKeys.add(routeMediaBodyKey) || changed;
        }
        final routeMediaFingerprintKey = _eventRouteMediaFingerprintKey(
          route,
          event,
        );
        if (routeMediaFingerprintKey.isNotEmpty) {
          changed = _sentKeys.add(routeMediaFingerprintKey) || changed;
        }
        final globalNetworkImageBodyKey = _eventGlobalNetworkImageBodyKey(
          event,
        );
        if (globalNetworkImageBodyKey.isNotEmpty) {
          changed = _sentKeys.add(globalNetworkImageBodyKey) || changed;
        }
        final globalNetworkImageFingerprintKey =
            _eventGlobalNetworkImageFingerprintKey(event);
        if (globalNetworkImageFingerprintKey.isNotEmpty) {
          changed = _sentKeys.add(globalNetworkImageFingerprintKey) || changed;
        }
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
    final feedCardTextKeys = _feedCardTextKeysFor(events);
    for (final event in events) {
      if (_shouldSkipProbeTextEvent(event)) {
        skippedDuplicate += 1;
        continue;
      }
      final key = _eventDedupeKey(event);
      if (_shouldSkipDomTextAlreadyCapturedByFeedCard(
        event,
        feedCardTextKeys,
        _sentKeys,
      )) {
        skippedDuplicate += 1;
        continue;
      }
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
          relayIdentity: const FeishuMonitorRelayIdentity(
            provider: 'feishu',
            displayName: '飞书转发助手',
            avatar: '',
          ),
          allowTextFallback: !retryMediaOnly,
        );
        _sentKeys.add(key);
        final feedCardTextPayloadDedupeKey = _feedCardTextPayloadDedupeKeyFor(
          event,
        );
        if (event.captureSource.trim() == 'feed_card_probe' &&
            feedCardTextPayloadDedupeKey.isNotEmpty) {
          _sentKeys.add(feedCardTextPayloadDedupeKey);
        }
        final feedCardTextBodyDedupeKey = _feedCardTextBodyDedupeKeyFor(event);
        if (event.captureSource.trim() == 'feed_card_probe' &&
            feedCardTextBodyDedupeKey.isNotEmpty) {
          _sentKeys.add(feedCardTextBodyDedupeKey);
        }
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
    final feedCardTextKeys = _feedCardTextKeysFor(events);

    await _loadPersistedSentKeys();
    for (final event in events) {
      final route = findFeishuMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null) {
        if (_hasConflictingDomRouteMatches(
          routes: settings.routes,
          event: event,
        )) {
          skippedUnmatched += 1;
        } else {
          final candidate = _findFeishuMonitorRouteCandidateForEvent(
            routes: settings.routes,
            event: event,
          );
          if (candidate == null) {
            skippedUnmatched += 1;
          } else {
            skippedDisabled += 1;
          }
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
      if (_shouldSkipDomTextAlreadyCapturedByFeedCard(
        event,
        feedCardTextKeys,
        _sentKeys,
      )) {
        skippedDuplicate += 1;
        continue;
      }
      final key = _eventDedupeKey(event);
      final routeTextReplayKey = _eventRouteTextReplayKey(route, event);
      final globalDomTextReplayKey = _eventGlobalDomTextReplayKey(event);
      final routeDomTextBodyKey = _eventRouteDomTextBodyKey(route, event);
      if (routeTextReplayKey.isNotEmpty &&
          _sentKeys.contains(routeTextReplayKey)) {
        skippedDuplicate += 1;
        continue;
      }
      if (globalDomTextReplayKey.isNotEmpty &&
          _sentKeys.contains(globalDomTextReplayKey)) {
        skippedDuplicate += 1;
        continue;
      }
      if (event.captureSource.trim() == 'feed_card_probe' &&
          routeDomTextBodyKey.isNotEmpty &&
          _sentKeys.contains(routeDomTextBodyKey)) {
        skippedDuplicate += 1;
        continue;
      }
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
      final networkImageFingerprint = _eventNetworkImageFingerprint(event);
      final routeMediaBodyKey = _eventRouteMediaBodyKey(route, event);
      final routeMediaFingerprintKey = _eventRouteMediaFingerprintKey(
        route,
        event,
      );
      final globalNetworkImageBodyKey = _eventGlobalNetworkImageBodyKey(event);
      final globalNetworkImageFingerprintKey =
          _eventGlobalNetworkImageFingerprintKey(event);
      if (key.isEmpty || _sentKeys.contains(key)) {
        if (retryMediaOnly) {
          // A previous feed-list pass may have forwarded only "[图片]".
          // Let a later enriched event send the real attachment once.
        } else {
          skippedDuplicate += 1;
          continue;
        }
      }
      if (_shouldSkipRouteMediaBodyReplay(
        route: route,
        event: event,
        routeMediaBodyKey: routeMediaBodyKey,
        sentKeys: _sentKeys,
      )) {
        skippedDuplicate += 1;
        continue;
      }
      if (_shouldSkipGlobalNetworkImageReplay(
        globalNetworkImageBodyKey: globalNetworkImageBodyKey,
        globalNetworkImageFingerprintKey: globalNetworkImageFingerprintKey,
        sentKeys: _sentKeys,
      )) {
        skippedDuplicate += 1;
        continue;
      }
      if (!_tryAcquireInFlightKey(key)) {
        skippedDuplicate += 1;
        continue;
      }
      if (_shouldDedupeMediaFingerprint(event) &&
          mediaFingerprint.isNotEmpty &&
          forwardedMediaFingerprints.contains(mediaFingerprint)) {
        _releaseInFlightKey(key);
        skippedDuplicate += 1;
        continue;
      }
      if (networkImageFingerprint.isNotEmpty &&
          forwardedMediaFingerprints.contains(networkImageFingerprint)) {
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
          relayIdentity: route.relayIdentity(),
          allowTextFallback: !retryMediaOnly,
        );
        _sentKeys.add(key);
        final feedCardTextPayloadDedupeKey = _feedCardTextPayloadDedupeKeyFor(
          event,
        );
        if (event.captureSource.trim() == 'feed_card_probe' &&
            feedCardTextPayloadDedupeKey.isNotEmpty) {
          _sentKeys.add(feedCardTextPayloadDedupeKey);
        }
        final feedCardTextBodyDedupeKey = _feedCardTextBodyDedupeKeyFor(event);
        if (event.captureSource.trim() == 'feed_card_probe' &&
            feedCardTextBodyDedupeKey.isNotEmpty) {
          _sentKeys.add(feedCardTextBodyDedupeKey);
        }
        if (routeTextReplayKey.isNotEmpty) {
          _sentKeys.add(routeTextReplayKey);
        }
        if (globalDomTextReplayKey.isNotEmpty) {
          _sentKeys.add(globalDomTextReplayKey);
        }
        if (_isDomFallbackCaptureSource(event.captureSource) &&
            routeDomTextBodyKey.isNotEmpty) {
          _sentKeys.add(routeDomTextBodyKey);
        }
        if (mediaKey.isNotEmpty && delivery.sentMedia) {
          _sentKeys.add(mediaKey);
          if (routeMediaBodyKey.isNotEmpty) {
            _sentKeys.add(routeMediaBodyKey);
          }
          if (routeMediaFingerprintKey.isNotEmpty) {
            _sentKeys.add(routeMediaFingerprintKey);
          }
          if (globalNetworkImageBodyKey.isNotEmpty) {
            _sentKeys.add(globalNetworkImageBodyKey);
          }
          if (globalNetworkImageFingerprintKey.isNotEmpty) {
            _sentKeys.add(globalNetworkImageFingerprintKey);
          }
          if (_shouldDedupeMediaFingerprint(event) &&
              mediaFingerprint.isNotEmpty) {
            forwardedMediaFingerprints.add(mediaFingerprint);
          }
          if (networkImageFingerprint.isNotEmpty) {
            forwardedMediaFingerprints.add(networkImageFingerprint);
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
    FeishuMonitorRelayIdentity? relayIdentity,
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
          relayIdentity: relayIdentity,
        );
        return const _FeishuMonitorEventDelivery(sentMedia: true);
      } catch (_) {
        if (!allowTextFallback ||
            _isFeishuMonitorMediaPlaceholderText(
              _forwardableEventText(event),
            )) {
          rethrow;
        }
        // If the image has a real caption, keep that text; never forward a
        // Feishu media placeholder as a successful message.
      }
    }
    await _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: formatFeishuMonitorEventForForward(event),
      relayIdentity: relayIdentity,
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
          return _withDefaultWorkerAssignments(
            FeishuMonitorForwardingSettings.fromJson(decoded),
          );
        }
        if (decoded is Map) {
          return _withDefaultWorkerAssignments(
            FeishuMonitorForwardingSettings.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
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

  FeishuMonitorForwardingSettings _withDefaultWorkerAssignments(
    FeishuMonitorForwardingSettings settings,
  ) {
    final routes = settings.routes;
    if (routes.isEmpty ||
        routes.every((route) => route.workerId.trim().isNotEmpty)) {
      return settings;
    }
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(
      routes.length,
    );
    return settings.copyWith(
      routes: <FeishuMonitorForwardingRoute>[
        for (var index = 0; index < routes.length; index += 1)
          routes[index].workerId.trim().isNotEmpty
              ? routes[index]
              : routes[index].copyWith(
                  workerId: workerIdForRouteIndex(index, workers),
                ),
      ],
    );
  }
}

String formatFeishuMonitorEventForForward(FeishuMonitorMessageEvent event) {
  final text = _forwardableEventText(event);
  return text.isEmpty ? '(空消息)' : text;
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

String _eventNetworkImageFingerprint(FeishuMonitorMessageEvent event) {
  if (event.captureSource.trim() != 'network_original_image') {
    return '';
  }
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
  return 'network_image_fingerprint:$dimensions:$digest';
}

String _eventRouteMediaBodyKey(
  FeishuMonitorForwardingRoute route,
  FeishuMonitorMessageEvent event,
) {
  if (event.captureSource.trim() != 'network_original_image') {
    return '';
  }
  final image = _firstUsableImageAttachmentForEvent(event);
  if (image == null || image.localPath.trim().isEmpty) {
    return '';
  }
  final routeScope = route.sourceConversationId.trim().isNotEmpty
      ? route.sourceConversationId.trim()
      : normalizeFeishuMonitorRouteName(route.sourceConversationName);
  if (routeScope.isEmpty) {
    return '';
  }
  final bodyKey = _networkImageBodyKey(event);
  if (bodyKey.isEmpty) {
    return '';
  }
  return 'network_original_image_body:$routeScope:$bodyKey';
}

String _eventRouteMediaFingerprintKey(
  FeishuMonitorForwardingRoute route,
  FeishuMonitorMessageEvent event,
) {
  if (event.captureSource.trim() != 'network_original_image') {
    return '';
  }
  final routeScope = route.sourceConversationId.trim().isNotEmpty
      ? route.sourceConversationId.trim()
      : normalizeFeishuMonitorRouteName(route.sourceConversationName);
  if (routeScope.isEmpty) {
    return '';
  }
  final fingerprint = _eventMediaFingerprint(event);
  if (fingerprint.isEmpty) {
    return '';
  }
  return 'network_original_image_fingerprint:$routeScope:$fingerprint';
}

String _eventGlobalNetworkImageBodyKey(FeishuMonitorMessageEvent event) {
  if (event.captureSource.trim() != 'network_original_image') {
    return '';
  }
  final bodyKey = _networkImageBodyKey(event);
  if (bodyKey.isEmpty) {
    return '';
  }
  return 'network_original_image_body_global:$bodyKey';
}

String _eventGlobalNetworkImageFingerprintKey(FeishuMonitorMessageEvent event) {
  if (event.captureSource.trim() != 'network_original_image') {
    return '';
  }
  final fingerprint = _eventMediaFingerprint(event);
  if (fingerprint.isEmpty) {
    return '';
  }
  return 'network_original_image_fingerprint_global:$fingerprint';
}

bool _shouldSkipRouteMediaBodyReplay({
  required FeishuMonitorForwardingRoute route,
  required FeishuMonitorMessageEvent event,
  required String routeMediaBodyKey,
  required Set<String> sentKeys,
}) {
  final routeMediaFingerprintKey = _eventRouteMediaFingerprintKey(route, event);
  if (routeMediaFingerprintKey.isNotEmpty &&
      sentKeys.contains(routeMediaFingerprintKey)) {
    return true;
  }
  if (routeMediaBodyKey.trim().isEmpty) {
    return false;
  }
  if (sentKeys.contains(routeMediaBodyKey.trim())) {
    return true;
  }
  return _sentKeysContainRouteMediaBodyKey(sentKeys, routeMediaBodyKey);
}

bool _shouldSkipGlobalNetworkImageReplay({
  required String globalNetworkImageBodyKey,
  required String globalNetworkImageFingerprintKey,
  required Set<String> sentKeys,
}) {
  if (globalNetworkImageFingerprintKey.trim().isNotEmpty &&
      sentKeys.contains(globalNetworkImageFingerprintKey.trim())) {
    return true;
  }
  if (globalNetworkImageBodyKey.trim().isEmpty) {
    return false;
  }
  if (sentKeys.contains(globalNetworkImageBodyKey.trim())) {
    return true;
  }
  return _sentKeysContainGlobalNetworkImageBodyKey(
    sentKeys,
    globalNetworkImageBodyKey,
  );
}

bool _sentKeysContainRouteMediaBodyKey(Set<String> sentKeys, String bodyKey) {
  final normalizedBodyKey = bodyKey.trim();
  if (normalizedBodyKey.isEmpty) {
    return false;
  }
  if (sentKeys.contains(normalizedBodyKey)) {
    return true;
  }
  const prefix = 'network_original_image_body:';
  if (!normalizedBodyKey.startsWith(prefix)) {
    return false;
  }
  final remainder = normalizedBodyKey.substring(prefix.length);
  final separator = remainder.lastIndexOf(':');
  if (separator <= 0 || separator >= remainder.length - 1) {
    return false;
  }
  final routeScope = remainder.substring(0, separator);
  final networkBodyKey = remainder.substring(separator + 1);
  final feedCardReplayParts = networkBodyKey.split('|');
  if (feedCardReplayParts.length == 2 &&
      feedCardReplayParts.first.trim().isNotEmpty &&
      feedCardReplayParts.last.trim().isNotEmpty) {
    final feedCardKey = feedCardReplayParts.first.trim();
    final imageBodyKey = feedCardReplayParts.last.trim();
    return sentKeys.any(
      (key) =>
          (key.startsWith('$routeScope:network_image:$feedCardKey:') &&
              key.endsWith(':$imageBodyKey')) ||
          (key.startsWith('$routeScope:network_image:$feedCardKey:') &&
              key.endsWith(':$imageBodyKey:media')),
    );
  }
  return sentKeys.any(
    (key) =>
        key == '$routeScope:network_image:$networkBodyKey' ||
        key == '$routeScope:network_image:$networkBodyKey:media' ||
        (key.startsWith('$routeScope:network_image:') &&
            key.endsWith(':$networkBodyKey')) ||
        (key.startsWith('$routeScope:network_image:') &&
            key.endsWith(':$networkBodyKey:media')),
  );
}

bool _sentKeysContainGlobalNetworkImageBodyKey(
  Set<String> sentKeys,
  String bodyKey,
) {
  final normalizedBodyKey = bodyKey.trim();
  if (normalizedBodyKey.isEmpty) {
    return false;
  }
  if (sentKeys.contains(normalizedBodyKey)) {
    return true;
  }
  const prefix = 'network_original_image_body_global:';
  if (!normalizedBodyKey.startsWith(prefix)) {
    return false;
  }
  final networkBodyKey = normalizedBodyKey.substring(prefix.length).trim();
  if (networkBodyKey.isEmpty) {
    return false;
  }
  final feedCardReplayParts = networkBodyKey.split('|');
  if (feedCardReplayParts.length == 2 &&
      feedCardReplayParts.first.trim().isNotEmpty &&
      feedCardReplayParts.last.trim().isNotEmpty) {
    final feedCardKey = feedCardReplayParts.first.trim();
    final imageBodyKey = feedCardReplayParts.last.trim();
    return sentKeys.any(
      (key) =>
          (key.contains(':network_image:$feedCardKey:') &&
              key.endsWith(':$imageBodyKey')) ||
          (key.contains(':network_image:$feedCardKey:') &&
              key.endsWith(':$imageBodyKey:media')),
    );
  }
  return sentKeys.any(
    (key) =>
        (key.contains(':network_image:') && key.endsWith(':$networkBodyKey')) ||
        (key.contains(':network_image:') &&
            key.endsWith(':$networkBodyKey:media')),
  );
}

String _networkImageBodyKey(FeishuMonitorMessageEvent event) {
  final messageKey = _networkImageBodyKeyFromParts(event.messageId.trim());
  if (messageKey.isNotEmpty) {
    return messageKey;
  }
  final dedupeKey = event.dedupeKey.trim();
  final dedupeParts = dedupeKey.split(':');
  final networkIndex = dedupeParts.indexOf('network_image');
  if (networkIndex >= 0 && networkIndex < dedupeParts.length - 1) {
    final dedupeNetworkKey = _networkImageBodyKeyFromParts(
      dedupeParts.sublist(networkIndex).join(':'),
    );
    if (dedupeNetworkKey.isNotEmpty) {
      return dedupeNetworkKey;
    }
  }
  final image = _firstUsableImageAttachmentForEvent(event);
  final localPath = image?.localPath.trim() ?? '';
  if (localPath.isEmpty) {
    return '';
  }
  return crypto.sha1.convert(utf8.encode(localPath)).toString();
}

String _networkImageBodyKeyFromParts(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 3 || parts.first != 'network_image') {
    return '';
  }
  final bodyKey = parts.last.trim();
  if (bodyKey.isEmpty) {
    return '';
  }
  final feedCardKey = parts[1].trim();
  if (feedCardKey.startsWith('feed_')) {
    return '$feedCardKey|$bodyKey';
  }
  return bodyKey;
}

bool _shouldDedupeMediaFingerprint(FeishuMonitorMessageEvent event) {
  return event.captureSource.trim() != 'network_original_image';
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

Set<String> _feedCardTextKeysFor(List<FeishuMonitorMessageEvent> events) {
  final keys = <String>{};
  for (final event in events) {
    if (event.captureSource.trim() != 'feed_card_probe') {
      continue;
    }
    if (_shouldSkipProbeTextEvent(event)) {
      continue;
    }
    final textKey = _textPayloadKeyFor(event);
    if (textKey.isNotEmpty) {
      keys.add(textKey);
    }
  }
  return keys;
}

bool _shouldSkipDomTextAlreadyCapturedByFeedCard(
  FeishuMonitorMessageEvent event,
  Set<String> feedCardTextKeys,
  Set<String> sentKeys,
) {
  if (!_isDomFallbackCaptureSource(event.captureSource)) {
    return false;
  }
  final textKey = _textPayloadKeyFor(event);
  if (textKey.isEmpty) {
    return false;
  }
  if (feedCardTextKeys.contains(textKey)) {
    return true;
  }
  final feedCardTextBodyKey = _feedCardTextBodyDedupeKeyFor(event);
  if (feedCardTextBodyKey.isNotEmpty &&
      (feedCardTextKeys.contains(feedCardTextBodyKey) ||
          sentKeys.contains(feedCardTextBodyKey))) {
    return true;
  }
  final persistedKey = _feedCardTextPayloadDedupeKeyFor(event);
  return persistedKey.isNotEmpty && sentKeys.contains(persistedKey);
}

String _eventRouteTextReplayKey(
  FeishuMonitorForwardingRoute route,
  FeishuMonitorMessageEvent event,
) {
  final textKey = _textPayloadKeyFor(event);
  if (textKey.isEmpty) {
    return '';
  }
  if (event.captureSource.trim() == 'feed_card_probe') {
    return '';
  }
  final routeScope = route.sourceConversationId.trim().isNotEmpty
      ? route.sourceConversationId.trim()
      : normalizeFeishuMonitorRouteName(route.sourceConversationName);
  if (routeScope.isEmpty) {
    return '';
  }
  final messageId = event.messageId.trim();
  if (messageId.isEmpty) {
    return '';
  }
  final payload = '$routeScope\n$messageId\n$textKey';
  return 'route_text_replay:${crypto.sha1.convert(utf8.encode(payload))}';
}

String _eventRouteDomTextBodyKey(
  FeishuMonitorForwardingRoute route,
  FeishuMonitorMessageEvent event,
) {
  final text = event.text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  if (text.isEmpty || _isFeishuMonitorMediaPlaceholderText(text)) {
    return '';
  }
  if (_rawFirstUsableImageAttachmentForEvent(event) != null) {
    return '';
  }
  final routeScope = route.sourceConversationId.trim().isNotEmpty
      ? route.sourceConversationId.trim()
      : normalizeFeishuMonitorRouteName(route.sourceConversationName);
  if (routeScope.isEmpty) {
    return '';
  }
  final payload = '$routeScope\n$text';
  return 'route_dom_text_body:${crypto.sha1.convert(utf8.encode(payload))}';
}

String _eventGlobalDomTextReplayKey(FeishuMonitorMessageEvent event) {
  if (!_isDomFallbackCaptureSource(event.captureSource)) {
    return '';
  }
  final text = event.text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  if (text.isEmpty || _isFeishuMonitorMediaPlaceholderText(text)) {
    return '';
  }
  final messageId = event.messageId.trim();
  if (messageId.isEmpty) {
    return '';
  }
  final payload = '$messageId\n$text';
  return 'dom_text_replay:${crypto.sha1.convert(utf8.encode(payload))}';
}

String _textPayloadKeyFor(FeishuMonitorMessageEvent event) {
  if (_rawFirstUsableImageAttachmentForEvent(event) != null) {
    return '';
  }
  final text = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty || _isFeishuMonitorMediaPlaceholderText(text)) {
    return '';
  }
  final conversationName = normalizeFeishuMonitorRouteName(
    event.conversationName,
  );
  if (conversationName.isEmpty) {
    return '';
  }
  return '$conversationName\n${text.toLowerCase()}';
}

String _feedCardTextPayloadDedupeKeyFor(FeishuMonitorMessageEvent event) {
  final key = _textPayloadKeyFor(event);
  if (key.isEmpty) {
    return '';
  }
  return 'feed_card_text_payload:${crypto.sha1.convert(utf8.encode(key))}';
}

String _feedCardTextBodyDedupeKeyFor(FeishuMonitorMessageEvent event) {
  if (_rawFirstUsableImageAttachmentForEvent(event) != null) {
    return '';
  }
  final text = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty || _isFeishuMonitorMediaPlaceholderText(text)) {
    return '';
  }
  return 'feed_card_text_body:'
      '${crypto.sha1.convert(utf8.encode(text.toLowerCase()))}';
}

bool _shouldSkipProbeTextEvent(FeishuMonitorMessageEvent event) {
  if (_isFeishuMonitorSystemNoticeEvent(event)) {
    return true;
  }
  final captureSource = event.captureSource.trim();
  if (captureSource == 'feed_card_probe' &&
      _isFeishuMonitorMediaPlaceholderText(event.text)) {
    return _firstUsableImageAttachmentForEvent(event) == null;
  }
  if (captureSource == 'network_original_image' &&
      _isFeishuMonitorMediaPlaceholderText(event.text)) {
    return _firstUsableImageAttachmentForEvent(event) == null;
  }
  if (!_isDomFallbackCaptureSource(captureSource)) {
    return false;
  }
  if (captureSource == 'body_text_probe') {
    return true;
  }
  if (_rawFirstUsableImageAttachmentForEvent(event) != null) {
    return true;
  }
  return _isLegacyDomTextNoise(event);
}

bool _isFeishuMonitorSystemNoticeEvent(FeishuMonitorMessageEvent event) {
  final normalized = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_isFeishuMonitorSystemNoticeText(normalized)) {
    return true;
  }
  final senderName = event.senderName.replaceAll(RegExp(r'\s+'), ' ').trim();
  final conversationName = event.conversationName
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final fromOfficialAssistant =
      senderName == '机器人' ||
      senderName.contains('飞书') ||
      conversationName.contains('飞书') ||
      conversationName.contains('助手') ||
      conversationName.contains('安全中心');
  return fromOfficialAssistant &&
      _isFeishuMonitorOfficialAssistantNoticeText(normalized);
}

bool _isFeishuMonitorSystemNoticeText(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (RegExp(r'^\d+\s*条新消息$').hasMatch(normalized)) {
    return true;
  }
  if (normalized.contains('二维码加入此群') &&
      normalized.contains('新成员') &&
      (normalized.contains('通过扫描') ||
          normalized.contains('通过 ') ||
          normalized.contains('分享的二维码')) &&
      (normalized.contains('入群可查看') || normalized.contains('仅可查看入群后的消息'))) {
    return true;
  }
  return _isFeishuMonitorOfficialAssistantNoticeText(normalized);
}

bool _isFeishuMonitorOfficialAssistantNoticeText(String normalized) {
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == '举报成立' ||
      normalized == '安全登录通知' ||
      normalized == '联系人申请' ||
      normalized == '猜您想问以下问题') {
    return true;
  }
  if (normalized.contains('经飞书团队核实') && normalized.contains('举报详情')) {
    return true;
  }
  if (normalized.contains('举报对象') && normalized.contains('举报理由')) {
    return true;
  }
  if (normalized.contains('涉嫌违规') && normalized.contains('感谢你对飞书安全秩序的维护')) {
    return true;
  }
  return normalized.contains('飞书官方专属智能伙伴开放限时体验');
}

bool _isDomFallbackCaptureSource(String captureSource) {
  final normalized = captureSource.trim();
  return normalized == 'dom_probe' || normalized == 'body_text_probe';
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

bool _isLegacyDomTextNoise(FeishuMonitorMessageEvent event) {
  final normalized = event.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty || _isFeishuMonitorMediaPlaceholderText(normalized)) {
    return true;
  }
  if (_isFeishuMonitorLoadingPlaceholderText(normalized)) {
    return true;
  }
  if (RegExp(
    r'^(?:\d{1,2}:\d{2}|昨天|前天|\d{1,2}月\d{1,2}日)$',
  ).hasMatch(normalized)) {
    return true;
  }
  final senderName = event.senderName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (senderName.isNotEmpty && normalized == senderName) {
    return true;
  }
  final conversationName = event.conversationName
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (conversationName.isNotEmpty && normalized == conversationName) {
    return true;
  }
  if (event.messageId.trim().startsWith('dom:history')) {
    return true;
  }
  final shellTokenCount = <String>[
    '鑷畾涔夋満鍣ㄤ汉',
    '鏈哄櫒浜',
    '宸ヤ綔鍙',
    '璐﹀彿瀹夊叏涓績',
    'Ctrl+K',
  ].where(normalized.contains).length;
  return normalized.length > 40 && shellTokenCount >= 2;
}

bool _isFeishuMonitorLoadingPlaceholderText(String value) {
  final normalized = value.trim();
  return normalized == '正在加载...' ||
      normalized == '正在加载…' ||
      normalized.toLowerCase() == 'loading...';
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
  final captureSource = event.captureSource.trim();
  if (captureSource == 'body_text_probe' || captureSource == 'dom_probe') {
    return null;
  }
  final image = _rawFirstUsableImageAttachmentForEvent(event);
  if (captureSource == 'network_original_image' &&
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
  if (_isDomFallbackCaptureSource(event.captureSource)) {
    final idMatch = _findRouteByConversationId(eligibleRoutes, event);
    final nameMatch = _findRouteByConversationName(eligibleRoutes, event);
    if (idMatch != null && nameMatch != null) {
      return identical(idMatch, nameMatch) ? idMatch : null;
    }
    if (idMatch != null) {
      final eventName = normalizeFeishuMonitorRouteName(event.conversationName);
      final routeName = normalizeFeishuMonitorRouteName(
        idMatch.sourceConversationName,
      );
      if (eventName.isEmpty || routeName.isEmpty || eventName == routeName) {
        return idMatch;
      }
      return null;
    }
    if (event.conversationId.trim().isNotEmpty) {
      return null;
    }
    if (nameMatch != null) {
      return nameMatch;
    }
    return null;
  }
  final idMatch = _findRouteByConversationId(eligibleRoutes, event);
  if (idMatch != null) {
    return idMatch;
  }
  if (event.conversationId.trim().isNotEmpty) {
    return null;
  }

  return _findRouteByConversationName(eligibleRoutes, event);
}

FeishuMonitorForwardingRoute? _findRouteByConversationId(
  List<FeishuMonitorForwardingRoute> routes,
  FeishuMonitorMessageEvent event,
) {
  final conversationId = event.conversationId.trim();
  if (conversationId.isEmpty) {
    return null;
  }
  final matches = routes
      .where((route) => route.sourceConversationId.trim() == conversationId)
      .toList(growable: false);
  if (matches.length == 1) {
    return matches.single;
  }
  return null;
}

FeishuMonitorForwardingRoute? _findRouteByConversationName(
  List<FeishuMonitorForwardingRoute> routes,
  FeishuMonitorMessageEvent event,
) {
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
    return null;
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

bool _hasConflictingDomRouteMatches({
  required List<FeishuMonitorForwardingRoute> routes,
  required FeishuMonitorMessageEvent event,
}) {
  if (!_isDomFallbackCaptureSource(event.captureSource)) {
    return false;
  }
  final eligibleRoutes = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final idMatch = _findRouteByConversationId(eligibleRoutes, event);
  final nameMatch = _findRouteByConversationName(eligibleRoutes, event);
  return idMatch != null && nameMatch != null && !identical(idMatch, nameMatch);
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
