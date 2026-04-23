import 'package:flutter/material.dart';

import 'wk_colors.dart';

class WKButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonStyle? style;
  final Widget? leading;

  const WKButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.style,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(WKColors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Text(text),
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonChild,
      ),
    );
  }
}

class WKTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? textColor;
  final double? fontSize;

  const WKTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: textColor, fontSize: fontSize);

    return TextButton(
      onPressed: onPressed,
      child: Text(text, style: textStyle),
    );
  }
}

class WKOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;
  final bool isFullWidth;

  const WKOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor,
    this.textColor,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = borderColor == null && textColor == null
        ? null
        : OutlinedButton.styleFrom(
            foregroundColor: textColor ?? WKColors.brand500,
            side: BorderSide(color: borderColor ?? WKColors.outlineStrong),
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(text),
      ),
    );
  }
}

class WKIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double? iconSize;
  final Color? backgroundColor;
  final bool isCircle;

  const WKIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.iconSize,
    this.backgroundColor,
    this.isCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: iconSize ?? 22,
      color: iconColor,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        shape: isCircle
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
