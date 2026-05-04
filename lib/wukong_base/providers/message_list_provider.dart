import 'package:flutter/material.dart';
import '../models/message_model.dart';

/// Message list state
class MessageListState {
  final List<WKMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int? mentionCount;

  const MessageListState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.mentionCount,
  });

  MessageListState copyWith({
    List<WKMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? mentionCount,
  }) {
    return MessageListState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      mentionCount: mentionCount ?? this.mentionCount,
    );
  }
}

/// Message list notifier
class MessageListNotifier extends ChangeNotifier {
  MessageListState _state = const MessageListState();
  final Map<String, WKMessage> _messageMap = {};  // For quick lookup by clientMsgNo

  MessageListState get state => _state;
  List<WKMessage> get messages => _state.messages;
  bool get isLoading => _state.isLoading;
  bool get hasMore => _state.hasMore;

  /// Initialize with messages
  void initMessages(List<WKMessage> messages) {
    _state = _state.copyWith(messages: messages);
    _updateMessageMap();
    notifyListeners();
  }

  /// Load more messages (prepend)
  void loadMore(List<WKMessage> messages) {
    final newMessages = [...messages, ..._state.messages];
    _state = _state.copyWith(messages: newMessages, hasMore: messages.isNotEmpty);
    _updateMessageMap();
    notifyListeners();
  }

  /// Add a new message (append)
  void addMessage(WKMessage message) {
    // Check if message already exists
    if (_messageMap.containsKey(message.clientMsgNo)) {
      updateMessage(message);
      return;
    }

    final newMessages = [..._state.messages, message];
    _state = _state.copyWith(messages: newMessages);
    _messageMap[message.clientMsgNo] = message;
    notifyListeners();
  }

  /// Update an existing message
  void updateMessage(WKMessage message) {
    final index = _state.messages.indexWhere((m) => m.clientMsgNo == message.clientMsgNo);
    if (index == -1) return;

    final newMessages = List<WKMessage>.from(_state.messages);
    newMessages[index] = message;
    _messageMap[message.clientMsgNo] = message;
    _state = _state.copyWith(messages: newMessages);
    notifyListeners();
  }

  /// Delete a message
  void deleteMessage(String clientMsgNo) {
    final newMessages = _state.messages.where((m) => m.clientMsgNo != clientMsgNo).toList();
    _messageMap.remove(clientMsgNo);
    _state = _state.copyWith(messages: newMessages);
    notifyListeners();
  }

  /// Recall (revoke) a message
  void recallMessage(String clientMsgNo) {
    final index = _state.messages.indexWhere((m) => m.clientMsgNo == clientMsgNo);
    if (index == -1) return;

    final newMessages = List<WKMessage>.from(_state.messages);
    newMessages[index] = newMessages[index].copyWith(
      isRevoked: 1,
      content: '你撤回了一条消息',
    );
    _state = _state.copyWith(messages: newMessages);
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool loading) {
    _state = _state.copyWith(isLoading: loading);
    notifyListeners();
  }

  /// Set error
  void setError(String? error) {
    _state = _state.copyWith(error: error);
    notifyListeners();
  }

  /// Clear all messages
  void clear() {
    _state = const MessageListState();
    _messageMap.clear();
    notifyListeners();
  }

  /// Get message by clientMsgNo
  WKMessage? getMessage(String clientMsgNo) {
    return _messageMap[clientMsgNo];
  }

  /// Update message status
  void updateMessageStatus(String clientMsgNo, int status) {
    final index = _state.messages.indexWhere((m) => m.clientMsgNo == clientMsgNo);
    if (index == -1) return;

    final newMessages = List<WKMessage>.from(_state.messages);
    newMessages[index] = newMessages[index].copyWith(status: status);
    _messageMap[clientMsgNo] = newMessages[index];
    _state = _state.copyWith(messages: newMessages);
    notifyListeners();
  }

  void _updateMessageMap() {
    _messageMap.clear();
    for (final message in _state.messages) {
      _messageMap[message.clientMsgNo] = message;
    }
  }
}
