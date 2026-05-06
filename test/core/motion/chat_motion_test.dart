import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/motion/chat_motion.dart';

String _readReceiptSection(String source) {
  final start = source.indexOf('class _ReadReceiptTicksState');
  final end = source.indexOf('/// Connection status banner', start);
  if (start == -1 || end == -1) {
    throw StateError('ReadReceiptTicks source section not found');
  }
  return source.substring(start, end);
}

void main() {
  test('motion durations expose stable semantic tokens', () {
    expect(ChatMotionDurations.fast.resolve(), 160.milliseconds);
    expect(ChatMotionDurations.normal.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.pressedScale.resolve(), 120.milliseconds);
    expect(
      ChatMotionDurations.normal.resolve(disableAnimations: true),
      Duration.zero,
    );
  });

  test('motion durations preserve existing compatibility tokens', () {
    expect(ChatMotionDurations.micro.resolve(), 160.milliseconds);
    expect(ChatMotionDurations.messageEnter.resolve(), 260.milliseconds);
    expect(ChatMotionDurations.statusChange.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.badgeBounce.resolve(), 400.milliseconds);
    expect(ChatMotionDurations.pageStandard.resolve(), 300.milliseconds);
    expect(ChatMotionDurations.pageEmphasized.resolve(), 350.milliseconds);
    expect(ChatMotionDurations.pageReverse.resolve(), 250.milliseconds);
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

  test('read receipt ticks use the shared status-change duration token', () {
    final source = File(
      'lib/core/theme/chat_micro_interactions.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('duration: ChatMotionDurations.statusChange.value'),
    );
    expect(
      source,
      contains('this.duration = const Duration(milliseconds: 300)'),
    );
    expect(
      _readReceiptSection(source),
      isNot(contains('Duration(milliseconds: 300)')),
    );
  });
}

extension on int {
  Duration get milliseconds => Duration(milliseconds: this);
}
