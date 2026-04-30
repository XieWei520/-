import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import 'group_robot_webhook_mode.dart';

class GroupRobotWebhookModeSection extends StatelessWidget {
  final String providerName;
  final GroupRobotWebhookMode mode;
  final ValueChanged<GroupRobotWebhookMode>? onModeChanged;
  final TextEditingController officialWebhookController;
  final TextEditingController officialSecretController;
  final bool isBusy;
  final String officialModeWarning;

  const GroupRobotWebhookModeSection({
    super.key,
    required this.providerName,
    required this.mode,
    required this.onModeChanged,
    required this.officialWebhookController,
    required this.officialSecretController,
    required this.isBusy,
    this.officialModeWarning = '当前版本说明：官方 Webhook 消息不会回流同步到 IM 群聊。',
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = !isBusy && onModeChanged != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '回调模式',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '可在群聊内接收回调与官方回调之间切换，按需选择接入方式。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: WKColors.color999,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<GroupRobotWebhookMode>(
            groupValue: mode,
            onChanged: (value) {
              if (!canEdit || value == null) {
                return;
              }
              onModeChanged?.call(value);
            },
            child: Column(
              children: [
                RadioListTile<GroupRobotWebhookMode>(
                  key: const ValueKey('group-robot-webhook-mode-im-generated'),
                  value: GroupRobotWebhookMode.imGenerated,
                  dense: true,
                  enabled: canEdit,
                  contentPadding: EdgeInsets.zero,
                  title: Text(GroupRobotWebhookMode.imGenerated.label),
                  subtitle: const Text(
                    '使用当前页面生成的回调地址与加签密钥接收消息',
                  ),
                ),
                RadioListTile<GroupRobotWebhookMode>(
                  key: const ValueKey('group-robot-webhook-mode-official'),
                  value: GroupRobotWebhookMode.official,
                  dense: true,
                  enabled: canEdit,
                  contentPadding: EdgeInsets.zero,
                  title: Text(GroupRobotWebhookMode.official.label),
                  subtitle: Text(
                    '手动填写$providerName官方回调地址与密钥进行接入',
                  ),
                ),
              ],
            ),
          ),
          if (mode == GroupRobotWebhookMode.official) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('group-robot-official-webhook-field'),
              controller: officialWebhookController,
              enabled: !isBusy,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '官方回调地址',
                hintText: 'https://',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: WKColors.homeBg,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('group-robot-official-secret-field'),
              controller: officialSecretController,
              enabled: !isBusy,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '官方密钥（可选）',
                border: OutlineInputBorder(),
                hintText: '如果官方机器人启用了签名，请填写对应加签密钥',
                filled: true,
                fillColor: WKColors.homeBg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              officialModeWarning,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: WKColors.color999,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
