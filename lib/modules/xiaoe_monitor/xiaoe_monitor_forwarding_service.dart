import 'dart:io';

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart'
    show FeishuMonitorImageUploader, prepareFeishuMonitorImageForWkUpload;
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart'
    show FeishuMonitorImageAttachment;
import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'xiaoe_monitor_shell_models.dart';

const String xiaoeMonitorForwardingSettingsStorageKey =
    'xiaoe_monitor_forwarding_settings_v1';
const String xiaoeMonitorForwardedDedupeStorageKey =
    'xiaoe_monitor_forwarded_dedupe_keys_v1';
const int xiaoeMonitorMaxForwardableFileBytes = 20 * 1024 * 1024;
const String xiaoeMonitorDefaultRelayDisplayName = '小鹅通转发助手';
const Duration xiaoeMonitorForwardedFileCacheRetention = Duration(hours: 24);

class XiaoeMonitorForwardingRoute {
  const XiaoeMonitorForwardingRoute({
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

  factory XiaoeMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return XiaoeMonitorForwardingRoute(
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

  XiaoeMonitorRelayIdentity relayIdentity({
    String defaultDisplayName = xiaoeMonitorDefaultRelayDisplayName,
  }) {
    return XiaoeMonitorRelayIdentity(
      provider: 'xiaoe',
      displayName: relayDisplayName.trim().isNotEmpty
          ? relayDisplayName.trim()
          : defaultDisplayName,
      avatar: relayAvatar.trim(),
    );
  }
}

class XiaoeMonitorForwardingSettings {
  const XiaoeMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <XiaoeMonitorForwardingRoute>[],
  });

  final bool enabled;
  final List<XiaoeMonitorForwardingRoute> routes;

  factory XiaoeMonitorForwardingSettings.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    return XiaoeMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return XiaoeMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return XiaoeMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<XiaoeMonitorForwardingRoute>()
                .toList(growable: false)
          : const <XiaoeMonitorForwardingRoute>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
    };
  }

  XiaoeMonitorForwardingSettings copyWith({
    bool? enabled,
    List<XiaoeMonitorForwardingRoute>? routes,
  }) {
    return XiaoeMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
    );
  }
}

class XiaoeMonitorForwardingDiagnostic {
  const XiaoeMonitorForwardingDiagnostic({
    required this.code,
    required this.message,
    this.eventId = '',
    this.fileName = '',
    this.sizeBytes = 0,
  });

  final String code;
  final String message;
  final String eventId;
  final String fileName;
  final int sizeBytes;
}

class XiaoeMonitorForwardingResult {
  const XiaoeMonitorForwardingResult({
    required this.sent,
    this.skippedDuplicate = 0,
    this.skippedUnmatched = 0,
    this.skippedDisabled = 0,
    this.skippedOversizedFile = 0,
    this.skippedUnsupportedFile = 0,
    required this.failed,
    this.diagnostics = const <XiaoeMonitorForwardingDiagnostic>[],
  });

  final int sent;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int skippedOversizedFile;
  final int skippedUnsupportedFile;
  final int failed;
  final List<XiaoeMonitorForwardingDiagnostic> diagnostics;

  int get skipped =>
      skippedDuplicate +
      skippedUnmatched +
      skippedDisabled +
      skippedOversizedFile +
      skippedUnsupportedFile;
}

typedef XiaoeMonitorRelayIdentity = LocalMonitorRelayIdentity;
typedef XiaoeMonitorForwardingDedupeStore = LocalMonitorForwardingDedupeStore;

abstract class XiaoeMonitorMediaSender
    implements
        LocalMonitorTextSender,
        LocalMonitorImageSender,
        LocalMonitorFileSender {}

class WkImXiaoeMonitorMediaSender implements XiaoeMonitorMediaSender {
  WkImXiaoeMonitorMediaSender({
    LocalMonitorTextSender? textSender,
    LocalMonitorImageSender? imageSender,
    LocalMonitorFileSender? fileSender,
    LocalMonitorImagePreparer? prepareImage,
    FeishuMonitorImageUploader? uploadImage,
    LocalMonitorFilePreparer? prepareFile,
    LocalMonitorFileUploader? uploadFile,
  }) : _textSender = textSender ?? WkImLocalMonitorTextSender(),
       _imageSender =
           imageSender ??
           WkImLocalMonitorImageSender(
             prepareImage: prepareImage ?? _prepareXiaoeMonitorImageForWkUpload,
             uploadImage: uploadImage ?? _uploadXiaoeMonitorImageForWk,
           ),
       _fileSender =
           fileSender ??
           WkImLocalMonitorFileSender(
             prepareFile: prepareFile ?? prepareXiaoeMonitorFileForWkUpload,
             uploadFile: uploadFile ?? _uploadXiaoeMonitorFileForWk,
             maxFileBytes: xiaoeMonitorMaxForwardableFileBytes,
           );

  final LocalMonitorTextSender _textSender;
  final LocalMonitorImageSender _imageSender;
  final LocalMonitorFileSender _fileSender;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    XiaoeMonitorRelayIdentity? relayIdentity,
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
    XiaoeMonitorRelayIdentity? relayIdentity,
  }) {
    return _imageSender.sendImage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      image: image,
      relayIdentity: relayIdentity,
    );
  }

  @override
  Future<void> sendFile({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableFile file,
    XiaoeMonitorRelayIdentity? relayIdentity,
  }) {
    return _fileSender.sendFile(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      file: file,
      relayIdentity: relayIdentity,
    );
  }
}

class SharedPreferencesXiaoeMonitorForwardingDedupeStore
    implements XiaoeMonitorForwardingDedupeStore {
  const SharedPreferencesXiaoeMonitorForwardingDedupeStore();

  @override
  Future<List<String>> loadSentKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(xiaoeMonitorForwardedDedupeStorageKey) ??
        const <String>[];
  }

  @override
  Future<void> saveSentKeys(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(xiaoeMonitorForwardedDedupeStorageKey, keys);
  }
}

abstract class XiaoeMonitorForwardingSettingsStore {
  Future<XiaoeMonitorForwardingSettings> load();
  Future<void> save(XiaoeMonitorForwardingSettings settings);
}

class SharedPreferencesXiaoeMonitorForwardingSettingsStore
    implements XiaoeMonitorForwardingSettingsStore {
  const SharedPreferencesXiaoeMonitorForwardingSettingsStore();

  @override
  Future<XiaoeMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(xiaoeMonitorForwardingSettingsStorageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const XiaoeMonitorForwardingSettings(enabled: false);
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        return XiaoeMonitorForwardingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return XiaoeMonitorForwardingSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on FormatException {
      return const XiaoeMonitorForwardingSettings(enabled: false);
    } on TypeError {
      return const XiaoeMonitorForwardingSettings(enabled: false);
    }
    return const XiaoeMonitorForwardingSettings(enabled: false);
  }

  @override
  Future<void> save(XiaoeMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      xiaoeMonitorForwardingSettingsStorageKey,
      jsonEncode(settings.toJson()),
    );
  }
}

class XiaoeMonitorForwardingService {
  XiaoeMonitorForwardingService({
    XiaoeMonitorMediaSender? sender,
    XiaoeMonitorForwardingDedupeStore? dedupeStore,
  }) : _sender = sender ?? WkImXiaoeMonitorMediaSender(),
       _dedupeStore =
           dedupeStore ??
           const SharedPreferencesXiaoeMonitorForwardingDedupeStore();

  final XiaoeMonitorMediaSender _sender;
  final XiaoeMonitorForwardingDedupeStore _dedupeStore;
  final Set<String> _sentKeys = <String>{};
  bool _sentKeysLoaded = false;
  static final Set<String> _inFlightKeys = <String>{};
  static const int _maxPersistedSentKeys = 500;

  Future<void> primeRoutedRecentEvents({
    required XiaoeMonitorForwardingSettings settings,
    required Iterable<XiaoeMonitorMessageEvent> events,
  }) async {
    if (!settings.enabled) {
      return;
    }
    await _loadPersistedSentKeys();
    var changed = false;
    for (final event in events) {
      final route = findXiaoeMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null ||
          route.targetGroupId.trim().isEmpty ||
          !_hasForwardablePayload(event)) {
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

  Future<XiaoeMonitorForwardingResult> forwardRoutedRecentEvents({
    required XiaoeMonitorForwardingSettings settings,
    required Iterable<XiaoeMonitorMessageEvent> events,
  }) async {
    final eventList = events.toList(growable: false);
    if (!settings.enabled) {
      return XiaoeMonitorForwardingResult(
        sent: 0,
        skippedDisabled: eventList.length,
        failed: 0,
      );
    }

    await _loadPersistedSentKeys();
    var sent = 0;
    var skippedDuplicate = 0;
    var skippedUnmatched = 0;
    var skippedDisabled = 0;
    var skippedOversizedFile = 0;
    var skippedUnsupportedFile = 0;
    var failed = 0;
    final diagnostics = <XiaoeMonitorForwardingDiagnostic>[];

    for (final event in eventList) {
      final route = findXiaoeMonitorRouteForEvent(
        routes: settings.routes,
        event: event,
      );
      if (route == null) {
        final disabledCandidate = _findXiaoeMonitorRouteCandidateForEvent(
          routes: settings.routes,
          event: event,
        );
        if (disabledCandidate == null) {
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
      if (!_hasForwardablePayload(event)) {
        skippedUnmatched += 1;
        continue;
      }

      final fileSkip = _fileSkipDiagnostic(event);
      if (fileSkip != null) {
        skippedOversizedFile += fileSkip.code == 'file_too_large' ? 1 : 0;
        skippedUnsupportedFile += fileSkip.code == 'file_unsupported' ? 1 : 0;
        diagnostics.add(fileSkip);
        _markEventSentIfPossible(event);
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
      } on LocalMonitorFileTooLargeException catch (error) {
        skippedOversizedFile += 1;
        diagnostics.add(
          XiaoeMonitorForwardingDiagnostic(
            code: 'file_too_large',
            message: 'Xiaoe file exceeds the 20 MB forwarding limit.',
            eventId: event.eventId,
            fileName: error.fileName,
            sizeBytes: error.sizeBytes,
          ),
        );
        _sentKeys.add(key);
        await _persistSentKeys();
      } catch (_) {
        failed += 1;
      } finally {
        _releaseInFlightKey(key);
      }
    }

    return XiaoeMonitorForwardingResult(
      sent: sent,
      skippedDuplicate: skippedDuplicate,
      skippedUnmatched: skippedUnmatched,
      skippedDisabled: skippedDisabled,
      skippedOversizedFile: skippedOversizedFile,
      skippedUnsupportedFile: skippedUnsupportedFile,
      failed: failed,
      diagnostics: List<XiaoeMonitorForwardingDiagnostic>.unmodifiable(
        diagnostics,
      ),
    );
  }

  Future<void> _sendEventToTarget({
    required XiaoeMonitorMessageEvent event,
    required String channelId,
    required int channelType,
    required String channelName,
    XiaoeMonitorRelayIdentity? relayIdentity,
  }) async {
    final file = _firstUsableFileAttachment(event);
    if (file != null) {
      await _sender.sendFile(
        channelId: channelId,
        channelType: channelType,
        channelName: channelName,
        file: _forwardableFile(file),
        relayIdentity: relayIdentity,
      );
      return;
    }
    final image = _firstUsableImageAttachment(event);
    if (image != null) {
      await _sender.sendImage(
        channelId: channelId,
        channelType: channelType,
        channelName: channelName,
        image: LocalMonitorForwardableImage(
          sourceUrl: image.sourceUrl,
          localPath: image.localPath,
          width: image.width,
          height: image.height,
        ),
        relayIdentity: relayIdentity,
      );
      return;
    }
    await _sender.sendText(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      text: formatXiaoeMonitorEventForForward(event),
      relayIdentity: relayIdentity,
    );
  }

  Future<void> _loadPersistedSentKeys() async {
    if (_sentKeysLoaded) {
      return;
    }
    _sentKeysLoaded = true;
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

  Future<void> _markEventSentIfPossible(XiaoeMonitorMessageEvent event) async {
    final key = _eventDedupeKey(event);
    if (key.isEmpty) {
      return;
    }
    _sentKeys.add(key);
    await _persistSentKeys();
  }
}

XiaoeMonitorForwardingRoute? findXiaoeMonitorRouteForEvent({
  required List<XiaoeMonitorForwardingRoute> routes,
  required XiaoeMonitorMessageEvent event,
}) {
  final eligibleRoutes = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final eventConversationId = event.conversationId.trim();
  if (eventConversationId.isNotEmpty) {
    final matches = eligibleRoutes
        .where(
          (route) => route.sourceConversationId.trim() == eventConversationId,
        )
        .toList(growable: false);
    if (matches.length == 1) {
      return matches.single;
    }
    return null;
  }

  return _findEnabledXiaoeRouteByName(eligibleRoutes, event.conversationName);
}

XiaoeMonitorForwardingRoute? _findEnabledXiaoeRouteByName(
  List<XiaoeMonitorForwardingRoute> routes,
  String conversationName,
) {
  final normalizedName = normalizeXiaoeMonitorRouteName(conversationName);
  if (normalizedName.isEmpty) {
    return null;
  }
  final matches = routes
      .where(
        (route) =>
            normalizeXiaoeMonitorRouteName(route.sourceConversationName) ==
            normalizedName,
      )
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

XiaoeMonitorForwardingRoute? _findXiaoeMonitorRouteCandidateForEvent({
  required List<XiaoeMonitorForwardingRoute> routes,
  required XiaoeMonitorMessageEvent event,
}) {
  final eventConversationId = event.conversationId.trim();
  if (eventConversationId.isNotEmpty) {
    final matches = routes
        .where(
          (route) => route.sourceConversationId.trim() == eventConversationId,
        )
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }
  return _findAnyXiaoeRouteByName(routes, event.conversationName);
}

XiaoeMonitorForwardingRoute? _findAnyXiaoeRouteByName(
  List<XiaoeMonitorForwardingRoute> routes,
  String conversationName,
) {
  final normalizedName = normalizeXiaoeMonitorRouteName(conversationName);
  if (normalizedName.isEmpty) {
    return null;
  }
  final matches = routes
      .where(
        (route) =>
            normalizeXiaoeMonitorRouteName(route.sourceConversationName) ==
            normalizedName,
      )
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

String normalizeXiaoeMonitorRouteName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String formatXiaoeMonitorEventForForward(XiaoeMonitorMessageEvent event) {
  final text = event.text.trim();
  return text.isEmpty ? '(空消息)' : text;
}

bool _hasForwardablePayload(XiaoeMonitorMessageEvent event) {
  return event.isForwardableText ||
      _firstUsableImageAttachment(event) != null ||
      _firstUsableFileAttachment(event) != null;
}

XiaoeMonitorImageAttachment? _firstUsableImageAttachment(
  XiaoeMonitorMessageEvent event,
) {
  for (final image in event.imageAttachments) {
    if (image.hasUsableSource) {
      return image;
    }
  }
  return null;
}

XiaoeMonitorFileAttachment? _firstUsableFileAttachment(
  XiaoeMonitorMessageEvent event,
) {
  for (final file in event.fileAttachments) {
    if (file.hasUsableSource) {
      return file;
    }
  }
  return null;
}

LocalMonitorForwardableFile _forwardableFile(XiaoeMonitorFileAttachment file) {
  return LocalMonitorForwardableFile(
    sourceUrl: file.sourceUrl,
    localPath: file.localPath,
    fileName: file.fileName,
    mimeType: file.mimeType,
    sizeBytes: file.sizeBytes,
  );
}

XiaoeMonitorForwardingDiagnostic? _fileSkipDiagnostic(
  XiaoeMonitorMessageEvent event,
) {
  final file = _firstUsableFileAttachment(event);
  if (file == null) {
    return null;
  }
  if (file.sizeBytes > xiaoeMonitorMaxForwardableFileBytes) {
    return XiaoeMonitorForwardingDiagnostic(
      code: 'file_too_large',
      message: 'Xiaoe file exceeds the 20 MB forwarding limit.',
      eventId: event.eventId,
      fileName: file.fileName,
      sizeBytes: file.sizeBytes,
    );
  }
  final sourceUrl = file.sourceUrl.trim();
  if (file.localPath.trim().isEmpty &&
      sourceUrl.isNotEmpty &&
      !_isDownloadableXiaoeFileUrl(sourceUrl)) {
    return XiaoeMonitorForwardingDiagnostic(
      code: 'file_unsupported',
      message: 'Xiaoe file source is not downloadable outside the WebView.',
      eventId: event.eventId,
      fileName: file.fileName,
      sizeBytes: file.sizeBytes,
    );
  }
  return null;
}

String _eventDedupeKey(XiaoeMonitorMessageEvent event) {
  final dedupeKey = localMonitorMessageDedupeKey(
    dedupeKey: event.dedupeKey,
    eventId: event.eventId,
    messageId: event.messageId,
  );
  if (dedupeKey.trim().isNotEmpty) {
    return 'xiaoe:$dedupeKey';
  }
  final sourceScope = event.conversationId.trim().isNotEmpty
      ? event.conversationId.trim()
      : normalizeXiaoeMonitorRouteName(event.conversationName);
  final body = <String>[
    event.messageId,
    event.senderName,
    event.text,
    ...event.imageAttachments.map(_imageDedupeSource),
    ...event.fileAttachments.map(_fileDedupeSource),
  ].join('\n').trim();
  if (sourceScope.isEmpty || body.isEmpty) {
    return '';
  }
  return 'xiaoe:$sourceScope:${crypto.sha1.convert(utf8.encode(body))}';
}

String _imageDedupeSource(XiaoeMonitorImageAttachment image) {
  return <String>[
    image.sourceUrl,
    image.localPath,
    image.width.toString(),
    image.height.toString(),
  ].join(':');
}

String _fileDedupeSource(XiaoeMonitorFileAttachment file) {
  return <String>[
    file.sourceUrl,
    file.localPath,
    file.fileName,
    file.sizeBytes.toString(),
  ].join(':');
}

Future<LocalMonitorForwardableImage> _prepareXiaoeMonitorImageForWkUpload(
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

Future<LocalMonitorForwardableFile> prepareXiaoeMonitorFileForWkUpload(
  LocalMonitorForwardableFile file, {
  Directory? fileDirectory,
}) async {
  final localPath = file.localPath.trim();
  if (localPath.isNotEmpty && await File(localPath).exists()) {
    return file;
  }
  await cleanupXiaoeMonitorForwardedFileCache(fileDirectory: fileDirectory);

  final sourceUrl = file.sourceUrl.trim();
  if (!_isDownloadableXiaoeFileUrl(sourceUrl)) {
    return file;
  }
  final uri = Uri.tryParse(sourceUrl);
  if (uri == null) {
    return file;
  }

  final client = HttpClient();
  File? targetFile;
  IOSink? sink;
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return file;
    }
    final contentLength = response.contentLength;
    if (contentLength > xiaoeMonitorMaxForwardableFileBytes) {
      throw LocalMonitorFileTooLargeException(
        fileName: _xiaoeMonitorDownloadFileName(file, uri),
        sizeBytes: contentLength,
        maxBytes: xiaoeMonitorMaxForwardableFileBytes,
      );
    }

    final directory = await _xiaoeMonitorFileDirectory(fileDirectory);
    final digest = crypto.sha1.convert(utf8.encode(sourceUrl)).toString();
    final safeName = _xiaoeMonitorDownloadFileName(file, uri);
    final extension = _safeXiaoeMonitorFileExtension(safeName);
    targetFile = File(path.join(directory.path, '$digest$extension'));
    final output = targetFile.openWrite();
    sink = output;
    var downloaded = 0;
    await for (final chunk in response) {
      downloaded += chunk.length;
      if (downloaded > xiaoeMonitorMaxForwardableFileBytes) {
        await output.close();
        sink = null;
        await targetFile.delete();
        throw LocalMonitorFileTooLargeException(
          fileName: safeName,
          sizeBytes: downloaded,
          maxBytes: xiaoeMonitorMaxForwardableFileBytes,
        );
      }
      output.add(chunk);
    }
    await output.close();
    sink = null;
    if (downloaded <= 0) {
      await targetFile.delete();
      return file;
    }
    return file.copyWith(
      localPath: targetFile.path,
      fileName: safeName,
      sizeBytes: file.sizeBytes > 0 ? file.sizeBytes : downloaded,
    );
  } finally {
    if (sink != null) {
      await sink.close();
    }
    client.close(force: true);
  }
}

Future<int> cleanupXiaoeMonitorForwardedFileCache({
  Directory? fileDirectory,
  DateTime? now,
  Duration retention = xiaoeMonitorForwardedFileCacheRetention,
}) async {
  final directory = await _xiaoeMonitorFileDirectory(fileDirectory);
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

Future<String> _uploadXiaoeMonitorImageForWk({
  required String filePath,
  required String channelId,
  required int channelType,
}) {
  return FileApi.instance.uploadChatFileAtPath(
    filePath: filePath,
    uploadPath:
        '/xiaoe-monitor/images/$channelType/'
        '${_safeXiaoeMonitorObjectPathSegment(channelId)}/'
        '${DateTime.now().toUtc().millisecondsSinceEpoch}'
        '${_safeXiaoeMonitorFileExtension(filePath)}',
  );
}

Future<String> _uploadXiaoeMonitorFileForWk({
  required String filePath,
  required String channelId,
  required int channelType,
  required String fileName,
}) {
  return FileApi.instance.uploadChatFileAtPath(
    filePath: filePath,
    uploadPath:
        '/xiaoe-monitor/files/$channelType/'
        '${_safeXiaoeMonitorObjectPathSegment(channelId)}/'
        '${DateTime.now().toUtc().millisecondsSinceEpoch}'
        '${_safeXiaoeMonitorFileExtension(fileName.isEmpty ? filePath : fileName)}',
  );
}

String _safeXiaoeMonitorObjectPathSegment(String value) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'[\\/]+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceFirst(RegExp(r'^[._-]+'), '')
      .replaceFirst(RegExp(r'[._-]+$'), '');
  return normalized.isEmpty ? 'channel' : normalized;
}

String _safeXiaoeMonitorFileExtension(String filePath) {
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

bool _isDownloadableXiaoeFileUrl(String sourceUrl) {
  final uri = Uri.tryParse(sourceUrl.trim());
  if (uri == null) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.trim().isNotEmpty;
}

Future<Directory> _xiaoeMonitorFileDirectory(Directory? fileDirectory) async {
  final directory =
      fileDirectory ??
      Directory(
        path.join((await getTemporaryDirectory()).path, 'xiaoe_monitor_files'),
      );
  await directory.create(recursive: true);
  return directory;
}

String _xiaoeMonitorDownloadFileName(
  LocalMonitorForwardableFile file,
  Uri uri,
) {
  final fromEvent = _safeXiaoeMonitorPathSegment(file.fileName);
  if (fromEvent.isNotEmpty) {
    return fromEvent;
  }
  final fromUrl = _safeXiaoeMonitorPathSegment(path.basename(uri.path));
  return fromUrl.isEmpty ? 'xiaoe-file' : fromUrl;
}

String _safeXiaoeMonitorPathSegment(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  if (cleaned.isEmpty) {
    return '';
  }
  final segments = cleaned
      .split(RegExp(r'[\\/]+'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .where((segment) => segment != '.' && segment != '..')
      .toList(growable: false);
  if (segments.isEmpty) {
    return '';
  }
  return segments.last;
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
