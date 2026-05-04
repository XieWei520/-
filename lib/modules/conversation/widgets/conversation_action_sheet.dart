import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';

class ConversationActionSheet extends StatelessWidget {
  const ConversationActionSheet({
    super.key,
    required this.isPinned,
    required this.onPinChanged,
    required this.onMute,
    required this.onDelete,
  });

  final bool isPinned;
  final ValueChanged<bool> onPinChanged;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pinTitle = isPinned ? '取消置顶' : '置顶会话';
    final pinSubtitle = isPinned ? '将此会话从列表顶部移除。' : '将此会话固定在列表顶部。';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConversationActionTile(
              tileKey: const ValueKey<String>('conversation-pin'),
              icon: Icons.push_pin_outlined,
              title: pinTitle,
              subtitle: pinSubtitle,
              onTap: () {
                Navigator.of(context).pop();
                onPinChanged(!isPinned);
              },
            ),
            const SizedBox(height: WKSpace.xs),
            _ConversationActionTile(
              tileKey: const ValueKey<String>('conversation-mute'),
              icon: Icons.notifications_off_outlined,
              title: '消息免打扰',
              subtitle: '隐藏提醒，但继续同步消息。',
              onTap: () {
                Navigator.of(context).pop();
                onMute();
              },
            ),
            const SizedBox(height: WKSpace.xs),
            _ConversationActionTile(
              tileKey: const ValueKey<String>('conversation-delete'),
              icon: Icons.delete_outline_rounded,
              iconColor: WKColors.danger,
              title: '删除会话',
              titleColor: WKColors.danger,
              subtitle: '只删除本地会话和草稿，服务器历史消息仍会保留。',
              onTap: () {
                Navigator.of(context).pop();
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationActionTile extends StatelessWidget {
  const _ConversationActionTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(WKRadius.lg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: WKColors.surfaceSoft,
            borderRadius: BorderRadius.circular(WKRadius.lg),
            border: Border.all(color: WKColors.outline),
          ),
          child: ListTile(
            key: tileKey,
            leading: Icon(icon, color: iconColor ?? WKColors.textSecondary),
            title: Text(
              title,
              style: textTheme.titleSmall?.copyWith(color: titleColor),
            ),
            subtitle: Text(subtitle),
          ),
        ),
      ),
    );
  }
}
