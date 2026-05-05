import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_top_menu_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/home_slots.dart';

void main() {
  test('home popup installer exposes Android ordered actions', () {
    final registry = SlotRegistry();

    final items = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: false,
        openCreateGroup: () {},
        openAddFriend: () {},
        openScan: () {},
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );

    expect(items.map((item) => item.id), <String>[
      'home.create_group',
      'home.add_friend',
      'home.scan',
      'home.multi_select',
      'home.clear_all',
    ]);
    expect(
      items.where((item) => !item.enabled).map((item) => item.id),
      <String>['home.multi_select', 'home.clear_all'],
    );
  });

  test('home popup installer keeps built-ins when some ids pre-registered', () {
    final registry = SlotRegistry();
    registry.register(
      homeTopMenuSlot,
      SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
        id: 'home.create_group',
        priority: 999,
        build: (_) => HomeTopMenuItem(
          id: 'home.create_group',
          title: 'Custom create',
          icon: Icons.group_add_outlined,
          onSelected: () {},
        ),
      ),
    );

    final items = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: true,
        openCreateGroup: () {},
        openAddFriend: () {},
        openScan: () {},
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );

    expect(items.map((item) => item.id).toSet(), <String>{
      'home.create_group',
      'home.add_friend',
      'home.scan',
      'home.multi_select',
      'home.clear_all',
    });
    expect(items.length, 5);
  });

  test('home popup installer is idempotent and wires callbacks', () {
    final registry = SlotRegistry();
    var tapped = false;

    resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: true,
        openCreateGroup: () {},
        openAddFriend: () {
          tapped = true;
        },
        openScan: () {},
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );
    final secondPass = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: true,
        openCreateGroup: () {},
        openAddFriend: () {
          tapped = true;
        },
        openScan: () {},
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );

    expect(secondPass.length, 5);
    final addFriend = secondPass.firstWhere(
      (item) => item.id == 'home.add_friend',
    );
    addFriend.onSelected();
    expect(tapped, isTrue);
  });
}
