import 'package:wukongimfluttersdk/model/wk_message_content.dart';

/// Screenshot notification content (type=20).
///
/// Sent when the peer takes a screenshot in a private chat.
class WKScreenshotContent extends WKMessageContent {
  WKScreenshotContent() {
    contentType = 20;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {'type': 20};
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    return this;
  }

  @override
  String displayText() {
    return '对方截取了屏幕';
  }

  @override
  String searchableWord() {
    return '截屏通知';
  }
}
