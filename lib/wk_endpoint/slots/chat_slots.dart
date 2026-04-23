import 'package:flutter/widgets.dart';

import '../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class ChatToolbarSlotContext {
  const ChatToolbarSlotContext({
    required this.isGroup,
    required this.showVoiceInput,
    required this.showEmojiPanel,
    required this.showFunctionPanel,
    required this.isMobile,
    required this.isDesktop,
    required this.isWeb,
  });

  final bool isGroup;
  final bool showVoiceInput;
  final bool showEmojiPanel;
  final bool showFunctionPanel;
  final bool isMobile;
  final bool isDesktop;
  final bool isWeb;
}

const chatToolbarSlot = SlotDescriptor<ChatToolbarSlotContext, ChatToolBarMenu>(
  'chat.toolbar',
);

const chatFunctionSlot =
    SlotDescriptor<ChatToolbarSlotContext, ChatFunctionMenu>('chat.function');
