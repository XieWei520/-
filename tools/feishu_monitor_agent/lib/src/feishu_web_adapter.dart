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
