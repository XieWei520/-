/// Conversation entity
class WKConversation {
  String channelId;
  int channelType;
  String name;
  String avatar;
  String? lastMessage;
  int lastMsgTime;
  int unreadCount;

  WKConversation({
    required this.channelId,
    required this.channelType,
    this.name = '',
    this.avatar = '',
    this.lastMessage,
    this.lastMsgTime = 0,
    this.unreadCount = 0,
  });

  factory WKConversation.fromJson(Map<String, dynamic> json) {
    return WKConversation(
      channelId: json['channel_id'] ?? json['channelId'] ?? '',
      channelType: json['channel_type'] ?? json['channelType'] ?? 1,
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      lastMessage: json['last_message'] ?? json['lastMessage'],
      lastMsgTime: json['last_msg_time'] ?? json['lastMsgTime'] ?? 0,
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
    );
  }
}
