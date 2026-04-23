import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_reference_assets.dart';

class WKTabShellItemData {
  final String label;
  final String normalIcon;
  final String selectedIcon;
  final int badgeCount;

  const WKTabShellItemData({
    required this.label,
    required this.normalIcon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });
}

class WKTabShell extends StatelessWidget {
  final int currentIndex;
  final List<Widget> pages;
  final List<WKTabShellItemData> items;
  final ValueChanged<int> onTap;

  const WKTabShell({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.items,
    required this.onTap,
  }) : assert(
         pages.length == items.length,
         'WKTabShell pages/items length mismatch.',
       );

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(
      MediaQuery.of(context).viewPadding.bottom,
      8.0,
    );

    return Scaffold(
      key: key ?? const ValueKey<String>('wk_tab_shell'),
      backgroundColor: WKColors.homeBg,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        color: WKColors.homeBg,
        padding: EdgeInsets.only(top: 4, bottom: bottomInset),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _WKTabBarItem(
                  data: items[index],
                  selected: currentIndex == index,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WKTabBarItem extends StatelessWidget {
  final WKTabShellItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _WKTabBarItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? const Color(0xFFFF5A33)
        : const Color(0xFFF3CDC2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 35,
                height: 35,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: WKReferenceAssets.image(
                        selected ? data.selectedIcon : data.normalIcon,
                        width: 35,
                        height: 35,
                      ),
                    ),
                    if (data.badgeCount > 0)
                      Positioned(
                        right: -12,
                        top: -2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: WKColors.reminderColor,
                            borderRadius: BorderRadius.circular(WKRadius.pill),
                          ),
                          child: Text(
                            data.badgeCount > 99 ? '99+' : '${data.badgeCount}',
                            style: const TextStyle(
                              fontFamily: WKFontFamily.primary,
                              color: WKColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
