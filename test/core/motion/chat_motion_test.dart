import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/motion/chat_motion.dart';

void main() {
  test('motion durations collapse when animations are disabled', () {
    expect(ChatMotionDurations.messageEnter.resolve(), 260.milliseconds);
    expect(
      ChatMotionDurations.messageEnter.resolve(disableAnimations: true),
      Duration.zero,
    );
  });

  testWidgets('ChatMotion inherits reduced-motion preference from MediaQuery', (
    tester,
  ) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolved = ChatMotion.of(
              context,
            ).duration(ChatMotionDurations.pageStandard);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved, Duration.zero);
  });

  test('motion curves expose named IM interaction curves', () {
    expect(ChatMotionCurves.messageEnter, Curves.easeOutCubic);
    expect(ChatMotionCurves.spring, Curves.elasticOut);
    expect(ChatMotionCurves.statusShake, Curves.easeInOut);
  });
}

extension on int {
  Duration get milliseconds => Duration(milliseconds: this);
}
