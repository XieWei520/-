import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/chat_message_reaction_mapping.dart';
import 'package:wukong_im_app/modules/chat/chat_message_view_model.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';

import 'chat_voice_message_bubble.dart';

class ChatMessageEngagementBubble extends StatefulWidget {
  const ChatMessageEngagementBubble({
    super.key,
    required this.session,
    required this.model,
    required this.gateway,
    this.participant,
    this.statusInfo,
    this.onLongPress,
    this.onTap,
    this.onSecondaryTapDown,
    this.onAddReaction,
    this.onReactionTap,
  });

  final ChatSession session;
  final ChatMessageViewModel model;
  final ChatSceneGateway gateway;
  final MessageParticipantInfo? participant;
  final MessageStatusInfo? statusInfo;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final void Function(TapDownDetails details)? onSecondaryTapDown;
  final VoidCallback? onAddReaction;
  final void Function(String emoji)? onReactionTap;

  @override
  State<ChatMessageEngagementBubble> createState() =>
      _ChatMessageEngagementBubbleState();
}

class _ChatMessageEngagementBubbleState
    extends State<ChatMessageEngagementBubble> {
  StreamSubscription<ReactionUpdate>? _reactionSubscription;
  List<WKMessageReaction> _reactions = const <WKMessageReaction>[];

  @override
  void initState() {
    super.initState();
    _seedReactions();
    _subscribeToReactionUpdates();
  }

  @override
  void didUpdateWidget(covariant ChatMessageEngagementBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    final didModelChange = oldWidget.model != widget.model;
    final didMessageChange = _messageIdOf(oldWidget) != _messageIdOf(widget);
    final didGatewayChange = oldWidget.gateway != widget.gateway;
    if (didModelChange || didMessageChange || didGatewayChange) {
      _seedReactions();
    }
    if (didGatewayChange) {
      _reactionSubscription?.cancel();
      _subscribeToReactionUpdates();
    }
  }

  @override
  void dispose() {
    _reactionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MessageBubble(
      model: widget.model,
      participant: widget.participant,
      statusInfo: widget.statusInfo,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      reactions: _reactions,
      onReactionTap: widget.onReactionTap,
      voiceContentBuilder: (context, model, isSelf) {
        return ChatVoiceMessageBubble(
          session: widget.session,
          model: model,
        );
      },
    );
  }

  void _seedReactions() {
    final prepared = widget.gateway.prepareReactions(widget.model.message);
    final mapped = ChatMessageReactionMapping.toWidgetReactions(prepared);
    _reactions = mapped;
  }

  void _subscribeToReactionUpdates() {
    _reactionSubscription = widget.gateway.watchReactionUpdates().listen((
      update,
    ) {
      if (!_matchesCurrentMessage(update.messageId)) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _reactions = ChatMessageReactionMapping.toWidgetReactions(
          update.reactions,
        );
      });
    });
  }

  bool _matchesCurrentMessage(String messageId) {
    final currentMessageId = _messageIdOf(widget);
    if (currentMessageId.isEmpty) {
      return false;
    }
    return currentMessageId == messageId.trim();
  }

  String _messageIdOf(ChatMessageEngagementBubble widget) {
    return widget.model.message.messageID.trim();
  }
}
