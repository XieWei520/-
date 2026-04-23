import 'package:flutter/foundation.dart';
import '../entity/conversation.dart';

/// Conversation list state notifier
class ConversationListNotifier extends ChangeNotifier {
  List<WKConversation> _conversations = [];

  List<WKConversation> get conversations => _conversations;

  void setConversations(List<WKConversation> conversations) {
    _conversations = conversations;
    notifyListeners();
  }

  void addConversation(WKConversation conversation) {
    _conversations.insert(0, conversation);
    notifyListeners();
  }

  void updateConversation(WKConversation conversation) {
    final index = _conversations.indexWhere((c) => c.channelId == conversation.channelId);
    if (index >= 0) {
      _conversations[index] = conversation;
      notifyListeners();
    }
  }
}
