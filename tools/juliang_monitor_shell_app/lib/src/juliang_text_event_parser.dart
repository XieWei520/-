import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'juliang_page_probe.dart';

List<NormalizedMessageEvent> normalizeJuliangProbeMessageEvents(
  List<JuliangProbeMessageEvent> events, {
  required DateTime observedAt,
}) {
  final normalized = <String, NormalizedMessageEvent>{};
  final fallbackObservedAt = observedAt.toUtc().toIso8601String();
  for (final event in events) {
    final text = _normalizeEventText(event.text);
    final messageType = event.messageType.trim().isEmpty
        ? 'text'
        : event.messageType.trim().toLowerCase();
    if (messageType != 'text' || text.isEmpty) {
      continue;
    }

    final conversationName = event.conversationName.trim();
    final conversationId = event.conversationId.trim().isNotEmpty
        ? event.conversationId.trim()
        : fallbackJuliangConversationId(conversationName);
    if (conversationId.isEmpty && conversationName.isEmpty) {
      continue;
    }
    if (_isDomProbeChromeText(
      text: text,
      conversationName: conversationName,
      captureSource: event.captureSource,
    )) {
      continue;
    }

    final messageId = event.messageId.trim().isNotEmpty
        ? event.messageId.trim()
        : 'dom:${text.hashCode}';
    final dedupeKey = event.dedupeKey.trim().isNotEmpty
        ? event.dedupeKey.trim()
        : _eventIdentity(conversationId: conversationId, messageId: messageId);
    final eventId = event.eventId.trim().isNotEmpty
        ? event.eventId.trim()
        : dedupeKey;
    final normalizedEvent = NormalizedMessageEvent(
      eventId: eventId,
      dedupeKey: dedupeKey,
      accountId: event.accountId.trim(),
      conversationId: conversationId,
      conversationName: conversationName,
      conversationType: event.conversationType.trim().isEmpty
          ? 'unknown'
          : event.conversationType.trim(),
      messageId: messageId,
      senderId: event.senderId.trim(),
      senderName: event.senderName.trim(),
      messageType: 'text',
      text: text,
      sentAt: event.sentAt.trim(),
      observedAt: event.observedAt.trim().isEmpty
          ? fallbackObservedAt
          : event.observedAt.trim(),
      captureSource: event.captureSource.trim().isEmpty
          ? 'dom_probe'
          : event.captureSource.trim(),
    );
    final key = dedupeKey.isEmpty ? eventId : dedupeKey;
    if (key.isEmpty) {
      continue;
    }
    final current = normalized[key];
    if (current == null || _compareObservedAt(normalizedEvent, current) >= 0) {
      normalized[key] = normalizedEvent;
    }
  }
  final result = normalized.values.toList(growable: false)
    ..sort((a, b) => _compareObservedAt(b, a));
  return result;
}

String fallbackJuliangConversationId(String name) {
  final normalized = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }
  return 'fallback:$normalized';
}

String _normalizeEventText(String value) {
  return value
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isDomProbeChromeText({
  required String text,
  required String conversationName,
  required String captureSource,
}) {
  if (captureSource.trim() != 'dom_probe') {
    return false;
  }
  final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedText.isEmpty) {
    return true;
  }
  final loginChromePatterns = <RegExp>[
    RegExp(r'FEIPANEL.*登录以继续使用面板'),
    RegExp(r'登录注册重置密码'),
    RegExp(r'邮箱\s*\*.*密码\s*\*.*验证码\s*\*'),
    RegExp(r'我已阅读并同意以下协议'),
    RegExp(r'用户服务协议|隐私条款|数据安全说明'),
    RegExp(r'忘记密码|正在登录|看不清验证码|粤ICP备'),
  ];
  if (loginChromePatterns.any((pattern) => pattern.hasMatch(normalizedText))) {
    return true;
  }
  final chromeTexts = <String>{
    '用户前台 设置 退出',
    '消息国内资讯国际资讯',
    '频道',
    '任务',
    '聚合',
    '选择一个 Chat 打开 频道 列表后选择 聚合',
  };
  if (chromeTexts.contains(normalizedText)) {
    return true;
  }
  final sourceName = conversationName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (sourceName.isNotEmpty) {
    final escapedSource = RegExp.escape(sourceName);
    final sourceRowPatterns = <RegExp>[
      RegExp('^$escapedSource\\s*\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}\$'),
      RegExp('^\\d+$escapedSource\\s*\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}\$'),
    ];
    if (sourceRowPatterns.any((pattern) => pattern.hasMatch(normalizedText))) {
      return true;
    }
  }
  return false;
}

String _eventIdentity({
  required String conversationId,
  required String messageId,
}) {
  if (conversationId.isNotEmpty && messageId.isNotEmpty) {
    return '$conversationId:$messageId';
  }
  if (messageId.isNotEmpty) {
    return 'message:$messageId';
  }
  return '';
}

int _compareObservedAt(
  NormalizedMessageEvent left,
  NormalizedMessageEvent right,
) {
  final parsedLeft = DateTime.tryParse(left.observedAt);
  final parsedRight = DateTime.tryParse(right.observedAt);
  if (parsedLeft != null && parsedRight != null) {
    return parsedLeft.compareTo(parsedRight);
  }
  return left.observedAt.compareTo(right.observedAt);
}
