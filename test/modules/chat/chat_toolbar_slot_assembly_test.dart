import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_toolbar_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/chat_toolbar_menu.dart';

void main() {
  test(
    'chat toolbar installer exposes mobile ordered toolbar and functions',
    () {
      final registry = SlotRegistry();

      final toolbarItems = resolveChatToolbarItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: true,
          showFunctionPanel: true,
          isMobile: true,
          isDesktop: false,
          isWeb: false,
        ),
      );
      final functionItems = resolveChatFunctionItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: true,
          showFunctionPanel: true,
          isMobile: true,
          isDesktop: false,
          isWeb: false,
        ),
      );

      expect(toolbarItems.map((item) => item.sid), <String>[
        'wk_chat_toolbar_voice',
        'wk_chat_toolbar_emoji',
        'wk_chat_toolbar_album',
        'wk_chat_toolbar_more',
      ]);
      expect(
        toolbarItems
            .firstWhere((item) => item.sid == 'wk_chat_toolbar_emoji')
            .isSelected,
        isTrue,
      );
      expect(
        toolbarItems
            .firstWhere((item) => item.sid == 'wk_chat_toolbar_more')
            .isSelected,
        isTrue,
      );
      expect(functionItems.map((item) => item.sid), <String>[
        'chooseImg',
        'captureImg',
        'chooseFile',
        'sendLocation',
        'chooseCard',
      ]);
    },
  );

  test(
    'desktop exposes ordered toolbar and function items without capture image',
    () {
      final registry = SlotRegistry();
      final toolbarItems = resolveChatToolbarItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: false,
          isDesktop: true,
          isWeb: false,
        ),
      );
      final functionItems = resolveChatFunctionItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: false,
          isDesktop: true,
          isWeb: false,
        ),
      );

      expect(toolbarItems.map((item) => item.sid), <String>[
        'wk_chat_toolbar_voice',
        'wk_chat_toolbar_emoji',
        'wk_chat_toolbar_album',
        'wk_chat_toolbar_more',
      ]);
      expect(functionItems.map((item) => item.sid), <String>[
        'chooseImg',
        'chooseFile',
        'sendLocation',
        'chooseCard',
      ]);
    },
  );

  test('desktop keeps sendLocation but hides capture image', () {
    final registry = SlotRegistry();
    final items = resolveChatFunctionItems(
      registry,
      const ChatToolbarSlotContext(
        isGroup: false,
        showVoiceInput: false,
        showEmojiPanel: false,
        showFunctionPanel: true,
        isMobile: false,
        isDesktop: true,
        isWeb: false,
      ),
    );

    expect(items.map((item) => item.sid), contains('sendLocation'));
    expect(items.map((item) => item.sid), isNot(contains('captureImg')));
  });

  test(
    'group chats expose mention toolbar ordering and omit rich text function item',
    () {
      final registry = SlotRegistry();
      final toolbarItems = resolveChatToolbarItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: true,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: true,
          isDesktop: false,
          isWeb: false,
        ),
      );
      final functionItems = resolveChatFunctionItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: true,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: true,
          isDesktop: false,
          isWeb: false,
        ),
      );

      expect(toolbarItems.map((item) => item.sid), <String>[
        'wk_chat_toolbar_voice',
        'wk_chat_toolbar_emoji',
        'wk_chat_toolbar_album',
        'wk_chat_toolbar_mention',
        'wk_chat_toolbar_more',
      ]);
      expect(functionItems.map((item) => item.sid), contains('groupCall'));
      expect(
        functionItems.map((item) => item.sid),
        isNot(contains('composeRichText')),
      );
    },
  );

  test(
    'function resolver keeps builtin order and appends only non-builtin extensions',
    () {
      final registry = SlotRegistry();
      registry.register(
        chatFunctionSlot,
        SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
          id: 'custom.duplicate_choose_file',
          priority: 1000,
          build: (_) => ChatFunctionMenu(sid: 'chooseFile', text: 'duplicate'),
        ),
      );
      registry.register(
        chatFunctionSlot,
        SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
          id: 'custom.extra_action',
          priority: 90,
          build: (_) => ChatFunctionMenu(sid: 'customAction', text: 'custom'),
        ),
      );

      final items = resolveChatFunctionItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: false,
          isDesktop: true,
          isWeb: false,
        ),
      );

      expect(items.map((item) => item.sid), <String>[
        'chooseImg',
        'chooseFile',
        'sendLocation',
        'chooseCard',
        'customAction',
      ]);
    },
  );

  test(
    'web exposes ordered toolbar and function items without capture image',
    () {
      final registry = SlotRegistry();
      final toolbarItems = resolveChatToolbarItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: false,
          isDesktop: false,
          isWeb: true,
        ),
      );
      final functionItems = resolveChatFunctionItems(
        registry,
        const ChatToolbarSlotContext(
          isGroup: false,
          showVoiceInput: false,
          showEmojiPanel: false,
          showFunctionPanel: true,
          isMobile: false,
          isDesktop: false,
          isWeb: true,
        ),
      );

      expect(toolbarItems.map((item) => item.sid), <String>[
        'wk_chat_toolbar_emoji',
        'wk_chat_toolbar_album',
        'wk_chat_toolbar_more',
      ]);
      expect(functionItems.map((item) => item.sid), <String>[
        'chooseImg',
        'chooseFile',
        'sendLocation',
        'chooseCard',
      ]);
    },
  );
}
