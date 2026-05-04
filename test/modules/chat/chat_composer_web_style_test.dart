import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_composer.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  testWidgets('chat composer supports warm Web shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            webStyle: true,
            inputRow: SizedBox(height: 20),
            toolbarRow: SizedBox(height: 20),
            panel: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-composer-shell')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, WKWebColors.surface);
    expect(decoration.border!.top.color, WKWebColors.borderWarm);
  });
}
