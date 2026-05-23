import 'package:permission_handler/permission_handler.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';
import '../../data/models/friend.dart';
import '../../data/models/user_relationship.dart';
import '../../data/models/user.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/user_api.dart';
import '../../wukong_base/utils/permission_utils.dart';
import '../video_call/video_call_runtime_bridge.dart';

const String chatCallAlreadyActiveMessage = '当前已有通话进行中';
const String chatCallForbiddenMessage = '当前会话已被禁言，无法发起音视频通话';
const String chatCallNonFriendRelationshipMessage = '当前为非好友关系，无法发起音视频通话';
const String chatCallBeBlacklistMessage = '你已被对方加入黑名单，无法发起音视频通话';
const String chatCallBlacklistMessage = '你已将对方加入黑名单，无法发起音视频通话';
const String chatCallBlacklistGroupMessage = '你已被加入群黑名单，无法发起音视频通话';
const String chatAudioPermissionDeniedMessage = '发起语音通话需要麦克风权限';
const String chatAudioPermissionSettingsMessage = '麦克风权限已被永久拒绝，请前往系统设置开启';
const String chatVideoPermissionDeniedMessage = '发起视频通话需要相机和麦克风权限';
const String chatVideoPermissionSettingsMessage = '相机或麦克风权限已被永久拒绝，请前往系统设置开启';

typedef ChatCallChannelLoader =
    Future<WKChannel?> Function({
      required String channelId,
      required int channelType,
    });
typedef ChatCallMemberLoader =
    Future<WKChannelMember?> Function({
      required String channelId,
      required int channelType,
      required String uid,
    });
typedef ChatCallUidReader = String? Function();
typedef ChatCallPersonalRelationshipLoader =
    Future<UserRelationshipState?> Function({required String uid});

class ChatCallEntryDecision {
  const ChatCallEntryDecision._({this.callType, this.feedbackMessage});

  final CallType? callType;
  final String? feedbackMessage;

  bool get shouldStart => callType != null;

  static ChatCallEntryDecision start(CallType callType) {
    return ChatCallEntryDecision._(callType: callType);
  }

  static ChatCallEntryDecision blocked(String message) {
    return ChatCallEntryDecision._(feedbackMessage: message);
  }
}

abstract class ChatCallEntryService {
  Future<ChatCallEntryDecision> prepareOutgoingCall(
    CallType callType, {
    required String channelId,
    required int channelType,
  });
}

class PlatformChatCallEntryService implements ChatCallEntryService {
  PlatformChatCallEntryService({
    bool Function()? hasActiveCallOrPendingSetup,
    Future<bool> Function()? requestMicrophone,
    Future<bool> Function()? requestCameraAndMicrophone,
    Future<bool> Function()? isMicrophonePermanentlyDenied,
    Future<bool> Function()? isCameraPermanentlyDenied,
    ChatCallChannelLoader? channelLoader,
    ChatCallMemberLoader? memberLoader,
    ChatCallUidReader? currentUidReader,
    ChatCallPersonalRelationshipLoader? personalRelationshipLoader,
  }) : _hasActiveCallOrPendingSetup =
           hasActiveCallOrPendingSetup ?? _defaultHasActiveCallOrPendingSetup,
       _requestMicrophone =
           requestMicrophone ?? WKPermissions.requestMicrophone,
       _requestCameraAndMicrophone =
           requestCameraAndMicrophone ??
           WKPermissions.requestCameraAndMicrophone,
       _isMicrophonePermanentlyDenied =
           isMicrophonePermanentlyDenied ??
           _defaultIsMicrophonePermanentlyDenied,
       _isCameraPermanentlyDenied =
           isCameraPermanentlyDenied ?? _defaultIsCameraPermanentlyDenied,
       _channelLoader = channelLoader ?? _defaultChannelLoader,
       _memberLoader = memberLoader ?? _defaultMemberLoader,
       _currentUidReader = currentUidReader ?? _defaultCurrentUidReader,
       _personalRelationshipLoader =
           personalRelationshipLoader ?? _defaultPersonalRelationshipLoader;

  final bool Function() _hasActiveCallOrPendingSetup;
  final Future<bool> Function() _requestMicrophone;
  final Future<bool> Function() _requestCameraAndMicrophone;
  final Future<bool> Function() _isMicrophonePermanentlyDenied;
  final Future<bool> Function() _isCameraPermanentlyDenied;
  final ChatCallChannelLoader _channelLoader;
  final ChatCallMemberLoader _memberLoader;
  final ChatCallUidReader _currentUidReader;
  final ChatCallPersonalRelationshipLoader _personalRelationshipLoader;

  @override
  Future<ChatCallEntryDecision> prepareOutgoingCall(
    CallType callType, {
    required String channelId,
    required int channelType,
  }) async {
    if (_hasActiveCallOrPendingSetup()) {
      return ChatCallEntryDecision.blocked(chatCallAlreadyActiveMessage);
    }

    final channel = await _channelLoader(
      channelId: channelId,
      channelType: channelType,
    );
    final member = await _loadCurrentMember(
      channelId: channelId,
      channelType: channelType,
    );
    final prePermissionDecision = _buildForbiddenDecision(
      channel: channel,
      member: member,
    );
    if (prePermissionDecision != null) {
      return prePermissionDecision;
    }

    switch (callType) {
      case CallType.audio:
        final granted = await _requestMicrophone();
        if (!granted) {
          final permanentlyDenied = await _isMicrophonePermanentlyDenied();
          return ChatCallEntryDecision.blocked(
            permanentlyDenied
                ? chatAudioPermissionSettingsMessage
                : chatAudioPermissionDeniedMessage,
          );
        }
        final postPermissionDecision = await _buildBusinessDecision(
          channelId: channelId,
          channelType: channelType,
          channel: channel,
          member: member,
        );
        return postPermissionDecision ??
            ChatCallEntryDecision.start(CallType.audio);
      case CallType.video:
        final granted = await _requestCameraAndMicrophone();
        if (!granted) {
          final cameraDenied = await _isCameraPermanentlyDenied();
          if (cameraDenied) {
            return ChatCallEntryDecision.blocked(
              chatVideoPermissionSettingsMessage,
            );
          }
          final microphoneDenied = await _isMicrophonePermanentlyDenied();
          return ChatCallEntryDecision.blocked(
            microphoneDenied
                ? chatVideoPermissionSettingsMessage
                : chatVideoPermissionDeniedMessage,
          );
        }
        final postPermissionDecision = await _buildBusinessDecision(
          channelId: channelId,
          channelType: channelType,
          channel: channel,
          member: member,
        );
        return postPermissionDecision ??
            ChatCallEntryDecision.start(CallType.video);
    }
  }

  static bool _defaultHasActiveCallOrPendingSetup() {
    return VideoCallRuntimeBridge.instance.hasActiveCallOrPendingSetupSync();
  }

  static Future<WKChannel?> _defaultChannelLoader({
    required String channelId,
    required int channelType,
  }) {
    return WKIM.shared.channelManager.getChannel(channelId, channelType);
  }

  static Future<WKChannelMember?> _defaultMemberLoader({
    required String channelId,
    required int channelType,
    required String uid,
  }) {
    return WKIM.shared.channelMemberManager.getMember(
      channelId,
      channelType,
      uid,
    );
  }

  static String? _defaultCurrentUidReader() => StorageUtils.getUid();

  static Future<UserRelationshipState?> _defaultPersonalRelationshipLoader({
    required String uid,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty || !StorageUtils.isLoggedIn()) {
      return null;
    }

    UserInfo? user;
    List<Friend> friends = const <Friend>[];
    List<UserInfo> blacklist = const <UserInfo>[];

    try {
      user = await UserApi.instance.getUserInfo(normalizedUid);
    } catch (_) {}
    try {
      friends = await FriendApi.instance.getFriends();
    } catch (_) {}
    try {
      blacklist = await UserApi.instance.getBlackList();
    } catch (_) {}

    final hasEvidence =
        user != null || friends.isNotEmpty || blacklist.isNotEmpty;
    if (!hasEvidence) {
      return null;
    }

    return resolveUserRelationshipState(
      targetUid: normalizedUid,
      user: user,
      friends: friends,
      blacklist: blacklist,
    );
  }

  static Future<bool> _defaultIsMicrophonePermanentlyDenied() {
    return WKPermissions.isPermanentlyDenied(Permission.microphone);
  }

  static Future<bool> _defaultIsCameraPermanentlyDenied() {
    return WKPermissions.isPermanentlyDenied(Permission.camera);
  }

  Future<WKChannelMember?> _loadCurrentMember({
    required String channelId,
    required int channelType,
  }) async {
    final uid = _currentUidReader()?.trim() ?? '';
    if (uid.isEmpty) {
      return null;
    }
    return _memberLoader(
      channelId: channelId,
      channelType: channelType,
      uid: uid,
    );
  }

  ChatCallEntryDecision? _buildForbiddenDecision({
    required WKChannel? channel,
    required WKChannelMember? member,
  }) {
    final channelForbidden = (channel?.forbidden ?? 0) == 1;
    final memberForbidden = _isMemberMuted(member);
    if (memberForbidden) {
      return ChatCallEntryDecision.blocked(chatCallForbiddenMessage);
    }
    if (!channelForbidden || _isGroupManagerOrOwner(member)) {
      return null;
    }
    return ChatCallEntryDecision.blocked(chatCallForbiddenMessage);
  }

  Future<ChatCallEntryDecision?> _buildBusinessDecision({
    required String channelId,
    required int channelType,
    required WKChannel? channel,
    required WKChannelMember? member,
  }) async {
    if (channelType == WKChannelType.personal) {
      final relationship = await _loadPersonalRelationship(
        channelId: channelId,
      );
      if (_isBlockedByPeer(channel, relationship)) {
        return ChatCallEntryDecision.blocked(chatCallBeBlacklistMessage);
      }
      if (_isBlacklistedByCurrentUser(channel, relationship)) {
        return ChatCallEntryDecision.blocked(chatCallBlacklistMessage);
      }
      if (_isNonFriendRelationship(channel, relationship)) {
        return ChatCallEntryDecision.blocked(
          chatCallNonFriendRelationshipMessage,
        );
      }
      return null;
    }

    if (channelType == WKChannelType.group && _isGroupBlacklisted(member)) {
      return ChatCallEntryDecision.blocked(chatCallBlacklistGroupMessage);
    }

    return null;
  }

  Future<UserRelationshipState?> _loadPersonalRelationship({
    required String channelId,
  }) async {
    try {
      return await _personalRelationshipLoader(uid: channelId);
    } catch (_) {
      return null;
    }
  }

  static bool _isNonFriendRelationship(
    WKChannel? channel,
    UserRelationshipState? relationship,
  ) {
    if (relationship != null) {
      return !relationship.isFriend;
    }
    if (channel == null) {
      return false;
    }
    final follow = channel.follow;
    if (follow == 0) {
      return true;
    }
    return _readExtraFlag(channel.localExtra, const [
          'beDeleted',
          'be_deleted',
        ]) ==
        1;
  }

  static bool _isBlockedByPeer(
    WKChannel? channel,
    UserRelationshipState? relationship,
  ) {
    if (relationship != null) {
      return relationship.isBlockedByPeer;
    }
    if (channel == null) {
      return false;
    }
    return _readExtraFlag(channel.localExtra, const [
          'beBlacklist',
          'be_blacklist',
        ]) ==
        1;
  }

  static bool _isBlacklistedByCurrentUser(
    WKChannel? channel,
    UserRelationshipState? relationship,
  ) {
    if (relationship != null) {
      return relationship.isInBlacklist;
    }
    return (channel?.status ?? 1) == 2;
  }

  static bool _isGroupBlacklisted(WKChannelMember? member) {
    return (member?.status ?? 1) == 2;
  }

  static bool _isGroupManagerOrOwner(WKChannelMember? member) {
    final role = member?.role ?? 0;
    return role == 1 || role == 2;
  }

  static bool _isMemberMuted(WKChannelMember? member) {
    final expiresAt = member?.forbiddenExpirationTime ?? 0;
    if (expiresAt <= 0) {
      return false;
    }
    return expiresAt > DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static int _readExtraFlag(dynamic map, List<String> keys) {
    if (map is! Map) {
      return 0;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }
}
