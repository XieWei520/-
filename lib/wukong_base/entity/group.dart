/// Group entity
/// 
/// Represents a group/chatroom in the application.
class GroupInfo {
  String groupNo;
  String name;
  String? notice;        // Group announcement
  String avatar;
  String creator;
  int status;            // Status: 0: normal
  int groupType;         // 0: normal group, 1: super group
  int version;
  int isUploadAvatar;
  int forbidden;         // Mute all members
  int invite;            // Invite confirmation required
  int forbiddenAddFriend; // Prevent members from adding friends
  int allowViewHistoryMsg; // Allow viewing history messages
  int allowMemberPinnedMessage; // Allow members to pin messages
  int createdAt;
  int updatedAt;

  // Local settings
  int mute;              // Do not disturb
  int top;               // Pinned
  String? remark;        // Group remark
  int showNick;          // Show nickname
  int save;              // Saved to contacts
  int receipt;           // Read receipt
  int flame;             // Secret chat
  int flameSecond;       // Secret chat duration

  GroupInfo({
    this.groupNo = '',
    this.name = '',
    this.notice,
    this.avatar = '',
    this.creator = '',
    this.status = 0,
    this.groupType = 0,
    this.version = 0,
    this.isUploadAvatar = 0,
    this.forbidden = 0,
    this.invite = 0,
    this.forbiddenAddFriend = 0,
    this.allowViewHistoryMsg = 1,
    this.allowMemberPinnedMessage = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.mute = 0,
    this.top = 0,
    this.remark,
    this.showNick = 1,
    this.save = 1,
    this.receipt = 1,
    this.flame = 0,
    this.flameSecond = 0,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      groupNo: json['group_no'] ?? json['groupNo'] ?? '',
      name: json['name'] ?? '',
      notice: json['notice'],
      avatar: json['avatar'] ?? '',
      creator: json['creator'] ?? '',
      status: json['status'] ?? 0,
      groupType: json['group_type'] ?? json['groupType'] ?? 0,
      version: json['version'] ?? 0,
      isUploadAvatar: json['is_upload_avatar'] ?? json['isUploadAvatar'] ?? 0,
      forbidden: json['forbidden'] ?? 0,
      invite: json['invite'] ?? 0,
      forbiddenAddFriend: json['forbidden_add_friend'] ?? json['forbiddenAddFriend'] ?? 0,
      allowViewHistoryMsg: json['allow_view_history_msg'] ?? json['allowViewHistoryMsg'] ?? 1,
      allowMemberPinnedMessage: json['allow_member_pinned_message'] ?? json['allowMemberPinnedMessage'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
      updatedAt: json['updated_at'] ?? json['updatedAt'] ?? 0,
      mute: json['mute'] ?? 0,
      top: json['top'] ?? 0,
      remark: json['remark'],
      showNick: json['show_nick'] ?? json['showNick'] ?? 1,
      save: json['save'] ?? 1,
      receipt: json['receipt'] ?? 1,
      flame: json['flame'] ?? 0,
      flameSecond: json['flame_second'] ?? json['flameSecond'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_no': groupNo,
      'name': name,
      'notice': notice,
      'avatar': avatar,
      'creator': creator,
      'status': status,
      'group_type': groupType,
      'version': version,
      'is_upload_avatar': isUploadAvatar,
      'forbidden': forbidden,
      'invite': invite,
      'forbidden_add_friend': forbiddenAddFriend,
      'allow_view_history_msg': allowViewHistoryMsg,
      'allow_member_pinned_message': allowMemberPinnedMessage,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'mute': mute,
      'top': top,
      'remark': remark,
      'show_nick': showNick,
      'save': save,
      'receipt': receipt,
      'flame': flame,
      'flame_second': flameSecond,
    };
  }

  String get displayName => remark?.isNotEmpty == true ? remark! : name;
}

/// Group member entity
class GroupMember {
  String groupNo;
  String uid;
  String name;
  String? remark;        // Member remark in group
  String? avatar;
  int role;              // 0: normal, 1: creator, 2: admin
  int version;
  int isDeleted;
  int status;            // 0: normal, 2: blacklisted
  String? vercode;
  String? inviteUid;     // Who invited this member
  int robot;             // Is robot
  int forbiddenExpirTime; // Mute expiration timestamp
  int createdAt;

  GroupMember({
    this.groupNo = '',
    this.uid = '',
    this.name = '',
    this.remark,
    this.avatar,
    this.role = 0,
    this.version = 0,
    this.isDeleted = 0,
    this.status = 0,
    this.vercode,
    this.inviteUid,
    this.robot = 0,
    this.forbiddenExpirTime = 0,
    this.createdAt = 0,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupNo: json['group_no'] ?? json['groupNo'] ?? '',
      uid: json['uid'] ?? '',
      name: json['name'] ?? '',
      remark: json['remark'],
      avatar: json['avatar'],
      role: json['role'] ?? 0,
      version: json['version'] ?? 0,
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? 0,
      status: json['status'] ?? 0,
      vercode: json['vercode'],
      inviteUid: json['invite_uid'] ?? json['inviteUid'],
      robot: json['robot'] ?? 0,
      forbiddenExpirTime: json['forbidden_expir_time'] ?? json['forbiddenExpirTime'] ?? 0,
      createdAt: json['created_at'] ?? json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_no': groupNo,
      'uid': uid,
      'name': name,
      'remark': remark,
      'avatar': avatar,
      'role': role,
      'version': version,
      'is_deleted': isDeleted,
      'status': status,
      'vercode': vercode,
      'invite_uid': inviteUid,
      'robot': robot,
      'forbidden_expir_time': forbiddenExpirTime,
      'created_at': createdAt,
    };
  }

  bool get isCreator => role == 1;
  bool get isAdmin => role == 2;
  bool get isAdminOrAbove => role >= 1;
  String get displayName => remark?.isNotEmpty == true ? remark! : name;
}

/// Group role constants
class GroupRole {
  static const int normal = 0;
  static const int creator = 1;
  static const int admin = 2;
}
