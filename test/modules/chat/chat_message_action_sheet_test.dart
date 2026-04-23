import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_policy.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_message_action_sheet.dart';

void main() {
  group('chat message action sheet', () {
    testWidgets('renders shrink widget when no actions are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageActionSheet(
              actions: const <ChatMessageActionDescriptor>[],
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ListTile), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-action-sheet-empty')),
        findsOneWidget,
      );
    });

    testWidgets('renders descriptors in Android order', (tester) async {
      final actions = <ChatMessageActionDescriptor>[
        const ChatMessageActionDescriptor(
          action: ChatSceneAction.react,
          label: '\u8868\u60c5\u56de\u5e94',
          order: 5,
        ),
        const ChatMessageActionDescriptor(
          action: ChatSceneAction.reply,
          label: '\u56de\u590d',
          order: 0,
        ),
        const ChatMessageActionDescriptor(
          action: ChatSceneAction.recall,
          label: '\u64a4\u56de',
          order: 4,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageActionSheet(
              actions: actions,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final replyFinder = find.byKey(
        const ValueKey<String>('chat-action-reply'),
      );
      final recallFinder = find.byKey(
        const ValueKey<String>('chat-action-recall'),
      );
      final reactFinder = find.byKey(
        const ValueKey<String>('chat-action-react'),
      );

      expect(replyFinder, findsOneWidget);
      expect(recallFinder, findsOneWidget);
      expect(reactFinder, findsOneWidget);
      expect(find.text('\u56de\u590d'), findsOneWidget);
      expect(find.text('\u64a4\u56de'), findsOneWidget);
      expect(find.text('\u8868\u60c5\u56de\u5e94'), findsOneWidget);

      final replyTop = tester.getTopLeft(replyFinder).dy;
      final recallTop = tester.getTopLeft(recallFinder).dy;
      final reactTop = tester.getTopLeft(reactFinder).dy;
      expect(replyTop, lessThan(recallTop));
      expect(recallTop, lessThan(reactTop));
    });

    testWidgets('renders a top emoji strip before action rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageActionSheet(
              actions: const <ChatMessageActionDescriptor>[
                ChatMessageActionDescriptor(
                  action: ChatSceneAction.reply,
                  label: '\u56de\u590d',
                  order: 0,
                ),
                ChatMessageActionDescriptor(
                  action: ChatSceneAction.react,
                  label: '\u8868\u60c5\u56de\u5e94',
                  order: 1,
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final emojiFinder = find.byKey(
        const ValueKey<String>('reaction-picker-\u{1F44D}'),
      );
      final replyFinder = find.byKey(
        const ValueKey<String>('chat-action-reply'),
      );

      expect(emojiFinder, findsOneWidget);
      expect(replyFinder, findsOneWidget);
      expect(
        tester.getTopLeft(emojiFinder).dy,
        lessThan(tester.getTopLeft(replyFinder).dy),
      );
    });

    testWidgets('tap closes sheet and returns selected action', (tester) async {
      ChatSceneAction? selected;

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
                        builder: (_) => ChatMessageActionSheet(
                          actions: const <ChatMessageActionDescriptor>[
                            ChatMessageActionDescriptor(
                              action: ChatSceneAction.reply,
                              label: '\u56de\u590d',
                              order: 0,
                            ),
                            ChatMessageActionDescriptor(
                              action: ChatSceneAction.forward,
                              label: '\u8f6c\u53d1',
                              order: 1,
                            ),
                          ],
                          onSelected: (action) {
                            selected = action;
                          },
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
        find.byKey(const ValueKey<String>('chat-action-forward')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('chat-action-forward')));
      await tester.pumpAndSettle();

      expect(selected, ChatSceneAction.forward);
      expect(
        find.byKey(const ValueKey<String>('chat-action-forward')),
        findsNothing,
      );
    });
  });
}
