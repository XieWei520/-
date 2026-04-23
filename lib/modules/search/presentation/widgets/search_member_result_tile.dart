import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/wukong_base/views/user_avatar.dart';

class SearchMemberResultTile extends StatelessWidget {
  const SearchMemberResultTile({
    super.key,
    required this.member,
    required this.hit,
    required this.onTap,
  });

  final SearchMemberHit member;
  final SearchMessageHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('search-member-result-${hit.messageSeq}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WKUserAvatar(
              key: ValueKey<String>('search-member-result-avatar-${member.uid}'),
              avatarUrl: member.avatarUrl,
              name: member.displayName,
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
                          member.displayName,
                          key: ValueKey<String>(
                            'search-member-result-name-${hit.messageSeq}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF999999),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTimestamp(hit.timestamp),
                        key: ValueKey<String>(
                          'search-member-result-time-${hit.messageSeq}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      'search-member-result-content-${hit.messageSeq}',
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
    );
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final isSameYear = dateTime.year == now.year;
    final isSameDay =
        isSameYear &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

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
