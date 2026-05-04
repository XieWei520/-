import 'package:flutter/material.dart';

@immutable
class WKBrandedIconSpec {
  const WKBrandedIconSpec({
    required this.icon,
    required this.startColor,
    required this.endColor,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color startColor;
  final Color endColor;
  final double iconSize;
}

Widget buildWKBrandedIcon(
  WKBrandedIconSpec spec, {
  double size = 40,
  double radius = 14,
}) {
  final borderRadius = BorderRadius.circular(radius);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[spec.startColor, spec.endColor],
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: spec.endColor.withValues(alpha: 0.24),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Positioned(
          left: 6,
          right: 6,
          top: 5,
          child: Container(
            height: size * 0.34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius - 4),
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        ),
        Icon(spec.icon, size: spec.iconSize, color: Colors.white),
      ],
    ),
  );
}
