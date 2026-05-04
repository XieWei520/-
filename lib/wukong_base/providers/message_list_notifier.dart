import 'package:flutter/foundation.dart';
import '../entity/message.dart';

/// Message list state notifier
class MessageListNotifier extends ChangeNotifier {
  final Map<String, List<WKMessage>> _messages = {};

  List<WKMessage> getMessages(String channelId) {
    return _messages[channelId] ?? [];
  }

  void addMessage(String channelId, WKMessage message) {
    _messages[channelId] ??= [];
    _messages[channelId]!.add(message);
    notifyListeners();
  }

  void clearMessages(String channelId) {
    _messages[channelId]?.clear();
    notifyListeners();
  }
}
