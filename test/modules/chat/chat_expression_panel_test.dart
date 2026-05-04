import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_gif_panel_service.dart';
import 'package:wukong_im_app/modules/chat/expression/chat_expression_models.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_expression_panel.dart';

void main() {
  testWidgets('expression panel uses one shell and swaps content inside it', (
    tester,
  ) async {
    final snapshot = ChatExpressionRegistrySnapshot(
      categories: const <ChatExpressionCategory>[
        ChatExpressionCategory(
          id: 'recent',
          kind: ChatExpressionKind.emoji,
          label: '最近',
          iconKey: 'recent',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'emoji:0',
          kind: ChatExpressionKind.emoji,
          label: '0',
          iconKey: 'emoji:0',
          emojiTags: <String>['[\u5fae\u7b11]'],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'sticker:android_sample_motion',
          kind: ChatExpressionKind.sticker,
          label: '示例动效',
          iconKey: 'assets/stickers/sample_pack/group.webp',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[
            ChatStickerDefinition(
              packId: 'android_sample_motion',
              stickerId: 'typing',
              title: '输入中',
              previewKey: 'assets/stickers/sample_pack/typing.webp',
              animationKey: 'assets/stickers/sample_pack/typing.webp',
              mimeType: 'image/webp',
              width: 512,
              height: 512,
              loopCount: 0,
              fallbackText: '[\u8d34\u7eb8]',
            ),
          ],
          recents: <ChatExpressionRecentRecord>[],
        ),
        ChatExpressionCategory(
          id: 'gif',
          kind: ChatExpressionKind.gif,
          label: '动图',
          iconKey: 'gif',
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[],
          recents: <ChatExpressionRecentRecord>[],
          isGif: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatExpressionPanel(
            snapshot: snapshot,
            activeCategoryId: 'emoji:0',
            gifResults: const <ChatGifPanelResult>[],
            gifErrorText: null,
            onCategorySelected: (_) {},
            onRecentSelected: (_) {},
            onEmojiSelected: (_) {},
            onStickerSelected: (_, _) {},
            onGifQueryChanged: (_) {},
            onGifSelected: (_) {},
            onBackspaceTap: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('chat-expression-panel-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-expression-category-gif')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-expression-emoji-grid')),
      findsOneWidget,
    );
  });

  testWidgets('sticker grid decodes lightweight previews at bounded size', (
    tester,
  ) async {
    const previewKey =
        'assets/stickers/sample_pack/previews/typing-preview.webp';
    const snapshot = ChatExpressionRegistrySnapshot(
      categories: <ChatExpressionCategory>[
        ChatExpressionCategory(
          id: 'sticker:android_sample_motion',
          kind: ChatExpressionKind.sticker,
          label: 'sample',
          iconKey: previewKey,
          emojiTags: <String>[],
          stickers: <ChatStickerDefinition>[
            ChatStickerDefinition(
              packId: 'android_sample_motion',
              stickerId: 'typing',
              title: 'typing',
              previewKey: previewKey,
              animationKey: 'assets/stickers/sample_pack/typing.webp',
              mimeType: 'image/webp',
              width: 512,
              height: 512,
              loopCount: 0,
              fallbackText: '[\u8d34\u7eb8]',
            ),
          ],
          recents: <ChatExpressionRecentRecord>[],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatExpressionPanel(
            snapshot: snapshot,
            activeCategoryId: 'sticker:android_sample_motion',
            gifResults: const <ChatGifPanelResult>[],
            gifErrorText: null,
            onCategorySelected: (_) {},
            onRecentSelected: (_) {},
            onEmojiSelected: (_) {},
            onStickerSelected: (_, _) {},
            onGifQueryChanged: (_) {},
            onGifSelected: (_) {},
            onBackspaceTap: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('chat-expression-sticker-typing')),
        matching: find.byType(Image),
      ),
    );

    expect(image.image, isA<ResizeImage>());
    final resizedImage = image.image as ResizeImage;
    expect(resizedImage.imageProvider, isA<AssetImage>());
    expect((resizedImage.imageProvider as AssetImage).assetName, previewKey);
    expect(resizedImage.width, 128);
    expect(resizedImage.height, 128);
  });
}
