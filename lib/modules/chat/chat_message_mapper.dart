import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import 'chat_message_view_model.dart';
import 'message_content_preview.dart';

String chatMessageIdentity(WKMsg message) {
  final messageId = message.messageID.trim();
  if (messageId.isNotEmpty) {
    return 'mid:$messageId';
  }
  final clientMsgNo = message.clientMsgNO.trim();
  if (clientMsgNo.isNotEmpty) {
    return 'cid:$clientMsgNo';
  }
  return 'seq:${message.orderSeq}:${message.messageSeq}:${message.timestamp}';
}

class ChatMessageMapper {
  ChatMessageMapper({
    int maxStructuredPayloadCacheEntries =
        defaultMaxStructuredPayloadCacheEntries,
  }) : _maxStructuredPayloadCacheEntries = maxStructuredPayloadCacheEntries < 1
           ? 1
           : maxStructuredPayloadCacheEntries;

  static const int defaultMaxStructuredPayloadCacheEntries = 512;

  final int _maxStructuredPayloadCacheEntries;
  final LinkedHashMap<String, Map<String, dynamic>?> _payloadCache =
      LinkedHashMap<String, Map<String, dynamic>?>();

  @visibleForTesting
  int get structuredPayloadCacheSizeForTesting => _payloadCache.length;

  ChatMessageViewModel map(WKMsg message, {required String currentUid}) {
    final identity = chatMessageIdentity(message);
    final normalizedCurrentUid = currentUid.trim();
    final normalizedFromUid = message.fromUID.trim();
    final messageContentType = message.messageContent.runtimeType.toString();
    final revision =
        '$identity|${message.status}|${message.isDeleted}|'
        '${message.contentType}|$messageContentType|${message.content.hashCode}';
    final structuredPayload = _structuredPayload(message, revision);
    final preview = resolveMessagePreview(message);
    return ChatMessageViewModel(
      identity: identity,
      message: message,
      preview: preview.text,
      system: preview.isSystemNotice,
      self:
          normalizedCurrentUid.isNotEmpty &&
          normalizedFromUid == normalizedCurrentUid,
      structured: structuredPayload,
      revision: revision,
    );
  }

  Map<String, dynamic>? _structuredPayload(WKMsg message, String revision) {
    final shouldDecode =
        message.contentType == WkMessageContentType.unknown ||
        message.messageContent is WKUnknownContent;
    if (!shouldDecode) {
      return null;
    }
    if (_payloadCache.containsKey(revision)) {
      final cached = _payloadCache.remove(revision);
      _payloadCache[revision] = cached;
      return cached;
    }
    final raw = message.content.trim();
    if (raw.isEmpty || (!raw.startsWith('{') && !raw.startsWith('['))) {
      _putStructuredPayload(revision, null);
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      final payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
      _putStructuredPayload(revision, payload);
      return payload;
    } catch (_) {
      _putStructuredPayload(revision, null);
      return null;
    }
  }

  void _putStructuredPayload(String revision, Map<String, dynamic>? payload) {
    _payloadCache.remove(revision);
    while (_payloadCache.length >= _maxStructuredPayloadCacheEntries) {
      _payloadCache.remove(_payloadCache.keys.first);
    }
    _payloadCache[revision] = payload;
  }
}
