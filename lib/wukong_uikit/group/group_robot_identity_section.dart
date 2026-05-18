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
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '群内显示',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WKAvatar(
                url: resolvedAvatar,
                name: resolvedName.isEmpty ? '机器人' : resolvedName,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('group-robot-display-name-field'),
                  controller: displayNameController,
                  enabled: !isBusy,
                  maxLength: 32,
                  textInputAction: TextInputAction.done,
                  onChanged: isBusy ? null : onDisplayNameChanged,
                  decoration: const InputDecoration(
                    labelText: '显示名称',
                    hintText: '默认机器人名称',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: WKColors.homeBg,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: '上传头像',
                child: IconButton(
                  key: const ValueKey('group-robot-upload-avatar-button'),
                  onPressed: isBusy || onUploadAvatar == null
                      ? null
                      : () => onUploadAvatar!.call(),
                  icon: const Icon(Icons.file_upload_outlined),
                ),
              ),
              Tooltip(
                message: '清空头像',
                child: IconButton(
                  key: const ValueKey('group-robot-clear-avatar-button'),
                  onPressed: isBusy || onClearAvatar == null
                      ? null
                      : onClearAvatar,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '仅影响悟空 IM 群内显示，不会修改$providerName官方机器人资料。',
            style: const TextStyle(fontSize: 12, color: WKColors.color999),
          ),
        ],
      ),
    );
  }
}
