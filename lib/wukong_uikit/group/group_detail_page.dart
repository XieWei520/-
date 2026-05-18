// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/platform/local_image_picker.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/models/user.dart';
import '../../data/providers/channel_provider.dart';
import '../../modules/group_reminder/group_reminder_page.dart';
import '../../modules/report/report_page.dart';
import '../../modules/chat/channel_settings_common.dart';
import '../../modules/settings/settings_surface_widgets.dart';
import '../../modules/search/presentation/message_record_search_page.dart';
import '../../service/api/channel_api.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/group_api.dart';
import '../../service/api/message_api.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_dialog.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/group_detail_slots.dart';
import '../user/user_detail_page.dart';
import 'all_members_page.dart';
import 'delete_group_members_page.dart';
import 'group_blacklist_page.dart';
import 'group_detail_slot_assembly.dart';
import 'group_dingtalk_bot_page.dart';
import 'group_feishu_bot_page.dart';
import 'group_member_picker_page.dart';
import 'group_notice_page.dart';
import 'group_qr_page.dart';
import 'group_remark_page.dart';
import 'update_group_name_page.dart';

enum AndroidGroupDetailMemberItemType { member, add, remove }

class AndroidGroupDetailMemberItem {
  final AndroidGroupDetailMemberItemType type;
  final GroupMember? member;

  const AndroidGroupDetailMemberItem._({required this.type, this.member});

  const AndroidGroupDetailMemberItem.member(GroupMember member)
    : this._(type: AndroidGroupDetailMemberItemType.member, member: member);

  const AndroidGroupDetailMemberItem.add()
    : this._(type: AndroidGroupDetailMemberItemType.add);

  const AndroidGroupDetailMemberItem.remove()
    : this._(type: AndroidGroupDetailMemberItemType.remove);
}

List<AndroidGroupDetailMemberItem> buildAndroidGroupDetailMemberItems({
  required List<GroupMember> members,
  required bool canAddMembers,
  required bool canRemoveMembers,
  int maxVisibleMembers = 19,
}) {
  final orderedMembers = <GroupMember>[
    ...members.where((member) => member.isOwner),
    ...members.where((member) => member.isAdmin),
    ...members.where((member) => !member.isOwner && !member.isAdmin),
  ];

  final items = orderedMembers
      .take(maxVisibleMembers)
      .map(AndroidGroupDetailMemberItem.member)
      .toList();

  if (canAddMembers) {
    items.add(const AndroidGroupDetailMemberItem.add());
  }
  if (canRemoveMembers) {
    items.add(const AndroidGroupDetailMemberItem.remove());
  }
  return items;
}

enum AndroidGroupDetailRowType {
  groupName,
  groupQr,
  groupNotice,
  remark,
  searchHistory,
  mute,
  top,
  save,
  myNick,
  showNick,
  feishuBot,
  dingTalkBot,
  groupReminder,
  report,
  clearHistory,
}

class AndroidGroupDetailRow {
  final AndroidGroupDetailRowType type;
  final String title;

  const AndroidGroupDetailRow({required this.type, required this.title});
}

List<AndroidGroupDetailRow> buildAndroidGroupDetailRows({
  required bool showNickSetting,
  required bool includeFeishuBot,
  required bool includeDingTalkBot,
  required bool includeGroupReminder,
}) {
  return _buildReadableAndroidGroupDetailRows(
    showNickSetting: showNickSetting,
    includeFeishuBot: includeFeishuBot,
    includeDingTalkBot: includeDingTalkBot,
    includeGroupReminder: includeGroupReminder,
  );
}
/*
  final rows = <AndroidGroupDetailRow>[
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupName,
      title: '缇よ亰鍚嶇О',
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupQr,
      title: '缇や簩缁寸爜',
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupNotice,
      title: '缇ゅ叕鍛?,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.remark,
      title: '澶囨敞',
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.searchHistory,
      title: '鏌ユ壘鑱婂ぉ璁板綍',
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.mute,
      title: '娑堟伅鍏嶆墦鎵?,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.top,
      title: '缃《鑱婂ぉ',
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.save,
      title: '淇濆瓨鍒伴€氳褰?,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.myNick,
      title: '鎴戝湪鏈兢鐨勬樀绉?,
    ),
  ];

  if (showNickSetting) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.showNick,
        title: '鏄剧ず缇ゆ垚鍛樻樀绉?,
      ),
    );
  }
  if (includeFeishuBot) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.feishuBot,
        title: '鍏煎椋炰功鏈哄櫒浜?,
      ),
    );
  }
  if (includeGroupReminder) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupReminder,
        title: '缇ゅ緟鍔?/ 缇ゆ彁閱?,
      ),
    );
  }

  rows.addAll(const [
    AndroidGroupDetailRow(type: AndroidGroupDetailRowType.report, title: '涓炬姤'),
    AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.clearHistory,
      title: '娓呯┖鑱婂ぉ璁板綍',
    ),
  ]);
  rows
    ..clear()
    ..addAll(const [
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupName,
        title: '缇よ亰鍚嶇О',
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupQr,
        title: '缇や簩缁寸爜',
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupNotice,
        title: '缇ゅ叕鍛?,
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.remark,
        title: '澶囨敞',
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.searchHistory,
        title: '鏌ユ壘鑱婂ぉ璁板綍',
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.mute,
        title: '娑堟伅鍏嶆墦鎵?,
      ),
      AndroidGroupDetailRow(type: AndroidGroupDetailRowType.top, title: '缃《鑱婂ぉ'),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.save,
        title: '淇濆瓨鍒伴€氳褰?,
      ),
      AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.myNick,
        title: '鎴戝湪鏈兢鐨勬樀绉?,
      ),
    ]);

  if (showNickSetting) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.showNick,
        title: '鏄剧ず缇ゆ垚鍛樻樀绉?,
      ),
    );
  }
  if (includeFeishuBot) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.feishuBot,
        title: '鍏煎椋炰功鏈哄櫒浜?,
      ),
    );
  }
  if (includeGroupReminder) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupReminder,
        title: '缇ゅ緟鍔?/ 缇ゆ彁閱?,
      ),
    );
  }

  rows.addAll(const [
    AndroidGroupDetailRow(type: AndroidGroupDetailRowType.report, title: '鎶曡瘔'),
    AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.clearHistory,
      title: '娓呯┖鑱婂ぉ璁板綍',
    ),
  ]);
  return rows;
}
*/

const String _groupDetailNameTitle = '群聊名称';
const String _groupDetailQrTitle = '群二维码';
const String _groupDetailNoticeTitle = '群公告';
const String _groupDetailRemarkTitle = '备注';
const String _groupDetailSearchHistoryTitle = '查找聊天记录';
const String _groupDetailMuteTitle = '消息免打扰';
const String _groupDetailTopTitle = '置顶聊天';
const String _groupDetailSaveTitle = '保存到通讯录';
const String _groupDetailMyNickTitle = '我在本群的昵称';
const String _groupDetailShowNickTitle = '显示群成员昵称';
const String _groupDetailFeishuBotTitle = '飞书机器人';
const String _groupDetailReminderTitle = '群待办 / 群提醒';
const String _groupDetailReportTitle = '投诉';
const String _groupDetailClearHistoryTitle = '清空聊天记录';

const String _groupDetailChatPasswordTitle = '聊天密码';
const String _groupDetailAutoDeleteTitle = '消息自动删除';
const String _groupDetailAutoDeleteUpdatedMessage = '消息自动删除设置已更新';

List<AndroidGroupDetailRow> _buildReadableAndroidGroupDetailRows({
  required bool showNickSetting,
  required bool includeFeishuBot,
  required bool includeDingTalkBot,
  required bool includeGroupReminder,
}) {
  final rows = <AndroidGroupDetailRow>[
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupName,
      title: _groupDetailNameTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupQr,
      title: _groupDetailQrTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.groupNotice,
      title: _groupDetailNoticeTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.remark,
      title: _groupDetailRemarkTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.searchHistory,
      title: _groupDetailSearchHistoryTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.mute,
      title: _groupDetailMuteTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.top,
      title: _groupDetailTopTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.save,
      title: _groupDetailSaveTitle,
    ),
    const AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.myNick,
      title: _groupDetailMyNickTitle,
    ),
  ];

  if (showNickSetting) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.showNick,
        title: _groupDetailShowNickTitle,
      ),
    );
  }
  if (includeFeishuBot) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.feishuBot,
        title: _groupDetailFeishuBotTitle,
      ),
    );
  }
  if (includeDingTalkBot) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.dingTalkBot,
        title: '钉钉机器人',
      ),
    );
  }
  if (includeGroupReminder) {
    rows.add(
      const AndroidGroupDetailRow(
        type: AndroidGroupDetailRowType.groupReminder,
        title: _groupDetailReminderTitle,
      ),
    );
  }

  rows.addAll(const [
    AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.report,
      title: _groupDetailReportTitle,
    ),
    AndroidGroupDetailRow(
      type: AndroidGroupDetailRowType.clearHistory,
      title: _groupDetailClearHistoryTitle,
    ),
  ]);
  return rows;
}

@visibleForTesting
Widget buildGroupSearchHistoryPage({
  required String channelId,
  required int channelType,
  String? channelName,
}) {
  return MessageRecordSearchPage(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
  );
}

class GroupDetailPage extends StatefulWidget {
  final String channelId;
  final int channelType;
  final Future<String?> Function()? pickAvatarImage;
  final Future<String> Function(String groupNo, String filePath)?
  uploadAvatarImage;

  const GroupDetailPage({
    super.key,
    required this.channelId,
    this.channelType = 1,
    this.pickAvatarImage,
    this.uploadAvatarImage,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  GroupInfo? _group;
  List<GroupMember> _members = const <GroupMember>[];
  bool _isLoading = true;
  bool _isUpdating = false;
  int _memberRole = 0;
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isSaved = false;
  bool _isChatPwdOn = false;
  int _messageAutoDeleteSeconds = 0;
  bool _showNick = true;
  bool _inviteOnly = false;
  bool _joinGroupRemind = false;
  bool _allowViewHistory = true;
  bool _allowMemberPinnedMessage = false;
  String _pendingUploadedGroupAvatar = '';
  String _groupAvatarBeforeUpload = '';
  Timer? _forbiddenTicker;

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';

  GroupMember? get _currentMember {
    for (final member in _members) {
      if (member.uid == _currentUid) {
        return member;
      }
    }
    return null;
  }

  bool get _isOwner => _memberRole == 1;
  bool get _isAdmin => _memberRole == 2;
  bool get _canManageMembers => _isOwner || _isAdmin;
  bool get _canEditGroupAvatar => _canManageMembers;
  bool get _canManageAdmins => _isOwner;
  bool get _canRenameGroup => _canManageMembers;
  bool get _canDismissGroup => _isOwner;

  bool get _canAddMembers {
    if (_currentUid.isEmpty || _currentMember == null) {
      return false;
    }
    return true;
  }

  List<GroupMember> get _removableMembers {
    if (!_canManageMembers) {
      return const <GroupMember>[];
    }
    return _members.where((member) {
      if (member.uid == _currentUid) {
        return false;
      }
      if (_isOwner) {
        return true;
      }
      return !member.isOwner && !member.isAdmin;
    }).toList();
  }

  bool get _canRemoveMembers => _removableMembers.isNotEmpty;

  List<GroupMember> get _promotableMembers {
    if (!_canManageAdmins) {
      return const <GroupMember>[];
    }
    return _members.where((member) {
      if (member.uid == _currentUid) {
        return false;
      }
      return member.isNormal;
    }).toList();
  }

  List<GroupMember> get _demotableManagers {
    if (!_canManageAdmins) {
      return const <GroupMember>[];
    }
    return _members.where((member) {
      if (member.uid == _currentUid) {
        return false;
      }
      return member.isAdmin;
    }).toList();
  }

  List<GroupMember> get _transferableMembers {
    if (!_canManageAdmins) {
      return const <GroupMember>[];
    }
    return _members.where((member) => member.uid != _currentUid).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _forbiddenTicker?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait<Object?>([
        GroupApi.instance.getGroupInfo(widget.channelId),
        GroupApi.instance.getGroupMembers(widget.channelId),
        () async {
          try {
            return await FriendApi.instance.getFriends();
          } catch (_) {
            return const <Friend>[];
          }
        }(),
        () async {
          try {
            return await UserApi.instance.getCurrentUser();
          } catch (_) {
            return null;
          }
        }(),
        () async {
          try {
            return await ChannelApi.instance.getChannelInfo(
              channelId: widget.channelId,
              channelType: widget.channelType,
            );
          } catch (_) {
            return null;
          }
        }(),
      ]);
      var group = results[0] as GroupInfo;
      group = _applyPendingGroupAvatarOverride(group);
      final members = results[1] as List<GroupMember>;
      final friends = results[2] as List<Friend>;
      final currentUser = results[3] as UserInfo?;
      final channelInfo = results[4] as ChannelInfo?;
      final resolvedMembers = _enrichMembers(
        members,
        friends: friends,
        currentUser: currentUser,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _group = group;
        _members = resolvedMembers;
        _memberRole = _resolveMemberRole(group, resolvedMembers);
        _syncSettingsFromGroup(group, channelInfo: channelInfo);
        _isLoading = false;
      });
      await updateChannelExtraCache(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _group?.name,
        chatPwdOn: _isChatPwdOn ? 1 : 0,
        msgAutoDelete: _messageAutoDeleteSeconds,
      );
      _syncGroupConversationCache(group);
      _refreshForbiddenTicker();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载群资料失败：$e');
    }
  }

  void _syncGroupConversationCache(GroupInfo group) {
    if (!mounted) {
      return;
    }
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(myGroupListProvider.notifier).upsertGroup(group);
    } catch (_) {
      // The group detail can be mounted in isolated tests/routes without the
      // app-level ProviderScope; cache sync is best effort and must not block
      // the detail page refresh.
    }
  }

  GroupInfo _applyPendingGroupAvatarOverride(GroupInfo group) {
    final pendingAvatar = _pendingUploadedGroupAvatar.trim();
    if (pendingAvatar.isEmpty) {
      return group;
    }

    final serverAvatar = (group.avatar ?? '').trim();
    final previousAvatar = _groupAvatarBeforeUpload.trim();
    final serverIsOld =
        serverAvatar.isEmpty ||
        (previousAvatar.isNotEmpty &&
            _sameAvatarIdentity(serverAvatar, previousAvatar)) ||
        _sameAvatarIdentity(serverAvatar, pendingAvatar);
    if (serverIsOld) {
      return group.copyWith(avatar: pendingAvatar);
    }

    _pendingUploadedGroupAvatar = '';
    _groupAvatarBeforeUpload = '';
    return group;
  }

  bool _sameAvatarIdentity(String first, String second) {
    return _avatarIdentity(first) == _avatarIdentity(second);
  }

  String _avatarIdentity(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return normalized;
    }
    return uri
        .replace(queryParameters: const <String, String>{}, fragment: '')
        .toString();
  }

  int _resolveMemberRole(GroupInfo group, List<GroupMember> members) {
    final role = group.role;
    if (role != null && role >= 0) {
      return role;
    }
    for (final member in members) {
      if (member.uid == _currentUid) {
        return member.role ?? 0;
      }
    }
    if ((group.creator ?? '').trim() == _currentUid) {
      return 1;
    }
    return 0;
  }

  List<GroupMember> _enrichMembers(
    List<GroupMember> members, {
    required List<Friend> friends,
    required UserInfo? currentUser,
  }) {
    final friendByUid = <String, Friend>{
      for (final friend in friends) friend.uid: friend,
    };

    return members
        .map((member) {
          final friend = friendByUid[member.uid];
          final isCurrentUser =
              currentUser != null && currentUser.uid.trim() == member.uid;
          final resolvedRemark = _firstNonEmptyText(
            member.remark,
            friend?.remark,
            isCurrentUser ? currentUser.remark : null,
          );
          final resolvedName = _firstNonEmptyText(
            member.name,
            friend?.name,
            isCurrentUser ? currentUser.name : null,
            isCurrentUser ? currentUser.username : null,
            member.uid,
          );

          return member.copyWith(remark: resolvedRemark, name: resolvedName);
        })
        .toList(growable: false);
  }

  String? _firstNonEmptyText(
    dynamic first, [
    dynamic second,
    dynamic third,
    dynamic fourth,
    dynamic fifth,
  ]) {
    for (final value in <dynamic>[first, second, third, fourth, fifth]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  void _syncSettingsFromGroup(GroupInfo group, {ChannelInfo? channelInfo}) {
    _isMuted = (group.mute ?? 0) == 1;
    _isPinned = (group.top ?? 0) == 1;
    _isSaved = (group.save ?? 1) == 1;
    _isChatPwdOn = (group.chatPwdOn ?? 0) == 1;
    _messageAutoDeleteSeconds =
        channelInfo?.msgAutoDelete ?? _messageAutoDeleteSeconds;
    _showNick = (group.showNick ?? 1) == 1;
    _inviteOnly = (group.invite ?? 0) == 1;
    _joinGroupRemind = (group.joinGroupRemind ?? 0) == 1;
    _allowViewHistory = (group.allowViewHistoryMsg ?? 1) == 1;
    _allowMemberPinnedMessage = (group.allowMemberPinnedMessage ?? 0) == 1;
  }

  int get _forbiddenExpireAt => _group?.forbiddenExpirTime ?? 0;

  bool get _hasForbiddenReminder =>
      _forbiddenExpireAt > DateTime.now().millisecondsSinceEpoch ~/ 1000;

  void _refreshForbiddenTicker() {
    _forbiddenTicker?.cancel();
    if (!_hasForbiddenReminder) {
      return;
    }
    _forbiddenTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_hasForbiddenReminder) {
        _forbiddenTicker?.cancel();
        if (mounted) {
          unawaited(_loadData(showLoading: false));
        }
        return;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatForbiddenCountdown() {
    final remaining =
        _forbiddenExpireAt - (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    if (remaining <= 0) {
      return '即将解除';
    }
    final hours = remaining ~/ 3600;
    final minutes = (remaining % 3600) ~/ 60;
    final seconds = remaining % 60;
    if (hours > 0) {
      return '$hours小时${minutes.toString().padLeft(2, '0')}分钟';
    }
    if (minutes > 0) {
      return '$minutes分钟${seconds.toString().padLeft(2, '0')}秒';
    }
    return '$seconds秒';
  }

  String _formatForbiddenExpireAt() {
    final expireAt = DateTime.fromMillisecondsSinceEpoch(
      _forbiddenExpireAt * 1000,
    );
    final month = expireAt.month.toString().padLeft(2, '0');
    final day = expireAt.day.toString().padLeft(2, '0');
    final hour = expireAt.hour.toString().padLeft(2, '0');
    final minute = expireAt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  int _currentSettingValue(String key) {
    switch (key) {
      case 'mute':
        return _isMuted ? 1 : 0;
      case 'top':
        return _isPinned ? 1 : 0;
      case 'save':
        return _isSaved ? 1 : 0;
      case 'chat_pwd_on':
        return _isChatPwdOn ? 1 : 0;
      case 'show_nick':
        return _showNick ? 1 : 0;
      case 'invite':
        return _inviteOnly ? 1 : 0;
      case 'join_group_remind':
        return _joinGroupRemind ? 1 : 0;
      case 'allow_view_history_msg':
        return _allowViewHistory ? 1 : 0;
      case 'allow_member_pinned_message':
        return _allowMemberPinnedMessage ? 1 : 0;
      default:
        return 0;
    }
  }

  void _applyLocalSetting(String key, int value) {
    switch (key) {
      case 'mute':
        _isMuted = value == 1;
        break;
      case 'top':
        _isPinned = value == 1;
        break;
      case 'save':
        _isSaved = value == 1;
        break;
      case 'chat_pwd_on':
        _isChatPwdOn = value == 1;
        break;
      case 'show_nick':
        _showNick = value == 1;
        break;
      case 'invite':
        _inviteOnly = value == 1;
        break;
      case 'join_group_remind':
        _joinGroupRemind = value == 1;
        break;
      case 'allow_view_history_msg':
        _allowViewHistory = value == 1;
        break;
      case 'allow_member_pinned_message':
        _allowMemberPinnedMessage = value == 1;
        break;
    }
  }

  Future<bool> _runAction(
    Future<void> Function() action, {
    String? successMessage,
    String failurePrefix = '操作失败',
    VoidCallback? onError,
  }) async {
    if (_isUpdating) {
      return false;
    }

    setState(() => _isUpdating = true);
    try {
      await action();
      if (successMessage != null && mounted) {
        _showMessage(successMessage);
      }
      return true;
    } catch (e) {
      onError?.call();
      if (mounted) {
        _showMessage('$failurePrefix: $e');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _updateGroupSetting(String key, int value) async {
    final previousValue = _currentSettingValue(key);
    setState(() => _applyLocalSetting(key, value));

    await _runAction(
      () async {
        await GroupApi.instance.updateGroupSetting(
          widget.channelId,
          key,
          value,
        );
        await _loadData(showLoading: false);
      },
      failurePrefix: '更新群设置失败',
      onError: () {
        if (!mounted) {
          return;
        }
        setState(() => _applyLocalSetting(key, previousValue));
      },
    );
  }

  Future<void> _updateInviteOnlySetting(bool enabled) async {
    final previousValue = _currentSettingValue('invite');
    setState(() => _applyLocalSetting('invite', enabled ? 1 : 0));

    await _runAction(
      () async {
        await GroupApi.instance.setGroupInviteMode(widget.channelId, enabled);
        await _loadData(showLoading: false);
      },
      failurePrefix: '更新邀请入群模式失败',
      onError: () {
        if (!mounted) {
          return;
        }
        setState(() => _applyLocalSetting('invite', previousValue));
      },
    );
  }

  Future<void> _updateAllowViewHistorySetting(bool enabled) async {
    final previousValue = _currentSettingValue('allow_view_history_msg');
    setState(
      () => _applyLocalSetting('allow_view_history_msg', enabled ? 1 : 0),
    );

    await _runAction(
      () async {
        await GroupApi.instance.setGroupAllowViewHistory(
          widget.channelId,
          enabled,
        );
        await _loadData(showLoading: false);
      },
      failurePrefix: '更新历史消息权限失败',
      onError: () {
        if (!mounted) {
          return;
        }
        setState(
          () => _applyLocalSetting('allow_view_history_msg', previousValue),
        );
      },
    );
  }

  Future<void> _updateJoinGroupRemindSetting(bool enabled) async {
    final previousValue = _currentSettingValue('join_group_remind');
    setState(() => _applyLocalSetting('join_group_remind', enabled ? 1 : 0));

    await _runAction(
      () async {
        await GroupApi.instance.setGroupJoinGroupRemind(
          widget.channelId,
          enabled,
        );
        await _loadData(showLoading: false);
      },
      failurePrefix: '更新进群提醒失败',
      onError: () {
        if (!mounted) {
          return;
        }
        setState(() => _applyLocalSetting('join_group_remind', previousValue));
      },
    );
  }

  Future<void> _updateAllowMemberPinnedMessageSetting(bool enabled) async {
    final previousValue = _currentSettingValue('allow_member_pinned_message');
    setState(
      () => _applyLocalSetting('allow_member_pinned_message', enabled ? 1 : 0),
    );

    await _runAction(
      () async {
        await GroupApi.instance.setGroupAllowMemberPinnedMessage(
          widget.channelId,
          enabled,
        );
        await _loadData(showLoading: false);
      },
      onError: () => setState(
        () => _applyLocalSetting('allow_member_pinned_message', previousValue),
      ),
    );
  }

  Future<void> _selectMessageAutoDelete() async {
    if (_isUpdating) {
      return;
    }

    final nextValue = await showChannelAutoDeletePicker(
      context: context,
      currentSeconds: _messageAutoDeleteSeconds,
      title: _groupDetailAutoDeleteTitle,
    );
    if (nextValue == null || nextValue == _messageAutoDeleteSeconds) {
      return;
    }

    final previousValue = _messageAutoDeleteSeconds;
    setState(() => _messageAutoDeleteSeconds = nextValue);

    await _runAction(
      () async {
        await ChannelApi.instance.setMessageAutoDelete(
          channelId: widget.channelId,
          channelType: widget.channelType,
          seconds: nextValue,
        );
        await _loadData(showLoading: false);
      },
      successMessage: _groupDetailAutoDeleteUpdatedMessage,
      onError: () {
        if (!mounted) {
          return;
        }
        setState(() => _messageAutoDeleteSeconds = previousValue);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SettingsScaffold(
        title: '聊天信息',
        loading: true,
        child: SizedBox.shrink(),
      );
    }

    if (_group == null) {
      return SettingsScaffold(
        title: '聊天信息',
        child: Center(
          child: TextButton(
            onPressed: () => _loadData(),
            child: const Text(
              '重试',
              style: TextStyle(
                color: WKColors.brand500,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final visibleMemberCount = _group?.memberCount ?? _members.length;
    final groupName = (_group?.name ?? '').trim();
    final groupRemark = (_group?.remark ?? '').trim();
    final registry = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(slotRegistryProvider);
    final msgRemindExtensions = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.msgRemind,
      groupId: widget.channelId,
      channelType: widget.channelType,
    );
    final msgSettingsExtensions = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.msgSettings,
      groupId: widget.channelId,
      channelType: widget.channelType,
    );
    final groupAvatarExtensions = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.groupAvatar,
      groupId: widget.channelId,
      channelType: widget.channelType,
    );
    final groupManageExtensions = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.groupManage,
      groupId: widget.channelId,
      channelType: widget.channelType,
    );
    final chatPasswordExtensions = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.chatPassword,
      groupId: widget.channelId,
      channelType: widget.channelType,
    );

    return SettingsScaffold(
      title: '聊天信息($visibleMemberCount)',
      loading: _isUpdating,
      actions: (_canRenameGroup || _canDismissGroup)
          ? <Widget>[
              IconButton(
                tooltip: '更多操作',
                onPressed: _isUpdating ? null : _showAndroidMoreActions,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ]
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.xl,
        ),
        children: [
          SettingsHero(
            icon: Icons.groups_rounded,
            title: groupName.isEmpty ? '群聊' : groupName,
            subtitle: '共 $visibleMemberCount 位成员 · 群号 ${widget.channelId}',
          ),
          if (groupRemark.isNotEmpty) ...[
            const SizedBox(height: WKSpace.md),
            SettingsInfoCard(
              icon: Icons.label_outline_rounded,
              title: '群备注',
              subtitle: groupRemark,
            ),
          ],
          if (_hasForbiddenReminder) ...[
            const SizedBox(height: WKSpace.md),
            SettingsInfoCard(
              icon: Icons.timer_outlined,
              title: '你当前在本群处于禁言状态',
              subtitle:
                  '预计 ${_formatForbiddenCountdown()} 后解除，解除时间 ${_formatForbiddenExpireAt()}',
              isError: true,
            ),
          ],
          const SizedBox(height: WKSpace.md),
          _buildSurfaceMembersSection(),
          const SizedBox(height: WKSpace.md),
          _buildSurfaceGroupInfoSection(),
          const SizedBox(height: WKSpace.md),
          _buildSurfaceChatSettingsSection(),
          if (_canManageMembers) ...[
            const SizedBox(height: WKSpace.md),
            _buildSurfaceManageSection(),
          ],
          ..._buildSurfaceExtensionSections(
            msgRemindExtensions: msgRemindExtensions,
            groupAvatarExtensions: groupAvatarExtensions,
            msgSettingsExtensions: msgSettingsExtensions,
            groupManageExtensions: groupManageExtensions,
            chatPasswordExtensions: chatPasswordExtensions,
          ),
          const SizedBox(height: WKSpace.md),
          _buildSurfaceActionsSection(),
        ],
      ),
    );
  }

  Widget _buildSurfaceMembersSection() {
    final visibleMemberLimit = _canRemoveMembers ? 18 : 19;
    final visibleMembers = buildAndroidGroupDetailMemberItems(
      members: _members,
      canAddMembers: _canAddMembers,
      canRemoveMembers: _canRemoveMembers,
      maxVisibleMembers: visibleMemberLimit,
    );

    return SettingsSection(
      title: '群成员',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WKSpace.md,
            WKSpace.sm,
            WKSpace.md,
            WKSpace.md,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 1200
                  ? 88.0
                  : constraints.maxWidth >= 900
                  ? 84.0
                  : 76.0;

              return Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (final item in visibleMembers)
                      SizedBox(
                        width: tileWidth,
                        child: _buildAndroidMemberItem(item),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_members.length > visibleMemberLimit)
          _buildSurfaceActionTile(
            icon: Icons.groups_rounded,
            title: '查看全部成员',
            subtitle: '共 ${_members.length} 人，查看完整成员列表',
            onTap: _isUpdating ? null : _navigateToAllMembers,
          ),
      ],
    );
  }

  Widget _buildSurfaceGroupInfoSection() {
    final groupName = (_group?.name ?? '').trim();
    final remark = (_group?.remark ?? '').trim();
    final notice = (_group?.notice ?? '').trim();

    return SettingsSection(
      title: '群资料',
      children: [
        _buildSurfaceGroupAvatarTile(),
        _buildSurfaceActionTile(
          icon: Icons.drive_file_rename_outline_rounded,
          title: _groupDetailNameTitle,
          subtitle: groupName.isEmpty ? '未设置' : groupName,
          onTap: _isUpdating ? null : _handleGroupNameTap,
        ),
        _buildSurfaceActionTile(
          icon: Icons.qr_code_rounded,
          title: _groupDetailQrTitle,
          subtitle: '查看当前群二维码',
          onTap: _isUpdating ? null : _showGroupQR,
        ),
        _buildSurfaceActionTile(
          icon: Icons.campaign_outlined,
          title: _groupDetailNoticeTitle,
          subtitle: notice.isEmpty ? '未设置' : notice,
          onTap: _isUpdating ? null : _handleNoticeTap,
        ),
        _buildSurfaceActionTile(
          icon: Icons.edit_note_rounded,
          title: _groupDetailRemarkTitle,
          subtitle: remark.isEmpty ? '未设置' : remark,
          onTap: _isUpdating ? null : _openGroupRemarkPage,
        ),
        _buildSurfaceActionTile(
          icon: Icons.search_rounded,
          title: _groupDetailSearchHistoryTitle,
          subtitle: '按关键词定位当前群的历史消息',
          onTap: _isUpdating ? null : _searchChatHistory,
        ),
      ],
    );
  }

  Widget _buildSurfaceGroupAvatarTile() {
    final groupName = (_group?.name ?? '缇よ亰').trim();
    final avatarUrl = (_group?.avatar ?? '').trim();
    final canEdit = _canEditGroupAvatar && !_isUpdating;

    return ListTile(
      key: const ValueKey<String>('group-detail-avatar-button'),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          WKAvatar(
            url: avatarUrl,
            name: groupName.isEmpty ? '缇よ亰' : groupName,
            size: 40,
            isGroup: true,
          ),
          if (_canEditGroupAvatar)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                key: const ValueKey<String>('group-detail-avatar-edit-badge'),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: WKColors.brand500,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: WKColors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  size: 11,
                  color: WKColors.white,
                ),
              ),
            ),
        ],
      ),
      title: const Text('群头像'),
      subtitle: Text(_canEditGroupAvatar ? '点击更换当前群头像' : '仅群主或管理员可修改'),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: canEdit ? WKColors.color999 : WKColors.colorCCC,
      ),
      enabled: canEdit,
      onTap: canEdit ? _changeGroupAvatar : null,
    );
  }

  Widget _buildSurfaceChatSettingsSection() {
    final canEditSettings = _currentMember != null && !_isUpdating;
    final myName = _getMyDisplayName();

    return SettingsSection(
      title: '聊天设置',
      children: [
        _buildSurfaceSwitchTile(
          title: _groupDetailMuteTitle,
          subtitle: '关闭当前群的消息提醒，不影响收发消息',
          icon: Icons.notifications_off_outlined,
          value: _isMuted,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('mute', value ? 1 : 0)
              : null,
        ),
        _buildSurfaceSwitchTile(
          title: _groupDetailTopTitle,
          subtitle: '将当前群固定在会话列表顶部',
          icon: Icons.push_pin_outlined,
          value: _isPinned,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('top', value ? 1 : 0)
              : null,
        ),
        _buildSurfaceSwitchTile(
          title: _groupDetailSaveTitle,
          subtitle: '在通讯录中保留当前群的快捷入口',
          icon: Icons.bookmark_outline_rounded,
          value: _isSaved,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('save', value ? 1 : 0)
              : null,
        ),
        _buildSurfaceActionTile(
          title: _groupDetailMyNickTitle,
          subtitle: myName,
          icon: Icons.badge_outlined,
          onTap: canEditSettings ? _updateMyGroupName : null,
        ),
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>('group_setting_show_nick_switch'),
          title: _groupDetailShowNickTitle,
          subtitle: '在聊天消息中显示群成员昵称',
          icon: Icons.alternate_email_rounded,
          value: _showNick,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('show_nick', value ? 1 : 0)
              : null,
        ),
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>('group_setting_chat_pwd_switch'),
          title: _groupDetailChatPasswordTitle,
          subtitle: '为当前群增加聊天密码保护',
          icon: Icons.lock_outline_rounded,
          value: _isChatPwdOn,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('chat_pwd_on', value ? 1 : 0)
              : null,
        ),
        _buildSurfaceActionTile(
          key: const ValueKey<String>('group_setting_message_auto_delete_cell'),
          title: _groupDetailAutoDeleteTitle,
          subtitle: formatChannelAutoDeleteLabel(
            _messageAutoDeleteSeconds,
            english: isEnglishLocale(context),
          ),
          icon: Icons.auto_delete_outlined,
          onTap: canEditSettings ? _selectMessageAutoDelete : null,
        ),
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>('group_setting_join_group_remind_switch'),
          title: '进群提醒',
          subtitle: '有新成员加入时显示提醒消息',
          icon: Icons.person_add_alt_1_outlined,
          value: _joinGroupRemind,
          onChanged: canEditSettings ? _updateJoinGroupRemindSetting : null,
        ),
      ],
    );
  }

  Widget _buildSurfaceManageSection() {
    final canManageSettings = _canManageMembers && !_isUpdating;

    return SettingsSection(
      title: '群管理',
      children: [
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>('group_setting_invite_mode_switch'),
          title: '邀请入群模式',
          subtitle: '开启后，普通成员通过邀请制拉人入群',
          icon: Icons.group_add_outlined,
          value: _inviteOnly,
          onChanged: canManageSettings ? _updateInviteOnlySetting : null,
        ),
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>(
            'group_setting_allow_view_history_switch',
          ),
          title: '新成员可查看历史消息',
          subtitle: '允许新成员进入后查看旧消息记录',
          icon: Icons.history_edu_outlined,
          value: _allowViewHistory,
          onChanged: canManageSettings ? _updateAllowViewHistorySetting : null,
        ),
        _buildSurfaceSwitchTile(
          key: const ValueKey<String>(
            'group_setting_allow_member_pinned_message_switch',
          ),
          title: '允许成员置顶消息',
          subtitle: '普通成员也可以把消息置顶到会话顶部',
          icon: Icons.vertical_align_top_outlined,
          value: _allowMemberPinnedMessage,
          onChanged: canManageSettings
              ? _updateAllowMemberPinnedMessageSetting
              : null,
        ),
        _buildSurfaceActionTile(
          key: const ValueKey<String>('group-blacklist-entry'),
          title: '群黑名单',
          subtitle: '查看和管理禁止发言或禁止加入的成员',
          icon: Icons.block_outlined,
          onTap: _isUpdating ? null : _openGroupBlacklistPage,
        ),
        _buildSurfaceActionTile(
          title: _groupDetailFeishuBotTitle,
          subtitle: '生成 Webhook 与加签密钥，接入第三方飞书机器人消息',
          icon: Icons.smart_toy_outlined,
          onTap: _isUpdating ? null : _openFeishuBotPage,
        ),
        _buildSurfaceActionTile(
          title: '钉钉机器人',
          subtitle: '生成 Webhook 与加签密钥，接入第三方钉钉自定义机器人消息',
          icon: Icons.smart_toy_outlined,
          onTap: _isUpdating ? null : _openDingTalkBotPage,
        ),
      ],
    );
  }

  List<Widget> _buildSurfaceExtensionSections({
    required List<Widget> msgRemindExtensions,
    required List<Widget> groupAvatarExtensions,
    required List<Widget> msgSettingsExtensions,
    required List<Widget> groupManageExtensions,
    required List<Widget> chatPasswordExtensions,
  }) {
    final sections = <Widget>[];

    void addSection(String title, List<Widget> children) {
      if (children.isEmpty) {
        return;
      }
      sections
        ..add(const SizedBox(height: WKSpace.md))
        ..add(SettingsSection(title: title, children: children));
    }

    addSection('消息提醒扩展', msgRemindExtensions);
    addSection('群资料扩展', groupAvatarExtensions);
    addSection('聊天设置扩展', msgSettingsExtensions);
    addSection('群管理扩展', groupManageExtensions);
    addSection('聊天安全扩展', chatPasswordExtensions);

    return sections;
  }

  Widget _buildSurfaceActionsSection() {
    return SettingsSection(
      title: '更多操作',
      children: [
        _buildSurfaceActionTile(
          title: _groupDetailReminderTitle,
          subtitle: '查看群待办、群提醒和完成状态',
          icon: Icons.alarm_on_outlined,
          onTap: _isUpdating ? null : _openGroupReminderPage,
        ),
        _buildSurfaceActionTile(
          title: _groupDetailReportTitle,
          subtitle: '举报当前群的违规内容或异常行为',
          icon: Icons.flag_outlined,
          onTap: _isUpdating ? null : _openReportPage,
        ),
        _buildSurfaceActionTile(
          title: _groupDetailClearHistoryTitle,
          subtitle: '清空当前群的本地聊天记录',
          icon: Icons.delete_sweep_outlined,
          onTap: _isUpdating ? null : _confirmClearHistoryAligned,
        ),
        _buildSurfaceActionTile(
          key: const ValueKey<String>('group_exit_action_tile'),
          title: _canDismissGroup ? '解散群聊' : '删除并退出',
          subtitle: _canDismissGroup ? '删除当前群并移除所有成员' : '从当前账号中删除该群并退出会话',
          icon: _canDismissGroup
              ? Icons.delete_forever_outlined
              : Icons.logout_rounded,
          onTap: _isUpdating ? null : _exitGroupAligned,
          danger: true,
          showArrow: false,
        ),
      ],
    );
  }

  Widget _buildSurfaceSwitchTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      key: key,
      secondary: _buildSurfaceLeadingIcon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSurfaceActionTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool danger = false,
    bool showArrow = true,
  }) {
    final titleColor = danger
        ? WKColors.danger
        : (onTap == null ? WKColors.color999 : WKColors.colorDark);
    final subtitleColor = danger
        ? WKColors.danger.withValues(alpha: 0.75)
        : WKColors.color999;

    return ListTile(
      key: key,
      leading: _buildSurfaceLeadingIcon(
        icon,
        backgroundColor: danger
            ? WKColors.danger.withValues(alpha: 0.08)
            : WKColors.surfaceSoft,
        iconColor: danger ? WKColors.danger : null,
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: subtitleColor),
      ),
      trailing: showArrow
          ? Icon(
              Icons.chevron_right_rounded,
              color: onTap == null ? WKColors.colorCCC : WKColors.color999,
            )
          : null,
      enabled: onTap != null,
      onTap: onTap,
    );
  }

  Widget _buildSurfaceLeadingIcon(
    IconData icon, {
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor ?? WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildGroupInfoSection() {
    final groupName = (_group?.name ?? '群聊').trim();
    final remark = (_group?.remark ?? '').trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          WKAvatar(
            url: _group?.avatar,
            name: groupName.isEmpty ? '群聊' : groupName,
            size: 60,
            isGroup: true,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName.isEmpty ? '群聊' : groupName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (remark.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '群备注: $remark',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '群号: ${widget.channelId}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForbiddenReminderSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8C98F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.timer_outlined, color: Color(0xFF9A6700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '你当前在本群处于禁言状态',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6F4E00),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '预计 ${_formatForbiddenCountdown()} 后解除，解除时间 ${_formatForbiddenExpireAt()}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF6F4E00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    final displayMembers = _members.take(20).toList();
    final actionTiles = <Widget>[
      if (_canAddMembers) _buildAddMemberButton(),
      if (_canRemoveMembers) _buildDeleteMemberButton(),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: displayMembers.length + actionTiles.length,
            itemBuilder: (context, index) {
              if (index < displayMembers.length) {
                return _buildMemberItem(displayMembers[index]);
              }
              return actionTiles[index - displayMembers.length];
            },
          ),
        ),
        if (_members.length > 20)
          ListTile(
            title: Text('查看全部群成员(${_members.length})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isUpdating ? null : _navigateToAllMembers,
          ),
      ],
    );
  }

  Widget _buildMemberItem(GroupMember member) {
    final displayName = (member.remark ?? member.name ?? member.uid).trim();

    return GestureDetector(
      onTap: _isUpdating ? null : () => _navigateToUserDetail(member.uid),
      child: Column(
        children: [
          Stack(
            children: [
              WKAvatar(
                url: member.avatar,
                name: displayName.isEmpty ? member.uid : displayName,
                size: 50,
                borderRadius: BorderRadius.circular(8),
              ),
              if (member.isOwner)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildRoleBadge(label: '群主', color: Colors.orange),
                )
              else if (member.isAdmin)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildRoleBadge(label: '管理', color: Colors.blue),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayName.isEmpty ? member.uid : displayName,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAddMemberButton() {
    return GestureDetector(
      onTap: _isUpdating ? null : _navigateToAddMembers,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text('添加', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDeleteMemberButton() {
    return GestureDetector(
      onTap: _isUpdating ? null : _openDeleteGroupMembersPage,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_remove, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text('删除', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final canEditSettings = _currentMember != null && !_isUpdating;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text(_groupDetailMyNickTitle),
          subtitle: Text(_getMyDisplayName()),
          trailing: const Icon(Icons.chevron_right),
          onTap: canEditSettings ? _updateMyGroupNameAligned : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_off_outlined),
          title: const Text(_groupDetailMuteTitle),
          value: _isMuted,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('mute', value ? 1 : 0)
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.star_outline),
          title: const Text(_groupDetailTopTitle),
          value: _isPinned,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('top', value ? 1 : 0)
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.bookmark_outline),
          title: const Text(_groupDetailSaveTitle),
          value: _isSaved,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('save', value ? 1 : 0)
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.person_outline),
          title: const Text(_groupDetailShowNickTitle),
          value: _showNick,
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('show_nick', value ? 1 : 0)
              : null,
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    final notice = (_group?.notice ?? '').trim();

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.qr_code),
          title: const Text(_groupDetailQrTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isUpdating ? null : _showGroupQR,
        ),
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: const Text(_groupDetailNoticeTitle),
          subtitle: Text(
            notice.isEmpty ? '未设置' : notice,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isUpdating ? null : _editGroupNotice,
        ),
        if (_canManageMembers)
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text(_groupDetailFeishuBotTitle),
            subtitle: const Text('生成 webhook 和加签，供第三方按飞书机器人格式推送到本群'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isUpdating ? null : _openFeishuBotPage,
          ),
        if (_canManageMembers)
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('钉钉机器人'),
            subtitle: const Text('生成 webhook 和加签，供第三方按钉钉自定义机器人格式推送到本群'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isUpdating ? null : _openDingTalkBotPage,
          ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text(_groupDetailSearchHistoryTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isUpdating ? null : _searchChatHistory,
        ),
        ListTile(
          leading: const Icon(Icons.alarm_on_outlined),
          title: const Text(_groupDetailReminderTitle),
          subtitle: const Text('查看群内待办，创建定时提醒并跟踪完成状态'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isUpdating ? null : _openGroupReminderPage,
        ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text(_groupDetailReportTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isUpdating ? null : _openReportPageAligned,
        ),
        ListTile(
          leading: Icon(
            _canDismissGroup ? Icons.delete_forever : Icons.exit_to_app,
            color: Colors.red,
          ),
          title: Text(
            _canDismissGroup ? '解散群聊' : '删除并退出',
            style: const TextStyle(color: Colors.red),
          ),
          onTap: _isUpdating ? null : _exitGroupAligned,
        ),
      ],
    );
  }

  Widget _buildAndroidGroupInfoSection() {
    final groupName = (_group?.name ?? '').trim();
    final remark = (_group?.remark ?? '').trim();

    return Column(
      children: [
        WKSettingsCell(
          title: _groupDetailNameTitle,
          value: groupName.isEmpty ? '未设置' : groupName,
          onTap: _isUpdating ? null : _handleGroupNameTap,
        ),
        WKSettingsCell(
          title: _groupDetailQrTitle,
          onTap: _isUpdating ? null : _showGroupQR,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WKReferenceAssets.image(
                WKReferenceAssets.qrCode,
                width: 18,
                height: 18,
                tint: WKColors.color999,
              ),
              const SizedBox(width: 6),
              WKReferenceAssets.image(
                WKReferenceAssets.arrowRight,
                width: 14,
                height: 14,
              ),
            ],
          ),
        ),
        _buildAndroidNoticeRow(),
        WKSettingsCell(
          title: _groupDetailRemarkTitle,
          value: remark,
          onTap: _isUpdating ? null : _openGroupRemarkPage,
        ),
        const WKSectionGap(10),
        WKSettingsCell(
          title: _groupDetailSearchHistoryTitle,
          onTap: _isUpdating ? null : _searchChatHistory,
        ),
      ],
    );
  }

  Widget _buildAndroidMembersSection() {
    final visibleMemberLimit = _canRemoveMembers ? 18 : 19;
    final visibleMembers = buildAndroidGroupDetailMemberItems(
      members: _members,
      canAddMembers: _canAddMembers,
      canRemoveMembers: _canRemoveMembers,
      maxVisibleMembers: visibleMemberLimit,
    );

    return ColoredBox(
      color: WKColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth >= 1200
                    ? 84.0
                    : constraints.maxWidth >= 900
                    ? 80.0
                    : 74.0;

                return Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 2,
                    runSpacing: 4,
                    children: [
                      for (final item in visibleMembers)
                        SizedBox(
                          width: tileWidth,
                          child: _buildAndroidMemberItem(item),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_members.length > visibleMemberLimit)
            WKSettingsCell(
              title: '查看全部成员',
              value: '共 ${_members.length} 人',
              onTap: _isUpdating ? null : _navigateToAllMembers,
            ),
        ],
      ),
    );
  }

  Widget _buildAndroidMemberItem(AndroidGroupDetailMemberItem item) {
    switch (item.type) {
      case AndroidGroupDetailMemberItemType.member:
        final member = item.member!;
        final displayName = (member.remark ?? member.name ?? member.uid).trim();
        final safeName = displayName.isEmpty ? member.uid : displayName;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isUpdating
                  ? null
                  : () => _navigateToUserDetail(member.uid),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      WKAvatar(
                        url: member.avatar,
                        name: safeName,
                        size: 50,
                        onTap: _isUpdating
                            ? null
                            : () => _navigateToUserDetail(member.uid),
                      ),
                      if (member.isOwner)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: _buildAndroidRoleBadge(
                            label: '群主',
                            color: const Color(0xFFFFC107),
                          ),
                        )
                      else if (member.isAdmin)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: _buildAndroidRoleBadge(
                            label: '管理员',
                            color: WKColors.brand500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: WKColors.colorDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case AndroidGroupDetailMemberItemType.add:
        return _buildAndroidMemberHandle(
          asset: WKReferenceAssets.chatAdd,
          label: '添加',
          onTap: _isUpdating ? null : _navigateToAddMembers,
        );
      case AndroidGroupDetailMemberItemType.remove:
        return _buildAndroidMemberHandle(
          asset: WKReferenceAssets.chatDelete,
          label: '删除',
          onTap: _isUpdating ? null : _openDeleteGroupMembersPage,
        );
    }
  }

  Widget _buildAndroidRoleBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: WKColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAndroidMemberHandle({
    required String asset,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: WKReferenceAssets.image(asset, width: 50, height: 50),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: WKColors.colorDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidSettingsSection() {
    final canEditSettings = _currentMember != null && !_isUpdating;
    final canManageSettings = _canManageMembers && !_isUpdating;
    final myName = _getMyDisplayName();

    return Column(
      children: [
        const WKSectionGap(10),
        WKSettingsSwitchCell(
          title: _groupDetailMuteTitle,
          value: _isMuted,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('mute', value ? 1 : 0)
              : null,
        ),
        WKSettingsSwitchCell(
          title: _groupDetailTopTitle,
          value: _isPinned,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('top', value ? 1 : 0)
              : null,
        ),
        WKSettingsSwitchCell(
          title: _groupDetailSaveTitle,
          value: _isSaved,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('save', value ? 1 : 0)
              : null,
        ),
        WKSettingsCell(
          title: _groupDetailMyNickTitle,
          value: myName == '未设置' ? '' : myName,
          onTap: canEditSettings ? _updateMyGroupName : null,
        ),
        const WKSectionGap(10),
        WKSettingsSwitchCell(
          key: const ValueKey<String>('group_setting_show_nick_switch'),
          title: _groupDetailShowNickTitle,
          value: _showNick,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('show_nick', value ? 1 : 0)
              : null,
        ),
        WKSettingsSwitchCell(
          key: const ValueKey<String>('group_setting_chat_pwd_switch'),
          title: _groupDetailChatPasswordTitle,
          value: _isChatPwdOn,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings
              ? (value) => _updateGroupSetting('chat_pwd_on', value ? 1 : 0)
              : null,
        ),
        WKSettingsCell(
          key: const ValueKey<String>('group_setting_message_auto_delete_cell'),
          title: _groupDetailAutoDeleteTitle,
          value: formatChannelAutoDeleteLabel(
            _messageAutoDeleteSeconds,
            english: isEnglishLocale(context),
          ),
          onTap: canEditSettings ? _selectMessageAutoDelete : null,
        ),
        if (_canManageMembers)
          WKSettingsSwitchCell(
            key: const ValueKey<String>('group_setting_invite_mode_switch'),
            title: '邀请入群模式',
            value: _inviteOnly,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onChanged: canManageSettings ? _updateInviteOnlySetting : null,
          ),
        if (_canManageMembers)
          WKSettingsSwitchCell(
            key: const ValueKey<String>(
              'group_setting_allow_view_history_switch',
            ),
            title: '新成员可查看历史消息',
            value: _allowViewHistory,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onChanged: canManageSettings
                ? _updateAllowViewHistorySetting
                : null,
          ),
        if (_canManageMembers)
          WKSettingsSwitchCell(
            key: const ValueKey<String>(
              'group_setting_allow_member_pinned_message_switch',
            ),
            title: '允许成员置顶消息',
            value: _allowMemberPinnedMessage,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            onChanged: canManageSettings
                ? _updateAllowMemberPinnedMessageSetting
                : null,
          ),
        WKSettingsSwitchCell(
          key: const ValueKey<String>('group_setting_join_group_remind_switch'),
          title: '进群提醒',
          value: _joinGroupRemind,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          onChanged: canEditSettings ? _updateJoinGroupRemindSetting : null,
        ),
      ],
    );
  }

  Widget _buildAndroidActionsSection() {
    return Column(
      children: [
        const WKSectionGap(10),
        if (_canManageMembers)
          WKSettingsCell(
            key: const ValueKey<String>('group-blacklist-entry'),
            title: '群黑名单',
            onTap: _isUpdating ? null : _openGroupBlacklistPage,
          ),
        if (_canManageMembers)
          WKSettingsCell(
            title: _groupDetailFeishuBotTitle,
            onTap: _isUpdating ? null : _openFeishuBotPage,
          ),
        if (_canManageMembers)
          WKSettingsCell(
            title: '钉钉机器人',
            onTap: _isUpdating ? null : _openDingTalkBotPage,
          ),
        WKSettingsCell(
          title: _groupDetailReminderTitle,
          onTap: _isUpdating ? null : _openGroupReminderPage,
        ),
        WKSettingsCell(
          title: _groupDetailReportTitle,
          onTap: _isUpdating ? null : _openReportPage,
        ),
        const WKSectionGap(10),
        WKSettingsCell(
          title: _groupDetailClearHistoryTitle,
          onTap: _isUpdating ? null : _confirmClearHistoryAligned,
        ),
        const WKSectionGap(10),
        WKSettingsCell(
          title: '删除并退出',
          centerTitle: true,
          showArrow: false,
          titleColor: WKColors.danger,
          onTap: _isUpdating ? null : _exitGroupAligned,
        ),
      ],
    );
  }

  Widget _buildAndroidNoticeRow() {
    final notice = (_group?.notice ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUpdating ? null : _handleNoticeTap,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      _groupDetailNoticeTitle,
                      style: TextStyle(fontSize: 16, color: WKColors.colorDark),
                    ),
                  ),
                  if (notice.isEmpty) ...[
                    const Text(
                      '未设置',
                      style: TextStyle(fontSize: 16, color: WKColors.color999),
                    ),
                    const SizedBox(width: 10),
                  ],
                  WKReferenceAssets.image(
                    WKReferenceAssets.arrowRight,
                    width: 14,
                    height: 14,
                  ),
                ],
              ),
              if (notice.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    notice,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGroupNameTap() async {
    if (!_canRenameGroup) {
      _showManagerOnlyHint();
      return;
    }
    await _openUpdateGroupNamePage();
  }

  Future<void> _handleNoticeTap() async {
    final notice = (_group?.notice ?? '').trim();
    if (notice.isEmpty && !_canManageMembers) {
      _showManagerOnlyHint();
      return;
    }
    await _editGroupNotice();
  }

  Future<void> _openGroupRemarkPage() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GroupRemarkPage(
          groupId: widget.channelId,
          groupName: (_group?.name ?? '').trim(),
          groupAvatar: _group?.avatar,
          initialRemark: (_group?.remark ?? '').trim(),
        ),
      ),
    );
    if (result == null) {
      return;
    }
    await _loadData(showLoading: false);
  }

  Future<void> _openUpdateGroupNamePage() async {
    final currentName = (_group?.name ?? '').trim();
    if (currentName.isEmpty) {
      _showMessage('群名称不能为空');
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UpdateGroupNamePage(
          groupId: widget.channelId,
          initialName: currentName,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    await _loadData(showLoading: false);
  }

  Future<void> _openDeleteGroupMembersPage() async {
    if (!_canRemoveMembers) {
      _showMessage('当前账号没有可执行的删人权限');
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeleteGroupMembersPage(
          groupId: widget.channelId,
          members: List<GroupMember>.from(_removableMembers),
        ),
      ),
    );
    if (result != true) {
      return;
    }
    await _loadData(showLoading: false);
  }

  Future<void> _openGroupBlacklistPage() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GroupBlacklistPage(channelId: widget.channelId),
      ),
    );
    if (changed == true) {
      await _loadData(showLoading: false);
    }
  }

  Future<void> _changeGroupAvatar() async {
    final filePath = await _pickGroupAvatarImagePath();
    if (!mounted) {
      return;
    }
    final normalizedPath = filePath?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return;
    }

    final previousAvatar = (_group?.avatar ?? '').trim();

    await _runAction(
      () async {
        final uploader = widget.uploadAvatarImage;
        final updatedAvatar =
            (uploader != null
                    ? await uploader(widget.channelId, normalizedPath)
                    : await GroupApi.instance.uploadGroupAvatar(
                        widget.channelId,
                        normalizedPath,
                      ))
                .trim();

        await _evictGroupAvatarCache(previousAvatar);
        await _evictGroupAvatarCache(updatedAvatar);
        if (updatedAvatar.isNotEmpty) {
          _groupAvatarBeforeUpload = previousAvatar;
          _pendingUploadedGroupAvatar = updatedAvatar;
        }
        await _loadData(showLoading: false);
        if (updatedAvatar.isNotEmpty) {
          _applyUploadedGroupAvatar(updatedAvatar);
          await _updateGroupChannelAvatar(updatedAvatar);
        }
        await _refreshGroupAvatarCacheKey();
      },
      successMessage: '群头像已更新',
      failurePrefix: '更新群头像失败',
    );
  }

  Future<String?> _pickGroupAvatarImagePath() async {
    final injectedPicker = widget.pickAvatarImage;
    if (injectedPicker != null) {
      return injectedPicker();
    }

    return pickSingleLocalImagePath(imageQuality: 85, maxWidth: 1024);
  }

  void _applyUploadedGroupAvatar(String avatar) {
    final normalizedAvatar = avatar.trim();
    final currentGroup = _group;
    if (!mounted || normalizedAvatar.isEmpty || currentGroup == null) {
      return;
    }
    final updatedGroup = currentGroup.copyWith(avatar: normalizedAvatar);
    setState(() => _group = updatedGroup);
    _syncGroupConversationCache(updatedGroup);
  }

  Future<void> _updateGroupChannelAvatar(String avatar) async {
    final normalizedAvatar = avatar.trim();
    if (normalizedAvatar.isEmpty) {
      return;
    }
    var channel = await WKIM.shared.channelManager.getChannel(
      widget.channelId,
      widget.channelType,
    );
    channel ??= WKChannel(widget.channelId, widget.channelType);
    channel.avatar = normalizedAvatar;
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
  }

  Future<String> _refreshGroupAvatarCacheKey() async {
    final avatarCacheKey = DateTime.now().microsecondsSinceEpoch.toString();
    await WKIM.shared.channelManager.updateAvatarCacheKey(
      widget.channelId,
      widget.channelType,
      avatarCacheKey,
    );
    return avatarCacheKey;
  }

  Future<void> _evictGroupAvatarCache(String? avatarUrl) async {
    final normalized = avatarUrl?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }

    await NetworkImage(normalized).evict();
    await WKAvatar.evictUrl(normalized);
    final uri = Uri.tryParse(normalized);
    if (uri != null && (uri.hasQuery || uri.fragment.isNotEmpty)) {
      final baseUrl = uri
          .replace(queryParameters: const <String, String>{}, fragment: '')
          .toString();
      await NetworkImage(baseUrl).evict();
      await WKAvatar.evictUrl(baseUrl);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void _showManagerOnlyHint() {
    _showMessage('只有群主及管理员可以编辑');
  }

  Future<void> _updateGroupRemark() async {
    final currentRemark = (_group?.remark ?? '').trim();
    final newRemark = await _showTextInputDialog(
      title: _groupDetailRemarkTitle,
      hintText: '群聊的备注仅自己可见',
      initialValue: currentRemark,
      maxLength: 40,
    );
    if (newRemark == null || newRemark == currentRemark) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.updateGroupSetting(
          widget.channelId,
          'remark',
          newRemark,
        );
        await _loadData(showLoading: false);
      },
      successMessage: newRemark.isEmpty ? '备注已清除' : '备注已更新',
      failurePrefix: '更新备注失败',
    );
  }

  Future<void> _confirmClearHistoryAligned() async {
    final groupName = _groupDisplayNameForDialog();
    final confirmed = await showWKConfirmDialog(
      context: context,
      title: '清除聊天记录',
      content: '您确定要清空 $groupName 的消息记录吗？',
      confirmText: '删除',
      confirmTextColor: WKColors.danger,
    );
    if (confirmed != true) {
      return;
    }

    try {
      await MessageApi.instance.clearChannelMessages(
        channelId: widget.channelId,
        channelType: widget.channelType,
      );
      WKIM.shared.messageManager.clearWithChannel(
        widget.channelId,
        widget.channelType,
      );
      _showMessage('聊天记录已清空');
    } catch (error) {
      _showMessage('清空聊天记录失败：$error');
    }
  }

  Future<void> _showAndroidMoreActions() async {
    final items = <WKBottomSheetItem>[
      if (_canRenameGroup)
        WKBottomSheetItem(
          title: '修改群名称',
          icon: Icons.edit_outlined,
          onTap: _handleGroupNameTap,
        ),
      if (_canManageAdmins)
        WKBottomSheetItem(
          title: '设置管理员',
          icon: Icons.admin_panel_settings_outlined,
          onTap: _setGroupManagers,
        ),
      if (_canManageAdmins)
        WKBottomSheetItem(
          title: '移除管理员',
          icon: Icons.remove_moderator_outlined,
          onTap: _removeGroupManagers,
        ),
      if (_canManageAdmins)
        WKBottomSheetItem(
          title: '杞缇や富',
          icon: Icons.swap_horiz_outlined,
          onTap: _transferGroupOwnerAligned,
        ),
    ];

    if (items.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WKBottomSheet(title: '群管理', items: items),
    );
  }

  Future<void> _updateMyGroupNameAligned() async {
    final member = _currentMember;
    if (member == null || _currentUid.isEmpty) {
      _showMessage('当前账号不在该群成员列表中，无法修改群内昵称');
      return;
    }

    final currentRemark = (member.remark ?? '').trim();
    final newRemark = await _showTextInputDialog(
      title: _groupDetailMyNickTitle,
      hintText: '留空可清除群内昵称',
      initialValue: currentRemark,
      maxLength: 10,
    );
    if (newRemark == null || newRemark == currentRemark) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.updateGroupMemberRemark(
          widget.channelId,
          _currentUid,
          newRemark,
        );
        await _loadData(showLoading: false);
      },
      successMessage: newRemark.isEmpty ? '群内昵称已清除' : '群内昵称已更新',
      failurePrefix: '更新群内昵称失败',
    );
  }

  Future<void> _openReportPageAligned() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          title: _groupDetailReportTitle,
          targetName: _group?.name,
        ),
      ),
    );
    if (result == true && mounted) {
      _showMessage('投诉已提交');
    }
  }

  Future<void> _transferGroupOwnerAligned() async {
    if (!_canManageAdmins) {
      _showMessage('只有群主可以转让群主身份');
      return;
    }

    final candidates = _transferableMembers
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: (member.remark ?? member.name ?? member.uid).trim(),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList();

    final selected = await openGroupMemberPicker(
      context,
      title: '转让群主',
      submitLabel: '转让',
      emptyText: '暂无可转让的群成员',
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }
    if (selected.length != 1) {
      _showMessage('转让群主时只能选择一位成员');
      return;
    }

    final targetUid = selected.first;
    final targetMember = _members
        .where((member) => member.uid == targetUid)
        .firstOrNull;
    final targetName = (targetMember?.remark ?? targetMember?.name ?? targetUid)
        .trim();
    if (!mounted) {
      return;
    }

    final confirmed = await showWKConfirmDialog(
      context: context,
      title: '转让群主',
      content:
          '确定将群主身份转让给 ${targetName.isEmpty ? targetUid : targetName} 吗？转让后当前账号会变成普通成员。',
    );
    if (confirmed != true) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.transferGroupOwner(widget.channelId, targetUid);
        await _loadData(showLoading: false);
      },
      successMessage: '群主已转让',
      failurePrefix: '杞缇や富澶辫触',
    );
  }

  Future<void> _exitGroupAligned() async {
    final confirmed = await showWKConfirmDialog(
      context: context,
      title: _canDismissGroup ? '解散群聊' : '删除并退出',
      content: _canDismissGroup
          ? '解散后当前群将不可恢复。'
          : '退出后不会通知群聊中的其他成员，且不会再接收该群消息。',
      confirmText: _canDismissGroup ? '解散群聊' : '删除并退出',
      confirmTextColor: WKColors.danger,
    );
    if (confirmed != true) {
      return;
    }

    final success = await _runAction(() async {
      if (_canDismissGroup) {
        await GroupApi.instance.dismissGroup(widget.channelId);
      } else {
        await GroupApi.instance.exitGroup(widget.channelId);
      }
      WKIM.shared.messageManager.clearWithChannel(
        widget.channelId,
        widget.channelType,
      );
      await WKIM.shared.conversationManager.deleteMsg(
        widget.channelId,
        widget.channelType,
      );
    }, failurePrefix: _canDismissGroup ? '解散群聊失败' : '退出群聊失败');

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _groupDisplayNameForDialog() {
    final remark = (_group?.remark ?? '').trim();
    if (remark.isNotEmpty) {
      return remark;
    }

    final name = (_group?.name ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }

    return widget.channelId;
  }

  String _getMyDisplayName() {
    final member = _currentMember;
    if (member == null) {
      return '未设置';
    }
    final displayName = (member.remark ?? member.name ?? '').trim();
    return displayName.isEmpty ? '未设置' : displayName;
  }

  void _showMoreActions() {
    final items = <Widget>[
      if (_canRenameGroup)
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('修改群名称'),
          onTap: () {
            Navigator.pop(context);
            _openUpdateGroupNamePage();
          },
        ),
      if (_canManageAdmins)
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('设置管理员'),
          onTap: () {
            Navigator.pop(context);
            _setGroupManagers();
          },
        ),
      if (_canManageAdmins)
        ListTile(
          leading: const Icon(Icons.remove_moderator_outlined),
          title: const Text('移除管理员'),
          onTap: () {
            Navigator.pop(context);
            _removeGroupManagers();
          },
        ),
      if (_canManageAdmins)
        ListTile(
          leading: const Icon(Icons.swap_horiz_outlined),
          title: const Text('转让群主'),
          onTap: () {
            Navigator.pop(context);
            _transferGroupOwner();
          },
        ),
      if (_canDismissGroup)
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('解散群聊', style: TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(context);
            _exitGroup();
          },
        ),
    ];

    if (items.isEmpty) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }

  void _navigateToAllMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllMembersPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
        ),
      ),
    );
  }

  void _navigateToUserDetail(String uid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserDetailPage(uid: uid, groupId: widget.channelId),
      ),
    );
  }

  void _openFeishuBotPage() {
    final title = (_group?.name ?? '').trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GroupFeishuBotPage(groupNo: widget.channelId, groupName: title),
      ),
    );
  }

  void _openDingTalkBotPage() {
    final title = (_group?.name ?? '').trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GroupDingTalkBotPage(groupNo: widget.channelId, groupName: title),
      ),
    );
  }

  Future<void> _navigateToAddMembers() async {
    if (!_canAddMembers) {
      _showMessage('当前群设置下，这个账号不能直接添加群成员');
      return;
    }

    try {
      final existingUids = _members.map((member) => member.uid).toSet();
      final friends = await FriendApi.instance.getFriends();
      final candidates = await _buildAddMemberCandidates(
        friends,
        existingUids: existingUids,
      );

      if (!mounted) {
        return;
      }

      final inviteModeEnabled = _inviteOnly;
      final useDirectAdd = !inviteModeEnabled || _canManageMembers;

      final selected = await openGroupMemberPicker(
        context,
        title: useDirectAdd ? '添加群成员' : '邀请群成员',
        submitLabel: useDirectAdd ? '添加' : '邀请',
        emptyText: '暂无可添加的好友',
        candidates: candidates,
      );
      if (selected == null || selected.isEmpty) {
        return;
      }
      final candidateTitleByUid = <String, String>{
        for (final candidate in candidates)
          candidate.uid: candidate.title.trim().isEmpty
              ? candidate.uid
              : candidate.title.trim(),
      };
      final memberNames = selected
          .map((uid) => candidateTitleByUid[uid] ?? uid)
          .toList(growable: false);

      await _runAction(
        () async {
          if (useDirectAdd) {
            await GroupApi.instance.addGroupMembers(
              widget.channelId,
              selected,
              memberNames: memberNames,
            );
          } else {
            await GroupApi.instance.inviteMembers(widget.channelId, selected);
          }
          await _loadData(showLoading: false);
        },
        successMessage: useDirectAdd
            ? '已添加 ${selected.length} 位成员'
            : '邀请已发送 (${selected.length} 位)',
        failurePrefix: useDirectAdd ? '添加群成员失败' : '发送邀请失败',
      );
    } catch (e) {
      _showMessage('加载可添加好友失败：$e');
    }
  }

  Future<List<SelectableGroupMember>> _buildAddMemberCandidates(
    List<Friend> friends, {
    required Set<String> existingUids,
  }) async {
    final candidates = <SelectableGroupMember>[];
    for (final friend in friends) {
      if (friend.isSystemAccount || existingUids.contains(friend.uid)) {
        continue;
      }

      var title = _firstNonEmptyText(friend.remark, friend.name);
      var avatar = friend.avatar;
      if (title == null || title == friend.uid) {
        try {
          final user = await UserApi.instance.getUserInfo(friend.uid);
          title = _firstNonEmptyText(user.remark, user.name, user.username);
          avatar = _firstNonEmptyText(avatar, user.avatar);
        } catch (_) {
          // Keep the friend sync payload as the source of truth when lookup fails.
        }
      }

      candidates.add(
        SelectableGroupMember(
          uid: friend.uid,
          title: (title ?? friend.uid).trim(),
          subtitle: friend.uid,
          avatar: avatar,
        ),
      );
    }
    return candidates;
  }

  Future<void> _setGroupManagers() async {
    if (!_canManageAdmins) {
      _showMessage('只有群主可以设置管理员');
      return;
    }

    final candidates = _promotableMembers
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: (member.remark ?? member.name ?? member.uid).trim(),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList();

    final selected = await openGroupMemberPicker(
      context,
      title: '设置管理员',
      submitLabel: '设置',
      emptyText: '鏆傛棤鍙缃负绠＄悊鍛樼殑鎴愬憳',
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.setGroupManagers(widget.channelId, selected);
        await _loadData(showLoading: false);
      },
      successMessage: '已设置 ${selected.length} 位管理员',
      failurePrefix: '设置管理员失败',
    );
  }

  Future<void> _removeGroupManagers() async {
    if (!_canManageAdmins) {
      _showMessage('只有群主可以移除管理员');
      return;
    }

    final candidates = _demotableManagers
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: (member.remark ?? member.name ?? member.uid).trim(),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList();

    final selected = await openGroupMemberPicker(
      context,
      title: '移除管理员',
      submitLabel: '移除',
      emptyText: '暂无可移除的管理员',
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.removeGroupManagers(widget.channelId, selected);
        await _loadData(showLoading: false);
      },
      successMessage: '已移除 ${selected.length} 位管理员',
      failurePrefix: '移除管理员失败',
    );
  }

  Future<void> _transferGroupOwner() async {
    if (!_canManageAdmins) {
      _showMessage('鍙湁缇や富鍙互杞缇や富韬唤');
      return;
    }

    final candidates = _transferableMembers
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: (member.remark ?? member.name ?? member.uid).trim(),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList();

    final selected = await openGroupMemberPicker(
      context,
      title: '转让群主',
      submitLabel: '转让',
      emptyText: '暂无可转让的群成员',
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }
    if (selected.length != 1) {
      _showMessage('转让群主时只能选择一位成员');
      return;
    }

    final targetUid = selected.first;
    final targetMember = _members
        .where((member) => member.uid == targetUid)
        .firstOrNull;
    final targetName = (targetMember?.remark ?? targetMember?.name ?? targetUid)
        .trim();
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('转让群主'),
        content: Text(
          '确定将群主身份转让给 ${targetName.isEmpty ? targetUid : targetName} 吗？转让后当前账号会变成普通成员。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.transferGroupOwner(widget.channelId, targetUid);
        await _loadData(showLoading: false);
      },
      successMessage: '群主已转让',
      failurePrefix: '杞缇や富澶辫触',
    );
  }

  Future<void> _navigateToDeleteMembers() async {
    if (!_canRemoveMembers) {
      _showMessage('当前账号没有可执行的删人权限');
      return;
    }

    final candidates = _removableMembers
        .map(
          (member) => SelectableGroupMember(
            uid: member.uid,
            title: (member.remark ?? member.name ?? member.uid).trim(),
            subtitle: member.uid,
            avatar: member.avatar,
            badge: _memberRoleLabel(member),
          ),
        )
        .toList();

    final selected = await openGroupMemberPicker(
      context,
      title: '移除群成员',
      submitLabel: '移除',
      emptyText: '暂无可移除的群成员',
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.removeGroupMembers(widget.channelId, selected);
        await _loadData(showLoading: false);
      },
      successMessage: '已移除 ${selected.length} 位成员',
      failurePrefix: '移除群成员失败',
    );
  }

  Future<void> _updateMyGroupName() async {
    final member = _currentMember;
    if (member == null || _currentUid.isEmpty) {
      _showMessage('当前账号不在该群成员列表中，无法修改群内昵称');
      return;
    }

    final currentRemark = (member.remark ?? '').trim();
    final newRemark = await _showTextInputDialog(
      title: _groupDetailMyNickTitle,
      hintText: '留空可清除群内昵称',
      initialValue: currentRemark,
      maxLength: 30,
    );
    if (newRemark == null || newRemark == currentRemark) {
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.updateGroupMemberRemark(
          widget.channelId,
          _currentUid,
          newRemark,
        );
        await _loadData(showLoading: false);
      },
      successMessage: newRemark.isEmpty ? '群内昵称已清除' : '群内昵称已更新',
      failurePrefix: '更新群内昵称失败',
    );
  }

  Future<void> _updateGroupName() async {
    final currentName = (_group?.name ?? '').trim();
    final newName = await _showTextInputDialog(
      title: '修改群名称',
      hintText: '请输入新的群聊名称',
      initialValue: currentName,
      maxLength: 30,
    );
    if (newName == null || newName == currentName) {
      return;
    }
    if (newName.isEmpty) {
      _showMessage('群名称不能为空');
      return;
    }

    await _runAction(
      () async {
        await GroupApi.instance.updateGroupInfo(
          widget.channelId,
          name: newName,
        );
        await _loadData(showLoading: false);
      },
      successMessage: '缇ゅ悕绉板凡鏇存柊',
      failurePrefix: '修改群名称失败',
    );
  }

  void _showGroupQR() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupQrPage(groupId: widget.channelId)),
    );
  }

  Future<void> _editGroupNotice() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GroupNoticePage(
          groupId: widget.channelId,
          initialNotice: _group?.notice,
          canEdit: _canManageMembers,
        ),
      ),
    );
    if (result != null) {
      await _loadData(showLoading: false);
    }
  }

  void _searchChatHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => buildGroupSearchHistoryPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          channelName: _group?.name,
        ),
      ),
    );
  }

  void _openGroupReminderPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupReminderPage(
          groupId: widget.channelId,
          groupName: _group?.name,
        ),
      ),
    );
  }

  Future<void> _openReportPage() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          title: _groupDetailReportTitle,
          targetName: _group?.name,
        ),
      ),
    );
    if (result == true && mounted) {
      _showMessage('投诉已提交');
    }
  }

  Future<void> _exitGroup() async {
    final isDismissAction = _canDismissGroup;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDismissAction ? '解散群聊' : '退出群聊'),
        content: Text(
          isDismissAction
              ? '确定要解散该群聊吗？解散后当前群将不可恢复。'
              : '确定要退出该群聊吗？退出后会按服务端结果返回上一页。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('确定', style: TextStyle(color: Colors.red[700])),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final success = await _runAction(() async {
      if (isDismissAction) {
        await GroupApi.instance.dismissGroup(widget.channelId);
      } else {
        await GroupApi.instance.exitGroup(widget.channelId);
      }
    }, failurePrefix: isDismissAction ? '解散群聊失败' : '退出群聊失败');

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String hintText,
    required String initialValue,
    int maxLength = 30,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          autofocus: true,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('鍙栨秷'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('淇濆瓨'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String? _memberRoleLabel(GroupMember member) {
    if (member.isOwner) {
      return '缇や富';
    }
    if (member.isAdmin) {
      return '管理员';
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
