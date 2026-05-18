import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../service/api/message_api.dart';
import 'message_content_preview.dart';

const String _emptyMessageText = '\u6682\u65e0\u6d88\u606f';

@immutable
class ResolvedPinnedMessage {
  const ResolvedPinnedMessage({
    required this.entry,
    required this.message,
    required this.previewText,
  });

  final PinnedMessageEntry entry;
  final WKMsg message;
  final String previewText;
}

List<ResolvedPinnedMessage> resolvePinnedMessages(
  PinnedMessageSyncSnapshot snapshot,
) {
  final messagesById = <String, WKMsg>{};
  final messagesBySeq = <int, WKMsg>{};
  final payloadsById = <String, dynamic>{};
  final payloadsBySeq = <int, dynamic>{};
  for (final syncMessage in snapshot.messages) {
    final message = syncMessage.getWKMsg();
    final messageId = message.messageID.trim();
    if (messageId.isNotEmpty) {
      messagesById[messageId] = message;
      payloadsById[messageId] = syncMessage.payload;
    }
    if (message.messageSeq > 0) {
      messagesBySeq[message.messageSeq] = message;
      payloadsBySeq[message.messageSeq] = syncMessage.payload;
    }
  }

  final resolved = <ResolvedPinnedMessage>[];
  for (final entry in snapshot.pinnedMessages) {
    if (entry.isDeleted == 1) {
      continue;
    }
    final message =
        messagesById[entry.messageId] ?? messagesBySeq[entry.messageSeq];
    if (message == null) {
      continue;
    }
    final rawPayload =
        payloadsById[entry.messageId] ?? payloadsBySeq[entry.messageSeq];
    final preview = resolvePinnedPreviewText(message, rawPayload);
    resolved.add(
      ResolvedPinnedMessage(
        entry: entry,
        message: message,
        previewText: preview,
      ),
    );
  }

  resolved.sort((a, b) {
    final versionCompare = b.entry.version.compareTo(a.entry.version);
    if (versionCompare != 0) {
      return versionCompare;
    }
    return b.entry.messageSeq.compareTo(a.entry.messageSeq);
  });
  return List<ResolvedPinnedMessage>.unmodifiable(resolved);
}

@visibleForTesting
String resolvePinnedPreviewText(WKMsg message, dynamic rawPayload) {
  if (rawPayload is Map) {
    final payload = Map<String, dynamic>.from(rawPayload);
    final directText = (payload['content'] ?? payload['text'] ?? '')
        .toString()
        .trim();
    if (directText.isNotEmpty) {
      return directText;
    }
  }
  if (rawPayload is Map || rawPayload is List) {
    final structured = resolveStructuredMessagePreview(
      jsonEncode(rawPayload),
      fallback: _emptyMessageText,
    ).text.trim();
    if (structured.isNotEmpty) {
      return structured;
    }
  }
  final preview = resolveMessagePreview(message).text.trim();
  if (preview.isNotEmpty && preview != _emptyMessageText) {
    return preview;
  }
  return _emptyMessageText;
}

bool canManagePinnedMessages(int? role) {
  return role == 1 || role == 2;
}
