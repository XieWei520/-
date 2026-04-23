/// Moon util for emoji conversion
class MoonUtil {
  MoonUtil._();
  static final MoonUtil _instance = MoonUtil._();
  static MoonUtil get instance => _instance;

  /// Convert text with emoji codes to emoji characters
  /// 
  /// Example: "Hello :smile:" -> "Hello 😀"
  String convertText(String text, {Map<String, String>? emojiMap}) {
    if (emojiMap == null) return text;

    String result = text;
    emojiMap.forEach((code, emoji) {
      result = result.replaceAll(':$code:', emoji);
    });

    return result;
  }

  /// Check if text contains emoji codes
  bool containsEmojiCodes(String text) {
    return text.contains(RegExp(r':[a-zA-Z_]+:'));
  }

  /// Extract emoji codes from text
  List<String> extractEmojiCodes(String text) {
    final regex = RegExp(r':([a-zA-Z_]+):');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Default emoji map (shortcode to unicode)
  static const Map<String, String> defaultEmojiMap = {
    'smile': '😀',
    'smiley': '😃',
    'smile_cat': '😸',
    'heart': '❤️',
    'thumbsup': '👍',
    'thumbsdown': '👎',
    'ok_hand': '👌',
    'pray': '🙏',
    'clap': '👏',
    'fire': '🔥',
    '100': '💯',
    'tada': '🎉',
    'star': '⭐',
    'eyes': '👀',
    'muscle': '💪',
    'wave': '👋',
    'thinking': '🤔',
    'sleeping': '😴',
    'joy': '😂',
    'sweat_smile': '😅',
  };

  /// Convert shortcodes in text using default map
  String convertWithDefaultMap(String text) {
    return convertText(text, emojiMap: defaultEmojiMap);
  }
}
