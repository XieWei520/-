import 'chat_action_capability_policy.dart';
import 'chat_action_definition.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/chat_slots.dart';
import '../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';

final ChatActionCapabilityPolicy _chatActionCapabilityPolicy =
    ChatActionCapabilityPolicy();

final Map<String, String> _builtinFunctionIcons = <String, String>{
  'chooseImg': WKReferenceAssets.chatFunctionAlbum,
  'captureImg': WKReferenceAssets.camera,
  'chooseFile': WKReferenceAssets.chatFunctionFile,
  'sendLocation': WKReferenceAssets.chatFunctionLocation,
  'chooseCard': WKReferenceAssets.chatFunctionCard,
  'groupCall': WKReferenceAssets.chatCallVideo,
};

final Set<String> _builtinFunctionSids = _builtinFunctionIcons.keys.toSet();

void ensureChatToolbarSlots(SlotRegistry registry) {
  if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_voice')) {
    registry.register(
      chatToolbarSlot,
      SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
        id: 'wk_chat_toolbar_voice',
        priority: 100,
        predicate: (context) => !context.isWeb,
        build: (context) => ChatToolBarMenu(
          sid: 'wk_chat_toolbar_voice',
          icon: WKReferenceAssets.chatToolbarVoice,
          isSelected: context.showVoiceInput,
        ),
      ),
    );
  }

  if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_emoji')) {
    registry.register(
      chatToolbarSlot,
      SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
        id: 'wk_chat_toolbar_emoji',
        priority: 99,
        build: (context) => ChatToolBarMenu(
          sid: 'wk_chat_toolbar_emoji',
          icon: WKReferenceAssets.chatToolbarEmoji,
          isSelected: context.showEmojiPanel,
        ),
      ),
    );
  }

  if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_album')) {
    registry.register(
      chatToolbarSlot,
      SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
        id: 'wk_chat_toolbar_album',
        priority: 98,
        build: (_) => ChatToolBarMenu(
          sid: 'wk_chat_toolbar_album',
          icon: WKReferenceAssets.chatToolbarAlbum,
        ),
      ),
    );
  }

  if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_mention')) {
    registry.register(
      chatToolbarSlot,
      SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
        id: 'wk_chat_toolbar_mention',
        priority: 97,
        predicate: (context) => context.isGroup,
        build: (_) => ChatToolBarMenu(
          sid: 'wk_chat_toolbar_mention',
          icon: WKReferenceAssets.chatToolbarMention,
        ),
      ),
    );
  }

  if (!registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_more')) {
    registry.register(
      chatToolbarSlot,
      SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
        id: 'wk_chat_toolbar_more',
        priority: 96,
        build: (context) => ChatToolBarMenu(
          sid: 'wk_chat_toolbar_more',
          icon: WKReferenceAssets.chatToolbarMore,
          isSelected: context.showFunctionPanel,
        ),
      ),
    );
  }

  if (!registry.containsId(chatFunctionSlot, 'chat_function.choose_img')) {
    registry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.choose_img',
        priority: 100,
        predicate: (context) => _supportsFunctionAction(context, 'chooseImg'),
        build: (_) => ChatFunctionMenu(
          sid: 'chooseImg',
          icon: WKReferenceAssets.chatFunctionAlbum,
          text: '\u56fe\u7247',
        ),
      ),
    );
  }

  if (!registry.containsId(chatFunctionSlot, 'chat_function.capture_img')) {
    registry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.capture_img',
        priority: 99,
        predicate: (context) => _supportsFunctionAction(context, 'captureImg'),
        build: (_) => ChatFunctionMenu(
          sid: 'captureImg',
          icon: WKReferenceAssets.camera,
          text: '\u62cd\u7167',
        ),
      ),
    );
  }

  if (!registry.containsId(chatFunctionSlot, 'chat_function.choose_file')) {
    registry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.choose_file',
        priority: 98,
        predicate: (context) => _supportsFunctionAction(context, 'chooseFile'),
        build: (_) => ChatFunctionMenu(
          sid: 'chooseFile',
          icon: WKReferenceAssets.chatFunctionFile,
          text: '\u6587\u4ef6',
        ),
      ),
    );
  }

  if (!registry.containsId(chatFunctionSlot, 'chat_function.send_location')) {
    registry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.send_location',
        priority: 97,
        predicate: (context) =>
            _supportsFunctionAction(context, 'sendLocation'),
        build: (_) => ChatFunctionMenu(
          sid: 'sendLocation',
          icon: WKReferenceAssets.chatFunctionLocation,
          text: '\u4f4d\u7f6e',
        ),
      ),
    );
  }

  if (!registry.containsId(chatFunctionSlot, 'chat_function.choose_card')) {
    registry.register(
      chatFunctionSlot,
      SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
        id: 'chat_function.choose_card',
        priority: 96,
        predicate: (context) => _supportsFunctionAction(context, 'chooseCard'),
        build: (_) => ChatFunctionMenu(
          sid: 'chooseCard',
          icon: WKReferenceAssets.chatFunctionCard,
          text: '\u540d\u7247',
        ),
      ),
    );
  }
}

List<ChatToolBarMenu> resolveChatToolbarItems(
  SlotRegistry registry,
  ChatToolbarSlotContext context,
) {
  ensureChatToolbarSlots(registry);
  return registry.resolve(chatToolbarSlot, context);
}

List<ChatFunctionMenu> resolveChatFunctionItems(
  SlotRegistry registry,
  ChatToolbarSlotContext context,
) {
  ensureChatToolbarSlots(registry);
  final builtinItems = _resolveBuiltinFunctionItems(context);
  final extensionItems = registry.resolve(chatFunctionSlot, context);
  return <ChatFunctionMenu>[
    ...builtinItems,
    ...extensionItems.where((item) => !_builtinFunctionSids.contains(item.sid)),
  ];
}

bool _supportsFunctionAction(ChatToolbarSlotContext context, String sid) {
  final resolvedActions = _resolveCapabilityActions(context);
  return resolvedActions.any((item) => item.functionSid == sid);
}

List<ChatFunctionMenu> _resolveBuiltinFunctionItems(
  ChatToolbarSlotContext context,
) {
  final resolvedActions = _resolveCapabilityActions(context);
  final items = <ChatFunctionMenu>[];
  for (final action in resolvedActions) {
    final icon = _builtinFunctionIcons[action.functionSid];
    if (icon == null) {
      continue;
    }
    items.add(
      ChatFunctionMenu(sid: action.functionSid, icon: icon, text: action.label),
    );
  }
  return items;
}

List<ChatActionDefinition> _resolveCapabilityActions(
  ChatToolbarSlotContext context,
) {
  final resolvedActions = _chatActionCapabilityPolicy.resolve(
    ChatActionCapabilityContext(
      isGroup: context.isGroup,
      isMobile: context.isMobile,
      isDesktop: context.isDesktop,
      isWeb: context.isWeb,
    ),
  );
  return resolvedActions;
}
