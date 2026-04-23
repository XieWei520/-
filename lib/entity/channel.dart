/// Channel type enum
enum ChannelType {
  personal(1),
  group(2);

  const ChannelType(this.value);
  final int value;

  static ChannelType fromValue(int value) {
    return ChannelType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChannelType.personal,
    );
  }
}

/// Channel entity
class WKChannel {
  String channelId;
  ChannelType channelType;
  String name;
  String avatar;

  WKChannel({
    required this.channelId,
    required this.channelType,
    this.name = '',
    this.avatar = '',
  });

  factory WKChannel.fromJson(Map<String, dynamic> json) {
    return WKChannel(
      channelId: json['channel_id'] ?? json['channelId'] ?? '',
      channelType: ChannelType.fromValue(json['channel_type'] ?? json['channelType'] ?? 1),
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
    );
  }

  String get displayName => name.isNotEmpty ? name : channelId;
}
