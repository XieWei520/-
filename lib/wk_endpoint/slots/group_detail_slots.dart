import 'package:flutter/material.dart';

import '../core/slot_descriptor.dart';

enum GroupDetailExtensionPoint {
  msgRemind,
  msgSettings,
  groupAvatar,
  groupManage,
  chatPassword,
}

@immutable
class GroupDetailExtensionContext {
  const GroupDetailExtensionContext({
    required this.point,
    required this.groupId,
    required this.channelType,
  });

  final GroupDetailExtensionPoint point;
  final String groupId;
  final int channelType;
}

@immutable
class GroupDetailExtensionItem {
  const GroupDetailExtensionItem({
    required this.id,
    required this.builder,
  });

  final String id;
  final WidgetBuilder builder;
}

const groupDetailExtensionSlot = SlotDescriptor<
    GroupDetailExtensionContext,
    GroupDetailExtensionItem>('group.detail.extension');
