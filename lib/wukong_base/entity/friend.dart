/// Friend entity
/// 
/// Represents a friend relationship between users.
class Friend {
  String uid;
  String name;
  String avatar;
  int sex;
  String? remark;
  String? friendRemark;  // Alias for remark
  int top;               // Pinned at top
  int mute;              // Do not disturb
  int status;            // 1: normal, 2: blocked
  int version;
  int isDeleted;
  int blacklist;
  String? category;      // Tag/category
  String? phone;
  String? shortNo;

  Friend({
    this.uid = '',
    this.name = '',
    this.avatar = '',
    this.sex = 1,
    this.remark,
    this.friendRemark,
    this.top = 0,
    this.mute = 0,
    this.status = 1,
    this.version = 0,
    this.isDeleted = 0,
    this.blacklist = 0,
    this.category,
    this.phone,
    this.shortNo,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      sex: json['sex'] ?? 1,
      remark: json['remark'],
      friendRemark: json['friend_remark'] ?? json['friendRemark'],
      top: json['top'] ?? 0,
      mute: json['mute'] ?? 0,
      status: json['status'] ?? 1,
      version: json['version'] ?? 0,
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? 0,
      blacklist: json['blacklist'] ?? 0,
      category: json['category'],
      phone: json['phone'],
      shortNo: json['short_no'] ?? json['shortNo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'sex': sex,
      'remark': remark ?? friendRemark,
      'top': top,
      'mute': mute,
      'status': status,
      'version': version,
      'is_deleted': isDeleted,
      'blacklist': blacklist,
      'category': category,
      'phone': phone,
      'short_no': shortNo,
    };
  }

  String get displayName => remark?.isNotEmpty == true ? remark! : name;

  Friend copyWith({
    String? uid,
    String? name,
    String? avatar,
    int? sex,
    String? remark,
    String? friendRemark,
    int? top,
    int? mute,
    int? status,
    int? version,
    int? isDeleted,
    int? blacklist,
    String? category,
    String? phone,
    String? shortNo,
  }) {
    return Friend(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      sex: sex ?? this.sex,
      remark: remark ?? this.remark,
      friendRemark: friendRemark ?? this.friendRemark,
      top: top ?? this.top,
      mute: mute ?? this.mute,
      status: status ?? this.status,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      blacklist: blacklist ?? this.blacklist,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      shortNo: shortNo ?? this.shortNo,
    );
  }
}

/// Friend request/apply record
class FriendApply {
  int id;
  String uid;            // Current user
  String toUid;         // Target user
  String? remark;        // Apply remark
  int status;            // 0: pending, 1: accepted, 2: rejected
  String? token;         // Verification token
  int createdAt;
  String? fromName;      // Applicant name
  String? fromAvatar;    // Applicant avatar

  FriendApply({
    this.id = 0,
    this.uid = '',
    this.toUid = '',
    this.remark,
    this.status = 0,
    this.token,
    this.createdAt = 0,
    this.fromName,
    this.fromAvatar,
  });

  factory FriendApply.fromJson(Map<String, dynamic> json) {
    return FriendApply(
      id: json['id'] ?? 0,
      uid: json['uid'] ?? '',
      toUid: json['to_uid'] ?? json['toUid'] ?? '',
      remark: json['remark'],
      status: json['status'] ?? 0,
      token: json['token'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
      fromName: json['from_name'] ?? json['fromName'],
      fromAvatar: json['from_avatar'] ?? json['fromAvatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'to_uid': toUid,
      'remark': remark,
      'status': status,
      'token': token,
      'created_at': createdAt,
      'from_name': fromName,
      'from_avatar': fromAvatar,
    };
  }
}
