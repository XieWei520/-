import 'package:flutter/material.dart';

const String vipBadgeDefaultLabel = 'VIP商家';

class VipBadge extends StatelessWidget {
  const VipBadge({
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
    final resolvedLabel = label ?? vipBadgeDefaultLabel;
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
          color: const Color(0xFFF7E7A8),
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: compact ? 0.8 : 0.5,
          height: 1.0,
        ) ??
        TextStyle(
          color: const Color(0xFFF7E7A8),
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
            Color(0xFF2F2A1F),
            Color(0xFF171410),
            Color(0xFF070707),
          ],
        ),
        borderRadius: resolvedRadius,
        border: Border.all(color: const Color(0xFFD6BA62), width: 0.9),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x3323180A),
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
              Icons.workspace_premium_rounded,
              size: compact ? 11 : 13,
              color: const Color(0xFFFFD978),
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
