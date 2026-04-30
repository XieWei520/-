import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_reply_preview_strip.dart';
import 'package:wukong_im_app/widgets/wk_emoji_text.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

void main() {
  testWidgets('reply preview strip renders catalog emoji with image spans', (
    tester,
  ) async {
    final entry = androidEmojiCatalog.lookupById('0_0')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatReplyPreviewStrip(
            previewText: 'quoted ${entry.tag}',
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.byType(WKEmojiText), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == entry.assetPath,
      ),
      findsOneWidget,
    );
  });
}
