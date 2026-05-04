import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';

class MessageLongPressMenu extends StatelessWidget {
  const MessageLongPressMenu({
    super.key,
    required this.messageType,
    required this.isFromMe,
    required this.canRecall,
    required this.onActionSelected,
  });

  final String messageType;
  final bool isFromMe;
  final bool canRecall;
  final ValueChanged<ChatSceneAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final actions = buildLegacyLongPressActionDescriptors(
      messageType: messageType,
      isFromMe: isFromMe,
      canRecall: canRecall,
    );
    return ChatMessageActionSheet(
      actions: actions,
      onSelected: onActionSelected,
    );
  }
}

Future<ChatSceneAction?> showMessageLongPressMenu({
  required BuildContext context,
  required Offset position,
  required String messageType,
  required bool isFromMe,
  required bool canRecall,
}) {
  final completer = Completer<ChatSceneAction?>();

  showModalBottomSheet<void>(
    context: context,
    builder: (_) => MessageLongPressMenu(
      messageType: messageType,
      isFromMe: isFromMe,
      canRecall: canRecall,
      onActionSelected: (action) {
        if (!completer.isCompleted) {
          completer.complete(action);
        }
      },
    ),
  ).whenComplete(() {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  return completer.future;
}
