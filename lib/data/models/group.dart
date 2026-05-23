class GroupInfo {
  final String groupNo;
  final String? name;
  final String? avatar;
  final String? creator;
  final String? notice;
  final int? memberCount;
  final int? status;
  final int? version;
  final int? forbidden;
  final int? invite;
  final int? groupType;
  final int? allowViewHistoryMsg;
  final int? allowMemberPinnedMessage;
  final int? joinGroupRemind;
  final int? revokeRemind;
  final int? receipt;
  final int? forbiddenAddFriend;
  final int? screenshot;
  final int? chatPwdOn;
  final int? mute;
  final int? top;
  final int? showNick;
  final int? save;
  final int? flame;
  final int? flameSecond;
  final String? remark;
  final int? role;
  final int? forbiddenExpirTime;
  final String? createdAt;
  final String? updatedAt;

  GroupInfo({
    required this.groupNo,
    this.name,
    this.avatar,
    this.creator,
    this.notice,
    this.memberCount,
    this.status,
    this.version,
    this.forbidden,
    this.invite,
    this.groupType,
    this.allowViewHistoryMsg,
    this.allowMemberPinnedMessage,
    this.joinGroupRemind,
    this.revokeRemind,
    this.receipt,
    this.forbiddenAddFriend,
    this.screenshot,
    this.chatPwdOn,
    this.mute,
    this.top,
    this.showNick,
    this.save,
    this.flame,
    this.flameSecond,
    this.remark,
    this.role,
    this.forbiddenExpirTime,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      groupNo:
          _firstNonEmptyString(
            json['group_no'],
            json['groupNo'],
            json['channel_id'],
            json['channelId'],
            json['group_id'],
            json['groupId'],
          ) ??
          '',
      name: _firstNonEmptyString(
        json['name'],
        json['group_name'],
        json['groupName'],
        json['channel_name'],
        json['channelName'],
        json['display_name'],
        json['displayName'],
      ),
      avatar: _firstNonEmptyString(
        json['avatar'],
        json['group_avatar'],
        json['groupAvatar'],
        json['channel_avatar'],
        json['channelAvatar'],
        json['avatar_url'],
        json['avatarUrl'],
        json['logo'],
        json['image'],
      ),
      creator: json['creator'],
      notice: json['notice'],
      memberCount: json['member_count'],
      status: json['status'],
      version: json['version'],
      forbidden: json['forbidden'],
      invite: json['invite'],
      groupType: json['group_type'],
      allowViewHistoryMsg: json['allow_view_history_msg'],
      allowMemberPinnedMessage: json['allow_member_pinned_message'],
      joinGroupRemind: json['join_group_remind'],
      revokeRemind: json['revoke_remind'],
      receipt: json['receipt'],
      forbiddenAddFriend: json['forbidden_add_friend'],
      screenshot: json['screenshot'],
      chatPwdOn: json['chat_pwd_on'],
      mute: json['mute'],
      top: json['top'] ?? json['stick'],
      showNick: json['show_nick'],
      save: json['save'],
      flame: json['flame'],
      flameSecond: json['flame_second'] ?? json['flameSecond'],
      remark: _firstNonEmptyString(
        json['remark'],
        json['channel_remark'],
        json['channelRemark'],
        json['group_remark'],
        json['groupRemark'],
      ),
      role: json['role'],
      forbiddenExpirTime: json['forbidden_expir_time'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_no': groupNo,
      'name': name,
      'avatar': avatar,
      'creator': creator,
      'notice': notice,
      'member_count': memberCount,
      'status': status,
      'version': version,
      'forbidden': forbidden,
      'invite': invite,
      'group_type': groupType,
      'allow_view_history_msg': allowViewHistoryMsg,
      'allow_member_pinned_message': allowMemberPinnedMessage,
      'join_group_remind': joinGroupRemind,
      'revoke_remind': revokeRemind,
      'receipt': receipt,
      'forbidden_add_friend': forbiddenAddFriend,
      'screenshot': screenshot,
      'chat_pwd_on': chatPwdOn,
      'mute': mute,
      'top': top,
      'show_nick': showNick,
      'save': save,
      'flame': flame,
      'flame_second': flameSecond,
      'remark': remark,
      'role': role,
      'forbidden_expir_time': forbiddenExpirTime,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  GroupInfo copyWith({
    String? groupNo,
    String? name,
    String? avatar,
    String? creator,
    String? notice,
    int? memberCount,
    int? status,
    int? version,
    int? forbidden,
    int? invite,
    int? groupType,
    int? allowViewHistoryMsg,
    int? allowMemberPinnedMessage,
    int? joinGroupRemind,
    int? revokeRemind,
    int? receipt,
    int? forbiddenAddFriend,
    int? screenshot,
    int? chatPwdOn,
    int? mute,
    int? top,
    int? showNick,
    int? save,
    int? flame,
    int? flameSecond,
    String? remark,
    int? role,
    int? forbiddenExpirTime,
    String? createdAt,
    String? updatedAt,
  }) {
    return GroupInfo(
      groupNo: groupNo ?? this.groupNo,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      creator: creator ?? this.creator,
      notice: notice ?? this.notice,
      memberCount: memberCount ?? this.memberCount,
      status: status ?? this.status,
      version: version ?? this.version,
      forbidden: forbidden ?? this.forbidden,
      invite: invite ?? this.invite,
      groupType: groupType ?? this.groupType,
      allowViewHistoryMsg: allowViewHistoryMsg ?? this.allowViewHistoryMsg,
      allowMemberPinnedMessage:
          allowMemberPinnedMessage ?? this.allowMemberPinnedMessage,
      joinGroupRemind: joinGroupRemind ?? this.joinGroupRemind,
      revokeRemind: revokeRemind ?? this.revokeRemind,
      receipt: receipt ?? this.receipt,
      forbiddenAddFriend: forbiddenAddFriend ?? this.forbiddenAddFriend,
      screenshot: screenshot ?? this.screenshot,
      chatPwdOn: chatPwdOn ?? this.chatPwdOn,
      mute: mute ?? this.mute,
      top: top ?? this.top,
      showNick: showNick ?? this.showNick,
      save: save ?? this.save,
      flame: flame ?? this.flame,
      flameSecond: flameSecond ?? this.flameSecond,
      remark: remark ?? this.remark,
      role: role ?? this.role,
      forbiddenExpirTime: forbiddenExpirTime ?? this.forbiddenExpirTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class GroupMemberStatus {
  static const int normal = 1;
  static const int blacklist = 2;
}

class GroupMember {
  final String groupNo;
  final String uid;
  final String? name;
  final String? avatar;
  final int? role;
  final String? remark;
  final int? status;
  final int? version;
  final String? inviteUid;
  final int? forbiddenExpirTime;
  final int? joinTime;

  GroupMember({
    required this.groupNo,
    required this.uid,
    this.name,
    this.avatar,
    this.role,
    this.remark,
    this.status,
    this.version,
    this.inviteUid,
    this.forbiddenExpirTime,
    this.joinTime,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final groupNo =
        _firstNonEmptyString(json['group_no'], json['channel_id']) ?? '';
    final uid = _firstNonEmptyString(json['uid'], json['member_uid']) ?? '';
    final name = _firstNonEmptyString(
      json['name'],
      json['member_name'],
      json['username'],
    );
    final avatar = _firstNonEmptyString(json['avatar'], json['member_avatar']);
    final remark = _firstNonEmptyString(json['remark'], json['member_remark']);

    return GroupMember(
      groupNo: groupNo,
      uid: uid,
      name: name,
      avatar: avatar,
      role: json['role'],
      remark: remark,
      status: json['status'],
      version: json['version'],
      inviteUid: json['invite_uid'],
      forbiddenExpirTime: json['forbidden_expir_time'],
      joinTime: json['join_time'],
    );
  }

  GroupMember copyWith({
    String? groupNo,
    String? uid,
    String? name,
    String? avatar,
    int? role,
    String? remark,
    int? status,
    int? version,
    String? inviteUid,
    int? forbiddenExpirTime,
    int? joinTime,
  }) {
    return GroupMember(
      groupNo: groupNo ?? this.groupNo,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      version: version ?? this.version,
      inviteUid: inviteUid ?? this.inviteUid,
      forbiddenExpirTime: forbiddenExpirTime ?? this.forbiddenExpirTime,
      joinTime: joinTime ?? this.joinTime,
    );
  }

  /// 角色判断
  bool get isOwner => role == 1;
  bool get isAdmin => role == 2;
  bool get isNormal => role == 0;
  bool get isBlacklisted => status == GroupMemberStatus.blacklist;

  bool isMutedAt(DateTime now) {
    final expirationTime = forbiddenExpirTime ?? 0;
    if (expirationTime <= 0) {
      return false;
    }

    final nowUnixSeconds = now.millisecondsSinceEpoch ~/ 1000;
    return expirationTime > nowUnixSeconds;
  }
}

String? _firstNonEmptyString(
  dynamic first, [
  dynamic second,
  dynamic third,
  dynamic fourth,
  dynamic fifth,
  dynamic sixth,
  dynamic seventh,
  dynamic eighth,
  dynamic ninth,
]) {
  for (final value in <dynamic>[
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
    eighth,
    ninth,
  ]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}
