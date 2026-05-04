import 'package:flutter/material.dart';

import '../motion/chat_motion.dart';

/// Reusable page transition helpers for the app.
///
/// Provides shared-element (Hero) transitions, fade transitions,
/// and slide transitions consistent with the app's design language.

/// Push a page with a fade-through transition (Material Design motion).
Future<T?> pushWithFadeThrough<T>(
  BuildContext context,
  Widget page, {
  Duration? duration,
}) {
  final motion = ChatMotion.of(context);
  final transitionDuration =
      duration ?? motion.duration(ChatMotionDurations.pageStandard);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
      transitionDuration: transitionDuration,
      reverseTransitionDuration: transitionDuration,
    ),
  );
}

/// Push a page with a slide-up + fade transition (for modals, detail pages).
Future<T?> pushWithSlideUp<T>(
  BuildContext context,
  Widget page, {
  Duration? duration,
}) {
  final motion = ChatMotion.of(context);
  final transitionDuration =
      duration ?? motion.duration(ChatMotionDurations.pageEmphasized);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: ChatMotionCurves.emphasized,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      transitionDuration: transitionDuration,
      reverseTransitionDuration: motion.duration(
        ChatMotionDurations.pageReverse,
      ),
    ),
  );
}

/// Push a page with a shared-axis horizontal transition (for navigation).
Future<T?> pushWithSharedAxisX<T>(
  BuildContext context,
  Widget page, {
  Duration? duration,
}) {
  final motion = ChatMotion.of(context);
  final transitionDuration =
      duration ?? motion.duration(ChatMotionDurations.pageStandard);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: ChatMotionCurves.sharedAxis,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.25, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      transitionDuration: transitionDuration,
      reverseTransitionDuration: motion.duration(
        ChatMotionDurations.pageReverse,
      ),
    ),
  );
}

/// A scale-and-fade transition for opening a detail view from a list item.
/// Pairs well with Hero widgets for shared-element transitions.
Future<T?> pushWithScaleFade<T>(
  BuildContext context,
  Widget page, {
  Duration? duration,
}) {
  final motion = ChatMotion.of(context);
  final transitionDuration =
      duration ?? motion.duration(ChatMotionDurations.pageEmphasized);
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: ChatMotionCurves.emphasized,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: transitionDuration,
      reverseTransitionDuration: motion.duration(
        ChatMotionDurations.pageReverse,
      ),
    ),
  );
}

/// Generate a unique Hero tag for a conversation list avatar.
String conversationAvatarHeroTag(String channelId, int channelType) {
  return 'conv-avatar-$channelId-$channelType';
}

/// Generate a unique Hero tag for a chat image message.
String chatImageHeroTag(String messageId) {
  return 'chat-image-$messageId';
}
