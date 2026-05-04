import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/chat_text_sticker_conversion.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/send_text_menu.dart';
import 'package:wukong_im_app/wukong_base/endpoint/menu/endpoint_menu.dart';

void main() {
  group('ChatTextStickerConversion.tryHandle', () {
    late EndpointManager endpointManager;
    late ChatTextStickerConversion conversion;
    final conversationContext = const ChatSession(
      channelId: 'u_text_sticker',
      channelType: 1,
    );

    setUp(() {
      endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      conversion = ChatTextStickerConversion(endpointManager: endpointManager);
    });

    tearDown(() {
      endpointManager.clear();
    });

    test('returns false for blank text', () async {
      var invokeCount = 0;
      endpointManager.setMethod(
        ChatMenuIDs.textToEmojiSticker,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) {
          invokeCount += 1;
          return true;
        }),
      );

      final handled = await conversion.tryHandle(
        text: '   ',
        conversationContext: conversationContext,
      );

      expect(handled, isFalse);
      expect(invokeCount, 0);
    });

    test('returns false when reply mode is active', () async {
      var invokeCount = 0;
      endpointManager.setMethod(
        ChatMenuIDs.textToEmojiSticker,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) {
          invokeCount += 1;
          return true;
        }),
      );

      final handled = await conversion.tryHandle(
        text: androidEmojiCatalog.entries.first.tag,
        replyMessageId: 'mid-reply-1',
        conversationContext: conversationContext,
      );

      expect(handled, isFalse);
      expect(invokeCount, 0);
    });

    test('returns false unless text is an exact Android emoji tag', () async {
      final exactTag = androidEmojiCatalog.entries.first.tag;

      final withPrefix = await conversion.tryHandle(
        text: 'x$exactTag',
        conversationContext: conversationContext,
      );
      final withSuffix = await conversion.tryHandle(
        text: '$exactTag x',
        conversationContext: conversationContext,
      );
      final unknownTag = await conversion.tryHandle(
        text: '[not-an-emoji-tag]',
        conversationContext: conversationContext,
      );

      expect(withPrefix, isFalse);
      expect(withSuffix, isFalse);
      expect(unknownTag, isFalse);
    });

    test(
      'invokes text_to_emoji_sticker endpoint with trimmed SendTextMenu payload',
      () async {
        SendTextMenu? capturedMenu;
        endpointManager.setMethod(
          ChatMenuIDs.textToEmojiSticker,
          '',
          0,
          SimpleFunctionHandler(([dynamic param]) {
            capturedMenu = param as SendTextMenu;
            return true;
          }),
        );
        final exactTag = androidEmojiCatalog.entries.first.tag;

        final handled = await conversion.tryHandle(
          text: '  $exactTag  ',
          conversationContext: conversationContext,
        );

        expect(handled, isTrue);
        expect(capturedMenu, isNotNull);
        expect(capturedMenu!.text, exactTag);
        expect(capturedMenu!.conversationContext, same(conversationContext));
      },
    );

    test('returns true only when endpoint result is true', () async {
      endpointManager.setMethod(
        ChatMenuIDs.textToEmojiSticker,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) => false),
      );
      final exactTag = androidEmojiCatalog.entries.first.tag;

      final handled = await conversion.tryHandle(
        text: exactTag,
        conversationContext: conversationContext,
      );

      expect(handled, isFalse);
    });

    test('supports async endpoint handlers that resolve true', () async {
      endpointManager.setMethod(
        ChatMenuIDs.textToEmojiSticker,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) async => true),
      );
      final exactTag = androidEmojiCatalog.entries.first.tag;

      final handled = await conversion.tryHandle(
        text: exactTag,
        conversationContext: conversationContext,
      );

      expect(handled, isTrue);
    });

    test('falls back to false when the endpoint throws', () async {
      endpointManager.setMethod(
        ChatMenuIDs.textToEmojiSticker,
        '',
        0,
        SimpleFunctionHandler(([dynamic _]) {
          throw StateError('boom');
        }),
      );
      final exactTag = androidEmojiCatalog.entries.first.tag;

      final handled = await conversion.tryHandle(
        text: exactTag,
        conversationContext: conversationContext,
      );

      expect(handled, isFalse);
    });
  });
}
