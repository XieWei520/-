import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

const String _defaultStickerFallbackText = '[\u8d34\u7eb8]';

/// Sticker message content.
class WKStickerContent extends WKMediaMessageContent {
  String packId;
  String stickerId;
  int packVersion;
  String title;
  String mimeType;
  int width;
  int height;
  int loopCount;
  String previewKey;
  String animationKey;
  String fallbackText;

  WKStickerContent({
    this.packId = '',
    this.stickerId = '',
    this.packVersion = 0,
    this.title = '',
    this.mimeType = '',
    this.width = 0,
    this.height = 0,
    this.loopCount = 0,
    this.previewKey = '',
    this.animationKey = '',
    this.fallbackText = _defaultStickerFallbackText,
    String url = '',
    String localPath = '',
  }) {
    contentType = WkMessageContentType.sticker;
    this.url = url;
    this.localPath = localPath;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return {
      'packId': packId,
      'stickerId': stickerId,
      'packVersion': packVersion,
      'title': title,
      'mimeType': mimeType,
      'width': width,
      'height': height,
      'loopCount': loopCount,
      'previewKey': previewKey,
      'animationKey': animationKey,
      'fallbackText': fallbackText,
      'url': url,
      'localPath': localPath,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    packId = readString(json, 'packId');
    stickerId = readString(json, 'stickerId');
    packVersion = readInt(json, 'packVersion');
    title = readString(json, 'title');
    mimeType = readString(json, 'mimeType');
    width = readInt(json, 'width');
    height = readInt(json, 'height');
    loopCount = readInt(json, 'loopCount');
    previewKey = readString(json, 'previewKey');
    animationKey = readString(json, 'animationKey');
    fallbackText = readString(json, 'fallbackText');
    if (fallbackText.trim().isEmpty) {
      fallbackText = _defaultStickerFallbackText;
    }
    url = readString(json, 'url');
    localPath = readString(json, 'localPath');
    return this;
  }

  @override
  String displayText() {
    final normalized = fallbackText.trim();
    return normalized.isEmpty ? _defaultStickerFallbackText : normalized;
  }

  @override
  String searchableWord() {
    final normalized = fallbackText.trim();
    return normalized.isEmpty ? _defaultStickerFallbackText : normalized;
  }
}
