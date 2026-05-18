import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

/// Rich text message content (type=14).
///
/// Supports markdown-style content with optional title.
class WKRichTextContent extends WKMessageContent {
  String title;
  String body;

  WKRichTextContent({this.title = '', this.body = ''}) {
    contentType = 14;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'title': title,
      'content': body,
      'type': contentType,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    title = WKDBConst.readString(json, 'title');
    body = WKDBConst.readString(json, 'content');
    return this;
  }

  @override
  String displayText() {
    return body.isNotEmpty ? body : '[富文本]';
  }

  @override
  String searchableWord() {
    return '$title $body'.trim();
  }
}
