import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_gif_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../core/cache/media_cache_manager.dart';
import '../core/config/api_config.dart';
import '../core/utils/avatar_utils.dart';
import '../data/models/link_preview.dart';
import '../data/models/wk_custom_content.dart';
import '../modules/chat/chat_message_view_model.dart';
import '../modules/chat/link_preview_service.dart';
import '../modules/chat/message_content_preview.dart';
import '../modules/chat/robot_card_message.dart';
import '../modules/chat/robot_message_identity.dart';
import '../wukong_base/msg/msg_content_type.dart';
import '../wukong_base/msg/widget/wk_message_reaction.dart' as reaction_widget;
import '../wukong_base/utils/time_utils.dart';
import 'local_media_image_provider.dart';
import 'robot_message_card.dart';
import 'wk_avatar.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_emoji_text.dart';
import 'wk_reference_assets.dart';
import 'wk_web_ui_tokens.dart';

class MessageParticipantInfo {
  final String displayName;
  final String? avatarUrl;

  const MessageParticipantInfo({
    required this.displayName,
    required this.avatarUrl,
  });
}

class MessageStatusInfo {
  final String label;
  final IconData? icon;
  final String? assetIcon;
  final Color foregroundColor;
  final bool isLoading;

  const MessageStatusInfo({
    required this.label,
    this.icon,
    this.assetIcon,
    required this.foregroundColor,
    this.isLoading = false,
  });
}

MessageParticipantInfo resolveMessageParticipantInfo(
  WKMsg message, {
  WKChannelMember? fallbackGroupMember,
  WKChannel? fallbackSenderChannel,
  Map<String, dynamic>? structuredPayload,
  String? currentUid,
  String? currentUserDisplayName,
  String? currentUserAvatarUrl,
}) {
  final member = _senderGroupMember(message, message.getMemberOfFrom());
  final fallbackMember = _senderGroupMember(message, fallbackGroupMember);
  final fallbackChannel = _senderChannel(message, fallbackSenderChannel);
  final from = _senderChannel(message, message.getFrom());
  final channelInfo = _senderChannel(message, message.getChannelInfo());
  final senderUid = message.fromUID.trim();
  final normalizedCurrentUid = currentUid?.trim() ?? '';
  final robotIdentity = message.channelType == WKChannelType.group
      ? resolveRobotMessageIdentityFromMessage(
          message,
          structuredPayload: structuredPayload,
        )
      : null;
  final isCurrentUserSender =
      normalizedCurrentUid.isNotEmpty && senderUid == normalizedCurrentUid;

  final displayName = _firstNonEmpty([
    if (isCurrentUserSender) currentUserDisplayName,
    robotIdentity?.displayName,
    _resolveGroupMemberName(fallbackMember),
    _resolveGroupMemberName(member),
    _resolveChannelName(fallbackChannel),
    _resolveChannelName(from),
    _resolveChannelName(channelInfo),
    senderUid,
    message.channelID.trim(),
    '未知用户',
  ]);

  final avatarUrl = _resolveParticipantAvatarUrl(
    _firstNonEmpty([
      if (isCurrentUserSender) currentUserAvatarUrl,
      robotIdentity?.displayAvatar,
      _resolveGroupMemberAvatar(fallbackMember),
      _resolveGroupMemberAvatar(member),
      fallbackChannel?.avatar.trim(),
      from?.avatar.trim(),
      channelInfo?.avatar.trim(),
    ]),
    senderUid,
  );

  return MessageParticipantInfo(displayName: displayName, avatarUrl: avatarUrl);
}

MessageStatusInfo? resolveMessageStatusInfo(
  WKMsg message, {
  required bool isSelf,
}) {
  if (!isSelf) {
    return null;
  }

  final hasServerIdentity =
      message.messageID.trim().isNotEmpty || message.messageSeq > 0;

  switch (message.status) {
    // Synced messages already acknowledged by the server should not keep the
    // local loading spinner just because a test fixture left status at 0.
    case WKSendMsgResult.sendLoading:
      if (hasServerIdentity) {
        break;
      }
      return const MessageStatusInfo(
        label: '发送中',
        icon: Icons.schedule_rounded,
        foregroundColor: Color(0xFF7A8799),
        isLoading: true,
      );
    case WKSendMsgResult.sendSuccess:
      break;
    default:
      return const MessageStatusInfo(
        label: '发送失败',
        icon: Icons.error_outline_rounded,
        foregroundColor: Color(0xFFD64545),
      );
  }

  final extra = message.wkMsgExtra;
  if (message.channelType == WKChannelType.group && extra != null) {
    final readedCount = extra.readedCount;
    final unreadCount = extra.unreadCount;
    if (readedCount > 0 || unreadCount > 0) {
      final label = unreadCount > 0
          ? '$readedCount已读 · $unreadCount未读'
          : '$readedCount已读';
      return const MessageStatusInfo(
        label: '',
        icon: Icons.groups_rounded,
        foregroundColor: Color(0xFF2F6FED),
      ).copyWith(label: label);
    }
  }

  final isRead =
      (extra?.readed ?? 0) == 1 ||
      (extra?.readedCount ?? 0) > 0 ||
      message.viewed == 1 ||
      message.viewedAt > 0;
  if (isRead) {
    return const MessageStatusInfo(
      label: '已读',
      icon: Icons.done_all_rounded,
      foregroundColor: Color(0xFF0F9D84),
    );
  }

  if (extra != null) {
    return const MessageStatusInfo(
      label: '未读',
      icon: Icons.done_rounded,
      foregroundColor: Color(0xFF677487),
    );
  }

  return const MessageStatusInfo(
    label: '已发送',
    icon: Icons.check_rounded,
    foregroundColor: Color(0xFF677487),
  );
}

typedef MessageVoiceContentBuilder =
    Widget Function(
      BuildContext context,
      ChatMessageViewModel model,
      bool isSelf,
    );

const Color _warmWebBubbleMetaColor = Color(0xFF475569);

class MessageBubble extends StatelessWidget {
  final ChatMessageViewModel model;
  final MessageParticipantInfo? participant;
  final MessageStatusInfo? statusInfo;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final VoidCallback? onRetrySend;
  final List<reaction_widget.WKMessageReaction> reactions;
  final VoidCallback? onAddReaction;
  final void Function(String emoji)? onReactionTap;
  final MessageVoiceContentBuilder? voiceContentBuilder;
  final bool webStyle;

  const MessageBubble({
    super.key,
    required this.model,
    this.participant,
    this.statusInfo,
    this.onLongPress,
    this.onTap,
    this.onSecondaryTapDown,
    this.onRetrySend,
    this.reactions = const [],
    this.onAddReaction,
    this.onReactionTap,
    this.voiceContentBuilder,
    this.webStyle = false,
  });

  WKMsg get message => model.message;

  bool get isSelf => model.isSelf;

  @override
  Widget build(BuildContext context) {
    // P1-T10: Sensitive word messages render as a special self-only notice
    if (message.contentType == MsgContentType.sensitiveWord) {
      return _buildSensitiveWordNotice();
    }

    if ((message.wkMsgExtra?.revoke ?? 0) == 1) {
      return _buildSystemNotice(_resolveRevokedNoticeText());
    }

    if (model.isSystemNotice) {
      return _buildSystemNotice(model.previewText);
    }

    final effectiveContentType = _resolveEffectiveContentType();
    final resolvedParticipant =
        participant ??
        resolveMessageParticipantInfo(
          message,
          structuredPayload: model.structuredPayload,
        );
    final resolvedStatusInfo =
        statusInfo ?? resolveMessageStatusInfo(message, isSelf: isSelf);
    final timeText = message.timestamp > 0
        ? WKTimeUtils.formatTimeOnly(message.timestamp)
        : '';
    final showPinnedIndicator = (message.wkMsgExtra?.isPinned ?? 0) == 1;
    final showInlineMeta =
        effectiveContentType != WkMessageContentType.card &&
        effectiveContentType != MsgContentType.robotCard &&
        (resolvedStatusInfo != null || timeText.isNotEmpty);
    final showGroupSenderName =
        !isSelf &&
        message.channelType == WKChannelType.group &&
        resolvedParticipant.displayName.trim().isNotEmpty;
    final bubblePadding = _bubblePaddingFor(effectiveContentType);
    final bubbleDecoration = _bubbleDecoration(effectiveContentType);
    final useWarmTextColors =
        webStyle && isSelf && _isTextLikeContent(effectiveContentType);
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bubble = GestureDetector(
          onTap: effectiveContentType == MsgContentType.robotCard
              ? null
              : onTap,
          onLongPress: onLongPress,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Container(
            key: const ValueKey<String>('message-bubble-body'),
            constraints: BoxConstraints(
              maxWidth: _resolveBubbleMaxWidth(
                laneWidth: laneWidth,
                effectiveContentType: effectiveContentType,
              ),
            ),
            padding: bubblePadding,
            decoration: bubbleDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPinnedIndicator) ...[
                  _PinnedMessageIndicator(
                    isSelf: isSelf,
                    useWarmTextColors: useWarmTextColors,
                  ),
                  const SizedBox(height: 6),
                ],
                _buildContent(
                  context: context,
                  previewText: model.previewText,
                  effectiveContentType: effectiveContentType,
                  useWarmTextColors: useWarmTextColors,
                ),
                if (showInlineMeta) ...[
                  const SizedBox(height: 10),
                  _CompactMessageStatusBadge(
                    status: resolvedStatusInfo,
                    isSelf: isSelf,
                    timeText: timeText,
                    insideBubble: true,
                    useWarmTextColors: useWarmTextColors,
                    onRetrySend: onRetrySend,
                  ),
                ],
              ],
            ),
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: isSelf
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isSelf) ...[
                WKAvatar(
                  url: resolvedParticipant.avatarUrl,
                  name: resolvedParticipant.displayName,
                  size: 40,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isSelf
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showGroupSenderName) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 4),
                        child: Text(
                          resolvedParticipant.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: WKColors.getNameColorFromString(
                              resolvedParticipant.displayName,
                            ),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                    bubble,
                  ],
                ),
              ),
              if (isSelf) ...[
                const SizedBox(width: 8),
                WKAvatar(
                  url: resolvedParticipant.avatarUrl,
                  name: resolvedParticipant.displayName,
                  size: 40,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _resolveBubbleMaxWidth({
    required double laneWidth,
    required int effectiveContentType,
  }) {
    final avatarAndGapWidth = 48.0;
    final horizontalOuterPadding = 24.0;
    final availableWidth = math.max(
      0,
      laneWidth - avatarAndGapWidth - horizontalOuterPadding,
    );
    if (availableWidth <= 0) {
      return 0;
    }

    final upperBound = effectiveContentType == MsgContentType.robotCard
        ? math.min(availableWidth, WKWebSizes.messageBubbleRobotMaxWidth)
        : math.min(
            availableWidth,
            webStyle ? WKWebSizes.messageBubbleMaxWidth : availableWidth,
          );
    final desiredWidth = effectiveContentType == MsgContentType.robotCard
        ? upperBound
        : availableWidth * WKWebSizes.messageBubbleWidthRatio;
    final lowerBound = math.min(WKWebSizes.messageBubbleMinWidth, upperBound);
    return desiredWidth.clamp(lowerBound, upperBound).toDouble();
  }

  Size _resolveAdaptiveMediaSize(
    BoxConstraints constraints, {
    required double preferredWidth,
    required double preferredHeight,
  }) {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : preferredWidth;
    final width = math.min(preferredWidth, math.max(0.0, maxWidth));
    if (width <= 0 || preferredWidth <= 0) {
      return Size.zero;
    }
    return Size(width, preferredHeight * (width / preferredWidth));
  }

  EdgeInsets _bubblePaddingFor(int effectiveContentType) {
    if (effectiveContentType == MsgContentType.robotCard) {
      return EdgeInsets.zero;
    }
    if (effectiveContentType == WkMessageContentType.image ||
        effectiveContentType == WkMessageContentType.gif ||
        effectiveContentType == WkMessageContentType.video ||
        effectiveContentType == WkMessageContentType.sticker) {
      return const EdgeInsets.all(10);
    }
    return const EdgeInsets.fromLTRB(14, 10, 14, 9);
  }

  bool _isTextLikeContent(int contentType) {
    return contentType == WkMessageContentType.text ||
        contentType == WkMessageContentType.unknown ||
        contentType == MsgContentType.robotCard;
  }

  BoxDecoration _bubbleDecoration(int effectiveContentType) {
    if (effectiveContentType == MsgContentType.robotCard) {
      return const BoxDecoration(color: Colors.transparent);
    }

    if (webStyle && _isTextLikeContent(effectiveContentType)) {
      return BoxDecoration(
        color: isSelf ? WKWebColors.actionSoft : WKWebColors.surface,
        borderRadius: BorderRadius.circular(WKWebRadius.control),
        border: Border.all(
          color: isSelf ? WKWebColors.borderWarm : const Color(0xFFFFEDD5),
        ),
      );
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isSelf ? 22 : 8),
      bottomRight: Radius.circular(isSelf ? 8 : 22),
    );

    if (isSelf) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF4B8CFF), Color(0xFF1F67E8)],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0x33235DDC)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A1F67E8),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: const Color(0xFFFCFCFE),
      borderRadius: borderRadius,
      border: Border.all(color: const Color(0xFFE4E9F1)),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required String previewText,
    int? effectiveContentType,
    bool useWarmTextColors = false,
  }) {
    final reply = message.messageContent?.reply;
    final resolvedContentType =
        effectiveContentType ?? _resolveEffectiveContentType();
    Widget content = switch (resolvedContentType) {
      MsgContentType.robotCard => _buildRobotCardContent(),
      WkMessageContentType.text => _buildTextContent(
        previewText,
        useWarmTextColors: useWarmTextColors,
      ),
      WkMessageContentType.image => _buildImageContent(context),
      WkMessageContentType.gif => _buildGifContent(context),
      WkMessageContentType.sticker => _buildStickerContent(context),
      WkMessageContentType.voice =>
        voiceContentBuilder?.call(context, model, isSelf) ??
            _buildVoiceContent(),
      WkMessageContentType.video => _buildVideoContent(context),
      WkMessageContentType.location => _buildLocationContent(),
      WkMessageContentType.file => _buildFileContent(),
      WkMessageContentType.card => _buildInteractiveCardContent(),
      MsgContentType.richText => _buildRichTextContent(context),
      _ => _buildTextContent(previewText, useWarmTextColors: useWarmTextColors),
    };

    if (reply != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyPreview(reply, useWarmTextColors: useWarmTextColors),
          const SizedBox(height: 8),
          content,
        ],
      );
    }

    if (reactions.isEmpty) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        reaction_widget.WKMessageReactions(
          reactions: reactions,
          onReactionTap: onReactionTap,
        ),
      ],
    );
  }

  int _resolveEffectiveContentType() {
    if (message.contentType != WkMessageContentType.unknown) {
      return message.contentType;
    }
    final payload = model.structuredPayload;
    final rawType = payload?['type'];
    if (rawType is num) {
      return rawType.toInt();
    }
    if (rawType is String) {
      return int.tryParse(rawType) ?? message.contentType;
    }
    return message.contentType;
  }

  String _readStructuredString(
    Map<String, dynamic>? payload,
    List<String> keys,
  ) {
    if (payload == null) {
      return '';
    }
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  int _readStructuredInt(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) {
      return 0;
    }
    for (final key in keys) {
      final value = payload[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  Widget _buildSystemNotice(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: WKColors.surfaceSoft,
            borderRadius: BorderRadius.circular(WKRadius.pill),
            border: Border.all(color: WKColors.outline),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: WKColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  /// P1-T10: Sensitive word message — shown only to sender with warning style.
  String _resolveRevokedNoticeText() {
    if (isSelf) {
      return '你撤回了一条消息';
    }
    final displayName = resolveMessageParticipantInfo(
      message,
      structuredPayload: model.structuredPayload,
    ).displayName.trim();
    if (displayName.isEmpty || displayName == message.fromUID.trim()) {
      return '对方撤回了一条消息';
    }
    return '$displayName撤回了一条消息';
  }

  Widget _buildSensitiveWordNotice() {
    final noticeText = _resolveSensitiveWordNoticeText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(WKRadius.pill),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  noticeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveSensitiveWordNoticeText() {
    try {
      final raw = message.content.trim();
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final resolved = (decoded['content'] ?? '').toString().trim();
          if (resolved.isNotEmpty) {
            return resolved;
          }
        }
      }
    } catch (_) {
      // Fall back to the built-in warning copy when payload parsing fails.
    }
    return '消息包含敏感词，仅自己可见';
  }

  Widget _buildReplyPreview(WKReply reply, {bool useWarmTextColors = false}) {
    final author = (reply.fromName).trim().isNotEmpty
        ? reply.fromName.trim()
        : (reply.fromUID).trim().isNotEmpty
        ? reply.fromUID.trim()
        : '未知用户';
    final summary = summarizeReply(reply);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: useWarmTextColors
            ? WKWebColors.surfaceSoft
            : isSelf
            ? WKColors.white.withValues(alpha: 0.18)
            : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(WKRadius.sm),
        border: Border.all(
          color: useWarmTextColors
              ? WKWebColors.borderWarm
              : isSelf
              ? WKColors.white.withValues(alpha: 0.2)
              : const Color(0xFFE0E6EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: useWarmTextColors
                  ? WKWebColors.textPrimary
                  : isSelf
                  ? WKColors.sendText
                  : const Color(0xFF3567C8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          _buildEmojiAwareText(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: useWarmTextColors
                  ? _warmWebBubbleMetaColor
                  : isSelf
                  ? WKColors.white.withValues(alpha: 0.78)
                  : const Color(0xFF707A8D),
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiAwareText(
    String text, {
    required TextStyle style,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (WKEmojiText.containsAndroidEmoji(text)) {
      return WKEmojiText(
        text: text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return Text(text, maxLines: maxLines, overflow: overflow, style: style);
  }

  Widget _buildTextContent(String text, {bool useWarmTextColors = false}) {
    final textStyle = TextStyle(
      color: useWarmTextColors
          ? WKWebColors.textPrimary
          : isSelf
          ? WKColors.sendText
          : WKColors.receiveText,
      fontSize: 16.5,
      height: 1.45,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    );
    final previewUrl = LinkPreviewService.extractFirstUrl(text);
    final textWidget = WKEmojiText.containsAndroidEmoji(text)
        ? SelectionArea(
            child: WKEmojiText(text: text, style: textStyle),
          )
        : SelectableText(text, style: textStyle);
    if (previewUrl == null) {
      return textWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textWidget,
        const SizedBox(height: 8),
        _LinkPreviewCard(url: previewUrl, isSelf: isSelf),
      ],
    );
  }

  Widget _buildRichTextContent(BuildContext context) {
    String title = '';
    String body = '';
    final mc = message.messageContent;
    if (mc is WKRichTextContent) {
      title = mc.title;
      body = mc.body;
    } else {
      // Fallback: try reading from raw content JSON
      try {
        if (message.content.isNotEmpty) {
          final data = jsonDecode(message.content) as Map<String, dynamic>?;
          title = data?['title']?.toString() ?? '';
          body = data?['content']?.toString() ?? '';
        }
      } catch (_) {}
    }

    final textColor = isSelf ? WKColors.sendText : WKColors.receiveText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
        ],
        SelectableText(
          body.isNotEmpty ? body : '[富文本]',
          style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context) {
    var url = '';
    var localPath = '';
    var intrinsicWidth = 0;
    var intrinsicHeight = 0;
    if (message.messageContent is WKImageContent) {
      final content = message.messageContent as WKImageContent;
      url = ApiConfig.resolveMediaUrl(content.url);
      localPath = content.localPath.trim();
      intrinsicWidth = content.width;
      intrinsicHeight = content.height;
    }
    if (url.isEmpty && _isRemoteMediaPath(localPath)) {
      url = ApiConfig.resolveMediaUrl(localPath);
      localPath = '';
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = _resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 200,
          preferredHeight: 200,
        );
        if (url.isEmpty && !_isLocalMediaPath(localPath)) {
          return _mediaFallback(
            icon: Icons.broken_image_outlined,
            width: mediaSize.width,
            height: mediaSize.height,
          );
        }
        final decodeRequest = resolveMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
        );

        Widget buildRemoteImage() {
          if (url.isEmpty) {
            return _mediaFallback(
              icon: Icons.broken_image_outlined,
              width: mediaSize.width,
              height: mediaSize.height,
            );
          }
          return CachedMediaImage(
            imageUrl: url,
            cacheKey: url,
            width: mediaSize.width,
            height: mediaSize.height,
            maxWidth: decodeRequest.cacheWidth,
            maxHeight: decodeRequest.cacheHeight,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => _mediaFallback(
              icon: Icons.broken_image_outlined,
              width: mediaSize.width,
              height: mediaSize.height,
            ),
            placeholder: (context, url) => _mediaFallback(
              width: mediaSize.width,
              height: mediaSize.height,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final localImageProvider = _isLocalMediaPath(localPath)
            ? resolveLocalMediaImageProvider(localPath)
            : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.md),
          child: localImageProvider != null
              ? Image(
                  image: ResizeImage.resizeIfNeeded(
                    decodeRequest.cacheWidth,
                    decodeRequest.cacheHeight,
                    localImageProvider,
                  ),
                  width: mediaSize.width,
                  height: mediaSize.height,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      buildRemoteImage(),
                )
              : buildRemoteImage(),
        );
      },
    );
  }

  Widget _buildGifContent(BuildContext context) {
    var url = '';
    var intrinsicWidth = 0;
    var intrinsicHeight = 0;
    if (message.messageContent is WKGifContent) {
      final content = message.messageContent as WKGifContent;
      url = ApiConfig.resolveMediaUrl(content.url);
      intrinsicWidth = content.width;
      intrinsicHeight = content.height;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = _resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 200,
          preferredHeight: 200,
        );
        if (url.isEmpty) {
          return _mediaFallback(
            icon: Icons.gif_box_outlined,
            width: mediaSize.width,
            height: mediaSize.height,
          );
        }
        final decodeRequest = resolveMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.md),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CachedMediaImage(
                imageUrl: url,
                cacheKey: url,
                width: mediaSize.width,
                height: mediaSize.height,
                maxWidth: decodeRequest.cacheWidth,
                maxHeight: decodeRequest.cacheHeight,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _mediaFallback(
                  icon: Icons.gif_box_outlined,
                  width: mediaSize.width,
                  height: mediaSize.height,
                ),
                placeholder: (context, url) => _mediaFallback(
                  width: mediaSize.width,
                  height: mediaSize.height,
                  child: const CircularProgressIndicator(),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '动图',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickerContent(BuildContext context) {
    final typedContent = message.messageContent;
    final payload = model.structuredPayload;
    final animationKey = typedContent is WKStickerContent
        ? typedContent.animationKey.trim()
        : _readStructuredString(payload, const ['animationKey', 'animation']);
    final previewKey = typedContent is WKStickerContent
        ? typedContent.previewKey.trim()
        : _readStructuredString(payload, const ['previewKey', 'preview']);
    final localPath = typedContent is WKStickerContent
        ? typedContent.localPath.trim()
        : _readStructuredString(payload, const ['localPath', 'local_path']);
    final url = typedContent is WKStickerContent
        ? typedContent.url.trim()
        : _readStructuredString(payload, const [
            'url',
            'remoteUrl',
            'remote_url',
            'download_url',
            'file_url',
          ]);
    final fallbackText = typedContent is WKStickerContent
        ? (typedContent.fallbackText.trim().isEmpty
              ? '[贴纸]'
              : typedContent.fallbackText.trim())
        : '[贴纸]';

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = _resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 160,
          preferredHeight: 160,
        );
        final decodeRequest = resolveMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.md),
          child: SizedBox(
            key: const ValueKey<String>('message-sticker-body'),
            width: mediaSize.width,
            height: mediaSize.height,
            child: _buildStickerAsset(
              animationKey: animationKey,
              previewKey: previewKey,
              localPath: localPath,
              url: url,
              fallbackText: fallbackText,
              decodeRequest: decodeRequest,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    var cover = '';
    var intrinsicWidth = 0;
    var intrinsicHeight = 0;
    if (message.messageContent is WKVideoContent) {
      final content = message.messageContent as WKVideoContent;
      cover = ApiConfig.resolveMediaUrl(content.cover);
      intrinsicWidth = content.width;
      intrinsicHeight = content.height;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = _resolveAdaptiveMediaSize(
          constraints,
          preferredWidth: 200,
          preferredHeight: 150,
        );
        final decodeRequest = resolveMediaDecodeRequest(
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          logicalWidth: mediaSize.width,
          logicalHeight: mediaSize.height,
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(WKRadius.md),
              child: cover.isNotEmpty
                  ? CachedMediaImage(
                      imageUrl: cover,
                      cacheKey: cover,
                      width: mediaSize.width,
                      height: mediaSize.height,
                      maxWidth: decodeRequest.cacheWidth,
                      maxHeight: decodeRequest.cacheHeight,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _mediaFallback(
                        icon: Icons.videocam_rounded,
                        width: mediaSize.width,
                        height: mediaSize.height,
                        backgroundColor: WKColors.textSecondary,
                        iconColor: WKColors.white.withValues(alpha: 0.72),
                      ),
                      placeholder: (context, url) => _mediaFallback(
                        width: mediaSize.width,
                        height: mediaSize.height,
                        backgroundColor: WKColors.textSecondary,
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  : _mediaFallback(
                      icon: Icons.videocam_rounded,
                      width: mediaSize.width,
                      height: mediaSize.height,
                      backgroundColor: WKColors.textSecondary,
                      iconColor: WKColors.white.withValues(alpha: 0.72),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: WKColors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(WKRadius.pill),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: WKColors.white,
                size: 24,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStickerAsset({
    required String animationKey,
    required String previewKey,
    required String localPath,
    required String url,
    required String fallbackText,
    required MediaDecodeRequest decodeRequest,
  }) {
    final sources = _dedupeStickerSources([
      previewKey,
      localPath,
      url,
      animationKey,
    ]);
    return _buildStickerMediaCandidate(
      sources: sources,
      index: 0,
      fallbackText: fallbackText,
      decodeRequest: decodeRequest,
    );
  }

  List<String> _dedupeStickerSources(List<String> rawSources) {
    final seen = <String>{};
    final sources = <String>[];
    for (final rawSource in rawSources) {
      final source = rawSource.trim();
      if (source.isEmpty || !seen.add(source)) {
        continue;
      }
      sources.add(source);
    }
    return sources;
  }

  Widget _buildStickerMediaCandidate({
    required List<String> sources,
    required int index,
    required String fallbackText,
    required MediaDecodeRequest decodeRequest,
  }) {
    if (index >= sources.length) {
      return _buildStickerPlaceholder(fallbackText);
    }

    final source = sources[index];
    Widget next() => _buildStickerMediaCandidate(
      sources: sources,
      index: index + 1,
      fallbackText: fallbackText,
      decodeRequest: decodeRequest,
    );

    if (_isBundledAssetPath(source)) {
      return Image.asset(
        source,
        fit: BoxFit.contain,
        cacheWidth: decodeRequest.cacheWidth,
        cacheHeight: decodeRequest.cacheHeight,
        errorBuilder: (context, error, stackTrace) => next(),
      );
    }

    final localImageProvider = _isLocalMediaPath(source)
        ? resolveLocalMediaImageProvider(source)
        : null;
    if (localImageProvider != null) {
      return Image(
        image: localImageProvider,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => next(),
      );
    }
    if (_isLocalMediaPath(source)) {
      return next();
    }

    final resolvedUrl = ApiConfig.resolveMediaUrl(source);
    if (resolvedUrl.isEmpty) {
      return next();
    }
    return CachedMediaImage(
      imageUrl: resolvedUrl,
      cacheKey: resolvedUrl,
      maxWidth: decodeRequest.cacheWidth,
      maxHeight: decodeRequest.cacheHeight,
      fit: BoxFit.contain,
      errorWidget: (context, url, error) => next(),
    );
  }

  Widget _buildStickerPlaceholder(String fallbackText) {
    return Container(
      key: const ValueKey<String>('message-sticker-placeholder'),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelf
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: Border.all(
          color: isSelf
              ? Colors.white.withValues(alpha: 0.24)
              : const Color(0xFFE4E9F1),
        ),
      ),
      child: Text(
        fallbackText,
        style: TextStyle(
          color: isSelf ? WKColors.sendText : WKColors.receiveText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVoiceContent() {
    var duration = 0;
    if (message.messageContent is WKVoiceContent) {
      duration = (message.messageContent as WKVoiceContent).timeTrad;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.volume_up_rounded,
          size: 20,
          color: isSelf ? WKColors.sendText : WKColors.receiveText,
        ),
        const SizedBox(width: 8),
        Text(
          '$duration"',
          style: TextStyle(
            color: isSelf ? WKColors.sendText : WKColors.receiveText,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationContent() {
    var title = '位置';
    var address = '';
    final payload = model.structuredPayload;
    if (message.messageContent is WKLocationContent) {
      final location = message.messageContent as WKLocationContent;
      title = location.title.isNotEmpty ? location.title : title;
      address = location.address;
    } else {
      title = _readStructuredString(payload, const ['title', 'name']);
      if (title.isEmpty) {
        title = '\u4f4d\u7f6e';
      }
      address = _readStructuredString(payload, const ['address']);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildAttachmentGlyph(
                WKReferenceAssets.chatFunctionLocation,
                tint: isSelf ? WKColors.sendText : WKColors.danger,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelf ? WKColors.sendText : WKColors.receiveText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelf
                    ? WKColors.white.withValues(alpha: 0.72)
                    : WKColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    var name = '文件';
    var size = 0;
    final payload = model.structuredPayload;
    if (message.messageContent is WKFileContent) {
      final file = message.messageContent as WKFileContent;
      name = file.name;
      size = file.size;
    } else {
      name = _readStructuredString(payload, const ['name']);
      if (name.isEmpty) {
        name = '\u6587\u4ef6';
      }
      size = _readStructuredInt(payload, const ['size']);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAttachmentGlyph(
            WKReferenceAssets.chatFunctionFile,
            tint: isSelf ? WKColors.sendText : WKColors.warning,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelf ? WKColors.sendText : WKColors.receiveText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _formatFileSize(size),
                  style: TextStyle(
                    color: isSelf
                        ? WKColors.white.withValues(alpha: 0.72)
                        : WKColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCardContent() {
    var name = '\u540d\u7247';
    var uid = '';
    final payload = model.structuredPayload;
    if (message.messageContent is WKCardContent) {
      final card = message.messageContent as WKCardContent;
      name = card.name.trim().isEmpty ? name : card.name;
      uid = card.uid.trim();
    } else {
      final payloadName = _readStructuredString(payload, const ['name']);
      if (payloadName.isNotEmpty) {
        name = payloadName;
      }
      uid = _readStructuredString(payload, const ['uid']);
    }

    final statusInfo = resolveMessageStatusInfo(message, isSelf: isSelf);
    final timeText = message.timestamp > 0
        ? WKTimeUtils.formatTimeOnly(message.timestamp)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            WKAvatar(url: buildUserAvatarUrl(uid), name: name, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WKColors.colorDark, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey<String>('card-bubble-divider'),
          height: 1,
          color: WKColors.outline,
        ),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey<String>('card-bubble-footer'),
          children: [
            const Expanded(
              child: Text(
                '\u4e2a\u4eba\u540d\u7247',
                style: TextStyle(color: WKColors.color999, fontSize: 12),
              ),
            ),
            if (statusInfo != null || timeText.isNotEmpty)
              _CompactMessageStatusBadge(
                status: statusInfo,
                isSelf: isSelf,
                timeText: timeText,
                insideBubble: true,
                onRetrySend: onRetrySend,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRobotCardContent() {
    final data = resolveRobotCardViewData(
      message,
      structuredPayload: model.structuredPayload,
    );
    if (data == null) {
      return _buildTextContent(model.previewText);
    }
    final timeText = message.timestamp > 0
        ? WKTimeUtils.formatTimeOnly(message.timestamp)
        : '';
    return RobotMessageCard(data: data, timeText: timeText, onTap: onTap);
  }

  // ignore: unused_element
  Widget _buildCardContent() {
    var name = '名片';
    if (message.messageContent is WKCardContent) {
      name = (message.messageContent as WKCardContent).name;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelf ? WKColors.chatOutgoingPressed : WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
        border: isSelf ? null : Border.all(color: WKColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isSelf ? WKColors.brand300 : WKColors.surfaceMuted,
            child: Icon(
              Icons.person_rounded,
              color: isSelf ? WKColors.white : WKColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelf ? WKColors.sendText : WKColors.receiveText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '个人名片',
                  style: TextStyle(
                    color: isSelf
                        ? WKColors.white.withValues(alpha: 0.72)
                        : WKColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaFallback({
    required double width,
    required double height,
    Widget? child,
    IconData icon = Icons.image_not_supported_outlined,
    Color backgroundColor = WKColors.surfaceMuted,
    Color iconColor = WKColors.textTertiary,
  }) {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      alignment: Alignment.center,
      child: child ?? Icon(icon, size: 44, color: iconColor),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  Widget _buildAttachmentGlyph(
    String asset, {
    required Color tint,
    double size = 24,
  }) {
    final backgroundColor = isSelf
        ? WKColors.white.withValues(alpha: 0.16)
        : WKColors.surfaceSoft;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: WKReferenceAssets.image(
        asset,
        width: size,
        height: size,
        tint: tint,
      ),
    );
  }
}

class MediaDecodeRequest {
  const MediaDecodeRequest({
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final int? cacheWidth;
  final int? cacheHeight;
}

MediaDecodeRequest resolveMediaDecodeRequest({
  required double devicePixelRatio,
  required double logicalWidth,
  required double logicalHeight,
  int intrinsicWidth = 0,
  int intrinsicHeight = 0,
}) {
  final normalizedRatio = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  var cacheWidth = logicalWidth > 0
      ? (logicalWidth * normalizedRatio).round()
      : null;
  var cacheHeight = logicalHeight > 0
      ? (logicalHeight * normalizedRatio).round()
      : null;

  if (cacheWidth != null && intrinsicWidth > 0) {
    cacheWidth = math.min(cacheWidth, intrinsicWidth);
  }
  if (cacheHeight != null && intrinsicHeight > 0) {
    cacheHeight = math.min(cacheHeight, intrinsicHeight);
  }

  return MediaDecodeRequest(cacheWidth: cacheWidth, cacheHeight: cacheHeight);
}

bool _isBundledAssetPath(String source) {
  final normalized = source.replaceAll('\\', '/');
  return normalized.startsWith('assets/');
}

bool _isLocalMediaPath(String mediaUrl) {
  if (mediaUrl.isEmpty) {
    return false;
  }
  if (_isRemoteMediaPath(mediaUrl)) {
    return false;
  }
  final uri = Uri.tryParse(mediaUrl);
  if (uri != null && uri.scheme == 'file') {
    return true;
  }
  if (mediaUrl.startsWith('/')) {
    return true;
  }
  if (mediaUrl.startsWith(r'\\')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(mediaUrl);
}

bool _isRemoteMediaPath(String mediaUrl) {
  final value = mediaUrl.trim();
  if (value.isEmpty) {
    return false;
  }
  final lowerValue = value.toLowerCase().replaceAll('\\', '/');
  if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
    return true;
  }
  final normalized = lowerValue.replaceFirst(RegExp(r'^/+'), '');
  if (normalized.startsWith('v1/file/preview/') ||
      normalized.startsWith('v1/file/download/') ||
      normalized.startsWith('minio/')) {
    return true;
  }
  for (final prefix in <String>[
    'chat/',
    'common/',
    'avatar/',
    'group/',
    'moment/',
    'report/',
    'download/',
    'sticker/',
    'chatbg/',
  ]) {
    if (normalized.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

class _CompactMessageStatusBadge extends StatelessWidget {
  final MessageStatusInfo? status;
  final bool isSelf;
  final String timeText;
  final bool insideBubble;
  final bool useWarmTextColors;
  final VoidCallback? onRetrySend;

  const _CompactMessageStatusBadge({
    required this.status,
    required this.isSelf,
    required this.timeText,
    this.insideBubble = false,
    this.useWarmTextColors = false,
    this.onRetrySend,
  });

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = status?.label.isEmpty ?? true
        ? 'message status'
        : status!.label;
    final timeColor = insideBubble
        ? (useWarmTextColors
              ? _warmWebBubbleMetaColor
              : isSelf
              ? WKColors.white.withValues(alpha: 0.72)
              : const Color(0xFF8B94A5))
        : WKColors.color999;
    final statusColor = status == null
        ? null
        : insideBubble && useWarmTextColors
        ? (status!.icon == Icons.error_outline_rounded
              ? status!.foregroundColor
              : _warmWebBubbleMetaColor)
        : insideBubble && isSelf
        ? (status!.icon == Icons.error_outline_rounded
              ? status!.foregroundColor
              : WKColors.white.withValues(alpha: 0.82))
        : status!.foregroundColor;

    final canRetry =
        isSelf &&
        onRetrySend != null &&
        status?.icon == Icons.error_outline_rounded;
    final badge = Row(
      key: const ValueKey<String>('message-status-badge'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (timeText.isNotEmpty)
          Text(
            timeText,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: timeColor,
            ),
          ),
        if (status != null) ...[
          const SizedBox(width: 4),
          if (status!.isLoading)
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor!),
              ),
            )
          else if (_statusAssetIcon(status!) != null)
            WKReferenceAssets.image(
              _statusAssetIcon(status!)!,
              width: 14,
              height: 14,
              tint: statusColor!,
            )
          else if (status!.icon != null)
            Icon(status!.icon, size: 13, color: statusColor),
        ],
      ],
    );
    final shouldShake =
        isSelf &&
        status?.icon == Icons.error_outline_rounded &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final shouldPulse =
        isSelf &&
        status?.isLoading == true &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final effectiveBadge = shouldShake
        ? _SendFailureShake(child: badge)
        : shouldPulse
        ? _SendPendingPulse(child: badge)
        : badge;
    final child = Semantics(
      label: semanticsLabel,
      button: canRetry,
      child: canRetry
          ? GestureDetector(
              key: const ValueKey<String>('message-retry-send-button'),
              behavior: HitTestBehavior.opaque,
              onTap: onRetrySend,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: effectiveBadge,
              ),
            )
          : effectiveBadge,
    );

    return Align(
      alignment: insideBubble
          ? Alignment.centerRight
          : (isSelf ? Alignment.centerRight : Alignment.centerLeft),
      child: child,
    );
  }

  String? _statusAssetIcon(MessageStatusInfo status) {
    if (status.assetIcon != null && status.assetIcon!.isNotEmpty) {
      return status.assetIcon;
    }
    final icon = status.icon;
    if (icon == Icons.error_outline_rounded) {
      return WKReferenceAssets.sendFail;
    }
    if (icon == Icons.done_all_rounded || icon == Icons.groups_rounded) {
      return WKReferenceAssets.sendDouble;
    }
    if (icon == Icons.done_rounded || icon == Icons.check_rounded) {
      return WKReferenceAssets.sendSingle;
    }
    return null;
  }
}

class _SendFailureShake extends StatelessWidget {
  const _SendFailureShake({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      child: child,
      builder: (context, progress, child) {
        final amplitude = (1 - progress) * 4;
        final dx = math.sin(progress * math.pi * 4.5) * amplitude;
        return Transform.translate(
          key: const ValueKey<String>('message-send-failure-shake'),
          offset: Offset(dx, 0),
          child: child,
        );
      },
    );
  }
}

class _SendPendingPulse extends StatefulWidget {
  const _SendPendingPulse({required this.child});

  final Widget child;

  @override
  State<_SendPendingPulse> createState() => _SendPendingPulseState();
}

class _SendPendingPulseState extends State<_SendPendingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0.72).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          key: const ValueKey<String>('message-send-pending-pulse'),
          opacity: _opacity.value,
          child: child,
        );
      },
    );
  }
}

class _PinnedMessageIndicator extends StatelessWidget {
  const _PinnedMessageIndicator({
    required this.isSelf,
    this.useWarmTextColors = false,
  });

  final bool isSelf;
  final bool useWarmTextColors;

  @override
  Widget build(BuildContext context) {
    final color = useWarmTextColors
        ? _warmWebBubbleMetaColor
        : isSelf
        ? WKColors.white.withValues(alpha: 0.82)
        : WKColors.brand500;
    return Row(
      key: const ValueKey<String>('message-pinned-indicator'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.push_pin_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          '\u7f6e\u9876',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

extension on MessageStatusInfo {
  MessageStatusInfo copyWith({
    String? label,
    IconData? icon,
    String? assetIcon,
    Color? foregroundColor,
    bool? isLoading,
  }) {
    return MessageStatusInfo(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      assetIcon: assetIcon ?? this.assetIcon,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

WKChannelMember? _senderGroupMember(WKMsg message, WKChannelMember? member) {
  if (member == null) {
    return null;
  }
  final senderUid = message.fromUID.trim();
  final memberUid = member.memberUID.trim();
  if (senderUid.isEmpty || memberUid.isEmpty || senderUid == memberUid) {
    return member;
  }
  return null;
}

WKChannel? _senderChannel(WKMsg message, WKChannel? channel) {
  if (channel == null) {
    return null;
  }
  final senderUid = message.fromUID.trim();
  if (senderUid.isEmpty || channel.channelType != WKChannelType.personal) {
    return null;
  }
  return channel.channelID.trim() == senderUid ? channel : null;
}

String _resolveGroupMemberName(WKChannelMember? member) {
  if (member == null) {
    return '';
  }
  return _firstNonEmpty([
    member.remark.trim(),
    member.memberRemark.trim(),
    member.memberName.trim(),
  ]);
}

String _resolveGroupMemberAvatar(WKChannelMember? member) {
  if (member == null) {
    return '';
  }
  return member.memberAvatar.trim();
}

String _resolveChannelName(WKChannel? channel) {
  if (channel == null) {
    return '';
  }
  return _firstNonEmpty([
    channel.channelRemark.trim(),
    channel.channelName.trim(),
    channel.channelID.trim(),
  ]);
}

String? _resolveParticipantAvatarUrl(String? rawAvatar, String? uid) {
  return resolveUserAvatarUrl(rawAvatar, uid);
}

String _firstNonEmpty(List<String?> candidates) {
  for (final candidate in candidates) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

class _LinkPreviewCard extends StatefulWidget {
  final String url;
  final bool isSelf;

  const _LinkPreviewCard({required this.url, required this.isSelf});

  @override
  State<_LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<_LinkPreviewCard> {
  late Future<LinkPreview?> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = LinkPreviewService.instance.getPreview(widget.url);
  }

  @override
  void didUpdateWidget(covariant _LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) {
      return;
    }
    _previewFuture = LinkPreviewService.instance.getPreview(widget.url);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LinkPreview?>(
      future: _previewFuture,
      builder: (context, snapshot) {
        final preview =
            snapshot.data ??
            LinkPreviewService.instance.buildFallbackPreview(widget.url);
        final backgroundColor = widget.isSelf
            ? WKColors.chatOutgoingPressed
            : WKColors.surface;
        final borderColor = widget.isSelf
            ? Colors.transparent
            : WKColors.outline;
        final textColor = widget.isSelf
            ? WKColors.sendText
            : WKColors.receiveText;
        final secondaryColor = widget.isSelf
            ? WKColors.white.withValues(alpha: 0.75)
            : WKColors.textSecondary;
        final imageDecodeRequest = preview.hasImage
            ? resolveMediaDecodeRequest(
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                logicalWidth: 260,
                logicalHeight: 132,
              )
            : null;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(WKRadius.md),
            onTap: () => _openLink(preview.url),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(WKRadius.md),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (preview.hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(WKRadius.md),
                      ),
                      child: CachedMediaImage(
                        imageUrl: preview.imageUrl!,
                        cacheKey: preview.imageUrl!,
                        maxWidth: imageDecodeRequest?.cacheWidth,
                        maxHeight: imageDecodeRequest?.cacheHeight,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                        placeholder: (_, _) =>
                            const SizedBox(height: 132, width: double.infinity),
                        height: 132,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (preview.title.trim().isNotEmpty) ...[
                          Text(
                            preview.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (preview.description.trim().isNotEmpty) ...[
                          Text(
                            preview.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 14,
                              color: secondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                preview.displayUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: secondaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
