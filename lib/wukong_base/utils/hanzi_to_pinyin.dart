/// Converts Chinese characters to Pinyin for sorting and searching.
class HanziToPinyin {
  static HanziToPinyin? _instance;
  final Map<String, String> _cache = {};

  HanziToPinyin._();

  static HanziToPinyin get instance {
    _instance ??= HanziToPinyin._();
    return _instance!;
  }

  /// Convert Chinese characters to pinyin
  /// 
  /// This is a simplified implementation. For production,
  /// consider using a proper Chinese pinyin library.
  String convert(String hanzi) {
    if (hanzi.isEmpty) return '';

    // Check cache first
    if (_cache.containsKey(hanzi)) {
      return _cache[hanzi]!;
    }

    // Simple pinyin mapping for common characters
    // In production, use a proper Chinese pinyin library
    final result = _toPinyin(hanzi);
    _cache[hanzi] = result;
    return result;
  }

  /// Get initials (first letter of pinyin)
  String getInitials(String hanzi) {
    final pinyin = convert(hanzi);
    if (pinyin.isEmpty) return '';
    return pinyin[0].toUpperCase();
  }

  /// Check if character is Chinese
  bool isChinese(String char) {
    return char.codeUnitAt(0) >= 0x4E00 && char.codeUnitAt(0) <= 0x9FFF;
  }

  /// Sort strings by pinyin (Chinese characters first, then by pinyin)
  List<String> sortByPinyin(List<String> items) {
    return List.from(items)..sort((a, b) {
      final pinyinA = convert(a);
      final pinyinB = convert(b);
      return pinyinA.compareTo(pinyinB);
    });
  }

  String _toPinyin(String hanzi) {
    // This is a placeholder implementation
    // In production, use a proper Chinese pinyin library like:
    // - pinyin (pub.dev)
    // - lpinyin (pub.dev)
    
    // For now, return the original string if it contains Chinese characters
    // and empty string otherwise
    if (isChinese(hanzi)) {
      // Return first character's Unicode range as pinyin placeholder
      // This is NOT real pinyin, just for sorting
      final code = hanzi.codeUnitAt(0);
      return String.fromCharCode((code - 0x4E00) + 0x61);
    }
    return hanzi;
  }
}

/// Character parser for contact sorting
class CharacterParser {
  static CharacterParser? _instance;
  final HanziToPinyin _pinyin = HanziToPinyin.instance;

  CharacterParser._();

  static CharacterParser get instance {
    _instance ??= CharacterParser._();
    return _instance!;
  }

  /// Get sorting key for a name
  String getSortingKey(String name) {
    if (name.isEmpty) return '#';

    final firstChar = name[0];
    
    // If it's a Chinese character
    if (_pinyin.isChinese(firstChar)) {
      return _pinyin.getInitials(name).toUpperCase();
    }
    
    // If it's a letter
    if (RegExp(r'[a-zA-Z]').hasMatch(firstChar)) {
      return firstChar.toUpperCase();
    }
    
    // Other characters
    return '#';
  }

  /// Get section title
  String getSectionTitle(String name) {
    return getSortingKey(name);
  }
}
