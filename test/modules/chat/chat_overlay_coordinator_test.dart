import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_overlay_coordinator.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  const session = ChatSession(
    channelId: 'overlay_test',
    channelType: WKChannelType.personal,
  );

  testWidgets('composes passive background behind interactive child', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ChatOverlayCoordinator(
              session: session,
              background: Container(
                key: const ValueKey<String>('overlay-background'),
                color: Colors.red,
              ),
              child: TextButton(
                key: const ValueKey<String>('overlay-child-button'),
                onPressed: () => taps++,
                child: const Text('child'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('overlay-background')), findsOne);
    expect(
      find.byKey(const ValueKey<String>('overlay-child-button')),
      findsOne,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('overlay-child-button')),
    );
    expect(taps, 1);
  });

  testWidgets('switches top chrome between selection and normal status bars', (
    tester,
  ) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const ChatOverlayCoordinator(
                  session: session,
                  selectionToolbar: SizedBox(
                    key: ValueKey<String>('test-selection-toolbar'),
                  ),
                  topStatusBars: <Widget>[
                    SizedBox(key: ValueKey<String>('test-calling-bar')),
                    SizedBox(key: ValueKey<String>('test-pinned-banner')),
                  ],
                  child: SizedBox(key: ValueKey<String>('test-chat-body')),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('test-chat-body')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('test-selection-toolbar')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('test-calling-bar')), findsOne);
    expect(find.byKey(const ValueKey<String>('test-pinned-banner')), findsOne);

    capturedRef
        .read(chatSceneControllerProvider(session).notifier)
        .enterSelectionMode(seedIdentity: 'mid:1');
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('test-selection-toolbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('test-calling-bar')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('test-pinned-banner')),
      findsNothing,
    );
  });
}
