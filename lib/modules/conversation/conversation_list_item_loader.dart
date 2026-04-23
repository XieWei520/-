import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';

import '../../widgets/wk_conversation_item.dart';

@immutable
class ConversationListItemRequest {
  const ConversationListItemRequest({
    required this.conversation,
    this.preferredTitle,
    this.preferredAvatarUrl,
    this.preferredVipLevel = 0,
    required this.refreshToken,
  });

  final WKUIConversationMsg conversation;
  final String? preferredTitle;
  final String? preferredAvatarUrl;
  final int preferredVipLevel;
  final int refreshToken;

  String get requestKey => buildConversationListItemRequestKey(
    channelId: conversation.channelID,
    channelType: conversation.channelType,
    clientMsgNo: conversation.clientMsgNo,
    unreadCount: conversation.unreadCount,
    lastMsgTimestamp: conversation.lastMsgTimestamp,
    preferredTitle: preferredTitle,
    preferredAvatarUrl: preferredAvatarUrl,
    preferredVipLevel: preferredVipLevel,
    refreshToken: refreshToken,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ConversationListItemRequest &&
        other.requestKey == requestKey;
  }

  @override
  int get hashCode => requestKey.hashCode;
}

@visibleForTesting
String buildConversationListItemRequestKey({
  required String channelId,
  required int channelType,
  String? clientMsgNo,
  required int unreadCount,
  required int lastMsgTimestamp,
  String? preferredTitle,
  String? preferredAvatarUrl,
  int preferredVipLevel = 0,
  required int refreshToken,
}) {
  return [
    channelType,
    channelId.trim(),
    clientMsgNo?.trim() ?? '',
    unreadCount,
    lastMsgTimestamp,
    preferredTitle?.trim() ?? '',
    preferredAvatarUrl?.trim() ?? '',
    preferredVipLevel,
    refreshToken,
  ].join('|');
}

class ConversationListItemLoader {
  final Map<String, Future<WKConversationItemData>> _inFlight =
      <String, Future<WKConversationItemData>>{};

  Future<WKConversationItemData> load(
    String requestKey,
    Future<WKConversationItemData> Function() resolver,
  ) {
    final existing = _inFlight[requestKey];
    if (existing != null) {
      return existing;
    }

    final future = resolver();
    _inFlight[requestKey] = future;
    future.whenComplete(() {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    });
    return future;
  }

  void dispose() {
    _inFlight.clear();
  }
}
