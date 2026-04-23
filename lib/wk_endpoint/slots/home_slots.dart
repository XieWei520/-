import 'package:flutter/material.dart';

import '../../widgets/wk_screen_popup_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class HomeTopMenuContext {
  const HomeTopMenuContext({
    required this.hasConversations,
    required this.openCreateGroup,
    required this.openAddFriend,
    required this.openScan,
    required this.enterMultiSelect,
    required this.clearAllConversations,
  });

  final bool hasConversations;
  final VoidCallback openCreateGroup;
  final VoidCallback openAddFriend;
  final VoidCallback openScan;
  final VoidCallback enterMultiSelect;
  final VoidCallback clearAllConversations;
}

@immutable
class HomeTopMenuItem {
  const HomeTopMenuItem({
    required this.id,
    required this.title,
    this.assetIcon,
    this.icon,
    this.enabled = true,
    required this.onSelected,
  }) : assert(assetIcon != null || icon != null);

  final String id;
  final String title;
  final String? assetIcon;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onSelected;

  WKScreenPopupMenuItem<HomeTopMenuItem> toPopupMenuItem() {
    return WKScreenPopupMenuItem<HomeTopMenuItem>(
      value: this,
      title: title,
      assetIcon: assetIcon,
      icon: icon,
      enabled: enabled,
    );
  }
}

const homeTopMenuSlot =
    SlotDescriptor<HomeTopMenuContext, HomeTopMenuItem>('home.top_menu');
