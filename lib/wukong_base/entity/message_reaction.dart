/// Message reaction entity for storing reactions to messages
class WKMessageReactionEntity {
  String messageId;
  String uid;
  int type;
  int createdAt;

  WKMessageReactionEntity({
    this.messageId = '',
    this.uid = '',
    this.type = 0,
    this.createdAt = 0,
  });

  factory WKMessageReactionEntity.fromJson(Map<String, dynamic> json) {
    return WKMessageReactionEntity(
      messageId: json['message_id'] ?? json['messageId'] ?? '',
      uid: json['uid'] ?? '',
      type: json['type'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
    );
  }
}
