import 'package:flutter/material.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_design_tokens.dart';

import '../../domain/search_models.dart';

class GlobalSearchChannelTile extends StatelessWidget {
  const GlobalSearchChannelTile({
    super.key,
    required this.group,
    required this.onTap,
  });

  final SearchMessageHit group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _groupTitle(group);
    final subtitle = group.previewText.trim();
    final showSubtitle = subtitle.isNotEmpty && subtitle != title;

    return Material(
      color: WKColors.surface,
      child: InkWell(
        key: ValueKey<String>('global-search-group-${group.channelId}'),
        onTap: onTap,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              WKAvatar(name: title, size: 40, isGroup: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 14,
                        color: WKColors.colorDark,
                      ),
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 12,
                          color: WKColors.color999,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String globalSearchGroupTitle(SearchMessageHit group) => _groupTitle(group);

String _groupTitle(SearchMessageHit group) {
  final channelName = group.channelName?.trim() ?? '';
  if (channelName.isNotEmpty) {
    return channelName;
  }
  final fromName = group.fromName.trim();
  if (fromName.isNotEmpty) {
    return fromName;
  }
  return group.channelId;
}
