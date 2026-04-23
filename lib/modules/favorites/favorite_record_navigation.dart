import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../chat/chat_page.dart';
import 'favorite_record.dart';

typedef FavoriteRecordChatPageBuilder = Widget Function(FavoriteRecord record);
typedef FavoriteRecordRouteResolver =
    Future<FavoriteChatTarget?> Function(FavoriteRecord record);

class FavoriteChatTarget {
  const FavoriteChatTarget({
    required this.channelId,
    required this.channelType,
    this.orderSeq,
  });

  final String channelId;
  final int channelType;
  final int? orderSeq;
}

Future<bool> openFavoriteRecordInContext(
  BuildContext context,
  FavoriteRecord record, {
  FavoriteRecordChatPageBuilder? chatPageBuilder,
  FavoriteRecordRouteResolver? routeResolver,
}) async {
  final chatTarget = await _resolveChatTarget(
    record,
    routeResolver: routeResolver ?? _resolveChatTargetFromLocalCache,
  );
  if (!context.mounted) {
    return false;
  }
  if (chatTarget != null) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            chatPageBuilder?.call(record) ??
            ChatPage(
              channelId: chatTarget.channelId,
              channelType: chatTarget.channelType,
              initialAroundOrderSeq: chatTarget.orderSeq,
            ),
      ),
    );
    return true;
  }

  final uri = record.externalUri;
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<FavoriteChatTarget?> _resolveChatTarget(
  FavoriteRecord record, {
  required FavoriteRecordRouteResolver routeResolver,
}) async {
  final directTarget = _buildDirectChatTarget(record);
  if (directTarget != null && record.hasServerOrderAnchor) {
    return directTarget;
  }

  final recoveredTarget = await routeResolver(record);
  if (recoveredTarget != null) {
    return recoveredTarget;
  }

  return directTarget;
}

FavoriteChatTarget? _buildDirectChatTarget(FavoriteRecord record) {
  if (!record.hasChatRoute) {
    return null;
  }
  final channelId = record.channelId?.trim() ?? '';
  final channelType = record.channelType ?? 0;
  if (channelId.isEmpty || channelType <= 0) {
    return null;
  }
  return FavoriteChatTarget(
    channelId: channelId,
    channelType: channelType,
    orderSeq: record.orderSeq,
  );
}

Future<FavoriteChatTarget?> _resolveChatTargetFromLocalCache(
  FavoriteRecord record,
) async {
  final message = await _lookupFavoriteMessage(record);
  if (message == null) {
    return null;
  }
  final channelId = message.channelID.trim();
  final channelType = message.channelType;
  if (channelId.isEmpty || channelType <= 0) {
    return null;
  }
  return FavoriteChatTarget(
    channelId: channelId,
    channelType: channelType,
    orderSeq: message.orderSeq > 0 ? message.orderSeq : null,
  );
}

Future<WKMsg?> _lookupFavoriteMessage(FavoriteRecord record) async {
  final messageId = record.messageId?.trim() ?? '';
  if (messageId.isNotEmpty) {
    final matches = await MessageDB.shared.queryWithMessageIds(<String>[
      messageId,
    ]);
    if (matches.isNotEmpty) {
      return matches.first;
    }
  }

  final clientMsgNo = record.clientMsgNo?.trim() ?? '';
  if (clientMsgNo.isEmpty) {
    return null;
  }
  return MessageDB.shared.queryWithClientMsgNo(clientMsgNo);
}
