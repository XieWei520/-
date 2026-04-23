import 'package:flutter/material.dart';

import '../../widgets/wk_avatar.dart';

class WKUserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double size;
  final BorderRadius? borderRadius;
  final bool isCircle;
  final VoidCallback? onTap;

  const WKUserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.size = 40,
    this.borderRadius,
    this.isCircle = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius =
        borderRadius ?? (isCircle ? null : BorderRadius.zero);
    return WKAvatar(
      url: avatarUrl,
      name: name,
      size: size,
      borderRadius: resolvedBorderRadius,
      onTap: onTap,
    );
  }
}

/// Avatar with online indicator
class WKUserAvatarWithIndicator extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double size;
  final bool isOnline;
  final VoidCallback? onTap;

  const WKUserAvatarWithIndicator({
    super.key,
    this.avatarUrl,
    this.name,
    this.size = 40,
    this.isOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WKUserAvatar(
          avatarUrl: avatarUrl,
          name: name,
          size: size,
          onTap: onTap,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
