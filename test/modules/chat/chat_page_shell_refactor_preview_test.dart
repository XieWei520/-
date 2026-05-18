import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell_refactor_preview.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_composer_pane.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_header_pane.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_overlay_coordinator.dart';
import 'package:wukong_im_app/modules/chat/panes/chat_viewport_pane.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  testWidgets('refactor preview shell is composed from four chat panes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ChatPageShellRefactorPreview(
            channelId: 'u_preview',
            channelType: WKChannelType.personal,
            channelName: 'Preview Chat',
          ),
        ),
      ),
    );

    expect(find.byType(ChatHeaderPane), findsOneWidget);
    expect(find.byType(ChatOverlayCoordinator), findsOneWidget);
    expect(find.byType(ChatViewportPane), findsOneWidget);
    expect(find.byType(ChatComposerPane), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('chat-page-shell-refactor-preview')),
      findsOneWidget,
    );
  });
}
