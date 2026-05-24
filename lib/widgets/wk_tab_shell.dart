import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/chat/chat_frame_jank_monitor.dart';
import 'liquid_glass_panel.dart';
import 'liquid_glass_tokens.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_reference_assets.dart';
import 'wk_web_ui_tokens.dart';

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
  final bool forceDesktopRailForTesting;

  const WKTabShell({
    super.key,
    required this.currentIndex,
    required this.pages,
    required this.items,
    required this.onTap,
    this.forceDesktopRailForTesting = false,
  }) : assert(
         pages.length == items.length,
         'WKTabShell pages/items length mismatch.',
       );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopRail = shouldUseDesktopRailShell(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
          viewportWidth: constraints.maxWidth,
          forceDesktopRail: forceDesktopRailForTesting,
        );
        if (useDesktopRail) {
          return _buildDesktopRailShell(context);
        }
        return _buildBottomTabShell(context);
      },
    );
  }

  Widget _buildBottomTabShell(BuildContext context) {
    final bottomInset = math.max(
      MediaQuery.of(context).viewPadding.bottom,
      8.0,
    );
    final isNarrowMobile = MediaQuery.sizeOf(context).width < 420;

    return Scaffold(
      key: key ?? const ValueKey<String>('wk_tab_shell'),
      backgroundColor: isNarrowMobile ? WKWebColors.pageWarm : WKColors.homeBg,
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        key: const ValueKey<String>('wk_tab_shell_bottom_bar'),
        decoration: BoxDecoration(
          color: isNarrowMobile ? WKWebColors.surface : WKColors.homeBg,
          border: isNarrowMobile
              ? const Border(top: BorderSide(color: WKWebColors.borderWarm))
              : null,
        ),
        padding: EdgeInsets.only(top: 6, bottom: bottomInset),
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

  Widget _buildDesktopRailShell(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: key ?? const ValueKey<String>('wk_tab_shell'),
      backgroundColor: dark
          ? LiquidGlassColors.darkBackground
          : LiquidGlassColors.lightBackground,
      body: LiquidGlassStage(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final shellWidth = viewportWidth;
            final shellHeight = math.max(
              0.0,
              viewportHeight - LiquidGlassSizes.appFrameViewportInset * 2,
            );

            return Center(
              child: _LiquidGlassFallbackFrame(
                width: shellWidth,
                height: shellHeight,
                child: Row(
                  children: [
                    Container(
                      key: const ValueKey<String>('wk_tab_shell_web_rail'),
                      width: LiquidGlassSizes.navRailWidth,
                      color: tokens.surface,
                      padding: const EdgeInsets.symmetric(vertical: WKSpace.md),
                      child: Column(
                        children: [
                          const _WKWebBrandMark(),
                          const SizedBox(height: WKSpace.lg),
                          for (var index = 0; index < items.length; index++)
                            _WKWebRailItem(
                              data: items[index],
                              selected: currentIndex == index,
                              onTap: () => onTap(index),
                            ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: tokens.border,
                    ),
                    Expanded(
                      key: const ValueKey<String>('wk_tab_shell_web_page_host'),
                      child: IndexedStack(
                        index: currentIndex,
                        sizing: StackFit.expand,
                        children: pages,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LiquidGlassFallbackFrame extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _LiquidGlassFallbackFrame({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!_hasProviderScope(context)) {
      return _buildFrame(disableBlur: false);
    }

    return Consumer(
      builder: (context, ref, _) {
        final disableGlassBlur = ref.watch(chatLiquidGlassFallbackProvider);
        return _buildFrame(disableBlur: disableGlassBlur);
      },
    );
  }

  Widget _buildFrame({required bool disableBlur}) {
    return LiquidGlassAppFrame(
      frameKey: const ValueKey<String>('wk_tab_shell_web_liquid_shell'),
      width: width,
      height: height,
      disableBlur: disableBlur,
      child: child,
    );
  }

  bool _hasProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } on StateError {
      return false;
    }
  }
}

@visibleForTesting
bool shouldUseDesktopRailShell({
  required bool isWeb,
  required TargetPlatform platform,
  required double viewportWidth,
  bool forceDesktopRail = false,
}) {
  return forceDesktopRail ||
      (WKWebBreakpoints.useDesktopWorkbench(viewportWidth) &&
          (isWeb || _isDesktopPlatform(platform)));
}

bool _isDesktopPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class _WKWebBrandMark extends StatelessWidget {
  const _WKWebBrandMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '信息平权',
      excludeFromSemantics: true,
      child: Semantics(
        label: '信息平权',
        child: ExcludeSemantics(
          child: Container(
            key: const ValueKey<String>('wk_tab_shell_brand_mark'),
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WKWebColors.action,
              borderRadius: BorderRadius.circular(WKWebRadius.control),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: WKWebColors.shadow,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              '信息\n平权',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: WKFontFamily.title,
                color: WKColors.white,
                fontSize: 12,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
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
    final isNarrowMobile = MediaQuery.sizeOf(context).width < 420;
    final labelColor = selected
        ? WKWebColors.action
        : WKWebColors.textSecondary;

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
                      child:
                          (selected ? data.selectedIcon : data.normalIcon)
                              .isNotEmpty
                          ? WKReferenceAssets.image(
                              selected ? data.selectedIcon : data.normalIcon,
                              width: 35,
                              height: 35,
                              tint: isNarrowMobile ? labelColor : null,
                            )
                          : Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: labelColor,
                              size: 24,
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WKWebRailItem extends StatelessWidget {
  final WKTabShellItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _WKWebRailItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? LiquidGlassColors.darkPrimary
        : LiquidGlassColors.primary;
    final iconColor = selected ? primary : tokens.textSecondary;
    final asset = selected ? data.selectedIcon : data.normalIcon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: WKSpace.xs / 2),
      child: Tooltip(
        message: data.label,
        child: Semantics(
          button: true,
          selected: selected,
          label: data.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(WKWebRadius.control),
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: dark ? 0.16 : 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(WKWebRadius.control),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (asset.isNotEmpty)
                      WKReferenceAssets.image(
                        asset,
                        width: 24,
                        height: 24,
                        tint: iconColor,
                      )
                    else
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: iconColor,
                        size: 24,
                      ),
                    if (data.badgeCount > 0)
                      Positioned(
                        right: -12,
                        top: -10,
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
            ),
          ),
        ),
      ),
    );
  }
}
