/// Emoji utilities
class EmojiUtils {
  /// Convert emoji text to image
  static String? getEmojiImage(String emoji) {
    return null;
  }

  /// Check if text contains emoji
  static bool containsEmoji(String text) {
    return text.codeUnits.any((c) => c > 255);
  }
}
