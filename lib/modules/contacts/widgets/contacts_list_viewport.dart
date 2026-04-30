import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/im_config.dart';
import '../../../data/models/friend.dart';
import '../../../modules/customer_service/customer_service_badge.dart';
import '../../../modules/customer_service/customer_service_identity.dart';
import '../../../modules/vip/vip_badge.dart';
import '../../../widgets/wk_avatar.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';
import '../../../widgets/wk_status_view.dart';
import '../contacts_strings.dart';
import '../contacts_directory_controller.dart';
import '../contacts_presence_controller.dart';

class ContactsListViewport extends StatelessWidget {
  const ContactsListViewport({
    super.key,
    required this.header,
    required this.directory,
    required this.contactPresenceByUid,
    required this.currentTimestampSeconds,
    required this.onTapEntry,
    required this.onLongPressEntry,
    this.scrollController,
  });

  final Widget header;
  final ContactsDirectoryData directory;
  final Map<String, ContactPresenceState> contactPresenceByUid;
  final int currentTimestampSeconds;
  final ValueChanged<ContactsDirectoryEntry> onTapEntry;
  final ValueChanged<ContactsDirectoryEntry> onLongPressEntry;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final strings = resolveContactsStrings(
      locale: Localizations.maybeLocaleOf(context),
    );
    final entries = _flattenEntries(directory.sections);

    return RepaintBoundary(
      key: const ValueKey('contacts-list-viewport-repaint'),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: entries.isEmpty ? 2 : entries.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return header;
          }
          if (entries.isEmpty) {
            return Column(
              children: [
                const SizedBox(height: 120),
                WKEmptyView(
                  icon: Icons.people_outline_rounded,
                  message: strings.contactsEmpty,
                  subMessage: strings.contactsEmptyHint,
                ),
              ],
            );
          }
          final rowIndex = index - 1;
          if (rowIndex >= entries.length) {
            return Container(
              color: WKColors.homeBg,
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              child: Text(
                strings.contactsCount(entries.length),
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 16,
                  color: WKColors.colorDark,
                ),
              ),
            );
          }
          final row = entries[rowIndex];
          return _ContactRow(
            entry: row.entry,
            presence: contactPresenceByUid[row.entry.friend.uid],
            currentTimestampSeconds: currentTimestampSeconds,
            showSection: row.showSection,
            onTap: () => onTapEntry(row.entry),
            onLongPress: () => onLongPressEntry(row.entry),
          );
        },
      ),
    );
  }

  List<_ContactListEntry> _flattenEntries(
    List<ContactsDirectorySection> sections,
  ) {
    final result = <_ContactListEntry>[];
    for (final section in sections) {
      for (var index = 0; index < section.entries.length; index++) {
        result.add(
          _ContactListEntry(
            entry: section.entries[index],
            showSection: index == 0,
          ),
        );
      }
    }
    return result;
  }
}

class _ContactListEntry {
  const _ContactListEntry({required this.entry, required this.showSection});

  final ContactsDirectoryEntry entry;
  final bool showSection;
}

class _ContactRow extends StatelessWidget {
  static const Color _onlineDotColor = Color(0xFF02F507);
  static const Color _recentOfflineBadgeBackground = Color(0xFFD4FCD5);

  const _ContactRow({
    required this.entry,
    required this.presence,
    required this.currentTimestampSeconds,
    required this.showSection,
    required this.onTap,
    required this.onLongPress,
  });

  final ContactsDirectoryEntry entry;
  final ContactPresenceState? presence;
  final int currentTimestampSeconds;
  final bool showSection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tags = _buildTags(entry.friend);
    final subtitle = _buildSubtitle();
    final recentOfflineBadgeText = _buildRecentOfflineBadgeText();
    final showOnlineDot = presence?.online ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSection)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
            child: Text(
              entry.sectionLetter,
              style: const TextStyle(
                fontFamily: WKFontFamily.title,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WKColors.brand500,
              ),
            ),
          ),
        Material(
          color: WKColors.surface,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            highlightColor: WKColors.screenBgSelected,
            splashColor: WKColors.screenBgSelected,
            child: Container(
              color: WKColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      WKAvatar(
                        url: entry.friend.avatar,
                        name: entry.sortKey,
                        size: 50,
                      ),
                      if (showOnlineDot)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            key: ValueKey(
                              'contacts-avatar-dot-${entry.friend.uid}',
                            ),
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: _onlineDotColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: WKColors.layoutColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      if (recentOfflineBadgeText != null)
                        Positioned(
                          right: -2,
                          bottom: -1,
                          child: Container(
                            key: ValueKey(
                              'contacts-avatar-badge-${entry.friend.uid}',
                            ),
                            constraints: const BoxConstraints(minHeight: 15),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _recentOfflineBadgeBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: WKColors.white,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              recentOfflineBadgeText,
                              style: const TextStyle(
                                fontFamily: WKFontFamily.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: _onlineDotColor,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNameAndBadges(tags),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 14,
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
        ),
      ],
    );
  }

  Widget _buildNameAndBadges(List<Widget> tags) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Text(
                entry.sortKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WKColors.colorDark,
                ),
              ),
            ),
            if (entry.friend.isVip)
              VipBadge(
                key: ValueKey<String>('contacts-vip-badge-${entry.friend.uid}'),
                compact: true,
              ),
            ...tags,
          ],
        );
      },
    );
  }

  List<Widget> _buildTags(Friend friend) {
    final tags = <Widget>[];
    final category = normalizePublicAccountCategory(friend.category) ?? '';
    if (friend.uid == 'u_10000' || category == 'system') {
      tags.add(
        const _ContactTag(
          label: '官方',
          textColor: WKColors.reminderColor,
          borderColor: WKColors.reminderColor,
        ),
      );
    } else if (isCustomerServiceCategory(category)) {
      tags.add(
        CustomerServiceBadge(
          key: ValueKey<String>(
            'contacts-customer-service-badge-${friend.uid}',
          ),
          compact: true,
        ),
      );
    } else if (category == 'visitor') {
      tags.add(
        const _ContactTag(
          label: '访客',
          textColor: WKColors.warning,
          borderColor: WKColors.warning,
        ),
      );
    }
    if ((friend.robot ?? 0) == 1) {
      tags.add(
        const _ContactTag(
          label: '机器人',
          backgroundColor: WKColors.warning,
          textColor: WKColors.white,
        ),
      );
    }
    return tags;
  }

  String? _buildSubtitle() {
    final currentPresence = presence;
    if (currentPresence == null) {
      return null;
    }
    if (currentPresence.online) {
      return '${_deviceLabel(currentPresence.deviceFlag)}在线';
    }
    if (currentPresence.lastOffline <= 0) {
      return null;
    }
    if (_recentOfflineText(currentPresence.lastOffline) != null) {
      return null;
    }
    return '上次在线时间 ${_formatLastSeenTime(currentPresence.lastOffline)}';
  }

  String? _buildRecentOfflineBadgeText() {
    final currentPresence = presence;
    if (currentPresence == null || currentPresence.online) {
      return null;
    }
    return _recentOfflineText(currentPresence.lastOffline);
  }

  String? _recentOfflineText(int lastOffline) {
    if (lastOffline <= 0) {
      return null;
    }

    final diffSeconds = currentTimestampSeconds - lastOffline;
    if (diffSeconds > 60) {
      final minutes = diffSeconds ~/ 60;
      if (minutes > 60) {
        return null;
      }
      return '$minutes分钟';
    }
    return '刚刚';
  }

  String _deviceLabel(int deviceFlag) {
    if (deviceFlag == IMConfig.deviceFlagWeb) {
      return 'Web';
    }
    if (deviceFlag == IMConfig.deviceFlagPC) {
      return 'PC';
    }
    return '手机';
  }

  String _formatLastSeenTime(int lastOffline) {
    final offlineDate = DateTime.fromMillisecondsSinceEpoch(lastOffline * 1000);
    final currentDate = DateTime.fromMillisecondsSinceEpoch(
      currentTimestampSeconds * 1000,
    );
    if (offlineDate.year != currentDate.year) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(offlineDate);
    }
    return DateFormat('MM-dd HH:mm').format(offlineDate);
  }
}

class _ContactTag extends StatelessWidget {
  const _ContactTag({
    required this.label,
    this.backgroundColor = Colors.transparent,
    required this.textColor,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.1,
        ),
      ),
    );
  }
}
