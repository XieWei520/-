import 'package:flutter/material.dart';

const String customerServiceBadgeDefaultLabel = '\u5ba2\u670d';

class CustomerServiceBadge extends StatelessWidget {
  const CustomerServiceBadge({
    super.key,
    this.label,
    this.compact = false,
    this.padding,
    this.textStyle,
    this.borderRadius,
  });

  final String? label;
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label ?? customerServiceBadgeDefaultLabel;
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 4 : 5,
        );
    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(compact ? 999 : 12);
    final resolvedTextStyle =
        textStyle ??
        Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFEAFBFF),
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: compact ? 0.8 : 0.5,
          height: 1.0,
        ) ??
        TextStyle(
          color: const Color(0xFFEAFBFF),
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: compact ? 0.8 : 0.5,
          height: 1.0,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0C8BFF),
            Color(0xFF0867D7),
            Color(0xFF053B88),
          ],
        ),
        borderRadius: resolvedRadius,
        border: Border.all(color: const Color(0xFF8FE7FF), width: 0.9),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x3302478F),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: resolvedPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.support_agent_rounded,
              size: compact ? 11 : 13,
              color: const Color(0xFFBFF5FF),
            ),
            SizedBox(width: compact ? 3 : 4),
            Text(
              resolvedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolvedTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}