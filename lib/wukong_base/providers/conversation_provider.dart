import 'package:flutter/material.dart';
import '../entity/channel.dart';

/// Conversation item state
class ConversationItem {
  final String channelId;
  final int channelType;
  final String? name;
  final String? avatar;
  final String? lastMsg;
  final int lastMsgTime;
  final int unreadCount;
  final bool top;
  final bool mute;
  final int? mentionCount;
  final bool isOnline;

  const ConversationItem({
    required this.channelId,
    required this.channelType,
    this.name,
    this.avatar,
    this.lastMsg,
    this.lastMsgTime = 0,
    this.unreadCount = 0,
    this.top = false,
    this.mute = false,
    this.mentionCount,
    this.isOnline = false,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      channelId: json['channel_id'] ?? json['channelId'] ?? '',
      channelType: json['channel_type'] ?? json['channelType'] ?? 1,
      name: json['name'],
      avatar: json['avatar'],
      lastMsg: json['last_msg'] ?? json['lastMsg'],
      lastMsgTime: json['last_msg_time'] ?? json['lastMsgTime'] ?? 0,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
      top: json['top'] == 1 || json['top'] == true,
      mute: json['mute'] == 1 || json['mute'] == true,
      mentionCount: json['mention_count'] ?? json['mentionCount'],
      isOnline: json['is_online'] == 1 || json['is_online'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'channel_type': channelType,
      'name': name,
      'avatar': avatar,
      'last_msg': lastMsg,
      'last_msg_time': lastMsgTime,
      'unread_count': unreadCount,
      'top': top ? 1 : 0,
      'mute': mute ? 1 : 0,
      'mention_count': mentionCount,
      'is_online': isOnline ? 1 : 0,
    };
  }

  ConversationItem copyWith({
    String? channelId,
    int? channelType,
    String? name,
    String? avatar,
    String? lastMsg,
    int? lastMsgTime,
    int? unreadCount,
    bool? top,
    bool? mute,
    int? mentionCount,
    bool? isOnline,
  }) {
    return ConversationItem(
      channelId: channelId ?? this.channelId,
      channelType: channelType ?? this.channelType,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      lastMsg: lastMsg ?? this.lastMsg,
      lastMsgTime: lastMsgTime ?? this.lastMsgTime,
      unreadCount: unreadCount ?? this.unreadCount,
      top: top ?? this.top,
      mute: mute ?? this.mute,
      mentionCount: mentionCount ?? this.mentionCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  bool get isPersonal => channelType == ChannelType.personal.index;
  bool get isGroup => channelType == ChannelType.group.index;
  String get displayName => name ?? channelId;
}

/// Conversation list state
class ConversationListState {
  final List<ConversationItem> conversations;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int totalUnreadCount;

  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.totalUnreadCount = 0,
  });

  ConversationListState copyWith({
    List<ConversationItem>? conversations,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? totalUnreadCount,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}

/// Conversation list notifier
class ConversationListNotifier extends ChangeNotifier {
  ConversationListState _state = const ConversationListState();
  final Map<String, ConversationItem> _conversationMap = {};

  ConversationListState get state => _state;
  List<ConversationItem> get conversations => _state.conversations;
  bool get isLoading => _state.isLoading;
  int get totalUnreadCount => _state.totalUnreadCount;

  /// Initialize with conversations
  void initConversations(List<ConversationItem> conversations) {
    _state = _state.copyWith(conversations: conversations);
    _updateConversationMap();
    _updateTotalUnreadCount();
    notifyListeners();
  }

  /// Update conversation
  void updateConversation(ConversationItem conversation) {
    final index = _state.conversations.indexWhere(
      (c) => c.channelId == conversation.channelId && 
             c.channelType == conversation.channelType,
    );

    List<ConversationItem> newConversations;
    if (index == -1) {
      // Add new conversation
      newConversations = [..._state.conversations, conversation];
    } else {
      // Update existing
      newConversations = List<ConversationItem>.from(_state.conversations);
      newConversations[index] = conversation;
    }

    // Sort: top first, then by lastMsgTime
    newConversations.sort((a, b) {
      if (a.top != b.top) return b.top ? 1 : -1;
      return b.lastMsgTime.compareTo(a.lastMsgTime);
    });

    _state = _state.copyWith(conversations: newConversations);
    _updateConversationMap();
    _updateTotalUnreadCount();
    notifyListeners();
  }

  /// Delete conversation
  void deleteConversation(String channelId, int channelType) {
    final newConversations = _state.conversations.where(
      (c) => !(c.channelId == channelId && c.channelType == channelType),
    ).toList();
    _state = _state.copyWith(conversations: newConversations);
    _conversationMap.remove('$channelId-$channelType');
    _updateTotalUnreadCount();
    notifyListeners();
  }

  /// Update last message for a conversation
  void updateLastMessage(String channelId, int channelType, String lastMsg, int lastMsgTime) {
    final conversation = _conversationMap['$channelId-$channelType'];
    if (conversation == null) return;

    updateConversation(conversation.copyWith(
      lastMsg: lastMsg,
      lastMsgTime: lastMsgTime,
    ));
  }

  /// Update unread count
  void updateUnreadCount(String channelId, int channelType, int count) {
    final conversation = _conversationMap['$channelId-$channelType'];
    if (conversation == null) return;

    updateConversation(conversation.copyWith(unreadCount: count));
  }

  /// Clear unread for a conversation
  void clearUnread(String channelId, int channelType) {
    updateUnreadCount(channelId, channelType, 0);
  }

  /// Set top status
  void setTop(String channelId, int channelType, bool top) {
    final conversation = _conversationMap['$channelId-$channelType'];
    if (conversation == null) return;

    updateConversation(conversation.copyWith(top: top));
  }

  /// Set mute status
  void setMute(String channelId, int channelType, bool mute) {
    final conversation = _conversationMap['$channelId-$channelType'];
    if (conversation == null) return;

    updateConversation(conversation.copyWith(mute: mute));
  }

  /// Get conversation
  ConversationItem? getConversation(String channelId, int channelType) {
    return _conversationMap['$channelId-$channelType'];
  }

  /// Set loading
  void setLoading(bool loading) {
    _state = _state.copyWith(isLoading: loading);
    notifyListeners();
  }

  /// Clear all
  void clear() {
    _state = const ConversationListState();
    _conversationMap.clear();
    notifyListeners();
  }

  void _updateConversationMap() {
    _conversationMap.clear();
    for (final c in _state.conversations) {
      _conversationMap['${c.channelId}-${c.channelType}'] = c;
    }
  }

  void _updateTotalUnreadCount() {
    int total = 0;
    for (final c in _state.conversations) {
      if (!c.mute) {
        total += c.unreadCount;
      }
    }
    _state = _state.copyWith(totalUnreadCount: total);
  }
}
