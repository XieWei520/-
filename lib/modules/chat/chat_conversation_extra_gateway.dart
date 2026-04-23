import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../service/api/conversation_draft_api.dart';

abstract class ChatConversationExtraGateway {
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  });

  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  });
}

final chatConversationExtraGatewayProvider =
    Provider<ChatConversationExtraGateway>(
      (ref) => WkImChatConversationExtraGateway(),
    );

class WkImChatConversationExtraGateway implements ChatConversationExtraGateway {
  WkImChatConversationExtraGateway({
    ConversationDraftRemoteStore? remoteStore,
  }) : _remoteStore = remoteStore ?? ConversationDraftApi.instance;

  final ConversationDraftRemoteStore _remoteStore;

  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    final conversation = await WKIM.shared.conversationManager.getWithChannel(
      channelId,
      channelType,
    );
    return conversation?.getRemoteMsgExtra();
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {
    final extra = WKConversationMsgExtra()
      ..channelID = channelId
      ..channelType = channelType
      ..browseTo = browseTo
      ..keepMessageSeq = keepMessageSeq
      ..keepOffsetY = keepOffsetY
      ..draft = draft;
    if (draft.trim().isNotEmpty) {
      extra.draftUpdatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    await WKIM.shared.conversationManager.updateMsgExtra(extra);
    unawaited(
      _remoteStore.updateExtra(
        channelId: channelId,
        channelType: channelType,
        browseTo: browseTo,
        keepMessageSeq: keepMessageSeq,
        keepOffsetY: keepOffsetY,
        draft: draft,
      ),
    );
  }
}
