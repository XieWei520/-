import 'package:flutter/material.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';

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
    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
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
                    style: const TextStyle(
                      fontFamily: WKFontFamily.title,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: WKColors.colorDark,
                    ),
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

  const WKTopBarActionButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.padding = const EdgeInsets.only(right: 15),
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: padding,
          child: SizedBox(width: 28, height: 28, child: Center(child: child)),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}
