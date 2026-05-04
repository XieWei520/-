import '../models/message_model.dart' as models;
import '../msg/msg_content_type.dart';

/// Parses message content from JSON based on content type.
class WKMessageContentParser {
  /// Parse content JSON to appropriate content object
  static dynamic parseContent(
    int contentType,
    Map<String, dynamic>? contentJson,
  ) {
    if (contentJson == null) return null;

    switch (contentType) {
      case MsgContentType.text:
        return models.WKTextContent.fromJson(contentJson);
      case MsgContentType.image:
        return models.WKImageContent.fromJson(contentJson);
      case MsgContentType.gif:
        return contentJson;
      case MsgContentType.voice:
        return models.WKVoiceContent.fromJson(contentJson);
      case MsgContentType.video:
        return models.WKVideoContent.fromJson(contentJson);
      case MsgContentType.file:
        return models.WKFileContent.fromJson(contentJson);
      case MsgContentType.location:
        return models.WKLocationContent.fromJson(contentJson);
      case MsgContentType.card:
        return models.WKCardContent.fromJson(contentJson);
      case MsgContentType.richText:
        return contentJson;
      default:
        return contentJson;
    }
  }

  /// Parse content JSON to message object
  static models.WKMessage parseMessage(Map<String, dynamic> json) {
    final message = models.WKMessage.fromJson(json);

    // Parse content if present
    if (json['content'] != null && json['content'] is Map) {
      message.extra = json['content'];
    }

    return message;
  }

  /// Create text content JSON
  static Map<String, dynamic> createTextContent(String text) {
    return models.WKTextContent(text: text).toJson();
  }

  /// Create image content JSON
  static Map<String, dynamic> createImageContent({
    String? url,
    String? localPath,
    String? thumbnail,
    int width = 0,
    int height = 0,
    int size = 0,
  }) {
    return models.WKImageContent(
      url: url,
      localPath: localPath,
      thumbnail: thumbnail,
      width: width,
      height: height,
      size: size,
    ).toJson();
  }

  /// Create voice content JSON
  static Map<String, dynamic> createVoiceContent({
    String? url,
    String? localPath,
    int duration = 0,
    int size = 0,
  }) {
    return models.WKVoiceContent(
      url: url,
      localPath: localPath,
      duration: duration,
      size: size,
    ).toJson();
  }

  /// Create video content JSON
  static Map<String, dynamic> createVideoContent({
    String? url,
    String? localPath,
    String? coverUrl,
    int width = 0,
    int height = 0,
    int duration = 0,
    int size = 0,
  }) {
    return models.WKVideoContent(
      url: url,
      localPath: localPath,
      coverUrl: coverUrl,
      width: width,
      height: height,
      duration: duration,
      size: size,
    ).toJson();
  }

  /// Create file content JSON
  static Map<String, dynamic> createFileContent({
    String? url,
    String? localPath,
    required String fileName,
    String? fileExtension,
    int size = 0,
  }) {
    return models.WKFileContent(
      url: url,
      localPath: localPath,
      fileName: fileName,
      fileExtension: fileExtension,
      size: size,
    ).toJson();
  }

  /// Create location content JSON
  static Map<String, dynamic> createLocationContent({
    required double latitude,
    required double longitude,
    String? title,
    String? address,
    String? snapshot,
  }) {
    return models.WKLocationContent(
      latitude: latitude,
      longitude: longitude,
      title: title,
      address: address,
      snapshot: snapshot,
    ).toJson();
  }

  /// Create card content JSON
  static Map<String, dynamic> createCardContent({
    required String uid,
    required String name,
    String? avatar,
  }) {
    return models.WKCardContent(uid: uid, name: name, avatar: avatar).toJson();
  }

  /// Get display text for message content
  static String getContentDisplayText(
    int contentType,
    Map<String, dynamic>? contentJson,
  ) {
    if (contentJson == null) return '';

    switch (contentType) {
      case MsgContentType.text:
        return contentJson['text'] ?? '';
      case MsgContentType.image:
        return '[ͼƬ]';
      case MsgContentType.gif:
        return '[GIF]';
      case MsgContentType.voice:
        return '[语音]';
      case MsgContentType.video:
        return '[视频]';
      case MsgContentType.file:
        return '[文件] ${contentJson['fileName'] ?? ''}';
      case MsgContentType.location:
        return '[位置] ${contentJson['title'] ?? '位置'}';
      case MsgContentType.card:
        return '[名片] ${contentJson['name'] ?? ''}';
      case MsgContentType.richText:
        final title = contentJson['title'] ?? '';
        return title.isNotEmpty ? '[富文本] $title' : '[富文本]';
      case MsgContentType.recall:
        return '撤回了一条消息';
      default:
        return '[未知消息]';
    }
  }
}
