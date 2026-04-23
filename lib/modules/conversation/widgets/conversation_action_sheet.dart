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
    final pinTitle = isPinned ? 'Unpin conversation' : 'Pin conversation';
    final pinSubtitle = isPinned
        ? 'Remove this conversation from the top of the list.'
        : 'Keep this conversation at the top of the list.';

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
              title: 'Mute notifications',
              subtitle: 'Hide alerts but keep messages in sync.',
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
              title: 'Delete conversation',
              titleColor: WKColors.danger,
              subtitle:
                  'Delete only local conversations and drafts. Server history is kept.',
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
