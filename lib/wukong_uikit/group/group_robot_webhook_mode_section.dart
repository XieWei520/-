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
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '接入方式',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
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
            child: Row(
              children: [
                Expanded(
                  child: _WebhookModeOption(
                    key: const ValueKey(
                      'group-robot-webhook-mode-im-generated',
                    ),
                    value: GroupRobotWebhookMode.imGenerated,
                    selected: mode == GroupRobotWebhookMode.imGenerated,
                    enabled: canEdit,
                    onTap: () =>
                        onModeChanged?.call(GroupRobotWebhookMode.imGenerated),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WebhookModeOption(
                    key: const ValueKey('group-robot-webhook-mode-official'),
                    value: GroupRobotWebhookMode.official,
                    selected: mode == GroupRobotWebhookMode.official,
                    enabled: canEdit,
                    onTap: () =>
                        onModeChanged?.call(GroupRobotWebhookMode.official),
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
                labelText: '官方 Webhook',
                hintText: 'https://',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: WKColors.homeBg,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('group-robot-official-secret-field'),
              controller: officialSecretController,
              enabled: !isBusy,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '加签密钥（可选）',
                border: OutlineInputBorder(),
                hintText: '启用签名时填写',
                filled: true,
                fillColor: WKColors.homeBg,
                isDense: true,
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

class _WebhookModeOption extends StatelessWidget {
  final GroupRobotWebhookMode value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _WebhookModeOption({
    super.key,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? WKColors.brand50 : WKColors.homeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? WKColors.brand500 : WKColors.colorLine,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Radio<GroupRobotWebhookMode>(
              value: value,
              enabled: enabled,
              visualDensity: VisualDensity.compact,
            ),
            Flexible(
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: enabled ? WKColors.colorDark : WKColors.color999,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
