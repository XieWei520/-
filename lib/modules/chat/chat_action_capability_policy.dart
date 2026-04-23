import 'package:wukong_im_app/modules/chat/chat_action_definition.dart';

class ChatActionCapabilityContext {
  const ChatActionCapabilityContext({
    required this.isGroup,
    required this.isMobile,
    required this.isDesktop,
    required this.isWeb,
  }) : assert(
         (isMobile ? 1 : 0) + (isDesktop ? 1 : 0) + (isWeb ? 1 : 0) == 1,
         'Exactly one platform flag must be true among '
         'isMobile/isDesktop/isWeb.',
       );

  final bool isGroup;
  final bool isMobile;
  final bool isDesktop;
  final bool isWeb;
}

class ChatActionCapabilityPolicy {
  List<ChatActionDefinition> resolve(ChatActionCapabilityContext context) {
    final actions = <ChatActionDefinition>[
      chatChooseImageAction,
      chatChooseFileAction,
      chatSendLocationAction,
      chatChooseCardAction,
    ];
    if (context.isMobile) {
      actions.insert(1, chatCaptureImageAction);
    }
    if (context.isGroup) {
      actions.add(chatGroupCallAction);
    } else {
      actions
        ..add(chatAudioCallAction)
        ..add(chatVideoCallAction);
    }
    return actions;
  }
}
