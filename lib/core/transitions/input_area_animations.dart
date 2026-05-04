import 'package:flutter/material.dart';

/// Animated input area transition helpers.
///
/// These widgets provide smooth transitions for common input area changes:
/// - Keyboard show/hide with AnimatedPadding
/// - Voice/text mode switch with AnimatedSwitcher
/// - @mention popup with SlideTransition
/// - Emoji panel with AnimatedContainer

/// Wraps the input area with animated padding that smoothly adjusts
/// when the keyboard appears/disappears.
class AnimatedKeyboardPadding extends StatelessWidget {
  const AnimatedKeyboardPadding({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: duration,
      curve: curve,
      child: child,
    );
  }
}

/// Animated toggle between voice and text input modes.
class VoiceTextToggle extends StatelessWidget {
  const VoiceTextToggle({
    super.key,
    required this.isVoiceMode,
    required this.voiceWidget,
    required this.textWidget,
    this.duration = const Duration(milliseconds: 200),
  });

  final bool isVoiceMode;
  final Widget voiceWidget;
  final Widget textWidget;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: isVoiceMode
          ? KeyedSubtree(key: const ValueKey('voice'), child: voiceWidget)
          : KeyedSubtree(key: const ValueKey('text'), child: textWidget),
    );
  }
}

/// Animated emoji/sticker panel that slides up with height transition.
class AnimatedEmojiPanel extends StatelessWidget {
  const AnimatedEmojiPanel({
    super.key,
    required this.isVisible,
    required this.height,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
  });

  final bool isVisible;
  final double height;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      height: isVisible ? height : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: child,
    );
  }
}

/// Animated mention suggestion popup that slides up from the bottom.
class MentionSuggestionPopup extends StatelessWidget {
  const MentionSuggestionPopup({
    super.key,
    required this.isVisible,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  final bool isVisible;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: duration,
        child: child,
      ),
    );
  }
}
