import 'package:flutter/material.dart';
import 'package:wukong_im_app/wukong_base/views/user_avatar.dart';

import '../../domain/search_models.dart';

class SearchMessageTile extends StatelessWidget {
  const SearchMessageTile({super.key, required this.hit, required this.onTap});

  final SearchMessageHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final senderName = hit.fromName.trim().isEmpty
        ? (hit.channelName?.trim().isNotEmpty == true
              ? hit.channelName!.trim()
              : hit.channelId)
        : hit.fromName.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('search-keyword-result-${hit.messageSeq}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WKUserAvatar(
                key: ValueKey<String>(
                  'search-keyword-result-avatar-${hit.messageSeq}',
                ),
                avatarUrl: null,
                name: senderName,
                size: 40,
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
                            senderName,
                            key: ValueKey<String>(
                              'search-keyword-result-name-${hit.messageSeq}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF999999),
                                  fontSize: 14,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTimestamp(hit.timestamp),
                          key: ValueKey<String>(
                            'search-keyword-result-time-${hit.messageSeq}',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF999999),
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hit.previewText,
                      key: ValueKey<String>(
                        'search-keyword-result-content-${hit.messageSeq}',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF313131),
                        fontSize: 14,
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
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final isSameYear = dateTime.year == now.year;
    final isSameDay =
        isSameYear && dateTime.month == now.month && dateTime.day == now.day;

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    if (isSameDay) {
      return '$hour:$minute';
    }

    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    if (isSameYear) {
      return '$month-$day $hour:$minute';
    }
    return '${dateTime.year}-$month-$day';
  }
}
