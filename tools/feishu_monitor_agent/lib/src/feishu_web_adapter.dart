import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agent_models.dart';

class FeishuWebDomClassifier {
  const FeishuWebDomClassifier._();

  static BrowserLoginStatus classifyText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return BrowserLoginStatus.unknown;
    }
    final hasLogin = normalized.contains('\u767b\u5f55');
    final hasScan = normalized.contains('\u626b\u7801');
    if ((hasLogin && hasScan) ||
        normalized.contains('\u8bf7\u4f7f\u7528\u98de\u4e66\u626b\u7801')) {
      return BrowserLoginStatus.loginRequired;
    }
    if (normalized.contains('\u6d88\u606f') ||
        normalized.contains('\u5de5\u4f5c\u53f0') ||
        normalized.contains('\u4e91\u6587\u6863')) {
      return BrowserLoginStatus.loggedIn;
    }
    return BrowserLoginStatus.unknown;
  }
}

class FeishuObservedMessage {
  const FeishuObservedMessage({
    required this.sourceMessageId,
    required this.messageType,
    required this.content,
    required this.sourceCreatedAt,
    required this.observedAt,
  });

  final String sourceMessageId;
  final String messageType;
  final String content;
  final String sourceCreatedAt;
  final String observedAt;

  factory FeishuObservedMessage.fromRaw({
    required String routeId,
    required String sourceChatName,
    required String rawId,
    required String messageType,
    required String content,
    required String observedAt,
    required int domOrder,
    String sourceCreatedAt = '',
  }) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final effectiveCreatedAt = sourceCreatedAt.trim().isEmpty
        ? observedAt
        : sourceCreatedAt.trim();
    final id = rawId.trim().isNotEmpty
        ? rawId.trim()
        : 'feishu_web_${sha256.convert(utf8.encode('$routeId|$sourceChatName|$normalized|$effectiveCreatedAt|$domOrder'))}';
    return FeishuObservedMessage(
      sourceMessageId: id,
      messageType: messageType.trim().isEmpty ? 'text' : messageType.trim(),
      content: normalized,
      sourceCreatedAt: effectiveCreatedAt,
      observedAt: observedAt,
    );
  }
}

class FeishuMessageTextExtractor {
  const FeishuMessageTextExtractor._();

  static String extractFocusedMessage(
    String value, {
    required String chatName,
  }) {
    final normalizedChatName = chatName.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lines = value
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return '';
    }
    for (final line in lines.reversed) {
      final extracted = _extractFromLine(line, normalizedChatName);
      if (extracted.isNotEmpty &&
          (normalizedChatName.isEmpty || line.contains(normalizedChatName))) {
        return extracted;
      }
    }
    for (final line in lines.reversed) {
      final extracted = _extractFromLine(line, normalizedChatName);
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }
    if (lines.length == 1) {
      final only = _stripKnownChrome(lines.single);
      return _isBadMessageText(only) ? '' : only;
    }
    return '';
  }

  static String _extractFromLine(String line, String chatName) {
    var text = _stripKnownChrome(line);
    if (text.isEmpty || _isBadMessageText(text)) {
      return '';
    }
    if (chatName.isNotEmpty && text.contains(chatName)) {
      final pattern = RegExp(
        '${RegExp.escape(chatName)}\\s+(?:刚刚|\\d{1,2}:\\d{2}|昨天|星期[一二三四五六日天]|\\d{1,2}月\\d{1,2}日)\\s+(.+)\$',
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        text = match.group(1)?.trim() ?? '';
      } else {
        final index = text.lastIndexOf(chatName);
        text = text.substring(index + chatName.length).trim();
        text = text
            .replaceFirst(
              RegExp(
                r'^(?:刚刚|\d{1,2}:\d{2}|昨天|星期[一二三四五六日天]|\d{1,2}月\d{1,2}日)\s+',
              ),
              '',
            )
            .trim();
      }
    }
    text = text.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
    return _isBadMessageText(text) ? '' : text;
  }

  static String _stripKnownChrome(String value) {
    var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceFirst(RegExp(r'^搜索\s*\(Ctrl\+K\)\s*'), '').trim();
    text = text
        .replaceFirst(
          RegExp(r'^(消息|知识问答|会议|日历|云文档|通讯录|邮箱|任务|工作台|下载飞书客户端)\s*'),
          '',
        )
        .trim();
    return text;
  }

  static bool _isBadMessageText(String text) {
    if (text.length < 2 || text.length > 4000) {
      return true;
    }
    if (RegExp(r'^[\d\s:：/\-.年月日]+$').hasMatch(text)) {
      return true;
    }
    final navigationWords = <String>[
      '搜索',
      '知识问答',
      '会议',
      '日历',
      '云文档',
      '通讯录',
      '邮箱',
      '任务',
      '工作台',
      '下载飞书客户端',
    ];
    var navigationHits = 0;
    for (final word in navigationWords) {
      if (text.contains(word)) {
        navigationHits += 1;
      }
    }
    if (navigationHits >= 4 && !RegExp(r'[:：]').hasMatch(text)) {
      return true;
    }
    return false;
  }
}

class FeishuChatNameNormalizer {
  const FeishuChatNameNormalizer._();

  static List<String> normalizeAll(Iterable<Object?> values) {
    final names = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final name = normalize(value?.toString() ?? '');
      if (name.isEmpty || seen.contains(name)) {
        continue;
      }
      seen.add(name);
      names.add(name);
    }
    return names;
  }

  static String normalize(String value) {
    var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return '';
    }
    text = text.replaceFirst(RegExp(r'^(置顶|免打扰|草稿|有人@我|@我)\s*'), '').trim();
    text = text
        .replaceFirst(RegExp(r'\s*(刚刚|\d{1,2}:\d{2}|昨天|星期[一二三四五六日天])$'), '')
        .trim();
    text = text.replaceFirst(RegExp(r'\s*\d+\s*条新消息$'), '').trim();
    text = text.replaceFirst(RegExp(r'\s*\[[^\]]{1,12}\]$'), '').trim();
    text = _stripConversationPreview(text);
    text = text
        .replaceFirst(RegExp(r'^\d+\s+'), '')
        .replaceFirst(RegExp(r'\s+(外部|机器人|官方)$'), '')
        .trim();
    if (_isBadText(text)) {
      return '';
    }
    return text;
  }

  static String dedupeKey(String value) {
    return normalize(value)
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'^(外部|机器人|官方)+'), '')
        .replaceAll(RegExp(r'(外部|机器人|官方)+$'), '')
        .toLowerCase();
  }

  static String _stripConversationPreview(String text) {
    final normalized = text.trim();
    final metadataPattern = RegExp(
      r'^(?:(?:\d+\s+)?)'
      r'(.{2,40}?)'
      r'(?:\s+(?:外部|机器人|官方))*'
      r'\s+(?:刚刚|\d{1,2}:\d{2}|昨天|星期[一二三四五六日天]|\d{1,2}月\d{1,2}日)'
      r'(?:\s+.*)?$',
    );
    final metadataMatch = metadataPattern.firstMatch(normalized);
    if (metadataMatch != null) {
      return metadataMatch.group(1)?.trim() ?? normalized;
    }
    final senderPreviewPattern = RegExp(
      r'^(.{2,40}?)\s+[^:\s]{1,24}[:：]\s*.+$',
    );
    final senderPreviewMatch = senderPreviewPattern.firstMatch(normalized);
    if (senderPreviewMatch != null) {
      return senderPreviewMatch.group(1)?.trim() ?? normalized;
    }
    return normalized;
  }

  static bool _isBadText(String text) {
    if (text.length < 2 || text.length > 80) {
      return true;
    }
    final exactBadLabels = <String>{
      '搜索',
      '快捷',
      '消息',
      '通讯录',
      '云文档',
      '工作台',
      '日历',
      '会议',
      '设置',
      '更多',
      '全部',
      '未读',
    };
    if (exactBadLabels.contains(text)) {
      return true;
    }
    if (RegExp(r'^(\d+|[0-9:：/\- ]+)$').hasMatch(text)) {
      return true;
    }
    return false;
  }
}
