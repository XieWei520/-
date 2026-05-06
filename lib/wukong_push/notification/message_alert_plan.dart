import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../modules/chat/message_content_preview.dart';

const int _maxAlertTitleLength = 80;
const int _maxAlertBodyLength = 240;

class MessageAlertPlan {
  const MessageAlertPlan({
    required this.title,
    required this.body,
    required this.channelId,
    required this.channelType,
    this.payload = '',
  });

  final String title;
  final String body;
  final String channelId;
  final int channelType;
  final String payload;

  String get conversationKey => '$channelType:$channelId';
}

MessageAlertPlan? buildMessageAlertPlan(
  WKMsg message, {
  required String currentUid,
}) {
  if (!shouldTriggerMessageAlert(message, currentUid: currentUid)) {
    return null;
  }

  final preview = resolveMessagePreview(message);
  final body = _compactText(
    preview.text,
    fallback: '[New message]',
    maxLength: _maxAlertBodyLength,
  );
  if (body.isEmpty) {
    return null;
  }

  final title = _compactText(
    _resolveAlertTitle(message),
    fallback: 'InfoEquity',
    maxLength: _maxAlertTitleLength,
  );

  return MessageAlertPlan(
    title: title,
    body: body,
    channelId: message.channelID.trim(),
    channelType: message.channelType,
    payload: buildMessageAlertPayload(
      title: title,
      body: body,
      channelId: message.channelID.trim(),
      channelType: message.channelType,
      senderUid: message.fromUID.trim(),
      messageId: message.messageID.toString(),
    ),
  );
}

String buildMessageAlertPayload({
  required String title,
  required String body,
  required String channelId,
  required int channelType,
  String? senderUid,
  String? messageId,
}) {
  final normalizedPayload = <String, dynamic>{
    'channel_id': channelId,
    'channel_type': channelType,
    'title': title,
    'body': body,
    if (senderUid != null && senderUid.trim().isNotEmpty)
      'sender_uid': senderUid.trim(),
    if (messageId != null && messageId.trim().isNotEmpty)
      'message_id': messageId.trim(),
  };
  return jsonEncode(<String, dynamic>{
    'payload': normalizedPayload,
    'title': title,
    'body': body,
  });
}

bool shouldTriggerMessageAlert(WKMsg message, {required String currentUid}) {
  if (message.isDeleted != 0 ||
      message.contentType == WkMessageContentType.insideMsg) {
    return false;
  }
  if (!message.header.redDot) {
    return false;
  }

  final normalizedCurrentUid = currentUid.trim();
  final normalizedFromUid = message.fromUID.trim();
  if (normalizedCurrentUid.isNotEmpty &&
      normalizedFromUid == normalizedCurrentUid) {
    return false;
  }

  final channel = message.getChannelInfo();
  if (channel?.mute == 1) {
    return false;
  }

  return true;
}

String _resolveAlertTitle(WKMsg message) {
  final senderName = _resolveSenderName(message);
  final conversationName = _resolveConversationName(message);

  if (_isGroupLikeChannel(message.channelType)) {
    if (senderName.isNotEmpty &&
        conversationName.isNotEmpty &&
        senderName != conversationName) {
      return '$senderName - $conversationName';
    }
    if (conversationName.isNotEmpty) {
      return conversationName;
    }
    if (senderName.isNotEmpty) {
      return senderName;
    }
  }

  if (senderName.isNotEmpty) {
    return senderName;
  }
  if (conversationName.isNotEmpty) {
    return conversationName;
  }
  return 'InfoEquity';
}

bool _isGroupLikeChannel(int channelType) {
  return channelType == WKChannelType.group ||
      channelType == WKChannelType.community ||
      channelType == WKChannelType.communityTopic;
}

String _resolveSenderName(WKMsg message) {
  final member = message.getMemberOfFrom();
  final memberCandidates = <String>[
    member?.memberRemark ?? '',
    member?.remark ?? '',
    member?.memberName ?? '',
    member?.memberUID ?? '',
  ];
  final memberName = _firstNonEmpty(memberCandidates);
  if (memberName.isNotEmpty) {
    return memberName;
  }

  final from = message.getFrom();
  final fromCandidates = <String>[
    from?.channelRemark ?? '',
    from?.channelName ?? '',
    from?.username ?? '',
    from?.channelID ?? '',
    message.fromUID,
  ];
  return _firstNonEmpty(fromCandidates);
}

String _resolveConversationName(WKMsg message) {
  final channel = message.getChannelInfo();
  final candidates = <String>[
    channel?.channelRemark ?? '',
    channel?.channelName ?? '',
    channel?.channelID ?? '',
    message.channelID,
  ];
  return _firstNonEmpty(candidates);
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final normalized = _normalizeWhitespace(value);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _compactText(
  String value, {
  required String fallback,
  required int maxLength,
}) {
  final normalized = _normalizeWhitespace(value);
  final resolved = normalized.isEmpty ? fallback.trim() : normalized;
  if (resolved.length <= maxLength) {
    return resolved;
  }
  if (maxLength <= 3) {
    return resolved.substring(0, maxLength);
  }
  return '${resolved.substring(0, maxLength - 3).trimRight()}...';
}

String _normalizeWhitespace(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
