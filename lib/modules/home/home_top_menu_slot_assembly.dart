import 'package:flutter/material.dart';

import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/home_slots.dart';

void ensureHomeTopMenuSlots(SlotRegistry registry) {
  if (!registry.containsId(homeTopMenuSlot, 'home.create_group')) {
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.create_group',
        priority: 200,
        build: (context) => HomeTopMenuItem(
          id: 'home.create_group',
          title: '创建群聊',
          assetIcon: WKReferenceAssets.menuChats,
          onSelected: context.openCreateGroup,
        ),
      ),
    );
  }
  if (!registry.containsId(homeTopMenuSlot, 'home.add_friend')) {
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.add_friend',
        priority: 99,
        build: (context) => HomeTopMenuItem(
          id: 'home.add_friend',
          title: '添加好友',
          assetIcon: WKReferenceAssets.menuInvite,
          onSelected: context.openAddFriend,
        ),
      ),
    );
  }
  if (!registry.containsId(homeTopMenuSlot, 'home.scan')) {
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.scan',
        priority: 98,
        build: (context) => HomeTopMenuItem(
          id: 'home.scan',
          title: '扫一扫',
          assetIcon: WKReferenceAssets.menuScan,
          onSelected: context.openScan,
        ),
      ),
    );
  }
  if (!registry.containsId(homeTopMenuSlot, 'home.multi_select')) {
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.multi_select',
        priority: 70,
        build: (context) => HomeTopMenuItem(
          id: 'home.multi_select',
          title: '多选',
          icon: Icons.playlist_add_check_circle_outlined,
          enabled: context.hasConversations,
          onSelected: context.enterMultiSelect,
        ),
      ),
    );
  }
  if (!registry.containsId(homeTopMenuSlot, 'home.clear_all')) {
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.clear_all',
        priority: 60,
        build: (context) => HomeTopMenuItem(
          id: 'home.clear_all',
          title: '清空全部会话',
          icon: Icons.delete_sweep_outlined,
          enabled: context.hasConversations,
          onSelected: context.clearAllConversations,
        ),
      ),
    );
  }
}

List<HomeTopMenuItem> resolveHomeTopMenuItems(
  SlotRegistry registry,
  HomeTopMenuContext context,
) {
  ensureHomeTopMenuSlots(registry);
  return registry.resolve(homeTopMenuSlot, context);
}
