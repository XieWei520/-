import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import '../core/utils/platform_utils.dart';
import 'wk_web_ui_tokens.dart';

class WKMainTopBar extends StatelessWidget {
  final Widget title;
  final Widget? leading;
  final List<Widget> actions;
  final Color backgroundColor;
  final double height;

  const WKMainTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const <Widget>[],
    this.backgroundColor = WKColors.homeBg,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isNarrowMobile =
        PlatformUtils.isMobile && MediaQuery.sizeOf(context).width < 420;
    final effectiveHeight = isNarrowMobile ? 56.0 : height;
    final effectiveTitleStyle = TextStyle(
      fontFamily: WKFontFamily.title,
      fontFamilyFallback: WKTypography.fontFamilyFallback,
      fontSize: isNarrowMobile ? 26 : 22,
      fontWeight: FontWeight.w700,
      color: WKColors.colorDark,
    );

    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: effectiveHeight,
          child: Row(
            children: [
              if (leading != null) ...[
                const SizedBox(width: 4),
                leading!,
                const SizedBox(width: 4),
              ] else
                const SizedBox(width: 15),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DefaultTextStyle(
                    style: effectiveTitleStyle,
                    child: title,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class WKTopBarActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final WKTopBarActionButtonVariant variant;
  final double size;

  const WKTopBarActionButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.padding = const EdgeInsets.only(right: 15),
    this.variant = WKTopBarActionButtonVariant.standard,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final isWarmSquare = variant == WKTopBarActionButtonVariant.warmSquare;
    final buttonSize = isWarmSquare ? size : 28.0;
    final radius = BorderRadius.circular(
      isWarmSquare ? WKWebRadius.control : 999,
    );
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: padding,
          child: SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: DecoratedBox(
              decoration: isWarmSquare
                  ? BoxDecoration(
                      color: WKWebColors.surfaceSoft,
                      borderRadius: radius,
                      border: Border.all(
                        color: WKWebColors.borderWarm,
                        width: 1.2,
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: WKWebColors.shadow,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    )
                  : const BoxDecoration(),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

enum WKTopBarActionButtonVariant { standard, warmSquare }
