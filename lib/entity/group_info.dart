/// Group info entity
class WKGroupInfo {
  String groupId;
  String name;
  String avatar;
  int memberCount;

  WKGroupInfo({
    this.groupId = '',
    this.name = '',
    this.avatar = '',
    this.memberCount = 0,
  });

  factory WKGroupInfo.fromJson(Map<String, dynamic> json) {
    return WKGroupInfo(
      groupId: json['group_id'] ?? json['groupId'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      memberCount: json['member_count'] ?? json['memberCount'] ?? 0,
    );
  }
}
