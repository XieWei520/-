import 'package:flutter/material.dart';

import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/group_detail_slots.dart';

List<Widget> buildGroupDetailExtensions({
  required SlotRegistry registry,
  required GroupDetailExtensionPoint point,
  required String groupId,
  required int channelType,
}) {
  final items = registry.resolve(
    groupDetailExtensionSlot,
    GroupDetailExtensionContext(
      point: point,
      groupId: groupId,
      channelType: channelType,
    ),
  );

  return items
      .map((item) => Builder(builder: item.builder))
      .toList(growable: false);
}
