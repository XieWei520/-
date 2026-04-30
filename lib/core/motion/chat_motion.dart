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

  static const ChatMotionDuration micro = ChatMotionDuration(
    Duration(milliseconds: 160),
  );
  static const ChatMotionDuration messageEnter = ChatMotionDuration(
    Duration(milliseconds: 260),
  );
  static const ChatMotionDuration statusChange = ChatMotionDuration(
    Duration(milliseconds: 300),
  );
  static const ChatMotionDuration badgeBounce = ChatMotionDuration(
    Duration(milliseconds: 400),
  );
  static const ChatMotionDuration pageStandard = ChatMotionDuration(
    Duration(milliseconds: 300),
  );
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
