import 'package:flutter/foundation.dart';

import '../conversation/conversation_activity_registry.dart';

class ChatConversationActivityBinding {
  ChatConversationActivityBinding({
    required ValueChanged<ConversationActivityState> onChanged,
    ConversationActivityRegistry? registry,
  }) : _onChanged = onChanged,
       _registry = registry ?? ConversationActivityRegistry.instance;

  final ConversationActivityRegistry _registry;
  final ValueChanged<ConversationActivityState> _onChanged;
  String? _channelId;
  int? _channelType;

  ConversationActivityState bind({
    required String channelId,
    required int channelType,
  }) {
    unbind();
    _channelId = channelId;
    _channelType = channelType;
    _registry.addConversationListener(
      channelId,
      channelType,
      _handleConversationActivityChanged,
    );
    return _registry.getState(channelId, channelType);
  }

  void unbind() {
    final channelId = _channelId;
    final channelType = _channelType;
    if (channelId == null || channelType == null) {
      return;
    }
    _registry.removeConversationListener(
      channelId,
      channelType,
      _handleConversationActivityChanged,
    );
    _channelId = null;
    _channelType = null;
  }

  void dispose() {
    unbind();
  }

  void _handleConversationActivityChanged() {
    final channelId = _channelId;
    final channelType = _channelType;
    if (channelId == null || channelType == null) {
      return;
    }
    _onChanged(_registry.getState(channelId, channelType));
  }
}
