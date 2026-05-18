import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/group.dart';
import '../../data/models/user.dart';
import '../../service/api/group_api.dart';
import '../../service/api/user_api.dart';
import 'chat_channel_identity.dart';
import 'chat_channel_settings.dart';

typedef ChatGroupInfoLoader =
    Future<GroupInfo> Function(String groupNo, {CancelToken? cancelToken});
typedef ChatUserInfoLoader =
    Future<UserInfo> Function(String uid, {CancelToken? cancelToken});

class ChatChannelHydrationResult {
  const ChatChannelHydrationResult({
    required this.channel,
    required this.didHydrate,
  });

  final WKChannel? channel;
  final bool didHydrate;
}

class ChatChannelHydrationService {
  ChatChannelHydrationService({
    ChatGroupInfoLoader? groupInfoLoader,
    ChatUserInfoLoader? userInfoLoader,
  }) : _groupInfoLoader = groupInfoLoader ?? GroupApi.instance.getGroupInfo,
       _userInfoLoader = userInfoLoader ?? UserApi.instance.getUserInfo;

  final ChatGroupInfoLoader _groupInfoLoader;
  final ChatUserInfoLoader _userInfoLoader;

  Future<ChatChannelHydrationResult> hydrateRemoteChannel({
    required String channelId,
    required int channelType,
    WKChannel? currentChannel,
    CancelToken? cancelToken,
  }) async {
    final channel = currentChannel ?? WKChannel(channelId, channelType);
    try {
      if (channelType == WKChannelType.group) {
        final group = await _groupInfoLoader(
          channelId,
          cancelToken: cancelToken,
        );
        _applyGroupRemoteState(channel, group);
      } else if (channelType == WKChannelType.personal) {
        final user = await _userInfoLoader(channelId, cancelToken: cancelToken);
        _applyUserRemoteState(channel, user);
      }
    } on DioException {
      return ChatChannelHydrationResult(
        channel: currentChannel,
        didHydrate: false,
      );
    } catch (_) {
      return ChatChannelHydrationResult(
        channel: currentChannel,
        didHydrate: false,
      );
    }
    return ChatChannelHydrationResult(channel: channel, didHydrate: true);
  }

  void _applyGroupRemoteState(WKChannel channel, GroupInfo group) {
    applyChannelFlameSettings(
      channel,
      flame: group.flame ?? 0,
      flameSecond: group.flameSecond ?? 0,
    );
    if ((group.memberCount ?? 0) > 0) {
      final remoteExtra = mutableChannelExtraMap(channel.remoteExtraMap);
      remoteExtra['member_count'] = group.memberCount ?? 0;
      channel.remoteExtraMap = remoteExtra;
    }
  }

  void _applyUserRemoteState(WKChannel channel, UserInfo user) {
    applyChannelUserIdentity(channel, user);
    applyChannelFlameSettings(
      channel,
      flame: user.flame ?? 0,
      flameSecond: user.flameSecond ?? 0,
    );
  }
}
