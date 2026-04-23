import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Duration _kAuthRouteTransitionDuration = Duration(milliseconds: 260);
const Duration _kAuthRouteReverseTransitionDuration = Duration(
  milliseconds: 220,
);

CustomTransitionPage<T> buildAuthRoutePage<T>({
  required LocalKey key,
  required Widget child,
  String? name,
  Object? arguments,
  String? restorationId,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionDuration: _kAuthRouteTransitionDuration,
    reverseTransitionDuration: _kAuthRouteReverseTransitionDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );
}
