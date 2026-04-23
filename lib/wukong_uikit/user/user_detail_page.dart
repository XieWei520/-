import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/models/user_relationship.dart';
import '../../data/models/user.dart';
import '../../data/providers/user_provider.dart';
import '../../modules/chat/chat_page.dart';
import '../../modules/customer_service/customer_service_badge.dart';
import '../../modules/vip/vip_badge.dart';
import '../../modules/vip/vip_guard.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/group_api.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_base/views/image_viewer.dart';
import 'file_helper_page.dart';
import 'my_info_page.dart';
import 'set_user_remark_page.dart';
import 'system_team_page.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final String uid;
  final String? groupId;
  final User? initialUserOverride;
  final GroupMember? initialGroupMemberOverride;
  final bool? initialIsFriendOverride;
  final bool? initialIsInBlacklistOverride;
  final bool? initialIsBlockedByPeerOverride;
  final bool skipInitialLoad;
  final ValueChanged<String>? onOpenAvatarPreview;
  final ValueChanged<String>? onCopyText;
  final Future<void> Function(bool isCurrentlyInBlacklist)? onToggleBlacklist;

  const UserDetailPage({
    super.key,
    required this.uid,
    this.groupId,
    this.initialUserOverride,
    this.initialGroupMemberOverride,
    this.initialIsFriendOverride,
    this.initialIsInBlacklistOverride,
    this.initialIsBlockedByPeerOverride,
    this.skipInitialLoad = false,
    this.onOpenAvatarPreview,
    this.onCopyText,
    this.onToggleBlacklist,
  });

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  User? _user;
  GroupMember? _groupMember;
  bool _isLoading = true;
  bool _isInBlacklist = false;
  bool _isBlockedByPeer = false;
  bool _isFriend = false;
  bool _isUpdating = false;

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';
  bool get _isSelf => widget.uid == _currentUid;
  bool get _isFileHelperAccount => widget.uid.trim() == 'fileHelper';
  bool get _isSystemTeamAccount => widget.uid.trim() == 'u_10000';
  bool get _isSpecialSystemAccount =>
      _isFileHelperAccount || _isSystemTeamAccount;

  String get _displayName {
    final remark = (_user?.remark ?? '').trim();
    final name = (_user?.name ?? '').trim();
    if (remark.isNotEmpty) {
      return remark;
    }
    if (name.isNotEmpty) {
      return name;
    }
    return widget.uid;
  }

  @override
  void initState() {
    super.initState();
    _user = widget.initialUserOverride;
    _groupMember = widget.initialGroupMemberOverride;
    _isFriend = widget.initialIsFriendOverride ?? false;
    _isInBlacklist = widget.initialIsInBlacklistOverride ?? false;
    _isBlockedByPeer = widget.initialIsBlockedByPeerOverride ?? false;
    _isLoading = _isSpecialSystemAccount
        ? false
        : !widget.skipInitialLoad && _user == null;
    if (!_isSpecialSystemAccount && !widget.skipInitialLoad) {
      _loadUserInfo(showLoading: true);
    }
  }

  Future<void> _loadUserInfo({bool showLoading = false}) async {
    if (!mounted) {
      return;
    }
    if (showLoading || _user == null) {
      setState(() => _isLoading = true);
    }

    try {
      final user = await UserApi.instance.getUserInfo(widget.uid);

      if (!mounted) {
        return;
      }

      final initialState = resolveUserDetailRelationshipState(
        targetUid: widget.uid,
        user: user,
      );

      setState(() {
        _user = user;
        _isFriend = initialState.isFriend;
        _isBlockedByPeer = initialState.isBlockedByPeer;
        _isLoading = false;
      });

      final friends = await _loadFriendsSafe();
      final blacklist = await _loadBlacklistSafe();
      final groupMember = await _loadGroupMemberSafe();

      if (!mounted) {
        return;
      }

      final resolvedState = resolveUserDetailRelationshipState(
        targetUid: widget.uid,
        user: user,
        friends: friends,
        blacklist: blacklist,
      );

      setState(() {
        _groupMember = groupMember;
        _isFriend = resolvedState.isFriend;
        _isInBlacklist = resolvedState.isInBlacklist;
        _isBlockedByPeer = resolvedState.isBlockedByPeer;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载用户资料失败：$error');
    }
  }

  Future<void> _refreshFriendList() async {
    await ref.read(friendListProvider.notifier).refresh();
  }

  Future<List<Friend>> _loadFriendsSafe() async {
    try {
      return await FriendApi.instance.getFriends();
    } catch (_) {
      return const <Friend>[];
    }
  }

  Future<List<UserInfo>> _loadBlacklistSafe() async {
    try {
      return await UserApi.instance.getBlackList();
    } catch (_) {
      return const <UserInfo>[];
    }
  }

  Future<GroupMember?> _loadGroupMemberSafe() async {
    final groupId = widget.groupId?.trim() ?? '';
    if (groupId.isEmpty) {
      return null;
    }

    try {
      final members = await GroupApi.instance.getGroupMembers(groupId);
      for (final member in members) {
        if (member.uid == widget.uid) {
          return member;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sendFriendRequest() async {
    if (_isFriend || _isSelf || (_user?.follow ?? 0) == 1) {
      if (!_isSelf && mounted) {
        setState(() => _isFriend = true);
      }
      return;
    }
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }

    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('申请加好友'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: '请输入申请备注'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('发送'),
            ),
          ],
        );
      },
    );

    if (message == null) {
      return;
    }

    try {
      await FriendApi.instance.addFriend(
        widget.uid,
        remark: message.isEmpty ? null : message,
        vercode: _user?.vercode,
      );
      _showMessage('好友申请已发送');
    } catch (error) {
      final errorText = error.toString();
      if (errorText.contains('已经是好友')) {
        if (mounted) {
          setState(() => _isFriend = true);
        }
        _showMessage('你们已经是好友了');
        return;
      }
      _showMessage('发送好友申请失败：$error');
    }
  }

  void _sendMessage() {
    if (_isBlockedByPeer) {
      _showMessage('对方已将你加入黑名单，当前无法向对方发消息');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: widget.uid,
          channelType: WKChannelType.personal,
          channelName: _displayName,
        ),
      ),
    );
  }

  Future<void> _setRemark() async {
    if (!_isFriend) {
      return;
    }

    final initialRemark = (_user?.remark ?? '').isNotEmpty
        ? _user!.remark!
        : _displayName;
    final remark = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SetUserRemarkPage(
          uid: widget.uid,
          initialValue: initialRemark,
          onSave: (value) =>
              FriendApi.instance.updateFriendRemark(widget.uid, value),
        ),
      ),
    );

    if (!mounted || remark == null) {
      return;
    }

    await _refreshFriendList();
    _applyRemarkUpdate(remark);
  }

  Future<void> _toggleBlacklist() async {
    final title = _isInBlacklist ? '移出黑名单' : '加入黑名单';
    final content = _isInBlacklist ? '确定将该用户移出黑名单吗？' : '加入黑名单后，你将不再接收对方消息。';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isUpdating = true);
    try {
      if (widget.onToggleBlacklist != null) {
        await widget.onToggleBlacklist!(_isInBlacklist);
        return;
      }
      if (_isInBlacklist) {
        await UserApi.instance.removeBlackList(widget.uid);
        _showMessage('已移出黑名单');
      } else {
        await UserApi.instance.addBlackList(widget.uid);
        _showMessage('已加入黑名单');
      }
      await _refreshFriendList();
      await _loadUserInfo();
    } catch (error) {
      _showMessage('操作失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _deleteFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('解除好友关系'),
          content: const Text('确定解除当前好友关系吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('解除', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await FriendApi.instance.deleteFriend(widget.uid);
      await _refreshFriendList();
      _showMessage('好友关系已解除');
      await _loadUserInfo();
    } catch (error) {
      _showMessage('解除好友关系失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _sexAsset(int? sex) {
    switch (sex) {
      case 1:
        return WKReferenceAssets.male;
      case 2:
        return WKReferenceAssets.female;
      default:
        return '';
    }
  }

  String _sourceText() {
    final sourceDesc = (_user?.sourceDesc ?? '').trim();
    return sourceDesc.isEmpty ? '' : sourceDesc;
  }

  String? _joinGroupWayText() {
    final inviteName = (_user?.joinGroupInviteName ?? '').trim();
    if (inviteName.isNotEmpty) {
      final joinGroupTime = (_user?.joinGroupTime ?? '').trim();
      final timePrefix = joinGroupTime.isEmpty ? '' : '$joinGroupTime ';
      return '$timePrefix$inviteName邀请入群';
    }

    final inviteUid = (_groupMember?.inviteUid ?? '').trim();
    if (inviteUid.isEmpty) {
      return null;
    }
    final joinGroupTime = _formatJoinGroupTime(_groupMember?.joinTime);
    final timePrefix = joinGroupTime == null ? '' : '$joinGroupTime ';
    return '$timePrefix$inviteUid邀请入群';
  }

  String? _inGroupNameText() {
    final remark = (_groupMember?.remark ?? '').trim();
    return remark.isEmpty ? null : remark;
  }

  String? _shortNoText() {
    final shortNo = (_user?.shortNo ?? '').trim();
    return shortNo.isEmpty ? null : shortNo;
  }

  String? _formatJoinGroupTime(int? joinTime) {
    if (joinTime == null || joinTime <= 0) {
      return null;
    }

    final date = DateTime.fromMillisecondsSinceEpoch(joinTime * 1000);
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _openAvatarPreview() async {
    final avatar = (_user?.avatar ?? '').trim();
    if (avatar.isEmpty) {
      return;
    }

    if (widget.onOpenAvatarPreview != null) {
      widget.onOpenAvatarPreview!(avatar);
      return;
    }

    await ImageViewerHelper.showImage(
      context,
      image: avatar,
      heroTag: 'user-detail-avatar-${widget.uid}',
      caption: _displayName,
    );
  }

  Future<void> _copyText(String text) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    if (widget.onCopyText != null) {
      widget.onCopyText!(normalizedText);
      return;
    }

    await Clipboard.setData(ClipboardData(text: normalizedText));
    _showMessage('已复制');
  }

  Future<void> _showCopyMenu({
    required Offset globalPosition,
    required String text,
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      await _copyText(normalizedText);
      return;
    }

    final action = await showMenu<_UserDetailTextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<_UserDetailTextAction>(
          value: _UserDetailTextAction.copy,
          child: Text('复制'),
        ),
      ],
    );

    if (!mounted || action != _UserDetailTextAction.copy) {
      return;
    }

    await _copyText(normalizedText);
  }

  Widget _buildProfileTag({
    required String label,
    required String value,
    bool allowCopy = false,
  }) {
    final row = Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: WKColors.colorDark),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: WKColors.colorDark),
            ),
          ),
        ],
      ),
    );

    if (!allowCopy) {
      return row;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) =>
          _showCopyMenu(globalPosition: details.globalPosition, text: value),
      child: row,
    );
  }

  Widget _buildHeader() {
    final sexAsset = _sexAsset(_user?.sex);
    final isVipUser = (_user?.vipLevel ?? 0) == 1;
    final inGroupName = _inGroupNameText();
    final shortNo = _shortNoText();

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 25, 15, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WKAvatar(
            url: _user?.avatar,
            name: _displayName,
            size: 50,
            onTap: _openAvatarPreview,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: (details) => _showCopyMenu(
                      globalPosition: details.globalPosition,
                      text: _displayName,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: WKColors.colorDark,
                            ),
                          ),
                        ),
                        if (isVipUser) ...[
                          const SizedBox(width: 6),
                          const VipBadge(),
                        ],
                        if (_user?.isCustomerService ?? false) ...[
                          const SizedBox(width: 6),
                          const CustomerServiceBadge(),
                        ],
                        if (sexAsset.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          WKReferenceAssets.image(
                            sexAsset,
                            width: 25,
                            height: 25,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (inGroupName != null)
                    _buildProfileTag(label: '群内昵称：', value: inGroupName),
                  if ((_user?.name ?? '').trim().isNotEmpty &&
                      (_user?.name ?? '').trim() != _displayName)
                    _buildProfileTag(
                      label: '昵称：',
                      value: (_user?.name ?? '').trim(),
                      allowCopy: true,
                    ),
                  if (shortNo != null)
                    _buildProfileTag(
                      label: '悟空号：',
                      value: shortNo,
                      allowCopy: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGroup() {
    final sourceText = _sourceText();
    final joinGroupWay = _joinGroupWayText();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: WKSettingsGroup(
        children: [
          if (_isFriend)
            WKSettingsCell(
              title: '设置备注',
              onTap: _isUpdating ? null : _setRemark,
            ),
          if (sourceText.isNotEmpty)
            WKSettingsCell(title: '来源', value: sourceText, showArrow: false),
          if (joinGroupWay != null)
            WKSettingsCell(
              title: '进群方式',
              value: joinGroupWay,
              showArrow: false,
            ),
          if (_isFriend) const WKSectionGap(15),
          if (_isFriend)
            WKSettingsCell(
              title: '解除好友关系',
              onTap: _isUpdating ? null : _deleteFriend,
            ),
        ],
      ),
    );
  }

  Widget _buildBlacklistGroup() {
    return WKSettingsGroup(
      children: [
        WKSettingsCell(
          title: _isInBlacklist ? '移出黑名单' : '加入黑名单',
          onTap: _isUpdating ? null : _toggleBlacklist,
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    if (_isSelf) {
      return const SizedBox(height: 30);
    }

    final isFriend = _isFriend;
    final canApplyFriend = (_user?.vercode ?? '').trim().isNotEmpty;
    final canSendMessage = isFriend && !_isBlockedByPeer;
    if (!isFriend && !canApplyFriend) {
      return const SizedBox(height: 30);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 30, 15, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : (isFriend
                        ? (canSendMessage ? _sendMessage : null)
                        : _sendFriendRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: WKColors.brand500,
                foregroundColor: WKColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(isFriend ? '发消息' : '申请加好友'),
            ),
          ),
          if (_isBlockedByPeer)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '对方已将你加入黑名单，当前无法向对方发消息。',
                style: TextStyle(fontSize: 14, color: WKColors.color999),
                textAlign: TextAlign.center,
              ),
            ),
          if (_isInBlacklist)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '加入黑名单后，将不再接收对方消息。',
                style: const TextStyle(fontSize: 14, color: WKColors.color999),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(),
        _buildInfoGroup(),
        _buildBlacklistGroup(),
        _buildBottomButton(),
        const SizedBox(height: 30),
      ],
    );
  }

  void _applyRemarkUpdate(String remark) {
    final currentUser = _user;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _user = currentUser.copyWith(remark: remark);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFileHelperAccount) {
      return FileHelperPage(
        avatarUrl: _user?.avatar,
        onOpenAvatarPreview: widget.onOpenAvatarPreview,
      );
    }
    if (_isSystemTeamAccount) {
      return SystemTeamPage(
        avatarUrl: _user?.avatar,
        onOpenAvatarPreview: widget.onOpenAvatarPreview,
      );
    }
    if (_isSelf) {
      return MyInfoPage(
        initialUserOverride: _user,
        skipInitialLoad: _user != null,
      );
    }
    return WKSubPageScaffold(
      title: '个人名片',
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildBody(),
          if (_isUpdating)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
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

enum _UserDetailTextAction { copy }

typedef UserDetailRelationshipState = UserRelationshipState;

UserRelationshipState resolveUserDetailRelationshipState({
  required String targetUid,
  User? user,
  Iterable<Friend> friends = const <Friend>[],
  Iterable<UserInfo> blacklist = const <UserInfo>[],
}) {
  return resolveUserRelationshipState(
    targetUid: targetUid,
    user: user,
    friends: friends,
    blacklist: blacklist,
  );
}
