import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/widgets/conversation_action_sheet.dart';

void main() {
  group('conversation action sheet', () {
    testWidgets('shows pin title when conversation is not pinned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationActionSheet(
              isPinned: false,
              onPinChanged: (_) {},
              onMute: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('conversation-pin')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-mute')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('conversation-delete')),
        findsOneWidget,
      );
      expect(find.text('Pin conversation'), findsOneWidget);
      expect(find.text('Unpin conversation'), findsNothing);
    });

    testWidgets('shows unpin title when conversation is pinned', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationActionSheet(
              isPinned: true,
              onPinChanged: (_) {},
              onMute: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Unpin conversation'), findsOneWidget);
      expect(find.text('Pin conversation'), findsNothing);
    });

    testWidgets('tap pin closes sheet and returns next pinned state', (
      tester,
    ) async {
      bool? nextPinned;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => ConversationActionSheet(
                          isPinned: false,
                          onPinChanged: (next) {
                            nextPinned = next;
                          },
                          onMute: () {},
                          onDelete: () {},
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('conversation-pin')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('conversation-pin')));
      await tester.pumpAndSettle();

      expect(nextPinned, isTrue);
      expect(
        find.byKey(const ValueKey<String>('conversation-pin')),
        findsNothing,
      );
    });

    testWidgets('tap pin sends false when currently pinned', (tester) async {
      bool? nextPinned;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => ConversationActionSheet(
                          isPinned: true,
                          onPinChanged: (next) {
                            nextPinned = next;
                          },
                          onMute: () {},
                          onDelete: () {},
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('conversation-pin')));
      await tester.pumpAndSettle();

      expect(nextPinned, isFalse);
    });
  });
}
