import 'package:flutter/foundation.dart';

import '../domain/search_models.dart';

typedef ResolveOrderSeq =
    Future<int> Function({
      required int messageSeq,
      required String channelId,
      required int channelType,
    });

@immutable
class ChatOpenRequest {
  const ChatOpenRequest({
    required this.channelId,
    required this.channelType,
    required this.orderSeq,
    required this.highlightKeyword,
    required this.source,
    this.locateMessageSeq,
    this.channelName,
    this.feedbackMessage,
  });

  final String channelId;
  final int channelType;
  final int? orderSeq;
  final int? locateMessageSeq;
  final String highlightKeyword;
  final String source;
  final String? channelName;
  final String? feedbackMessage;
}

class ChatLocateCoordinator {
  const ChatLocateCoordinator({required this.resolveOrderSeq});

  final ResolveOrderSeq resolveOrderSeq;

  static const String _fallbackMessage =
      'Unable to locate the exact message. Opened the conversation instead.';

  Future<ChatOpenRequest> buildOpenRequestFromIntent(
    ChatLocateIntent intent,
  ) async {
    final anchoredOrderSeq = intent.orderSeq;
    final locateMessageSeq = intent.messageSeq != null && intent.messageSeq! > 0
        ? intent.messageSeq
        : null;
    if (anchoredOrderSeq != null && anchoredOrderSeq > 0) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: anchoredOrderSeq,
        locateMessageSeq: locateMessageSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
      );
    }

    final messageSeq = intent.messageSeq;
    if (messageSeq == null) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: null,
        locateMessageSeq: locateMessageSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: _fallbackMessage,
      );
    }

    try {
      final resolvedOrderSeq = await resolveOrderSeq(
        messageSeq: messageSeq,
        channelId: intent.channelId,
        channelType: intent.channelType,
      );

      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: resolvedOrderSeq > 0 ? resolvedOrderSeq : null,
        locateMessageSeq: locateMessageSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: resolvedOrderSeq > 0 ? null : _fallbackMessage,
      );
    } catch (_) {
      return ChatOpenRequest(
        channelId: intent.channelId,
        channelType: intent.channelType,
        orderSeq: null,
        locateMessageSeq: locateMessageSeq,
        highlightKeyword: intent.highlightKeyword,
        source: intent.source,
        channelName: intent.channelName,
        feedbackMessage: _fallbackMessage,
      );
    }
  }

  Future<ChatOpenRequest> buildOpenRequest(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) async {
    final intent = ChatLocateIntent.fromSearchHit(
      hit,
      highlightKeyword: highlightKeyword,
      source: source,
    );
    return buildOpenRequestFromIntent(intent);
  }
}
