import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_overlay_coordinator.dart';
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
}
