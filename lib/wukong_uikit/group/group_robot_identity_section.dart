import 'package:flutter/material.dart';

import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';

class GroupRobotIdentitySection extends StatelessWidget {
  final String providerName;
  final TextEditingController displayNameController;
  final String displayAvatar;
  final bool isBusy;
  final ValueChanged<String>? onDisplayNameChanged;
  final Future<void> Function()? onUploadAvatar;
  final VoidCallback? onClearAvatar;

  const GroupRobotIdentitySection({
    super.key,
    required this.providerName,
    required this.displayNameController,
    required this.displayAvatar,
    required this.isBusy,
    this.onDisplayNameChanged,
    this.onUploadAvatar,
    this.onClearAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAvatar = displayAvatar.trim();
    final resolvedName = displayNameController.text.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '机器人在 IM 群内展示',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '仅影响悟空 IM 群内显示，不会修改$providerName官方机器人资料。',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('group-robot-display-name-field'),
            controller: displayNameController,
            enabled: !isBusy,
            maxLength: 32,
            textInputAction: TextInputAction.done,
            onChanged: isBusy ? null : onDisplayNameChanged,
            decoration: const InputDecoration(
              labelText: '机器人显示名称（仅 IM 群内）',
              hintText: '留空则沿用官方机器人名称',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: WKColors.homeBg,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WKAvatar(
                url: resolvedAvatar,
                name: resolvedName.isEmpty ? '机器人' : resolvedName,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resolvedAvatar.isEmpty
                      ? '未设置展示头像，上传后仅用于悟空 IM 群内机器人展示。'
                      : '已设置 IM 展示头像，保存当前配置后生效。',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: WKColors.color999,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            key: const ValueKey('group-robot-avatar-action-row'),
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('group-robot-upload-avatar-button'),
                  onPressed: isBusy || onUploadAvatar == null
                      ? null
                      : () => onUploadAvatar!.call(),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('上传头像'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('group-robot-clear-avatar-button'),
                  onPressed: isBusy || onClearAvatar == null
                      ? null
                      : onClearAvatar,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空头像'),
                ),
              ),
            ],
          ),
          if (resolvedAvatar.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              resolvedAvatar,
              style: const TextStyle(fontSize: 12, color: WKColors.color999),
            ),
          ],
        ],
      ),
    );
  }
}
