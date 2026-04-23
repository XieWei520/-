import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

import '../../data/models/wk_custom_content.dart';
import 'chat_action_definition.dart';

sealed class ChatActionDispatchResult {
  const ChatActionDispatchResult();
}

class ChatActionDispatchContext {
  const ChatActionDispatchContext({
    this.context,
    this.channelId = '',
    this.channelType = 0,
    this.channelName,
  });

  final BuildContext? context;
  final String channelId;
  final int channelType;
  final String? channelName;
}

class ChatActionNoopResult extends ChatActionDispatchResult {
  const ChatActionNoopResult();
}

class ChatActionMessageResult extends ChatActionDispatchResult {
  const ChatActionMessageResult(this.content);

  final WKMessageContent content;
}

class ChatActionDispatcher {
  const ChatActionDispatcher({
    required this.pickImage,
    required this.pickFile,
    required this.pickLocation,
    required this.pickCard,
    required this.pickRichText,
  });

  final Future<WKImageContent?> Function(ChatActionDispatchContext context)
  pickImage;
  final Future<WKFileContent?> Function(ChatActionDispatchContext context)
  pickFile;
  final Future<WKLocationContent?> Function(ChatActionDispatchContext context)
  pickLocation;
  final Future<WKCardContent?> Function(ChatActionDispatchContext context)
  pickCard;
  final Future<WKRichTextContent?> Function(ChatActionDispatchContext context)
  pickRichText;

  Future<ChatActionDispatchResult> dispatch(
    ChatActionId id,
    ChatActionDispatchContext context,
  ) async {
    switch (id) {
      case ChatActionId.chooseImage:
        final content = await pickImage(context);
        return content == null
            ? const ChatActionNoopResult()
            : ChatActionMessageResult(content);
      case ChatActionId.chooseFile:
        final content = await pickFile(context);
        return content == null
            ? const ChatActionNoopResult()
            : ChatActionMessageResult(content);
      case ChatActionId.sendLocation:
        final content = await pickLocation(context);
        return content == null
            ? const ChatActionNoopResult()
            : ChatActionMessageResult(content);
      case ChatActionId.chooseCard:
        final content = await pickCard(context);
        return content == null
            ? const ChatActionNoopResult()
            : ChatActionMessageResult(content);
      case ChatActionId.composeRichText:
        final content = await pickRichText(context);
        return content == null
            ? const ChatActionNoopResult()
            : ChatActionMessageResult(content);
      default:
        return const ChatActionNoopResult();
    }
  }
}
