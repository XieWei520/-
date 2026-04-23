import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';

class CustomerServiceBadge extends StatelessWidget {
  const CustomerServiceBadge({
    super.key,
    this.label = '客服',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WKColors.brand500,
        borderRadius: BorderRadius.circular(compact ? 999 : 12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F1856E7),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.support_agent_rounded,
              size: compact ? 11 : 13,
              color: WKColors.white,
            ),
            SizedBox(width: compact ? 3 : 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: WKColors.white,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                letterSpacing: compact ? 0.5 : 0.3,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
