import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/platform_utils.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/user.dart';
import '../../data/providers/auth_provider.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_screen_popup_menu.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/utils/download_manager.dart';
import 'avatar_crop_page.dart';

enum _MyHeadPortraitAction { changeAvatar, saveLocal }

typedef AvatarPathCropper = Future<String?> Function(String sourcePath);

class AvatarParityArtifacts {
  const AvatarParityArtifacts({
    required this.avatarCacheKey,
    required this.rtcAvatarUrl,
  });

  final String avatarCacheKey;
  final String rtcAvatarUrl;
}

const Uuid _avatarParityUuid = Uuid();

@visibleForTesting
Future<String?> resolveAvatarUploadSourcePath(
  String sourcePath, {
  required AvatarPathCropper cropAvatarPath,
}) async {
  final normalizedSource = sourcePath.trim();
  if (normalizedSource.isEmpty) {
    return null;
  }
  final croppedPath = await cropAvatarPath(normalizedSource);
  final normalizedCropped = croppedPath?.trim() ?? '';
  if (normalizedCropped.isEmpty) {
    return null;
  }
  return normalizedCropped;
}

@visibleForTesting
Future<AvatarParityArtifacts?> syncAvatarParityArtifacts(
  String? avatarUrl, {
  String? currentUid,
  EndpointManager? endpointManager,
}) async {
  final normalizedAvatarUrl = avatarUrl?.trim() ?? '';
  if (normalizedAvatarUrl.isEmpty) {
    return null;
  }

  final uid =
      currentUid?.trim() ??
      StorageUtils.getUid()?.trim() ??
      WKIM.shared.options.uid?.trim() ??
      '';
  if (uid.isEmpty) {
    return null;
  }

  var channel = await WKIM.shared.channelManager.getChannel(
    uid,
    WKChannelType.personal,
  );
  if (channel == null || channel.channelID.trim().isEmpty) {
    channel = WKChannel(uid, WKChannelType.personal);
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
  }

  final avatarCacheKey = _avatarParityUuid.v4().replaceAll('-', '');
  await WKIM.shared.channelManager.updateAvatarCacheKey(
    uid,
    WKChannelType.personal,
    avatarCacheKey,
  );

  final rtcAvatarUrl = buildRtcAvatarUrl(normalizedAvatarUrl, avatarCacheKey);
  (endpointManager ?? EndpointManager.getInstance()).invoke(
    'updateRtcAvatarUrl',
    rtcAvatarUrl,
  );

  return AvatarParityArtifacts(
    avatarCacheKey: avatarCacheKey,
    rtcAvatarUrl: rtcAvatarUrl,
  );
}

@visibleForTesting
String buildRtcAvatarUrl(String avatarUrl, String avatarCacheKey) {
  final uri = Uri.tryParse(avatarUrl);
  if (uri == null) {
    final separator = avatarUrl.contains('?') ? '&' : '?';
    return '$avatarUrl${separator}key=$avatarCacheKey';
  }
  return uri
      .replace(
        queryParameters: <String, String>{'key': avatarCacheKey},
        fragment: '',
      )
      .toString();
}

class MyHeadPortraitPage extends ConsumerStatefulWidget {
  final User? initialUserOverride;
  final String? displayName;
  final String? avatarUrl;
  final bool skipInitialLoad;
  final Future<String?> Function()? onChangeAvatar;
  final Future<void> Function(String avatarUrl)? onSaveAvatar;
  final ValueChanged<String>? onAvatarChanged;
  final AvatarPathCropper? cropAvatarPath;

  const MyHeadPortraitPage({
    super.key,
    this.initialUserOverride,
    this.displayName,
    this.avatarUrl,
    this.skipInitialLoad = false,
    this.onChangeAvatar,
    this.onSaveAvatar,
    this.onAvatarChanged,
    this.cropAvatarPath,
  });

  @override
  ConsumerState<MyHeadPortraitPage> createState() => _MyHeadPortraitPageState();
}

class _MyHeadPortraitPageState extends ConsumerState<MyHeadPortraitPage> {
  final GlobalKey _moreActionKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  User? _user;
  String _displayName = '我';
  String _avatarUrl = '';
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUserOverride;
    _displayName = _resolveDisplayName(
      widget.displayName ?? widget.initialUserOverride?.name,
    );
    _avatarUrl = _resolveAvatarUrl(
      widget.avatarUrl ?? widget.initialUserOverride?.avatar,
    );
    _isLoading = !widget.skipInitialLoad && _user == null && _avatarUrl.isEmpty;
    if (!_isLoading) {
      return;
    }
    _loadUser();
  }

  Future<void> _loadUser({String? overrideAvatarUrl}) async {
    setState(() => _isLoading = true);

    try {
      var user = await UserApi.instance.getCurrentUser();
      final normalizedOverride = _resolveAvatarUrl(overrideAvatarUrl);
      if (normalizedOverride.isNotEmpty) {
        user = user.copyWith(avatar: normalizedOverride, isUploadAvatar: 1);
      }
      if (!mounted) {
        return;
      }
      ref.read(authProvider.notifier).updateCurrentUser(user);
      setState(() {
        _user = user;
        _displayName = _resolveDisplayName(user.name);
        _avatarUrl = _resolveAvatarUrl(user.avatar);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('加载头像失败：$error');
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

  Future<void> _showMoreActions() async {
    final anchorContext = _moreActionKey.currentContext;
    if (anchorContext == null) {
      return;
    }

    final action = await showWKScreenPopupMenu<_MyHeadPortraitAction>(
      context: context,
      anchorContext: anchorContext,
      items: [
        WKScreenPopupMenuItem<_MyHeadPortraitAction>(
          value: _MyHeadPortraitAction.changeAvatar,
          title: '更换头像',
          icon: Icons.edit_outlined,
          enabled: !_isUpdating,
        ),
        WKScreenPopupMenuItem<_MyHeadPortraitAction>(
          value: _MyHeadPortraitAction.saveLocal,
          title: '保存到本地',
          icon: Icons.download_rounded,
          enabled: !_isUpdating,
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _MyHeadPortraitAction.changeAvatar:
        await _changeAvatar();
      case _MyHeadPortraitAction.saveLocal:
        await _saveAvatar();
    }
  }

  Future<void> _changeAvatar() async {
    final override = widget.onChangeAvatar;
    if (override != null) {
      final updatedAvatar = await override();
      if (!mounted) {
        return;
      }
      _applyAvatarUpdate(updatedAvatar);
      await syncAvatarParityArtifacts(updatedAvatar);
      return;
    }

    final source = await _selectAvatarSource();
    if (source == null) {
      return;
    }
    await _pickAndUploadAvatar(source);
  }

  Future<ImageSource?> _selectAvatarSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('拍照'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (source == ImageSource.camera && PlatformUtils.isDesktop) {
      _showMessage('${PlatformUtils.platformName} 端暂不支持直接拍照');
      return;
    }

    try {
      final filePath = await _pickImagePath(source);
      if (filePath == null || filePath.trim().isEmpty) {
        return;
      }
      final uploadPath = await resolveAvatarUploadSourcePath(
        filePath,
        cropAvatarPath: widget.cropAvatarPath ?? _openAvatarCropper,
      );
      if (uploadPath == null || uploadPath.trim().isEmpty) {
        return;
      }

      await _runUpdate(() async {
        final previousAvatar = _avatarUrl;
        final updatedAvatar = await UserApi.instance.uploadAvatar(uploadPath);
        await _evictAvatarCache(previousAvatar);
        await _evictAvatarCache(updatedAvatar);
        await syncAvatarParityArtifacts(updatedAvatar);
        _applyAvatarUpdate(updatedAvatar);
        await _loadUser(overrideAvatarUrl: updatedAvatar);
        _showMessage('头像已更新');
      });
    } catch (error) {
      _showMessage('头像上传失败：$error');
    }
  }

  Future<String?> _openAvatarCropper(String sourcePath) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => AvatarCropPage(sourcePath: sourcePath),
      ),
    );
  }

  Future<String?> _pickImagePath(ImageSource source) async {
    if (source == ImageSource.gallery && PlatformUtils.isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
        allowMultiple: false,
        withData: false,
      );
      return result?.files.single.path;
    }

    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    return file?.path;
  }

  Future<void> _saveAvatar() async {
    final normalizedAvatar = _resolveAvatarUrl(_avatarUrl);
    if (normalizedAvatar.isEmpty) {
      _showMessage('当前没有可保存的头像');
      return;
    }

    await _runUpdate(() async {
      if (widget.onSaveAvatar != null) {
        await widget.onSaveAvatar!(normalizedAvatar);
      } else {
        final savedPath = await DownloadManager().downloadImage(normalizedAvatar);
        if (savedPath == null || savedPath.trim().isEmpty) {
          throw Exception('保存头像失败');
        }
      }
      _showMessage('已保存在相册');
    });
  }

  Future<void> _evictAvatarCache(String? avatarUrl) async {
    final normalized = _resolveAvatarUrl(avatarUrl);
    if (normalized.isEmpty) {
      return;
    }

    await NetworkImage(normalized).evict();
    await WKAvatar.evictUrl(normalized);
    final uri = Uri.tryParse(normalized);
    if (uri != null && (uri.hasQuery || uri.fragment.isNotEmpty)) {
      final baseUrl = uri
          .replace(queryParameters: const {}, fragment: '')
          .toString();
      await NetworkImage(baseUrl).evict();
      await WKAvatar.evictUrl(baseUrl);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void _applyAvatarUpdate(String? avatarUrl) {
    final normalizedAvatar = _resolveAvatarUrl(avatarUrl);
    if (normalizedAvatar.isEmpty) {
      return;
    }

    setState(() {
      _avatarUrl = normalizedAvatar;
      _user = (_user ?? UserInfo(uid: '')).copyWith(
        avatar: normalizedAvatar,
        isUploadAvatar: 1,
      );
    });
    widget.onAvatarChanged?.call(normalizedAvatar);
  }

  Widget _buildAvatarImage() {
    final normalizedAvatar = _resolveAvatarUrl(_avatarUrl);

    Widget child;
    if (normalizedAvatar.startsWith('http://') ||
        normalizedAvatar.startsWith('https://')) {
      child = Image.network(
        normalizedAvatar,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _buildAvatarFallback(),
      );
    } else {
      child = _buildAvatarFallback();
    }

    return GestureDetector(
      key: const ValueKey('my_head_portrait_image'),
      onLongPress: _isLoading || _isUpdating ? null : _showMoreActions,
      child: SizedBox(
        width: double.infinity,
        child: child,
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: WKColors.white),
        child: Center(
          child: WKAvatar(
            url: _avatarUrl,
            name: _displayName,
            size: 180,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '头像',
      trailing: Builder(
        builder: (context) {
          return KeyedSubtree(
            key: _moreActionKey,
            child: GestureDetector(
              key: const ValueKey('my_head_portrait_more_action'),
              onTap: _isLoading || _isUpdating ? null : _showMoreActions,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: WKReferenceAssets.image(
                  WKReferenceAssets.topMore,
                  width: 18,
                  height: 18,
                  tint: _isUpdating ? WKColors.color999 : WKColors.colorDark,
                ),
              ),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          ColoredBox(
            color: WKColors.homeBg,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(child: _buildAvatarImage()),
          ),
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

  String _resolveDisplayName(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '我' : normalized;
  }

  String _resolveAvatarUrl(String? value) {
    return value?.trim() ?? '';
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
