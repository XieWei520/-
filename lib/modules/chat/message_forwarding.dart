import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/core/utils/avatar_utils.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/wk_custom_content.dart';

class ForwardTarget {
  final String channelId;
  final int channelType;
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final bool isGroup;

  const ForwardTarget({
    required this.channelId,
    required this.channelType,
    required this.name,
    this.subtitle = '',
    this.avatarUrl,
    this.isGroup = false,
  });

  String get key => '$channelType:$channelId';

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return channelId.trim();
  }
}

@immutable
class ForwardPayload {
  const ForwardPayload({required this.clientMsgNo, required this.content});

  final String clientMsgNo;
  final WKMessageContent? content;

  WKMessageContent? cloneContent() => cloneMessageContentForForward(content);
}

List<ForwardPayload> buildForwardPayloads(Iterable<WKMsg> messages) {
  return messages
      .map(
        (message) => ForwardPayload(
          clientMsgNo: message.clientMsgNO,
          content: cloneMessageContentForForward(message.messageContent),
        ),
      )
      .where((payload) => payload.clientMsgNo.trim().isNotEmpty)
      .where((payload) => payload.content != null)
      .toList(growable: false);
}

WKMessageContent? cloneMessageContentForForward(WKMessageContent? content) {
  if (content == null) {
    return null;
  }

  if (content is WKTextContent) {
    return WKTextContent(content.content);
  }

  if (content is WKImageContent) {
    return WKImageContent(content.width, content.height)
      ..url = content.url
      ..localPath = content.localPath;
  }

  if (content is WKVideoContent) {
    return WKVideoContent()
      ..cover = content.cover
      ..coverLocalPath = content.coverLocalPath
      ..localPath = content.localPath
      ..size = content.size
      ..width = content.width
      ..height = content.height
      ..second = content.second
      ..url = content.url;
  }

  if (content is WKLocationContent) {
    return WKLocationContent()
      ..latitude = content.latitude
      ..longitude = content.longitude
      ..title = content.title
      ..address = content.address;
  }

  if (content is WKFileContent) {
    return WKFileContent()
      ..name = content.name
      ..size = content.size
      ..url = content.url
      ..localPath = content.localPath
      ..suffix = content.suffix;
  }

  if (content is WKCardContent) {
    return WKCardContent(content.uid, content.name)..vercode = content.vercode;
  }

  return null;
}

List<ForwardTarget> filterForwardTargets(
  List<ForwardTarget> targets,
  String keyword,
) {
  final query = keyword.trim().toLowerCase();
  if (query.isEmpty) {
    return List<ForwardTarget>.from(targets, growable: false);
  }

  return targets.where((target) {
    final haystack = [
      target.displayName,
      target.subtitle,
      target.channelId,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }).toList(growable: false);
}

String targetAvatarLabel(String? name, {String fallback = '?'}) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) {
    return fallback;
  }
  return trimmed.substring(0, 1).toUpperCase();
}

Future<List<ForwardTarget>> buildForwardTargetsFromConversations(
  Iterable<WKUIConversationMsg> conversations, {
  String? excludedChannelId,
  int? excludedChannelType,
}) async {
  final targets = <ForwardTarget>[];

  for (final conversation in conversations) {
    if (excludedChannelId != null &&
        excludedChannelType != null &&
        conversation.channelID == excludedChannelId &&
        conversation.channelType == excludedChannelType) {
      continue;
    }

    final channel = await conversation.getWkChannel();
    final isGroup = conversation.channelType == WKChannelType.group;
    targets.add(
      ForwardTarget(
        channelId: conversation.channelID,
        channelType: conversation.channelType,
        name: _resolveForwardTargetTitle(conversation, channel),
        subtitle: isGroup ? 'Group chat' : 'Direct chat',
        avatarUrl: _resolveForwardTargetAvatar(conversation, channel),
        isGroup: isGroup,
      ),
    );
  }

  return targets;
}

String _resolveForwardTargetTitle(
  WKUIConversationMsg conversation,
  WKChannel? channel,
) {
  final remark = channel?.channelRemark.trim() ?? '';
  if (remark.isNotEmpty) {
    return remark;
  }

  final name = channel?.channelName.trim() ?? '';
  if (name.isNotEmpty) {
    return name;
  }

  return conversation.channelID.trim();
}

String? _resolveForwardTargetAvatar(
  WKUIConversationMsg conversation,
  WKChannel? channel,
) {
  final resolvedAvatar = resolveAvatarUrl(channel?.avatar);
  if (resolvedAvatar != null) {
    return resolvedAvatar;
  }

  if (conversation.channelType == WKChannelType.personal) {
    return buildUserAvatarUrl(
      conversation.channelID,
      cacheKey: channel?.avatarCacheKey,
    );
  }

  return null;
}
