import '../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/entity/send_text_menu.dart';
import '../../wukong_base/endpoint/menu/endpoint_menu.dart';

class ChatTextStickerConversion {
  ChatTextStickerConversion({
    EndpointManager? endpointManager,
    AndroidEmojiCatalog? emojiCatalog,
  }) : _endpointManager = endpointManager ?? EndpointManager.getInstance(),
       _emojiCatalog = emojiCatalog ?? androidEmojiCatalog;

  final EndpointManager _endpointManager;
  final AndroidEmojiCatalog _emojiCatalog;

  Future<bool> tryHandle({
    required String text,
    String? replyMessageId,
    dynamic conversationContext,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (replyMessageId?.trim().isNotEmpty == true) {
      return false;
    }
    if (_emojiCatalog.lookupByTag(trimmed) == null) {
      return false;
    }

    try {
      final result = _endpointManager.invoke(
        ChatMenuIDs.textToEmojiSticker,
        SendTextMenu(text: trimmed, conversationContext: conversationContext),
      );
      if (result is Future<dynamic>) {
        return await result == true;
      }
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
