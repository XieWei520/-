import 'package:flutter/material.dart';

import '../modules/customer_service/customer_service_badge.dart';
import '../modules/customer_service/customer_service_identity.dart';
import '../modules/vip/vip_badge.dart';
import 'wk_avatar.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_emoji_text.dart';
import 'wk_reference_assets.dart';
import 'wk_web_ui_tokens.dart';

class WKConversationItemData {
  final String channelId;
  final int channelType;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String? lastMsgContent;
  final String? typingLabel;
  final DateTime? lastMsgTime;
  final int unreadCount;
  final bool isMentionMe;
  final String? reminderLabel;
  final bool showTypingIndicator;
  final bool isGroup;
  final bool isMuted;
  final bool isDraft;
  final bool isTop;
  final bool isForbidden;
  final bool isRobot;
  final bool isCalling;
  final String? category;
  final bool showSingleTick;
  final bool showDoubleTick;
  final bool showSending;
  final bool showSendFailed;
  final int vipLevel;
  final bool personalInfoKnown;

  const WKConversationItemData({
    required this.channelId,
    required this.channelType,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.lastMsgContent,
    this.typingLabel,
    this.lastMsgTime,
    this.unreadCount = 0,
    this.isMentionMe = false,
    this.reminderLabel,
    this.showTypingIndicator = false,
    this.isGroup = false,
    this.isMuted = false,
    this.isDraft = false,
    this.isTop = false,
    this.isForbidden = false,
    this.isRobot = false,
    this.isCalling = false,
    this.category,
    this.showSingleTick = false,
    this.showDoubleTick = false,
    this.showSending = false,
    this.showSendFailed = false,
    this.vipLevel = 0,
    this.personalInfoKnown = false,
  });
}

class WKConversationItem extends StatelessWidget {
  final WKConversationItemData data;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool webStyle;

  const WKConversationItem({
    super.key,
    required this.data,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.webStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = const TextStyle(
      fontFamily: WKFontFamily.primary,
      color: WKColors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    final baseSubtitle = data.lastMsgContent?.trim().isNotEmpty == true
        ? data.lastMsgContent!.trim()
        : (data.subtitle?.trim().isNotEmpty == true
              ? data.subtitle!.trim()
              : '暂无消息');
    final displaySubtitle = data.showTypingIndicator
        ? ((data.typingLabel?.trim().isNotEmpty ?? false)
              ? data.typingLabel!.trim()
              : baseSubtitle)
        : baseSubtitle;
    final reminderLabels = _parseReminderLabels();
    final hasReminder = reminderLabels.isNotEmpty;
    final rowBackground = data.isTop ? WKColors.homeBg : WKColors.surface;
    final unreadBackground = data.isMuted
        ? WKColors.textSecondary
        : WKColors.reminderColor;
    final tags = _buildTags();
    const subtitleStyle = TextStyle(
      fontFamily: WKFontFamily.primary,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: WKColors.textSecondary,
    );

    final effectiveRowBackground = webStyle
        ? (selected ? WKWebColors.actionSoft : WKWebColors.surface)
        : rowBackground;
    final effectivePadding = webStyle
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 15, vertical: 5);
    final rowBorderRadius = BorderRadius.circular(
      webStyle ? WKWebRadius.control : 0,
    );
    final hitbox = Container(
      key: const ValueKey<String>('wk-conversation-item-hitbox'),
      height: webStyle ? WKWebSizes.conversationRowHeight : null,
      padding: effectivePadding,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: WKAvatar(
                url: data.avatarUrl,
                name: data.title,
                size: 50,
                isGroup: data.isGroup,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (data.isGroup) ...[
                            WKReferenceAssets.image(
                              WKReferenceAssets.groupTag,
                              width: 14,
                              height: 14,
                              tint: WKColors.colorDark,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: WKFontFamily.title,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: WKColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!data.isGroup && data.vipLevel == 1) ...[
                            const SizedBox(width: 6),
                            VipBadge(
                              key: ValueKey<String>(
                                'conversation-vip-badge-${data.channelId}',
                              ),
                              compact: true,
                            ),
                          ],
                          for (final tag in tags) ...[
                            const SizedBox(width: 4),
                            tag,
                          ],
                        ],
                      ),
                    ),
                    if (data.showSingleTick ||
                        data.showDoubleTick ||
                        data.showSending ||
                        data.showSendFailed) ...[
                      const SizedBox(width: 5),
                      _buildSendStatus(),
                    ],
                    if (data.lastMsgTime != null)
                      Text(
                        _formatTime(data.lastMsgTime!),
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 13,
                          color: WKColors.color999,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (hasReminder)
                            for (final reminderLabel in reminderLabels)
                              Flexible(
                                fit: FlexFit.loose,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Text(
                                    reminderLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: WKFontFamily.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: WKColors.brand500,
                                    ),
                                  ),
                                ),
                              ),
                          if (data.showTypingIndicator) ...[
                            const WKConversationTypingDots(),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: _buildSubtitlePreview(
                              displaySubtitle,
                              subtitleStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data.isCalling) ...[
                      const SizedBox(width: 10),
                      WKReferenceAssets.image(
                        WKReferenceAssets.calling,
                        width: 20,
                        height: 20,
                        tint: WKColors.brand500,
                      ),
                    ],
                    if (data.isForbidden) ...[
                      const SizedBox(width: 10),
                      WKReferenceAssets.image(
                        WKReferenceAssets.forbidden,
                        width: 15,
                        height: 15,
                      ),
                    ],
                    if (data.unreadCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: unreadBackground,
                          borderRadius: BorderRadius.circular(WKRadius.pill),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          data.unreadCount > 99
                              ? '99+'
                              : data.unreadCount.toString(),
                          style: labelStyle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        key: webStyle
            ? const ValueKey<String>('wk-conversation-item-web-shell')
            : null,
        duration: const Duration(milliseconds: 160),
        margin: webStyle
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: effectiveRowBackground,
          borderRadius: rowBorderRadius,
          border: webStyle
              ? Border.all(
                  color: selected ? WKWebColors.action : Colors.transparent,
                )
              : null,
        ),
        child: webStyle
            ? Material(
                type: MaterialType.transparency,
                borderRadius: rowBorderRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  borderRadius: rowBorderRadius,
                  highlightColor: WKWebColors.actionSoft.withValues(alpha: 0.6),
                  splashColor: WKWebColors.actionSoft.withValues(alpha: 0.4),
                  child: hitbox,
                ),
              )
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                borderRadius: rowBorderRadius,
                highlightColor: WKColors.screenBgSelected,
                splashColor: WKColors.screenBgSelected,
                child: hitbox,
              ),
      ),
    );
  }

  Widget _buildSubtitlePreview(String text, TextStyle style) {
    if (WKEmojiText.containsAndroidEmoji(text)) {
      return WKEmojiText(
        text: text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }

  List<String> _parseReminderLabels() {
    final rawLabel = data.reminderLabel?.trim() ?? '';
    final labels = rawLabel.isEmpty
        ? <String>[]
        : rawLabel
              .split(RegExp(r'\s+'))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
    if (labels.isEmpty && data.isDraft) {
      labels.add('[草稿]');
    }
    return labels;
  }

  List<Widget> _buildTags() {
    final tags = <Widget>[];
    if (data.isMuted) {
      tags.add(
        WKReferenceAssets.image(
          WKReferenceAssets.listMute,
          width: 15,
          height: 15,
          tint: WKColors.popupText,
        ),
      );
    }

    final category = normalizePublicAccountCategory(data.category) ?? '';
    if (category == 'system') {
      tags.add(
        _ConversationTag(
          label: '官方',
          textColor: WKColors.reminderColor,
          borderColor: WKColors.reminderColor,
        ),
      );
    } else if (isCustomerServiceCategory(category)) {
      tags.add(
        CustomerServiceBadge(
          key: ValueKey<String>(
            'conversation-customer-service-badge-${data.channelId}',
          ),
          compact: true,
        ),
      );
    } else if (category == 'visitor') {
      tags.add(
        const _ConversationTag(
          label: '访客',
          textColor: WKColors.warning,
          borderColor: WKColors.warning,
        ),
      );
    } else if (category == 'organization') {
      tags.add(
        const _ConversationTag(
          label: '全员',
          backgroundColor: Color(0xFFD0DDFD),
          textColor: Color(0xFF1856E7),
        ),
      );
    } else if (category == 'department') {
      tags.add(
        const _ConversationTag(
          label: '部门',
          backgroundColor: Color(0xFFD0DDFD),
          textColor: Color(0xFF1856E7),
        ),
      );
    } else if (category == 'community') {
      tags.add(
        const _ConversationTag(
          label: '社区',
          backgroundColor: Color(0xFFD0BCF3),
          textColor: Color(0xFF7E51CC),
        ),
      );
    }

    if (data.isRobot) {
      tags.add(
        const _ConversationTag(
          label: '机器人',
          backgroundColor: WKColors.warning,
          textColor: WKColors.white,
        ),
      );
    }
    return tags;
  }

  Widget _buildSendStatus() {
    if (data.showSendFailed) {
      return WKReferenceAssets.image(
        WKReferenceAssets.sendFail,
        width: 22,
        height: 22,
      );
    }
    if (data.showSending) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: WKColors.color999,
        ),
      );
    }
    if (data.showDoubleTick) {
      return WKReferenceAssets.image(
        WKReferenceAssets.sendDouble,
        width: 22,
        height: 22,
        tint: WKColors.brand500,
      );
    }
    return WKReferenceAssets.image(
      WKReferenceAssets.sendSingle,
      width: 22,
      height: 22,
      tint: WKColors.brand500,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    if (difference.inDays == 1) {
      return '昨天';
    }

    if (difference.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }

    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}

class WKConversationTypingDots extends StatefulWidget {
  const WKConversationTypingDots({super.key});

  @override
  State<WKConversationTypingDots> createState() =>
      _WKConversationTypingDotsState();
}

class _WKConversationTypingDotsState extends State<WKConversationTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey<String>('conversation_typing_dots'),
      width: 30,
      height: 15,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final phase = (_controller.value + (index * 0.18)) % 1.0;
              final opacity = 0.35 + ((1.0 - (phase - 0.5).abs() * 2) * 0.65);
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: WKColors.color999.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ConversationTag extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _ConversationTag({
    required this.label,
    this.backgroundColor = Colors.transparent,
    required this.textColor,
    this.borderColor,
  });

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
