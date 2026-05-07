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
    this.preferredCategory,
    this.preferredVipLevel = 0,
    this.preferredPersonalInfoKnown = false,
    required this.refreshToken,
    this.lastMessageExtraDigest,
  });

  final WKUIConversationMsg conversation;
  final String? preferredTitle;
  final String? preferredAvatarUrl;
  final String? preferredCategory;
  final int preferredVipLevel;
  final bool preferredPersonalInfoKnown;
  final int refreshToken;
  final String? lastMessageExtraDigest;

  String get requestKey => buildConversationListItemRequestKey(
    channelId: conversation.channelID,
    channelType: conversation.channelType,
    clientMsgNo: conversation.clientMsgNo,
    unreadCount: conversation.unreadCount,
    lastMsgTimestamp: conversation.lastMsgTimestamp,
    lastMessageExtraDigest: lastMessageExtraDigest,
    preferredTitle: preferredTitle,
    preferredAvatarUrl: preferredAvatarUrl,
    preferredCategory: preferredCategory,
    preferredVipLevel: preferredVipLevel,
    preferredPersonalInfoKnown: preferredPersonalInfoKnown,
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
  String? lastMessageExtraDigest,
  String? preferredTitle,
  String? preferredAvatarUrl,
  String? preferredCategory,
  int preferredVipLevel = 0,
  bool preferredPersonalInfoKnown = false,
  required int refreshToken,
}) {
  return [
    channelType,
    channelId.trim(),
    clientMsgNo?.trim() ?? '',
    unreadCount,
    lastMsgTimestamp,
    lastMessageExtraDigest?.trim() ?? '',
    preferredTitle?.trim() ?? '',
    preferredAvatarUrl?.trim() ?? '',
    preferredCategory?.trim().toLowerCase() ?? '',
    preferredVipLevel,
    preferredPersonalInfoKnown ? 1 : 0,
    refreshToken,
  ].join('|');
}

class ConversationListItemLoader {
  final Map<String, Future<WKConversationItemData>> _inFlight =
      <String, Future<WKConversationItemData>>{};
  final Map<String, WKConversationItemData> _resolved =
      <String, WKConversationItemData>{};

  WKConversationItemData? cachedDataFor(String cacheKey) {
    final normalizedKey = cacheKey.trim();
    if (normalizedKey.isEmpty) {
      return null;
    }
    return _resolved[normalizedKey];
  }

  Future<WKConversationItemData> load(
    String requestKey,
    Future<WKConversationItemData> Function() resolver, {
    String? cacheKey,
  }) {
    final existing = _inFlight[requestKey];
    if (existing != null) {
      return existing;
    }

    final future = resolver();
    _inFlight[requestKey] = future;
    unawaited(
      future.then<void>((data) {
        final normalizedCacheKey = cacheKey?.trim() ?? '';
        if (normalizedCacheKey.isNotEmpty) {
          _resolved[normalizedCacheKey] = data;
        }
      }, onError: (_) {}),
    );
    future.whenComplete(() {
      if (identical(_inFlight[requestKey], future)) {
        _inFlight.remove(requestKey);
      }
    });
    return future;
  }

  void dispose() {
    _inFlight.clear();
    _resolved.clear();
  }
}
