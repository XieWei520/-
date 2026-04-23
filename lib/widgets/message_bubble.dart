import 'dart:convert';
import 'dart:io';
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
import '../wukong_base/utils/time_utils.dart';
import 'robot_message_card.dart';
import 'wk_avatar.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_emoji_text.dart';
import 'wk_reference_assets.dart';
import '../wukong_base/msg/widget/wk_message_reaction.dart' as reaction_widget;

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
  Map<String, dynamic>? structuredPayload,
}) {
  final member = message.getMemberOfFrom();
  final from = message.getFrom();
  final channelInfo = message.getChannelInfo();
  final robotIdentity = message.channelType == WKChannelType.group
      ? resolveRobotMessageIdentityFromMessage(
          message,
          structuredPayload: structuredPayload,
        )
      : null;

  final displayName = _firstNonEmpty([
    robotIdentity?.displayName,
    _resolveGroupMemberName(member),
    _resolveGroupMemberName(fallbackGroupMember),
    _resolveChannelName(from),
    _resolveChannelName(channelInfo),
    message.fromUID.trim(),
    message.channelID.trim(),
    '未知用户',
  ]);

  final avatarUrl = _resolveParticipantAvatarUrl(
    _firstNonEmpty([
      robotIdentity?.displayAvatar,
      _resolveGroupMemberAvatar(member),
      _resolveGroupMemberAvatar(fallbackGroupMember),
      from?.avatar.trim(),
      channelInfo?.avatar.trim(),
    ]),
    message.fromUID,
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

class MessageBubble extends StatelessWidget {
  final ChatMessageViewModel model;
  final MessageParticipantInfo? participant;
  final MessageStatusInfo? statusInfo;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final List<reaction_widget.WKMessageReaction> reactions;
  final VoidCallback? onAddReaction;
  final void Function(String emoji)? onReactionTap;
  final MessageVoiceContentBuilder? voiceContentBuilder;

  const MessageBubble({
    super.key,
    required this.model,
    this.participant,
    this.statusInfo,
    this.onLongPress,
    this.onTap,
    this.onSecondaryTapDown,
    this.reactions = const [],
    this.onAddReaction,
    this.onReactionTap,
    this.voiceContentBuilder,
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
    final bubble = GestureDetector(
      onTap: effectiveContentType == MsgContentType.robotCard ? null : onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Container(
        key: const ValueKey<String>('message-bubble-body'),
        constraints: BoxConstraints(
          maxWidth: effectiveContentType == MsgContentType.robotCard
              ? math.min(MediaQuery.of(context).size.width * 0.88, 460)
              : MediaQuery.of(context).size.width * 0.72,
        ),
        padding: bubblePadding,
        decoration: bubbleDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPinnedIndicator) ...[
              _PinnedMessageIndicator(isSelf: isSelf),
              const SizedBox(height: 6),
            ],
            _buildContent(
              context: context,
              previewText: model.previewText,
              effectiveContentType: effectiveContentType,
            ),
            if (showInlineMeta) ...[
              const SizedBox(height: 10),
              _CompactMessageStatusBadge(
                status: resolvedStatusInfo,
                isSelf: isSelf,
                timeText: timeText,
                insideBubble: true,
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
                        letterSpacing: 0.2,
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

  BoxDecoration _bubbleDecoration(int effectiveContentType) {
    if (effectiveContentType == MsgContentType.robotCard) {
      return const BoxDecoration(color: Colors.transparent);
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
  }) {
    final reply = message.messageContent?.reply;
    final resolvedContentType =
        effectiveContentType ?? _resolveEffectiveContentType();
    Widget content = switch (resolvedContentType) {
      MsgContentType.robotCard => _buildRobotCardContent(),
      WkMessageContentType.text => _buildTextContent(previewText),
      WkMessageContentType.image => _buildImageContent(context),
      WkMessageContentType.gif => _buildGifContent(context),
      WkMessageContentType.sticker => _buildStickerContent(),
      WkMessageContentType.voice =>
        voiceContentBuilder?.call(context, model, isSelf) ??
            _buildVoiceContent(),
      WkMessageContentType.video => _buildVideoContent(context),
      WkMessageContentType.location => _buildLocationContent(),
      WkMessageContentType.file => _buildFileContent(),
      WkMessageContentType.card => _buildInteractiveCardContent(),
      MsgContentType.richText => _buildRichTextContent(context),
      _ => _buildTextContent(previewText),
    };

    if (reply != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyPreview(reply),
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

  Widget _buildReplyPreview(WKReply reply) {
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
        color: isSelf
            ? WKColors.white.withValues(alpha: 0.18)
            : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(WKRadius.sm),
        border: Border.all(
          color: isSelf
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
              color: isSelf ? WKColors.sendText : const Color(0xFF3567C8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelf
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

  Widget _buildTextContent(String text) {
    final textStyle = TextStyle(
      color: isSelf ? WKColors.sendText : WKColors.receiveText,
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
    if (url.isEmpty && !_isLocalMediaPath(localPath)) {
      return _mediaFallback(
        icon: Icons.broken_image_outlined,
        width: 200,
        height: 200,
      );
    }
    final decodeRequest = resolveMediaDecodeRequest(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      logicalWidth: 200,
      logicalHeight: 200,
      intrinsicWidth: intrinsicWidth,
      intrinsicHeight: intrinsicHeight,
    );

    Widget buildRemoteImage() {
      if (url.isEmpty) {
        return _mediaFallback(
          icon: Icons.broken_image_outlined,
          width: 200,
          height: 200,
        );
      }
      return Image(
        image: ResizeImage.resizeIfNeeded(
          decodeRequest.cacheWidth,
          decodeRequest.cacheHeight,
          NetworkImage(url),
        ),
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _mediaFallback(
          icon: Icons.broken_image_outlined,
          width: 200,
          height: 200,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return _mediaFallback(
            width: 200,
            height: 200,
            child: const CircularProgressIndicator(),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(WKRadius.md),
      child: _isLocalMediaPath(localPath)
          ? Image(
              image: ResizeImage.resizeIfNeeded(
                decodeRequest.cacheWidth,
                decodeRequest.cacheHeight,
                FileImage(_resolveLocalMediaFile(localPath)),
              ),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => buildRemoteImage(),
            )
          : buildRemoteImage(),
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
    if (url.isEmpty) {
      return _mediaFallback(
        icon: Icons.gif_box_outlined,
        width: 200,
        height: 200,
      );
    }
    final decodeRequest = resolveMediaDecodeRequest(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      logicalWidth: 200,
      logicalHeight: 200,
      intrinsicWidth: intrinsicWidth,
      intrinsicHeight: intrinsicHeight,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(WKRadius.md),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Image.network(
            url,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            cacheWidth: decodeRequest.cacheWidth,
            cacheHeight: decodeRequest.cacheHeight,
            errorBuilder: (context, error, stackTrace) => _mediaFallback(
              icon: Icons.gif_box_outlined,
              width: 200,
              height: 200,
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return _mediaFallback(
                width: 200,
                height: 200,
                child: const CircularProgressIndicator(),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'GIF',
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
  }

  Widget _buildStickerContent() {
    final typedContent = message.messageContent;
    final payload = model.structuredPayload;
    final animationKey = typedContent is WKStickerContent
        ? typedContent.animationKey.trim()
        : _readStructuredString(payload, const ['animationKey', 'animation']);
    final previewKey = typedContent is WKStickerContent
        ? typedContent.previewKey.trim()
        : _readStructuredString(payload, const ['previewKey', 'preview']);
    final fallbackText = typedContent is WKStickerContent
        ? (typedContent.fallbackText.trim().isEmpty
              ? '[贴纸]'
              : typedContent.fallbackText.trim())
        : '[贴纸]';

    return ClipRRect(
      borderRadius: BorderRadius.circular(WKRadius.md),
      child: SizedBox(
        key: const ValueKey<String>('message-sticker-body'),
        width: 160,
        height: 160,
        child: _buildStickerAsset(
          animationKey: animationKey,
          previewKey: previewKey,
          fallbackText: fallbackText,
        ),
      ),
    );
  }

  Widget _buildStickerAsset({
    required String animationKey,
    required String previewKey,
    required String fallbackText,
  }) {
    if (animationKey.isNotEmpty) {
      return Image.asset(
        animationKey,
        fit: BoxFit.contain,
        errorBuilder: (_, _, __) => _buildStickerPreviewOrPlaceholder(
          previewKey: previewKey,
          fallbackText: fallbackText,
        ),
      );
    }

    return _buildStickerPreviewOrPlaceholder(
      previewKey: previewKey,
      fallbackText: fallbackText,
    );
  }

  Widget _buildStickerPreviewOrPlaceholder({
    required String previewKey,
    required String fallbackText,
  }) {
    if (previewKey.isNotEmpty) {
      return Image.asset(
        previewKey,
        fit: BoxFit.contain,
        errorBuilder: (_, _, __) => _buildStickerPlaceholder(fallbackText),
      );
    }

    return _buildStickerPlaceholder(fallbackText);
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
    final decodeRequest = resolveMediaDecodeRequest(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      logicalWidth: 200,
      logicalHeight: 150,
      intrinsicWidth: intrinsicWidth,
      intrinsicHeight: intrinsicHeight,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(WKRadius.md),
          child: cover.isNotEmpty
              ? Image(
                  image: ResizeImage.resizeIfNeeded(
                    decodeRequest.cacheWidth,
                    decodeRequest.cacheHeight,
                    NetworkImage(cover),
                  ),
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                )
              : _mediaFallback(
                  icon: Icons.videocam_rounded,
                  width: 200,
                  height: 150,
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

bool _isLocalMediaPath(String mediaUrl) {
  if (mediaUrl.isEmpty) {
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

File _resolveLocalMediaFile(String mediaUrl) {
  if (mediaUrl.startsWith('file://')) {
    final uri = Uri.tryParse(mediaUrl);
    if (uri != null) {
      return File.fromUri(uri);
    }
    return File(mediaUrl.substring('file://'.length));
  }
  final uri = Uri.tryParse(mediaUrl);
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri);
  }
  return File(mediaUrl);
}

class _CompactMessageStatusBadge extends StatelessWidget {
  final MessageStatusInfo? status;
  final bool isSelf;
  final String timeText;
  final bool insideBubble;

  const _CompactMessageStatusBadge({
    required this.status,
    required this.isSelf,
    required this.timeText,
    this.insideBubble = false,
  });

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = status?.label.isEmpty ?? true
        ? 'message status'
        : status!.label;
    final timeColor = insideBubble
        ? (isSelf
              ? WKColors.white.withValues(alpha: 0.72)
              : const Color(0xFF8B94A5))
        : WKColors.color999;
    final statusColor = status == null
        ? null
        : insideBubble && isSelf
        ? (status!.icon == Icons.error_outline_rounded
              ? status!.foregroundColor
              : WKColors.white.withValues(alpha: 0.82))
        : status!.foregroundColor;

    return Align(
      alignment: insideBubble
          ? Alignment.centerRight
          : (isSelf ? Alignment.centerRight : Alignment.centerLeft),
      child: Semantics(
        label: semanticsLabel,
        child: Row(
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
        ),
      ),
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

class _PinnedMessageIndicator extends StatelessWidget {
  const _PinnedMessageIndicator({required this.isSelf});

  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final color = isSelf
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
                      child: Image(
                        image: ResizeImage.resizeIfNeeded(
                          resolveMediaDecodeRequest(
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                            logicalWidth: 260,
                            logicalHeight: 132,
                          ).cacheWidth,
                          resolveMediaDecodeRequest(
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                            logicalWidth: 260,
                            logicalHeight: 132,
                          ).cacheHeight,
                          NetworkImage(preview.imageUrl!),
                        ),
                        height: 132,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
