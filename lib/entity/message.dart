/// Message entity
class WKMessage {
  String messageId;
  String channelId;
  int channelType;
  String fromUid;
  String content;
  int createdAt;

  WKMessage({
    this.messageId = '',
    this.channelId = '',
    this.channelType = 1,
    this.fromUid = '',
    this.content = '',
    this.createdAt = 0,
  });

  factory WKMessage.fromJson(Map<String, dynamic> json) {
    return WKMessage(
      messageId: json['message_id'] ?? json['messageId'] ?? json['id'] ?? '',
      channelId: json['channel_id'] ?? json['channelId'] ?? '',
      channelType: json['channel_type'] ?? json['channelType'] ?? 1,
      fromUid: json['from_uid'] ?? json['fromUid'] ?? '',
      content: json['content'] ?? json['text'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
    );
  }
}

/// Message content types
class MsgContentType {
  static const int text = 1;
  static const int image = 2;
  static const int voice = 3;
  static const int video = 4;
  static const int file = 5;
  static const int location = 6;
  static const int card = 7;
  static const int notification = 9;
  static const int recall = 10;
  static const int multiForward = 19;
}

/// Message reaction entity
class WKMessageReaction {
  String uid;
  String name;
  int type;

  WKMessageReaction({
    this.uid = '',
    this.name = '',
    this.type = 0,
  });

  factory WKMessageReaction.fromJson(Map<String, dynamic> json) {
    return WKMessageReaction(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 0,
    );
  }
}
