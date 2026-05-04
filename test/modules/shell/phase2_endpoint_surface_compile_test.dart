import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_toolbar_slot_assembly.dart';
import 'package:wukong_im_app/modules/contacts/contacts_slot_assembly.dart';
import 'package:wukong_im_app/modules/home/home_top_menu_slot_assembly.dart';
import 'package:wukong_im_app/modules/user/user_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/providers/slot_registry_provider.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/group_detail_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/home_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/settings_slots.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_slot_assembly.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_slot_assembly.dart';

void main() {
  test('phase2 installers are idempotent against one shared registry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(slotRegistryProvider);

    ensureHomeTopMenuSlots(registry);
    ensureHomeTopMenuSlots(registry);
    ensureContactsHeaderSlots(registry);
    ensureContactsHeaderSlots(registry);
    ensurePersonalCenterSlots(registry);
    ensurePersonalCenterSlots(registry);
    ensureSettingsSections(registry);
    ensureSettingsSections(registry);
    ensureChatToolbarSlots(registry);
    ensureChatToolbarSlots(registry);

    expect(registry.containsId(homeTopMenuSlot, 'home.create_group'), isTrue);
    expect(registry.containsId(contactsHeaderSlot, 'contacts.friend'), isTrue);
    expect(
      registry.containsId(personalCenterSlot, 'personal_center_currency'),
      isTrue,
    );
    expect(
      registry.containsId(settingsSectionSlot, 'settings.appearance'),
      isTrue,
    );
    expect(
      registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_voice'),
      isTrue,
    );
  });

  test('group detail extension slot accepts late registrations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(slotRegistryProvider);

    registry.register(
      groupDetailExtensionSlot,
      SlotEntry<GroupDetailExtensionContext, GroupDetailExtensionItem>(
        id: 'group.msg_settings',
        predicate: (context) =>
            context.point == GroupDetailExtensionPoint.msgSettings,
        build: (_) => GroupDetailExtensionItem(
          id: 'group.msg_settings',
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    final items = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.msgSettings,
      groupId: 'g-1',
      channelType: 1,
    );

    expect(items, hasLength(1));
  });
}
