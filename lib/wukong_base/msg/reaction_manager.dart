import 'dart:async';

import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/reaction_api.dart';

class MessageReaction {
  final int type;
  final String emoji;
  final int count;
  final bool isMe;
  final List<String> userIds;
  final List<String> usernames;

  const MessageReaction({
    required this.type,
    required this.emoji,
    required this.count,
    required this.isMe,
    required this.userIds,
    required this.usernames,
  });

  MessageReaction copyWith({
    int? type,
    String? emoji,
    int? count,
    bool? isMe,
    List<String>? userIds,
    List<String>? usernames,
  }) {
    return MessageReaction(
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      isMe: isMe ?? this.isMe,
      userIds: userIds ?? this.userIds,
      usernames: usernames ?? this.usernames,
    );
  }
}

class ReactionManager {
  ReactionManager._internal();
  static final ReactionManager _instance = ReactionManager._internal();
  factory ReactionManager() => _instance;

  final Map<String, List<MessageReaction>> _reactionCache = {};
  final Map<String, String> _reactionHashes = {};

  final _reactionUpdatesController =
      StreamController<ReactionUpdate>.broadcast();
  Stream<ReactionUpdate> get reactionUpdates =>
      _reactionUpdatesController.stream;

  static const List<String> defaultReactions = [
    '👍',
    '👎',
    '❤️',
    '😀',
    '😢',
    '😮',
    '😡',
    '😂',
  ];

  String get _currentUid => StorageUtils.getUid() ?? '';

  List<MessageReaction> prepareReactions(WKMsg message) {
    final key = _messageKey(message.messageID);
    if (key == null) {
      return const [];
    }

    final hash = _computeHash(message.reactionList);
    if (hash != _reactionHashes[key]) {
      _reactionHashes[key] = hash;
      _reactionCache[key] = _buildFromRaw(message.reactionList);
      final updated = _reactionCache[key];
      if (updated != null) {
        _notifyUpdate(key, updated);
      }
    }
    return List.unmodifiable(_reactionCache[key] ?? const []);
  }

  Future<void> toggleReaction({
    required WKMsg message,
    required String emoji,
  }) async {
    final messageId = _messageKey(message.messageID);
    if (messageId == null) {
      throw StateError('消息尚未同步，无法添加表情回应');
    }
    await ReactionApi.instance.toggleReaction(
      messageId: message.messageID,
      channelId: message.channelID,
      channelType: message.channelType,
      emoji: emoji,
    );
    _applyLocalToggle(messageId: messageId, emoji: emoji);
  }

  void clearCache() {
    _reactionCache.clear();
    _reactionHashes.clear();
  }

  void clearCacheForMessage(String messageId) {
    _reactionCache.remove(messageId);
    _reactionHashes.remove(messageId);
  }

  void dispose() {
    _reactionUpdatesController.close();
  }

  // Helpers -------------------------------------------------

  String? _messageKey(String messageId) {
    final trimmed = messageId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _computeHash(List<WKMsgReaction>? reactions) {
    if (reactions == null || reactions.isEmpty) {
      return 'empty';
    }
    final buffer = StringBuffer();
    for (final reaction in reactions) {
      buffer.write(
        '${reaction.uid}-${reaction.emoji}-${reaction.isDeleted}-${reaction.seq};',
      );
    }
    return buffer.toString();
  }

  List<MessageReaction> _buildFromRaw(List<WKMsgReaction>? raw) {
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final uid = _currentUid;
    final Map<String, Set<String>> userIds = {};
    final Map<String, Set<String>> userNames = {};

    for (final reaction in raw) {
      if (reaction.isDeleted == 1) {
        continue;
      }
      final emoji = reaction.emoji.trim();
      if (emoji.isEmpty) {
        continue;
      }
      userIds.putIfAbsent(emoji, () => <String>{}).add(reaction.uid);
      final displayName = reaction.name.trim().isEmpty
          ? reaction.uid
          : reaction.name.trim();
      userNames.putIfAbsent(emoji, () => <String>{}).add(displayName);
    }

    final result = <MessageReaction>[];
    userIds.forEach((emoji, ids) {
      final names = userNames[emoji] ?? <String>{};
      result.add(
        MessageReaction(
          type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
          emoji: emoji,
          count: ids.length,
          isMe: uid.isNotEmpty && ids.contains(uid),
          userIds: ids.toList(),
          usernames: names.toList(),
        ),
      );
    });
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  void _applyLocalToggle({
    required String messageId,
    required String emoji,
  }) {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }

    final reactions = List<MessageReaction>.from(
      _reactionCache[messageId] ?? const [],
    );

    final currentIndex = reactions.indexWhere(
      (reaction) => reaction.userIds.contains(uid),
    );
    final targetIndex = reactions.indexWhere((r) => r.emoji == emoji);
    MessageReaction? current =
        currentIndex >= 0 ? reactions[currentIndex] : null;
    MessageReaction? target =
        targetIndex >= 0 ? reactions[targetIndex] : null;

    void removeFromCurrent() {
      final currentValue = current;
      if (currentValue == null) {
        return;
      }
      final updatedIds = List<String>.from(currentValue.userIds)..remove(uid);
      final updatedNames = List<String>.from(currentValue.usernames)..remove(uid);
      if (updatedIds.isEmpty) {
        reactions.removeAt(currentIndex);
      } else {
        reactions[currentIndex] = currentValue.copyWith(
          count: updatedIds.length,
          isMe: false,
          userIds: updatedIds,
          usernames: updatedNames,
        );
      }
    }

    if (current != null && current.emoji == emoji) {
      removeFromCurrent();
    } else {
      removeFromCurrent();
      final targetValue = target;
      if (targetValue != null) {
        final updatedIds = {...targetValue.userIds, uid}.toList();
        final updatedNames = {...targetValue.usernames, uid}.toList();
        reactions[targetIndex] = targetValue.copyWith(
          count: updatedIds.length,
          isMe: true,
          userIds: updatedIds,
          usernames: updatedNames,
        );
      } else {
        reactions.add(
          MessageReaction(
            type: emoji.runes.isNotEmpty ? emoji.runes.first : 0,
            emoji: emoji,
            count: 1,
            isMe: true,
            userIds: [uid],
            usernames: [uid],
          ),
        );
      }
    }

    reactions.sort((a, b) => b.count.compareTo(a.count));
    _reactionCache[messageId] = reactions;
    _reactionHashes[messageId] =
        DateTime.now().millisecondsSinceEpoch.toString();
    _notifyUpdate(messageId, reactions);
  }

  void _notifyUpdate(String messageId, List<MessageReaction> reactions) {
    _reactionUpdatesController.add(
      ReactionUpdate(
        messageId: messageId,
        reactions: List.unmodifiable(reactions),
      ),
    );
  }
}

class ReactionUpdate {
  final String messageId;
  final List<MessageReaction> reactions;

  const ReactionUpdate({
    required this.messageId,
    required this.reactions,
  });
}
