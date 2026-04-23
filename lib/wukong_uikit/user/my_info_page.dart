import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/runtime_capabilities_provider.dart';
import '../../modules/vip/vip_badge.dart';
import '../../service/api/common_api.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'my_head_portrait_page.dart';
import 'update_user_info_page.dart';
import 'user_qr_page.dart';

class MyInfoPage extends ConsumerStatefulWidget {
  final User? initialUserOverride;
  final bool skipInitialLoad;
  final Future<void> Function(int value)? onUpdateSex;
  final AppRuntimeCapabilities? runtimeCapabilitiesOverride;

  const MyInfoPage({
    super.key,
    this.initialUserOverride,
    this.skipInitialLoad = false,
    this.onUpdateSex,
    this.runtimeCapabilitiesOverride,
  });

  @override
  ConsumerState<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends ConsumerState<MyInfoPage> {
  User? _user;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUserOverride;
    _isLoading = !widget.skipInitialLoad && _user == null;
    if (!widget.skipInitialLoad) {
      _loadUserInfo();
    }
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);

    try {
      final user = await UserApi.instance.getCurrentUser();
      if (!mounted) {
        return;
      }
      ref.read(authProvider.notifier).updateCurrentUser(user);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载个人信息失败：$error');
    }
  }

  Future<void> _runUpdate(Future<void> Function() action) async {
    if (_isUpdating) {
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _editName() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UpdateUserInfoPage(
          type: UserInfoUpdateType.name,
          initialValue: _user?.name ?? '',
          onSave: (value) => UserApi.instance.updateUserInfo(name: value),
        ),
      ),
    );

    if (!mounted || name == null) {
      return;
    }

    _applyUserProfileUpdate(name: name);
  }

  Future<void> _openHeadPortraitPage() async {
    final displayName = _resolveDisplayName(_user?.name);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyHeadPortraitPage(
          initialUserOverride: _user,
          displayName: displayName,
          avatarUrl: _user?.avatar,
          skipInitialLoad: true,
          onAvatarChanged: _handleAvatarChanged,
        ),
      ),
    );
  }

  void _handleAvatarChanged(String avatarUrl) {
    final currentUser = _user ?? widget.initialUserOverride;
    if (currentUser == null) {
      return;
    }

    final updatedUser = currentUser.copyWith(
      avatar: avatarUrl,
      isUploadAvatar: 1,
    );

    ref.read(authProvider.notifier).updateCurrentUser(updatedUser);
    if (!mounted) {
      return;
    }
    setState(() => _user = updatedUser);
  }

  Future<void> _editSex() async {
    final currentSex = (_user?.sex ?? 0) == 1 ? 1 : 0;
    final selectedValue = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.male),
                title: const Text('男'),
                onTap: () => Navigator.of(sheetContext).pop(1),
              ),
              ListTile(
                leading: const Icon(Icons.female),
                title: const Text('女'),
                onTap: () => Navigator.of(sheetContext).pop(0),
              ),
            ],
          ),
        );
      },
    );

    if (selectedValue == null || selectedValue == currentSex) {
      return;
    }

    await _runUpdate(() async {
      if (widget.onUpdateSex != null) {
        await widget.onUpdateSex!(selectedValue);
      } else {
        await UserApi.instance.updateUserInfo(sex: selectedValue);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _user = (_user ?? widget.initialUserOverride)?.copyWith(
          sex: selectedValue,
        );
      });

      if (widget.onUpdateSex == null) {
        await _loadUserInfo();
      }
    });
  }

  Future<void> _editShortNo() async {
    final AppRuntimeCapabilities capabilities =
        widget.runtimeCapabilitiesOverride ??
        await ref.read(runtimeCapabilitiesProvider.future);
    if (!mounted) {
      return;
    }
    if ((_user?.shortStatus ?? 0) == 1) {
      return;
    }
    if (!capabilities.shortNoEditable) {
      _showMessage(capabilities.shortNoEditStatusMessage);
      return;
    }

    final shortNo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => UpdateUserInfoPage(
          type: UserInfoUpdateType.shortNo,
          initialValue: _user?.shortNo ?? '',
          onSave: (value) => UserApi.instance.updateUserInfo(shortNo: value),
        ),
      ),
    );

    if (!mounted || shortNo == null) {
      return;
    }

    _applyUserProfileUpdate(shortNo: shortNo, shortStatus: 1);
  }

  void _showQRCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserQrPage(
          uid: _user?.uid,
          username: _user?.name,
          avatarUrl: _user?.avatar,
        ),
      ),
    );
  }

  String _sexLabel(int? sex) {
    return sex == 1 ? '男' : '女';
  }

  String _resolveDisplayName(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '我' : normalized;
  }

  void _applyUserProfileUpdate({
    String? name,
    String? shortNo,
    int? shortStatus,
  }) {
    final currentUser = _user ?? widget.initialUserOverride;
    if (currentUser == null) {
      return;
    }

    final updatedUser = currentUser.copyWith(
      name: name ?? currentUser.name,
      shortNo: shortNo ?? currentUser.shortNo,
      shortStatus: shortStatus ?? currentUser.shortStatus,
    );

    ref.read(authProvider.notifier).updateCurrentUser(updatedUser);
    if (!mounted) {
      return;
    }
    setState(() => _user = updatedUser);
  }

  AppRuntimeCapabilities? _resolveRuntimeCapabilities() {
    if (widget.runtimeCapabilitiesOverride != null) {
      return widget.runtimeCapabilitiesOverride;
    }
    if (widget.skipInitialLoad) {
      return null;
    }
    return ref
        .watch(runtimeCapabilitiesProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
  }

  bool _isShortNoImmutable(AppRuntimeCapabilities? capabilities) {
    if ((_user?.shortStatus ?? 0) == 1) {
      return true;
    }
    if (capabilities == null) {
      return false;
    }
    return !capabilities.shortNoEditable;
  }

  Widget _buildAvatarTrailing() {
    final displayName = _resolveDisplayName(_user?.name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            WKAvatar(url: _user?.avatar, name: displayName, size: 40),
            if (_isUpdating)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WKColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        WKReferenceAssets.image(
          WKReferenceAssets.arrowRight,
          width: 14,
          height: 14,
        ),
      ],
    );
  }

  Widget _buildQrTrailing() {
    return WKReferenceAssets.image(
      WKReferenceAssets.qrCode,
      width: 18,
      height: 18,
      tint: WKColors.color999,
    );
  }

  Widget _buildBody() {
    final shortNo = (_user?.shortNo ?? '').trim();
    final isVipUser = (_user?.vipLevel ?? 0) == 1;
    final runtimeCapabilities = _resolveRuntimeCapabilities();
    final isShortNoImmutable = _isShortNoImmutable(runtimeCapabilities);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WKSettingsGroup(
          children: [
            const WKSectionGap(15),
            WKSettingsCell(
              title: '头像',
              showArrow: false,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              trailing: _buildAvatarTrailing(),
              onTap: _isUpdating ? null : _openHeadPortraitPage,
            ),
            WKSettingsCell(
              title: '名字',
              value: (_user?.name ?? '').trim().isEmpty
                  ? '未设置'
                  : (_user?.name ?? '').trim(),
              onTap: _isUpdating ? null : _editName,
            ),
            if (isVipUser)
              const WKSettingsCell(
                title: '身份',
                showArrow: false,
                trailing: VipBadge(),
              ),
            WKSettingsCell(
              title: '悟空号',
              value: shortNo.isEmpty ? '未设置' : shortNo,
              showArrow: !isShortNoImmutable,
              enabled: !isShortNoImmutable,
              onTap: _isUpdating || isShortNoImmutable ? null : _editShortNo,
            ),
            WKSettingsCell(
              title: '我的二维码',
              showArrow: false,
              trailing: _buildQrTrailing(),
              onTap: _showQRCode,
            ),
            const WKSectionGap(15),
            WKSettingsCell(
              title: '性别',
              value: _sexLabel(_user?.sex),
              onTap: _isUpdating ? null : _editSex,
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '个人信息',
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
