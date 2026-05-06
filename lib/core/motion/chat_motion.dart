import 'package:flutter/material.dart';

@immutable
class ChatMotionDuration {
  const ChatMotionDuration(this.value);

  final Duration value;

  Duration resolve({bool disableAnimations = false}) {
    return disableAnimations ? Duration.zero : value;
  }
}

class ChatMotionDurations {
  ChatMotionDurations._();

  /// Short feedback for lightweight IM micro-interactions.
  static const ChatMotionDuration fast = ChatMotionDuration(
    Duration(milliseconds: 160),
  );

  /// Default state and lightweight component transition duration.
  static const ChatMotionDuration normal = ChatMotionDuration(
    Duration(milliseconds: 300),
  );

  /// Press/scale feedback duration for touch or pointer-down affordances.
  static const ChatMotionDuration pressedScale = ChatMotionDuration(
    Duration(milliseconds: 120),
  );

  /// Compatibility alias for pre-existing micro-interaction callers.
  static const ChatMotionDuration micro = fast;

  static const ChatMotionDuration messageEnter = ChatMotionDuration(
    Duration(milliseconds: 260),
  );

  /// Compatibility alias for read/send status transitions.
  static const ChatMotionDuration statusChange = normal;

  static const ChatMotionDuration badgeBounce = ChatMotionDuration(
    Duration(milliseconds: 400),
  );

  /// Compatibility alias for standard page transitions.
  static const ChatMotionDuration pageStandard = normal;

  static const ChatMotionDuration pageEmphasized = ChatMotionDuration(
    Duration(milliseconds: 350),
  );
  static const ChatMotionDuration pageReverse = ChatMotionDuration(
    Duration(milliseconds: 250),
  );
}

class ChatMotionCurves {
  ChatMotionCurves._();

  static const Curve messageEnter = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve sharedAxis = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve statusShake = Curves.easeInOut;
}

@immutable
class ChatMotion {
  const ChatMotion({required this.disableAnimations});

  final bool disableAnimations;

  static ChatMotion of(BuildContext context) {
    return ChatMotion(
      disableAnimations:
          MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
  }

  Duration duration(ChatMotionDuration token) {
    return token.resolve(disableAnimations: disableAnimations);
  }
}
