import 'package:flutter/foundation.dart';
import 'package:wukong_im_app/core/constants/im_constants.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

enum ChatSceneAction {
  reply,
  forward,
  copy,
  edit,
  favorite,
  select,
  delete,
  pin,
  unpin,
  recall,
  react,
}

@immutable
class ChatMessageActionDescriptor {
  const ChatMessageActionDescriptor({
    required this.action,
    required this.label,
    required this.order,
  });

  final ChatSceneAction action;
  final String label;
  // Stable Android action rank. Gaps are intentional when hidden actions
  // are omitted, so consumers must not assume this matches the list index.
  final int order;
}

const ChatMessageActionDescriptor _replyAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.reply,
  label: '\u56de\u590d',
  order: 0,
);
const ChatMessageActionDescriptor _forwardAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.forward,
  label: '\u8f6c\u53d1',
  order: 1,
);
const ChatMessageActionDescriptor _copyAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.copy,
  label: '\u590d\u5236',
  order: 2,
);
const ChatMessageActionDescriptor _editAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.edit,
  label: '\u7f16\u8f91',
  order: 3,
);
const ChatMessageActionDescriptor _favoriteAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.favorite,
  label: '\u6536\u85cf',
  order: 4,
);
const ChatMessageActionDescriptor _selectAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.select,
  label: '\u591a\u9009',
  order: 5,
);
const ChatMessageActionDescriptor _deleteAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.delete,
  label: '\u5220\u9664',
  order: 6,
);
const ChatMessageActionDescriptor _pinAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.pin,
  label: '\u7f6e\u9876',
  order: 9,
);
const ChatMessageActionDescriptor _unpinAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.unpin,
  label: '\u53d6\u6d88\u7f6e\u9876',
  order: 9,
);
const ChatMessageActionDescriptor _recallAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.recall,
  label: '\u64a4\u56de',
  order: 7,
);
const ChatMessageActionDescriptor _reactAction = ChatMessageActionDescriptor(
  action: ChatSceneAction.react,
  label: '\u8868\u60c5\u56de\u5e94',
  order: 8,
);

List<ChatMessageActionDescriptor> buildChatMessageActionDescriptors({
  required WKMsg message,
  required bool isSelf,
  required bool canRecall,
  bool canPin = false,
}) {
  if (_isNonInteractiveMessage(message)) {
    return const <ChatMessageActionDescriptor>[];
  }
  return _buildInteractiveActionDescriptors(
    includeCopy: message.contentType == MessageContentType.text,
    includeEdit: isSelf && message.contentType == MessageContentType.text,
    includeDelete: isSelf,
    includeRecall: isSelf && canRecall,
    includePin: canPin && _supportsPinnedToggle(message),
    isPinned: (message.wkMsgExtra?.isPinned ?? 0) == 1,
  );
}

List<ChatMessageActionDescriptor> buildLegacyLongPressActionDescriptors({
  required String messageType,
  required bool isFromMe,
  required bool canRecall,
  bool canPin = false,
  bool isPinned = false,
}) {
  if (messageType == 'system') {
    return const <ChatMessageActionDescriptor>[];
  }
  return _buildInteractiveActionDescriptors(
    includeCopy: messageType == 'text',
    includeEdit: isFromMe && messageType == 'text',
    includeDelete: isFromMe,
    includeRecall: isFromMe && canRecall,
    includePin: canPin,
    isPinned: isPinned,
  );
}

bool _isNonInteractiveMessage(WKMsg message) {
  return message.isDeleted != 0 ||
      (message.wkMsgExtra?.revoke ?? 0) != 0 ||
      message.contentType == MessageContentType.systemMsg;
}

bool _supportsPinnedToggle(WKMsg message) {
  return message.messageID.trim().isNotEmpty && message.messageSeq > 0;
}

List<ChatMessageActionDescriptor> _buildInteractiveActionDescriptors({
  required bool includeCopy,
  required bool includeEdit,
  required bool includeDelete,
  required bool includeRecall,
  required bool includePin,
  required bool isPinned,
}) {
  final actions = <ChatMessageActionDescriptor>[
    _replyAction,
    _forwardAction,
  ];
  if (includeCopy) {
    actions.add(_copyAction);
  }
  if (includeEdit) {
    actions.add(_editAction);
  }
  actions
    ..add(_favoriteAction)
    ..add(_selectAction);
  if (includeDelete) {
    actions.add(_deleteAction);
  }
  if (includeRecall) {
    actions.add(_recallAction);
  }
  actions.add(_reactAction);
  if (includePin) {
    actions.add(isPinned ? _unpinAction : _pinAction);
  }
  return List<ChatMessageActionDescriptor>.unmodifiable(actions);
}
