import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/user.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/search_api.dart';
import '../../service/api/user_api.dart';
import '../../modules/vip/vip_guard.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_scan/scan_page.dart';
import 'mail_list_page.dart';
import '../user/user_detail_page.dart';
import '../user/user_qr_page.dart';

class AddFriendsPage extends StatefulWidget {
  final String? currentShortNo;
  final String? currentUid;
  final String? currentName;
  final String? currentAvatarUrl;
  final VoidCallback? onOpenSearchUser;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenQrCode;
  final VoidCallback? onOpenMailList;
  final bool showMailList;

  const AddFriendsPage({
    super.key,
    this.currentShortNo,
    this.currentUid,
    this.currentName,
    this.currentAvatarUrl,
    this.onOpenSearchUser,
    this.onOpenScan,
    this.onOpenQrCode,
    this.onOpenMailList,
    this.showMailList = true,
  });

  @override
  State<AddFriendsPage> createState() => _AddFriendsPageState();
}

class _AddFriendsPageState extends State<AddFriendsPage> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    if (!_hasInjectedUserData) {
      _loadCurrentUser();
    }
  }

  bool get _hasInjectedUserData {
    return (widget.currentShortNo?.trim().isNotEmpty ?? false) ||
        (widget.currentUid?.trim().isNotEmpty ?? false) ||
        (widget.currentName?.trim().isNotEmpty ?? false) ||
        (widget.currentAvatarUrl?.trim().isNotEmpty ?? false);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await UserApi.instance.getCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() => _currentUser = user);
    } catch (_) {}
  }

  String get _displayShortNo {
    final injected = widget.currentShortNo?.trim() ?? '';
    if (injected.isNotEmpty) {
      return injected;
    }
    final loaded = _currentUser?.shortNo?.trim() ?? '';
    if (loaded.isNotEmpty) {
      return loaded;
    }
    return '--';
  }

  String? get _displayUid {
    final injected = widget.currentUid?.trim() ?? '';
    if (injected.isNotEmpty) {
      return injected;
    }
    final loaded = _currentUser?.uid.trim() ?? '';
    return loaded.isEmpty ? null : loaded;
  }

  String? get _displayName {
    final injected = widget.currentName?.trim() ?? '';
    if (injected.isNotEmpty) {
      return injected;
    }
    final loaded = _currentUser?.name?.trim() ?? '';
    return loaded.isEmpty ? null : loaded;
  }

  String? get _displayAvatar {
    final injected = widget.currentAvatarUrl?.trim() ?? '';
    if (injected.isNotEmpty) {
      return injected;
    }
    final loaded = _currentUser?.avatar?.trim() ?? '';
    return loaded.isEmpty ? null : loaded;
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '添加好友',
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: _buildSearchEntry(),
          ),
          const SizedBox(height: 10),
          _buildIdentityRow(),
          const SizedBox(height: 20),
          _buildActionCell(
            iconAsset: WKReferenceAssets.scanLarge,
            title: '扫一扫',
            subtitle: '扫描二维码名片',
            onTap: _openScanPage,
          ),
          if (widget.showMailList)
            _buildActionCell(
              key: const ValueKey('add-friends-mail-list-entry'),
              iconAsset: WKReferenceAssets.mailList,
              title: '手机联系人',
              subtitle: '添加或邀请通讯录中的朋友',
              onTap: _openMailListPage,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchEntry() {
    return Material(
      color: WKColors.surface,
      child: InkWell(
        key: const ValueKey('add-friends-search-entry'),
        onTap: _openSearchUserPage,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WKReferenceAssets.image(
                WKReferenceAssets.search,
                width: 16,
                height: 16,
                tint: WKColors.color999,
              ),
              const SizedBox(width: 5),
              const Text(
                '搜索',
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 14,
                  color: WKColors.color999,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityRow() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '我的悟空号：',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              color: WKColors.colorDark,
            ),
          ),
          Text(
            _displayShortNo,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 14,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openQrCodePage,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: WKReferenceAssets.image(
                  WKReferenceAssets.qrCode,
                  width: 18,
                  height: 18,
                  tint: WKColors.color999,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCell({
    Key? key,
    required String iconAsset,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      key: key,
      color: WKColors.surface,
      child: InkWell(
        onTap: onTap,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              WKReferenceAssets.image(iconAsset, width: 30, height: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 14,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              WKReferenceAssets.image(
                WKReferenceAssets.arrowRight,
                width: 14,
                height: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSearchUserPage() async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (widget.onOpenSearchUser != null) {
      widget.onOpenSearchUser!();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchUserPage()));
  }

  void _openScanPage() {
    if (widget.onOpenScan != null) {
      widget.onOpenScan!();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScanPage()));
  }

  void _openQrCodePage() {
    if (widget.onOpenQrCode != null) {
      widget.onOpenQrCode!();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserQrPage(
          uid: _displayUid,
          username: _displayName,
          avatarUrl: _displayAvatar,
        ),
      ),
    );
  }

  Future<void> _openMailListPage() async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (widget.onOpenMailList != null) {
      widget.onOpenMailList!();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MailListPage()));
  }
}

class SearchUserPage extends StatefulWidget {
  final String? initialQuery;
  final Future<List<User>> Function(String query)? onSearchUsers;
  final Future<void> Function(User user, String remark)? onApplyUser;
  final ValueChanged<String>? onOpenUserDetail;
  final Future<WKChannel?> Function(String uid, int channelType)?
  onLoadLocalChannel;

  const SearchUserPage({
    super.key,
    this.initialQuery,
    this.onSearchUsers,
    this.onApplyUser,
    this.onOpenUserDetail,
    this.onLoadLocalChannel,
  });

  @override
  State<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends State<SearchUserPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _appliedUids = <String>{};

  bool _isSearching = false;
  bool _hasSearched = false;
  List<User> _results = const <User>[];
  Set<String> _locallyFollowedUids = const <String>{};

  String get _currentUid => StorageUtils.getUid()?.trim() ?? '';
  String get _query => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
        if (initialQuery.isNotEmpty) {
          unawaited(_searchUsers());
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSearch = _query.isNotEmpty && !_isSearching;

    return Scaffold(
      backgroundColor: WKColors.homeBg,
      body: Column(
        children: [
          ColoredBox(
            color: WKColors.homeBg,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                          child: WKReferenceAssets.image(
                            WKReferenceAssets.back,
                            width: 11,
                            height: 19,
                            tint: WKColors.colorDark,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: WKColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            textInputAction: TextInputAction.search,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
                              color: WKColors.colorDark,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: '搜索(精确搜索)',
                              hintStyle: TextStyle(
                                fontFamily: WKFontFamily.primary,
                                fontSize: 14,
                                color: WKColors.color999,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _searchUsers(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Opacity(
                        opacity: canSearch ? 1 : 0.2,
                        child: ElevatedButton(
                          key: const ValueKey('search-user-submit'),
                          onPressed: canSearch ? _searchUsers : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(56, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: WKColors.brand500,
                            foregroundColor: WKColors.white,
                            disabledBackgroundColor: WKColors.brand500,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            _isSearching ? '搜索中' : '搜索',
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: WKColors.colorLine),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          '暂无数据',
          style: TextStyle(
            fontFamily: WKFontFamily.primary,
            fontSize: 14,
            color: WKColors.colorDark,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildUserRow(_results[index]),
    );
  }

  Widget _buildUserRow(User user) {
    final title = (user.name ?? user.uid).trim().isEmpty
        ? '未知用户'
        : (user.name ?? user.uid).trim();
    final showApply =
        user.uid.trim().isNotEmpty &&
        user.uid.trim() != _currentUid &&
        (user.follow ?? 0) != 1 &&
        !_locallyFollowedUids.contains(user.uid.trim());
    final isApplied = _appliedUids.contains(user.uid);

    return Material(
      color: WKColors.surface,
      child: InkWell(
        onTap: () => _openUserDetail(user),
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  WKAvatar(url: user.avatar, name: title, size: 50),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 14,
                        color: WKColors.colorDark,
                      ),
                    ),
                  ),
                  if (showApply)
                    Opacity(
                      opacity: isApplied ? 0.2 : 1,
                      child: ElevatedButton(
                        onPressed: isApplied ? null : () => _applyUser(user),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(56, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          backgroundColor: WKColors.brand500,
                          foregroundColor: WKColors.white,
                          disabledBackgroundColor: WKColors.brand500,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          '申请',
                          style: TextStyle(
                            fontFamily: WKFontFamily.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 65),
              child: Divider(
                height: 1,
                thickness: 1,
                color: WKColors.colorLine,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchUsers() async {
    final keyword = _query;
    if (keyword.isEmpty || _isSearching) {
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final users = widget.onSearchUsers != null
          ? await widget.onSearchUsers!(keyword)
          : (await SearchApi.instance.searchUsers(keyword))
                .map((json) => User.fromJson(Map<String, dynamic>.from(json)))
                .where((user) => user.uid.trim().isNotEmpty)
                .toList(growable: false);
      final locallyFollowedUids = await _resolveLocallyFollowedUids(users);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = users;
        _locallyFollowedUids = locallyFollowedUids;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSearching = false);
      _showMessage('搜索好友失败: $error');
    }
  }

  Future<void> _applyUser(User user) async {
    if (_appliedUids.contains(user.uid)) {
      return;
    }
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }

    if (widget.onApplyUser != null) {
      await widget.onApplyUser!(user, '');
      if (!mounted) {
        return;
      }
      setState(() => _appliedUids.add(user.uid));
      return;
    }

    final controller = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('申请'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '输入备注'),
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

    if (remark == null) {
      return;
    }

    try {
      await FriendApi.instance.addFriend(
        user.uid,
        remark: remark.isEmpty ? null : remark,
        vercode: user.vercode,
      );
      if (!mounted) {
        return;
      }
      setState(() => _appliedUids.add(user.uid));
    } catch (error) {
      _showMessage('发送好友申请失败: $error');
    }
  }

  Future<Set<String>> _resolveLocallyFollowedUids(Iterable<User> users) async {
    final locallyFollowedUids = <String>{};
    for (final user in users) {
      final uid = user.uid.trim();
      if (uid.isEmpty || uid == _currentUid) {
        continue;
      }
      final channel = widget.onLoadLocalChannel != null
          ? await widget.onLoadLocalChannel!(uid, WKChannelType.personal)
          : await WKIM.shared.channelManager.getChannel(
              uid,
              WKChannelType.personal,
            );
      if (channel != null && channel.follow == 1 && channel.isDeleted == 0) {
        locallyFollowedUids.add(uid);
      }
    }
    return locallyFollowedUids;
  }

  void _openUserDetail(User user) {
    if (widget.onOpenUserDetail != null) {
      widget.onOpenUserDetail!(user.uid);
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserDetailPage(uid: user.uid)));
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
