import 'package:flutter/material.dart';
import 'package:wukong_im_app/widgets/wk_avatar.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_design_tokens.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../domain/search_models.dart';

class GlobalSearchMessageTile extends StatelessWidget {
  const GlobalSearchMessageTile({
    super.key,
    required this.hit,
    required this.onTap,
  });

  final SearchMessageHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = globalSearchMessageTitle(hit);
    final subtitle = hit.matchCount > 1
        ? '${hit.matchCount} related records'
        : hit.previewText;

    return Material(
      color: WKColors.surface,
      child: InkWell(
        key: ValueKey<String>(
          'global-search-message-${globalSearchMessageRowId(hit)}',
        ),
        onTap: onTap,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WKAvatar(
                name: title,
                size: 40,
                isGroup: hit.channelType == WKChannelType.group,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
                              color: WKColors.colorDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(hit.timestamp),
                          style: const TextStyle(
                            fontFamily: WKFontFamily.primary,
                            fontSize: 12,
                            color: WKColors.color999,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 13,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp <= 0) {
      return '';
    }
    final normalized = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    final time = DateTime.fromMillisecondsSinceEpoch(normalized);
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

String globalSearchMessageRowId(SearchMessageHit hit) {
  if (hit.messageSeq > 0) {
    return hit.messageSeq.toString();
  }
  if (hit.orderSeq > 0) {
    return hit.orderSeq.toString();
  }
  return '${hit.channelType}_${hit.channelId}_${hit.timestamp}';
}

String globalSearchMessageTitle(SearchMessageHit hit) {
  final channelName = hit.channelName?.trim() ?? '';
  if (channelName.isNotEmpty) {
    return channelName;
  }
  final sender = hit.fromName.trim();
  if (sender.isNotEmpty) {
    return sender;
  }
  return hit.channelId;
}
