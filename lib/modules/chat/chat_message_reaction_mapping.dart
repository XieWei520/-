import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukong_im_app/wukong_base/msg/widget/wk_message_reaction.dart';

class ChatMessageReactionMapping {
  const ChatMessageReactionMapping._();

  static List<WKMessageReaction> toWidgetReactions(
    Iterable<MessageReaction> reactions,
  ) {
    return reactions
        .map(
          (reaction) => WKMessageReaction(
            emoji: reaction.emoji,
            count: reaction.count,
            isMe: reaction.isMe,
            usernames: List<String>.from(reaction.usernames),
          ),
        )
        .toList(growable: false);
  }

  static String? selectedReactionEmoji(Iterable<MessageReaction> reactions) {
    for (final reaction in reactions) {
      if (reaction.isMe) {
        return reaction.emoji;
      }
    }
    return null;
  }
}
