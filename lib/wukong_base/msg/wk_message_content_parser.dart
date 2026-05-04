/// Message content parser
class WKMessageContentParser {
  /// Parse message content to display text
  static String parseToText(dynamic content) {
    if (content is String) return content;
    if (content is Map) {
      return content['text'] ?? content['content'] ?? '';
    }
    return '';
  }

  /// Check if message has additional content
  static bool hasExtraContent(dynamic content) {
    if (content is Map) {
      return content['extra'] != null;
    }
    return false;
  }
}
