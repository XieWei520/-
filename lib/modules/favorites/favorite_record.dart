import 'dart:convert';

import '../../core/config/api_config.dart';

class FavoriteRecord {
  const FavoriteRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.contentType,
    required this.createdAt,
    this.clientMsgNo,
    this.messageId,
    this.channelId,
    this.channelType,
    this.messageSeq,
    this.orderSeq,
    this.openUrl,
    this.openLocalPath,
  });

  factory FavoriteRecord.fromMap(Map<String, dynamic> payload) {
    final contentType = _readInt(payload, 'content_type');
    final createdAt = _readDateTime(payload['created_at']);
    final rawContent = payload['content'];
    final content = _normalizeContent(rawContent, contentType: contentType);
    final senderName = _readText(payload, 'sender_name');
    final senderUid = _readText(payload, 'sender_uid');
    final title = senderName.isNotEmpty
        ? senderName
        : (senderUid.isNotEmpty ? senderUid : _contentTypeLabel(contentType));
    final subtitleParts = <String>[
      _contentTypeLabel(contentType),
      if (createdAt != null) _formatDateTime(createdAt),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);

    final channelId = _readOptionalText(payload, 'channel_id');
    final channelType = _readOptionalInt(payload, 'channel_type');
    final messageSeq = _readOptionalInt(payload, 'message_seq');
    final orderSeq = _readOptionalInt(payload, 'order_seq');

    return FavoriteRecord(
      id: _readText(payload, 'id'),
      title: title,
      subtitle: subtitleParts.join(' · '),
      content: content,
      contentType: contentType,
      createdAt: createdAt,
      clientMsgNo: _readOptionalText(payload, 'client_msg_no'),
      messageId: _readOptionalText(payload, 'message_id'),
      channelId: channelId,
      channelType: channelType,
      messageSeq: messageSeq,
      orderSeq: orderSeq,
      openUrl: _resolveOpenUrl(rawContent),
      openLocalPath: _resolveOpenLocalPath(rawContent),
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String content;
  final int contentType;
  final DateTime? createdAt;
  final String? clientMsgNo;
  final String? messageId;
  final String? channelId;
  final int? channelType;
  final int? messageSeq;
  final int? orderSeq;
  final String? openUrl;
  final String? openLocalPath;

  bool get hasChatRoute {
    final resolvedChannelId = channelId?.trim() ?? '';
    final resolvedChannelType = channelType ?? 0;
    return resolvedChannelId.isNotEmpty && resolvedChannelType > 0;
  }

  bool get hasServerOrderAnchor {
    final resolvedOrderSeq = orderSeq ?? 0;
    return hasChatRoute && resolvedOrderSeq > 0;
  }

  bool get hasTrustedLocateRoute {
    return hasServerOrderAnchor;
  }

  bool get canOpenExternally {
    final normalizedLocalPath = openLocalPath?.trim() ?? '';
    final normalizedOpenUrl = openUrl?.trim() ?? '';
    return normalizedLocalPath.isNotEmpty || normalizedOpenUrl.isNotEmpty;
  }

  Uri? get externalUri {
    final normalizedLocalPath = openLocalPath?.trim() ?? '';
    if (normalizedLocalPath.isNotEmpty) {
      return _toFileUri(normalizedLocalPath);
    }
    final normalizedOpenUrl = openUrl?.trim() ?? '';
    if (normalizedOpenUrl.isEmpty) {
      return null;
    }
    return Uri.tryParse(normalizedOpenUrl);
  }

  static int _readInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static int? _readOptionalInt(Map<String, dynamic> payload, String key) {
    final value = _readInt(payload, key);
    if (value <= 0) {
      return null;
    }
    return value;
  }

  static String _readText(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }

  static String? _readOptionalText(Map<String, dynamic> payload, String key) {
    final value = _readText(payload, key);
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  static String _normalizeContent(dynamic raw, {required int contentType}) {
    final payload = _coercePayloadMap(raw);
    if (payload != null) {
      return _normalizeStructuredContent(payload, contentType: contentType);
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    if (raw == null) {
      return _contentTypeLabel(contentType);
    }
    final value = raw.toString().trim();
    return value.isNotEmpty ? value : _contentTypeLabel(contentType);
  }

  static String _normalizeStructuredContent(
    Map<String, dynamic> payload, {
    required int contentType,
  }) {
    switch (contentType) {
      case 1:
        return _firstNonEmpty(payload, const [
          'content',
          'text',
          'title',
          'name',
        ]).ifEmpty('文本');
      case 2:
        return _firstNonEmpty(payload, const [
          'title',
          'name',
          'file_name',
        ]).ifEmpty('图片');
      case 3:
        final seconds = _readStructuredInt(payload, const [
          'duration',
          'time',
          'timeTrad',
        ]);
        return seconds > 0 ? '语音 $seconds"' : '语音';
      case 4:
        return _firstNonEmpty(payload, const ['title', 'name']).ifEmpty('视频');
      case 5:
        return _firstNonEmpty(payload, const [
          'name',
          'file_name',
          'title',
          'content',
        ]).ifEmpty('文件');
      case 6:
        return _firstNonEmpty(payload, const [
          'title',
          'name',
          'address',
        ]).ifEmpty('位置');
      case 7:
        return _firstNonEmpty(payload, const [
          'name',
          'nickname',
          'uid',
        ]).ifEmpty('名片');
      default:
        return _firstNonEmpty(payload, const [
          'content',
          'text',
          'title',
          'name',
          'url',
          'file_name',
        ]).ifEmpty(_contentTypeLabel(contentType));
    }
  }

  static Map<String, dynamic>? _coercePayloadMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty || (!value.startsWith('{') && !value.startsWith('['))) {
        return null;
      }
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _readStructuredInt(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static String _firstNonEmpty(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String? _resolveOpenLocalPath(dynamic raw) {
    final payload = _coercePayloadMap(raw);
    final candidates = <String>[
      if (payload != null)
        ...const <String>[
          'localPath',
          'local_path',
          'path',
          'file_path',
        ].map((key) => payload[key]?.toString().trim() ?? ''),
      if (raw is String) raw.trim(),
    ];
    for (final value in candidates) {
      if (_isLocalPath(value)) {
        return value;
      }
    }
    return null;
  }

  static String? _resolveOpenUrl(dynamic raw) {
    final payload = _coercePayloadMap(raw);
    final candidates = <String>[
      if (payload != null)
        ...const <String>[
          'url',
          'download_url',
          'downloadUrl',
          'file_url',
          'fileUrl',
          'link',
          'href',
        ].map((key) => payload[key]?.toString().trim() ?? ''),
      if (raw is String) raw.trim(),
    ];
    for (final value in candidates) {
      if (value.isEmpty || _isLocalPath(value)) {
        continue;
      }
      if (_isAbsoluteUrl(value)) {
        return value;
      }
      if (_looksLikeRemotePath(value)) {
        return ApiConfig.resolveMediaUrl(value);
      }
    }
    return null;
  }

  static bool _isAbsoluteUrl(String value) {
    final lowerValue = value.toLowerCase();
    return lowerValue.startsWith('http://') ||
        lowerValue.startsWith('https://');
  }

  static bool _looksLikeRemotePath(String value) {
    final normalized = value.trim();
    return normalized == '/v1' ||
        normalized.startsWith('/v1/') ||
        normalized.startsWith('v1/');
  }

  static bool _isLocalPath(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (_looksLikeRemotePath(normalized)) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.scheme == 'file') {
      return true;
    }
    if (normalized.startsWith('/')) {
      return true;
    }
    if (normalized.startsWith(r'\\')) {
      return true;
    }
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized);
  }

  static Uri _toFileUri(String value) {
    final normalized = value.trim();
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.scheme == 'file') {
      return parsed;
    }
    final isWindows = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized);
    return Uri.file(normalized, windows: isWindows);
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return _fromUnix(value);
    }
    if (value is num) {
      return _fromUnix(value.toInt());
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final unix = int.tryParse(trimmed);
      if (unix != null) {
        return _fromUnix(unix);
      }
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  static DateTime _fromUnix(int value) {
    final milliseconds = value > 1000000000000 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  static String _contentTypeLabel(int type) {
    switch (type) {
      case 1:
        return '文本';
      case 2:
        return '图片';
      case 3:
        return '语音';
      case 4:
        return '视频';
      case 5:
        return '文件';
      case 6:
        return '位置';
      case 7:
        return '名片';
      default:
        return '收藏';
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
