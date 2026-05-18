import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/user.dart';
import '../customer_service/customer_service_identity.dart';

const String androidSystemTeamId = 'u_10000';
const String androidFileHelperId = 'fileHelper';
const String _fileHelperTitle = '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b';
const String _systemTitle = '\u7cfb\u7edf\u901a\u77e5';

String? androidFixedChatTitle(String channelId, int channelType) {
  if (channelType != WKChannelType.personal) {
    return null;
  }
  if (channelId == androidSystemTeamId) {
    return _systemTitle;
  }
  if (channelId == androidFileHelperId) {
    return _fileHelperTitle;
  }
  return null;
}

bool isAndroidFixedChat(String channelId, int channelType) {
  return androidFixedChatTitle(channelId, channelType) != null;
}

bool shouldHydrateRemoteFlameSettings({
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

bool canShowPersonalCallActions({
  required String channelId,
  required int channelType,
}) {
  if (channelType != WKChannelType.personal) {
    return false;
  }
  return !isAndroidFixedChat(channelId, channelType);
}

bool canShowGroupCallAction(int channelType) {
  return channelType == WKChannelType.group;
}

WKChannel? buildParticipantFallbackChannel({
  required String channelId,
  required int channelType,
  String? channelName,
  WKChannel? loadedChannel,
}) {
  if (loadedChannel != null) {
    return loadedChannel;
  }
  if (channelType != WKChannelType.personal) {
    return null;
  }

  final title = firstNonEmptyText([
    androidFixedChatTitle(channelId, channelType),
    channelName,
  ]);
  if (title.isEmpty) {
    return null;
  }
  return WKChannel(channelId, channelType)..channelName = title;
}

void applyChannelUserIdentity(WKChannel channel, UserInfo user) {
  final displayName = firstNonEmptyText([
    user.remark,
    user.name,
    user.username,
  ]);
  if (displayName.isNotEmpty && displayName != channel.channelID) {
    channel.channelName = displayName;
  }
  final avatar = (user.avatar ?? '').trim();
  if (avatar.isNotEmpty) {
    channel.avatar = avatar;
  }
  final category = normalizePublicAccountCategory(user.category);
  if (category != null && category.isNotEmpty) {
    channel.category = category;
  }
}

String firstNonEmptyText(Iterable<String?> values) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}
