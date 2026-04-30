import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_unknown_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/wk_custom_content.dart';
import '../../data/models/wk_robot_card_content.dart';
import '../../wukong_base/msg/msg_content_type.dart';
import '../../wukong_crypto/e2ee/e2ee_message_codec.dart';
import 'message_forwarding.dart';

const String _messageFallback = '[\u6d88\u606f]';
const String _textMessageFallback = '\u6587\u672c\u6d88\u606f';
const String _imageMessageLabel = '[\u56fe\u7247]';
const String _gifMessageLabel = '[动图]';
const String _stickerMessageLabel = '[\u8d34\u7eb8]';
const String _voiceMessageLabel = '[\u8bed\u97f3]';
const String _videoMessageLabel = '[\u89c6\u9891]';
const String _locationMessageLabel = '[\u4f4d\u7f6e]';
const String _fileMessageLabel = '[\u6587\u4ef6]';
const String _cardMessageLabel = '[\u540d\u7247]';
const String _richTextMessageLabel = '[\u5bcc\u6587\u672c]';
const String _systemMessageLabel = '\u7cfb\u7edf\u6d88\u606f';
const String _selfLabel = '\u4f60';
const String _unknownUserLabel = '\u672a\u77e5\u7528\u6237';
const String _systemAccountLabel = '\u7cfb\u7edf\u8d26\u53f7';
const String _fileHelperLabel = '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b';

class MessagePreviewData {
  final String text;
  final bool isSystemNotice;

  const MessagePreviewData({required this.text, this.isSystemNotice = false});
}

WKMessageContent? resolveVisibleMessageContent(WKMsg message) {
  return message.wkMsgExtra?.messageContent ??
      _resolveEditedTextContent(message.wkMsgExtra?.contentEdit) ??
      message.messageContent;
}

String resolveVisibleTextMessage(WKMsg message, {String fallback = ''}) {
  final content = resolveVisibleMessageContent(message);
  if (content is WKTextContent && content.content.trim().isNotEmpty) {
    return content.content.trim();
  }

  final genericText = content?.content.trim() ?? '';
  if (genericText.isNotEmpty) {
    return genericText;
  }

  final rawText = message.content.trim();
  if (rawText.isNotEmpty &&
      !rawText.startsWith('{') &&
      !rawText.startsWith('[')) {
    return rawText;
  }
  return fallback;
}

WKMessageContent? _resolveEditedTextContent(dynamic rawContentEdit) {
  final raw = rawContentEdit?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    final payload = Map<String, dynamic>.from(decoded);
    final rawType = payload['type'];
    final type = rawType is num
        ? rawType.toInt()
        : int.tryParse(rawType?.toString() ?? '');
    if (type != null && type != WkMessageContentType.text) {
      return null;
    }

    final text = (payload['content'] ?? payload['text'] ?? '')
        .toString()
        .trim();
    if (text.isEmpty) {
      return null;
    }
    return WKTextContent(text);
  } catch (_) {
    return null;
  }
}

String summarizeMessageContent(
  WKMessageContent? content, {
  String fallback = _messageFallback,
}) {
  if (content == null) {
    return fallback;
  }

  final display = content.displayText().trim();
  if (display.isNotEmpty) {
    return display;
  }

  final searchable = content.searchableWord().trim();
  if (searchable.isNotEmpty) {
    return searchable;
  }

  return fallback;
}

String resolveRobotCardPlainText(WKMsg message, {WKMessageContent? content}) {
  if (message.contentType != MsgContentType.robotCard) {
    return '';
  }

  final resolvedContent = content ?? resolveVisibleMessageContent(message);
  if (resolvedContent is WKRobotCardContent) {
    final modelText = resolvedContent.displayText().trim();
    if (modelText.isNotEmpty) {
      return modelText;
    }
  }

  final payload = _parseRawPayloadMap(message.content);
  if (payload == null) {
    return '';
  }
  return _resolveRobotCardPlainTextFromPayload(payload);
}

String resolveRobotCardName(WKMsg message, {WKMessageContent? content}) {
  if (message.contentType != MsgContentType.robotCard) {
    return '';
  }

  final resolvedContent = content ?? resolveVisibleMessageContent(message);
  if (resolvedContent is WKRobotCardContent) {
    final modelName = resolvedContent.robotName.trim();
    if (modelName.isNotEmpty) {
      return modelName;
    }
  }

  final payload = _parseRawPayloadMap(message.content);
  if (payload == null) {
    return '';
  }
  return _resolveRobotCardNameFromPayload(payload);
}

MessagePreviewData resolveMessagePreview(
  WKMsg message, {
  String fallback = _messageFallback,
}) {
  final content = resolveVisibleMessageContent(message);
  if (message.contentType == MsgContentType.richText) {
    final summary = summarizeMessageContent(
      content,
      fallback: _richTextMessageLabel,
    ).trim();
    return MessagePreviewData(
      text: summary.isNotEmpty ? summary : _richTextMessageLabel,
    );
  }

  switch (message.contentType) {
    case WkMessageContentType.text:
      final rawText = resolveVisibleTextMessage(
        message,
        fallback: _textMessageFallback,
      );
      return MessagePreviewData(
        text: rawText.isNotEmpty ? rawText : _textMessageFallback,
      );
    case WkMessageContentType.image:
      return const MessagePreviewData(text: _imageMessageLabel);
    case WkMessageContentType.gif:
      return const MessagePreviewData(text: _gifMessageLabel);
    case WkMessageContentType.sticker:
      return const MessagePreviewData(text: _stickerMessageLabel);
    case WkMessageContentType.voice:
      if (content is WKVoiceContent && content.timeTrad > 0) {
        return MessagePreviewData(
          text: '$_voiceMessageLabel ${content.timeTrad}"',
        );
      }
      return const MessagePreviewData(text: _voiceMessageLabel);
    case WkMessageContentType.video:
      return const MessagePreviewData(text: _videoMessageLabel);
    case WkMessageContentType.location:
      final summary = summarizeMessageContent(
        content,
        fallback: _locationMessageLabel,
      ).trim();
      return MessagePreviewData(
        text: summary.isNotEmpty ? summary : _locationMessageLabel,
      );
    case WkMessageContentType.file:
      if (content is WKFileContent && content.name.trim().isNotEmpty) {
        return MessagePreviewData(
          text: '$_fileMessageLabel ${content.name.trim()}',
        );
      }
      return const MessagePreviewData(text: _fileMessageLabel);
    case WkMessageContentType.card:
      if (content is WKCardContent && content.name.trim().isNotEmpty) {
        return MessagePreviewData(
          text: '$_cardMessageLabel ${content.name.trim()}',
        );
      }
      return const MessagePreviewData(text: _cardMessageLabel);
    case MsgContentType.robotCard:
      final robotCardText = resolveRobotCardPlainText(
        message,
        content: content,
      );
      return MessagePreviewData(
        text: robotCardText.isNotEmpty ? robotCardText : fallback,
      );
    case 20: // screenshot
      return const MessagePreviewData(text: '对方截取了屏幕', isSystemNotice: true);
    case MsgContentType.sensitiveWord:
      return const MessagePreviewData(
        text: '[敏感词提醒] 消息包含敏感词，仅自己可见',
        isSystemNotice: true,
      );
    case MsgContentType.richText:
      return const MessagePreviewData(text: '[富文本]');
    default:
      final structuredUnknown = _resolveUnknownStructuredPreview(
        message,
        fallback: fallback,
      );
      if (structuredUnknown != null) {
        return structuredUnknown;
      }
      final summary = summarizeMessageContent(content, fallback: '').trim();
      if (summary.isNotEmpty) {
        return MessagePreviewData(text: summary);
      }
      return resolveStructuredMessagePreview(
        message.content,
        fallback: fallback,
      );
  }
}

MessagePreviewData resolveStructuredMessagePreview(
  String raw, {
  String fallback = _messageFallback,
}) {
  final normalizedRaw = raw.trim();
  if (normalizedRaw.isEmpty) {
    return MessagePreviewData(text: fallback);
  }

  if (!normalizedRaw.startsWith('{') && !normalizedRaw.startsWith('[')) {
    return MessagePreviewData(text: normalizedRaw);
  }

  try {
    final decoded = jsonDecode(normalizedRaw);
    if (decoded is! Map) {
      return MessagePreviewData(text: normalizedRaw);
    }

    final payload = Map<String, dynamic>.from(decoded);
    final content = _resolveStructuredContentText(payload);
    final isSystemNotice = _isSystemPayload(payload);

    if (content.isNotEmpty) {
      return MessagePreviewData(text: content, isSystemNotice: isSystemNotice);
    }

    final commandText = _resolveCommandText(payload);
    if (commandText.isNotEmpty) {
      return MessagePreviewData(text: commandText, isSystemNotice: true);
    }

    if (isSystemNotice) {
      return const MessagePreviewData(
        text: _systemMessageLabel,
        isSystemNotice: true,
      );
    }
  } catch (_) {
    return MessagePreviewData(text: normalizedRaw);
  }

  return MessagePreviewData(text: normalizedRaw);
}

String summarizeReply(WKReply? reply, {String fallback = _messageFallback}) {
  if (reply == null) {
    return fallback;
  }
  if (reply.revoke == 1) {
    return '[\u539f\u6d88\u606f\u5df2\u64a4\u56de]';
  }
  if (reply.contentEditMsgModel != null) {
    return summarizeMessageContent(
      reply.contentEditMsgModel,
      fallback: fallback,
    );
  }
  return summarizeMessageContent(reply.payload, fallback: fallback);
}

String buildReminderTitleFromContent(
  WKMessageContent? content, {
  String fallback = _messageFallback,
  int maxLength = 40,
}) {
  final summary = summarizeMessageContent(content, fallback: fallback).trim();
  if (summary.length <= maxLength) {
    return summary;
  }
  return '${summary.substring(0, maxLength).trimRight()}...';
}

String buildReminderDescriptionFromContent(
  WKMessageContent? content, {
  String fallback = _messageFallback,
}) {
  return summarizeMessageContent(content, fallback: fallback).trim();
}

String resolveReplyAuthor(
  WKMsg message, {
  String currentUid = '',
  String selfLabel = _selfLabel,
}) {
  if (message.fromUID == currentUid && currentUid.isNotEmpty) {
    return selfLabel;
  }

  final member = message.getMemberOfFrom();
  final memberRemark = member?.memberRemark.trim() ?? '';
  if (memberRemark.isNotEmpty) {
    return memberRemark;
  }
  final memberName = member?.memberName.trim() ?? '';
  if (memberName.isNotEmpty) {
    return memberName;
  }
  final user = message.getFrom();
  final remark = user?.channelRemark.trim() ?? '';
  if (remark.isNotEmpty) {
    return remark;
  }
  final name = user?.channelName.trim() ?? '';
  if (name.isNotEmpty) {
    return name;
  }
  if (message.fromUID.trim().isNotEmpty) {
    return message.fromUID.trim();
  }
  return _unknownUserLabel;
}

WKReply buildReplyForMessage(
  WKMsg message, {
  String currentUid = '',
  String selfLabel = _selfLabel,
}) {
  final reply = WKReply();
  final messageId = message.messageID.trim().isNotEmpty
      ? message.messageID.trim()
      : message.clientMsgNO.trim();
  final rootMid =
      message.messageContent?.reply?.rootMid.trim().isNotEmpty == true
      ? message.messageContent!.reply!.rootMid.trim()
      : messageId;

  reply.rootMid = rootMid;
  reply.messageId = messageId;
  reply.messageSeq = message.messageSeq;
  reply.fromUID = message.fromUID;
  reply.fromName = resolveReplyAuthor(
    message,
    currentUid: currentUid,
    selfLabel: selfLabel,
  );
  reply.payload =
      cloneMessageContentForForward(message.messageContent) ??
      WKTextContent(resolveMessagePreview(message).text);
  return reply;
}

String _resolveStructuredContentText(Map<String, dynamic> payload) {
  final typedPayloadText = _resolveTypedPayloadText(payload);
  if (typedPayloadText.isNotEmpty) {
    return typedPayloadText;
  }

  final template = payload['content']?.toString().trim() ?? '';
  if (template.isNotEmpty) {
    final names = _extractStructuredNames(payload['extra']);
    return _replaceIndexedPlaceholders(template, names);
  }

  final creatorName = _resolveDisplayName(
    payload['creator_name'] ?? payload['creator'],
  );
  final targetNames = _extractStructuredNames(payload['extra']);
  final type = int.tryParse(payload['type']?.toString() ?? '');

  if (type == 1001 && creatorName.isNotEmpty && targetNames.isNotEmpty) {
    final joinedNames = targetNames.join('\u3001');
    return '$creatorName\u9080\u8bf7$joinedNames\u52a0\u5165\u7fa4\u804a';
  }

  return '';
}

String _resolveRobotCardPlainTextFromPayload(Map<String, dynamic> payload) {
  final plainText = _firstNonEmptyText([
    payload['plain_text'],
    payload['plainText'],
  ]);
  if (plainText.isNotEmpty) {
    return plainText;
  }

  final card =
      _asStringDynamicMap(payload['card']) ?? const <String, dynamic>{};
  final title = _firstNonEmptyText([card['title'], payload['title']]);
  final body = _firstNonEmptyText([card['body'], payload['body']]);
  if (title.isEmpty) {
    if (body.isNotEmpty) {
      return body;
    }
    return _firstNonEmptyText([payload['content']]);
  }
  if (body.isEmpty) {
    return title;
  }
  return '$title $body';
}

String _resolveRobotCardNameFromPayload(Map<String, dynamic> payload) {
  final robot =
      _asStringDynamicMap(payload['robot']) ?? const <String, dynamic>{};
  return _firstNonEmptyText([
    payload['robot_name'],
    payload['robotName'],
    payload['name'],
    payload['display_name'],
    payload['displayName'],
    robot['name'],
    robot['display_name'],
    robot['displayName'],
  ]);
}

Map<String, dynamic>? _parseRawPayloadMap(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty ||
      (!normalized.startsWith('{') && !normalized.startsWith('['))) {
    return null;
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is! Map) {
    return null;
  }
  final normalized = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      return null;
    }
    normalized[key] = entry.value;
  }
  return normalized;
}

String _firstNonEmptyText(List<dynamic> values) {
  for (final value in values) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

MessagePreviewData? _resolveUnknownStructuredPreview(
  WKMsg message, {
  String fallback = _messageFallback,
}) {
  final content = message.messageContent;
  final shouldResolveFromRaw =
      message.contentType == WkMessageContentType.unknown ||
      content is WKUnknownContent;
  if (!shouldResolveFromRaw) {
    return null;
  }

  final preview = resolveStructuredMessagePreview(
    message.content,
    fallback: '',
  );
  final normalized = preview.text.trim();
  if (normalized.isEmpty || normalized == '{}' || normalized == '[]') {
    return null;
  }
  return MessagePreviewData(
    text: normalized,
    isSystemNotice: preview.isSystemNotice,
  );
}

String _resolveTypedPayloadText(Map<String, dynamic> payload) {
  if (E2eeMessageCodec.isEncryptedPayload(payload)) {
    final fallback = payload['fallback']?.toString().trim() ?? '';
    return fallback.isNotEmpty ? fallback : E2eeMessageCodec.fallbackText;
  }

  final type = int.tryParse(payload['type']?.toString() ?? '');
  if (type == MsgContentType.richText) {
    final text = (payload['content'] ?? payload['body'] ?? '')
        .toString()
        .trim();
    return text.isNotEmpty ? text : _richTextMessageLabel;
  }
  switch (type) {
    case WkMessageContentType.gif:
      return _gifMessageLabel;
    case WkMessageContentType.sticker:
      return _stickerMessageLabel;
    case WkMessageContentType.card:
      final name = payload['name']?.toString().trim() ?? '';
      return name.isNotEmpty ? '$_cardMessageLabel $name' : _cardMessageLabel;
    case MsgContentType.robotCard:
      return _resolveRobotCardPlainTextFromPayload(payload);
    case WkMessageContentType.file:
      final name = payload['name']?.toString().trim() ?? '';
      return name.isNotEmpty ? '$_fileMessageLabel $name' : _fileMessageLabel;
    case WkMessageContentType.location:
      final title = payload['title']?.toString().trim() ?? '';
      return title.isNotEmpty
          ? '$_locationMessageLabel $title'
          : _locationMessageLabel;
    case MsgContentType.sensitiveWord:
      return '[敏感词提醒] 消息包含敏感词，仅自己可见';
    case MsgContentType.richText:
      final text = payload['content']?.toString().trim() ?? '';
      return text.isNotEmpty ? '[富文本] $text' : '[富文本]';
    case 20: // screenshot
      return '对方截取了屏幕';
    default:
      return '';
  }
}

String _replaceIndexedPlaceholders(String template, List<String> values) {
  var resolved = template;
  for (var index = 0; index < values.length; index++) {
    resolved = resolved.replaceAll('{$index}', values[index]);
  }
  return resolved.trim();
}

List<String> _extractStructuredNames(dynamic rawExtra) {
  if (rawExtra is! List) {
    return const <String>[];
  }

  final names = <String>[];
  for (final item in rawExtra) {
    if (item is Map) {
      final mapped = Map<String, dynamic>.from(item);
      final name = _resolveDisplayName(
        mapped['remark'] ??
            mapped['name'] ??
            mapped['nickname'] ??
            mapped['channel_name'] ??
            mapped['uid'],
      );
      if (name.isNotEmpty) {
        names.add(name);
      }
      continue;
    }

    final value = _resolveDisplayName(item);
    if (value.isNotEmpty) {
      names.add(value);
    }
  }
  return names;
}

String _resolveCommandText(Map<String, dynamic> payload) {
  final cmd = payload['cmd']?.toString().trim() ?? '';
  switch (cmd) {
    case 'group.avatar.update':
    case 'groupAvatarUpdate':
    case 'group_avatar_update':
      return '\u7fa4\u5934\u50cf\u5df2\u66f4\u65b0';
    case 'group.name.update':
    case 'groupNameUpdate':
    case 'group_name_update':
      return '\u7fa4\u540d\u79f0\u5df2\u66f4\u65b0';
    case 'group.notice.update':
    case 'groupNoticeUpdate':
    case 'group_notice_update':
      return '\u7fa4\u516c\u544a\u5df2\u66f4\u65b0';
    case 'messageRevoke':
    case 'message.revoke':
    case 'message_revoke':
      return '\u6d88\u606f\u5df2\u64a4\u56de';
    case 'messageEerase':
    case 'message.erase':
    case 'message_erase':
      return '\u6d88\u606f\u5df2\u88ab\u6e05\u9664';
    default:
      return '';
  }
}

bool _isSystemPayload(Map<String, dynamic> payload) {
  final cmd = payload['cmd']?.toString().trim() ?? '';
  if (cmd.isNotEmpty) {
    return true;
  }

  final type = int.tryParse(payload['type']?.toString() ?? '');
  return type != null && type >= 1000;
}

String _resolveDisplayName(dynamic raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    return '';
  }
  if (value == 'u_10000') {
    return _systemAccountLabel;
  }
  if (value == 'fileHelper') {
    return _fileHelperLabel;
  }
  return value;
}
