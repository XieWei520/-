import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

/// GIF message content — mirrors Android WKGifContent.
class WKGifContent extends WKMediaMessageContent {
  int width;
  int height;
  String category;
  String placeholder;
  String format;
  String title;

  WKGifContent({
    this.width = 0,
    this.height = 0,
    this.category = '',
    this.placeholder = '',
    this.format = 'gif',
    this.title = '',
  }) {
    contentType = WkMessageContentType.gif;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'width': width,
      'height': height,
      'url': url,
      'localPath': localPath,
      'category': category,
      'placeholder': placeholder,
      'format': format,
      'title': title,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    width = readInt(json, 'width');
    height = readInt(json, 'height');
    url = readString(json, 'url');
    localPath = readString(json, 'localPath');
    category = readString(json, 'category');
    placeholder = readString(json, 'placeholder');
    format = readString(json, 'format');
    title = readString(json, 'title');
    return this;
  }

  @override
  String displayText() {
    return '[GIF]';
  }

  @override
  String searchableWord() {
    return '[GIF]';
  }
}
