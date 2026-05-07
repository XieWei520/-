import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/group_detail_slots.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_slot_assembly.dart';

void main() {
  test(
    'group detail resolver only returns widgets for the requested point',
    () {
      final registry = SlotRegistry();
      registry.register(
        groupDetailExtensionSlot,
        SlotEntry<GroupDetailExtensionContext, GroupDetailExtensionItem>(
          id: 'group.msg_settings',
          priority: 20,
          predicate: (context) =>
              context.point == GroupDetailExtensionPoint.msgSettings,
          build: (_) => GroupDetailExtensionItem(
            id: 'group.msg_settings',
            builder: (_) => const Text('msg settings'),
          ),
        ),
      );

      final widgets = buildGroupDetailExtensions(
        registry: registry,
        point: GroupDetailExtensionPoint.msgSettings,
        groupId: 'g-1',
        channelType: 1,
      );

      expect(widgets, hasLength(1));
    },
  );
}
