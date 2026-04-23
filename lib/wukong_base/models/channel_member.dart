/// Channel member entity
///
/// Represents a member in a channel (group or channel conversation).
class WKChannelMember {
  /// Member UID
  String uid;

  /// Member name
  String name;

  /// Member avatar
  String avatar;

  /// Member role in the group
  int role;

  /// Member's remark/nickname
  String? remark;

  /// When the member joined
  int createdAt;

  WKChannelMember({
    this.uid = '',
    this.name = '',
    this.avatar = '',
    this.role = 0,
    this.remark,
    this.createdAt = 0,
  });

  factory WKChannelMember.fromJson(Map<String, dynamic> json) {
    return WKChannelMember(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      role: json['role'] ?? 0,
      remark: json['remark'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'role': role,
      'remark': remark,
      'created_at': createdAt,
    };
  }

  /// Get display name
  String get displayName => remark?.isNotEmpty == true ? remark! : name;
}
