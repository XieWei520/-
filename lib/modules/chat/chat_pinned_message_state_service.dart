import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../service/api/message_api.dart';
import 'chat_channel_identity.dart';
import 'chat_channel_settings.dart';
import 'chat_pinned_message_resolver.dart';

typedef ChatPinnedGroupInfoLoader = Future<GroupInfo> Function(String groupNo);

typedef ChatPinnedMessagesSync =
    Future<PinnedMessageSyncSnapshot> Function({
      required String channelId,
      required int channelType,
      int version,
    });

class ChatPinnedUiSnapshot {
  const ChatPinnedUiSnapshot({
    required this.canPin,
    required this.canClearAll,
    required this.messages,
  });

  final bool canPin;
  final bool canClearAll;
  final List<ResolvedPinnedMessage> messages;
}

class ChatPinnedMessageStateService {
  ChatPinnedMessageStateService({ChatPinnedGroupInfoLoader? groupInfoLoader})
    : _groupInfoLoader = groupInfoLoader ?? GroupApi.instance.getGroupInfo;

  final ChatPinnedGroupInfoLoader _groupInfoLoader;

  Future<ChatPinnedUiSnapshot> loadSnapshot({
    required String channelId,
    required int channelType,
    required ChatPinnedMessagesSync syncPinnedMessages,
    required List<ResolvedPinnedMessage> previousMessages,
    WKChannel? channel,
  }) async {
    if (!supportsPinnedMessages(
      channelId: channelId,
      channelType: channelType,
    )) {
      return const ChatPinnedUiSnapshot(
        canPin: false,
        canClearAll: false,
        messages: <ResolvedPinnedMessage>[],
      );
    }

    var canPin = channelType == WKChannelType.personal;
    var canClearAll = false;

    if (channelType == WKChannelType.group) {
      try {
        final group = await _groupInfoLoader(channelId);
        final canManage = canManagePinnedMessages(group.role);
        canPin = canManage || (group.allowMemberPinnedMessage ?? 0) == 1;
        canClearAll = canManage;
      } catch (_) {
        final allowMemberPinned = readChannelExtraInt(
          channel?.remoteExtraMap,
          const ['allow_member_pinned_message'],
        );
        canPin = allowMemberPinned == 1;
        canClearAll = false;
      }
    }

    try {
      final pinnedSnapshot = await syncPinnedMessages(
        channelId: channelId,
        channelType: channelType,
        version: 0,
      );
      return ChatPinnedUiSnapshot(
        canPin: canPin,
        canClearAll: canClearAll,
        messages: resolvePinnedMessages(pinnedSnapshot),
      );
    } catch (_) {
      return ChatPinnedUiSnapshot(
        canPin: canPin,
        canClearAll: canClearAll,
        messages: previousMessages,
      );
    }
  }
}

bool supportsPinnedMessages({
  required String channelId,
  required int channelType,
}) {
  if (channelType == WKChannelType.group) {
    return true;
  }
  if (channelType != WKChannelType.personal) {
    return false;
  }
  return !isAndroidFixedChat(channelId, channelType);
}
