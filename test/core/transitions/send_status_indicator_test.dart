import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/transitions/message_animations.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('SendStatusIndicator maps raw success to a neutral sent check', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SendStatusIndicator(status: WKSendMsgResult.sendSuccess),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(icon.color, const Color(0xFF677487));
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  testWidgets(
    'SendStatusIndicator renders delivered and read semantic states',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SendStatusIndicator.visual(
                  state: ChatSendVisualState.delivered,
                ),
                SendStatusIndicator.visual(state: ChatSendVisualState.read),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deliveredIcon = tester.widget<Icon>(
        find.byKey(const ValueKey<String>('send-status-delivered')),
      );
      final readIcon = tester.widget<Icon>(
        find.byKey(const ValueKey<String>('send-status-read')),
      );

      expect(deliveredIcon.icon, Icons.done_all_rounded);
      expect(deliveredIcon.color, const Color(0xFF677487));
      expect(readIcon.icon, Icons.done_all_rounded);
      expect(readIcon.color, const Color(0xFF2196F3));
    },
  );

  testWidgets('SendStatusIndicator keeps loading and failed affordances', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SendStatusIndicator(status: WKSendMsgResult.sendLoading),
              SendStatusIndicator(status: WKSendMsgResult.sendFail),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 48));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final failedIcon = tester.widget<Icon>(
      find.byKey(const ValueKey<String>('send-status-failed')),
    );
    expect(failedIcon.icon, Icons.error_outline);
    expect(failedIcon.color, Colors.red.shade400);
  });
}
