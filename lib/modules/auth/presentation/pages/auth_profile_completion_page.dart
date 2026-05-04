import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/local_media_image_provider.dart';
import '../../../../widgets/wk_colors.dart';
import '../../../../widgets/wk_design_tokens.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_flow_models.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthProfileCompletionPage extends ConsumerStatefulWidget {
  const AuthProfileCompletionPage({super.key});

  @override
  ConsumerState<AuthProfileCompletionPage> createState() =>
      _AuthProfileCompletionPageState();
}

class _AuthProfileCompletionPageState
    extends ConsumerState<AuthProfileCompletionPage> {
  final TextEditingController _nameController = TextEditingController();
  String? _avatarFilePath;
  bool _showingAlert = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      unawaited(_showAlert(message));
      ref.read(authFlowControllerProvider.notifier).clearError();
    });

    return AuthPageScaffold(
      title: '完善个人资料',
      subtitle: '完成头像和昵称设置后，才可以进入首页。',
      statusBanner: AuthStatusBanner(
        key: const ValueKey<String>('auth-status-banner'),
        message: _hasAvatarSelection ? '头像已选择，请继续提交资料' : '请先选择头像并填写昵称',
        tone: _hasAvatarSelection
            ? AuthStatusBannerTone.success
            : AuthStatusBannerTone.info,
        leadingIcon: _hasAvatarSelection
            ? Icons.check_circle_outline_rounded
            : Icons.person_outline_rounded,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              key: const ValueKey('auth-profile-avatar'),
              onTap: authState.isLoading ? null : _pickAvatar,
              child: Column(
                children: [
                  _buildAvatarPreview(),
                  const SizedBox(height: 12),
                  Text(
                    _hasAvatarSelection ? '头像已选择，点击可重新选择' : '点击上传头像',
                    style: const TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 13,
                      color: WKColors.color999,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          AuthFormField(
            fieldKey: const ValueKey('auth-profile-name'),
            controller: _nameController,
            textInputAction: TextInputAction.done,
            enabled: !authState.isLoading,
            onSubmitted: authState.isLoading ? null : (_) => _handleSubmit(),
            hintText: '昵称',
          ),
        ],
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey('auth-profile-submit'),
        label: '确定',
        isLoading: authState.isLoading,
        onPressed: authState.isLoading ? null : _handleSubmit,
      ),
    );
  }

  bool get _hasAvatarSelection => (_avatarFilePath?.trim().isNotEmpty ?? false);

  Widget _buildAvatarPreview() {
    final filePath = _avatarFilePath?.trim() ?? '';
    final imageProvider = filePath.isEmpty
        ? null
        : resolveLocalMediaImageProvider(filePath);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: WKColors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: _hasAvatarSelection ? WKColors.brand500 : WKColors.colorCCC,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageProvider != null
          ? Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildAvatarPlaceholder(),
            )
          : _buildAvatarPlaceholder(),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _hasAvatarSelection
              ? Icons.check_circle_rounded
              : Icons.add_a_photo_outlined,
          size: 36,
          color: _hasAvatarSelection ? WKColors.brand500 : WKColors.color999,
        ),
        const SizedBox(height: 8),
        Text(
          _hasAvatarSelection ? '已选头像' : '上传头像',
          style: const TextStyle(
            fontFamily: WKFontFamily.primary,
            fontSize: 12,
            color: WKColors.color999,
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ref.read(authProfileAvatarPickerProvider);
    final filePath = await picker();
    if (!mounted) {
      return;
    }
    final normalizedPath = filePath?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return;
    }
    setState(() {
      _avatarFilePath = normalizedPath;
    });
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (!_hasAvatarSelection) {
      await _showAlert('请先上传头像。');
      return;
    }
    if (name.isEmpty) {
      await _showAlert('请输入昵称。');
      return;
    }

    await ref
        .read(authFlowControllerProvider.notifier)
        .completeProfile(name: name, avatarFilePath: _avatarFilePath);
  }

  Future<void> _showAlert(String message) async {
    if (!mounted || _showingAlert) {
      return;
    }
    _showingAlert = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    _showingAlert = false;
  }
}
