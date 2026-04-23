import 'dart:convert';

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
  final Map<String, Map<String, dynamic>?> _payloadCache =
      <String, Map<String, dynamic>?>{};

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
    final cached = _payloadCache[revision];
    if (_payloadCache.containsKey(revision)) {
      return cached;
    }
    final shouldDecode =
        message.contentType == WkMessageContentType.unknown ||
        message.messageContent is WKUnknownContent;
    if (!shouldDecode) {
      _payloadCache[revision] = null;
      return null;
    }
    final raw = message.content.trim();
    if (raw.isEmpty || (!raw.startsWith('{') && !raw.startsWith('['))) {
      _payloadCache[revision] = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      final payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
      _payloadCache[revision] = payload;
      return payload;
    } catch (_) {
      _payloadCache[revision] = null;
      return null;
    }
  }
}
