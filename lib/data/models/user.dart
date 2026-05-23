import 'dart:convert';

import '../../core/utils/avatar_utils.dart';
import '../../modules/customer_service/customer_service_identity.dart';

enum VipStatus { none, active, expired }

class VipEntitlement {
  const VipEntitlement._();

  static const String addFriend = 'add_friend';
  static const String createGroup = 'create_group';
  static const String inviteGroupMember = 'invite_group_member';
  static const String systemManagement = 'system_management';

  static const Set<String> merchantDefaults = <String>{
    addFriend,
    createGroup,
    inviteGroupMember,
    systemManagement,
  };
}

class UserInfo {
  final String uid;
  final String? name;
  final String? avatar;
  final String? phone;
  final int? sex;
  final String? shortNo;
  final int? shortStatus;
  final String? vercode;
  final String? sourceDesc;
  final String? joinGroupInviteUid;
  final String? joinGroupInviteName;
  final String? joinGroupTime;
  final String? zone;
  final int? status;
  final String? token;
  final String? category;
  final String? username;
  final String? region;
  final String? signature;
  final DateTime? createdAt;
  final String? remark;
  final DateTime? friendCreatedAt;
  final int? follow;
  final int? beBlacklist;
  final int? isUploadAvatar;
  final int? flame;
  final int? flameSecond;
  final String? chatPwd;
  final int? chatPwdOn;
  final int vipLevel;
  final DateTime? vipExpireTime;
  final VipStatus? explicitVipStatus;
  final Set<String>? vipEntitlements;

  VipStatus get vipStatus {
    if (explicitVipStatus != null) {
      return explicitVipStatus!;
    }
    if (vipLevel != 1) {
      return VipStatus.none;
    }
    final expireTime = vipExpireTime;
    if (expireTime != null && !expireTime.isAfter(DateTime.now())) {
      return VipStatus.expired;
    }
    return VipStatus.active;
  }

  bool get isVip => vipStatus == VipStatus.active;
  bool get isCustomerService => isCustomerServiceCategory(category);
  bool get canAddFriend => hasVipEntitlement(VipEntitlement.addFriend);
  bool get canCreateGroup => hasVipEntitlement(VipEntitlement.createGroup);
  bool get canInviteGroupMember =>
      hasVipEntitlement(VipEntitlement.inviteGroupMember);
  bool get canUseSystemManagement =>
      hasVipEntitlement(VipEntitlement.systemManagement);

  bool hasVipEntitlement(String entitlement) {
    if (!isVip) {
      return false;
    }
    final explicitEntitlements = vipEntitlements;
    if (explicitEntitlements == null) {
      return VipEntitlement.merchantDefaults.contains(entitlement);
    }
    return explicitEntitlements.contains(entitlement);
  }

  UserInfo({
    required this.uid,
    this.name,
    this.avatar,
    this.phone,
    this.sex,
    this.shortNo,
    this.shortStatus,
    this.vercode,
    this.sourceDesc,
    this.joinGroupInviteUid,
    this.joinGroupInviteName,
    this.joinGroupTime,
    this.zone,
    this.status,
    this.token,
    String? category,
    this.username,
    this.region,
    this.signature,
    this.createdAt,
    this.remark,
    this.friendCreatedAt,
    this.follow,
    this.beBlacklist,
    this.isUploadAvatar,
    this.flame,
    this.flameSecond,
    this.chatPwd,
    this.chatPwdOn,
    this.vipLevel = 0,
    this.vipExpireTime,
    VipStatus? vipStatus,
    Set<String>? vipEntitlements,
  }) : category = normalizePublicAccountCategory(category),
       explicitVipStatus = vipStatus,
       vipEntitlements = vipEntitlements == null
           ? null
           : Set<String>.unmodifiable(vipEntitlements);

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final uid = json['uid']?.toString() ?? '';
    final isUploadAvatar = _parseInt(json['is_upload_avatar']);
    return UserInfo(
      uid: uid,
      name: json['name'],
      avatar: _resolveAvatarUrl(json['avatar'], uid),
      phone: json['phone'],
      sex: json['sex'],
      shortNo: json['short_no'],
      shortStatus: _parseInt(json['short_status']),
      vercode: json['vercode'],
      sourceDesc: json['source_desc'],
      joinGroupInviteUid: json['join_group_invite_uid'],
      joinGroupInviteName: json['join_group_invite_name'],
      joinGroupTime: json['join_group_time'],
      zone: json['zone'],
      status: json['status'],
      token: json['token'],
      username: json['username'],
      region: json['region'],
      signature: json['signature'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      remark: json['remark'],
      friendCreatedAt: json['friend_created_at'] != null
          ? DateTime.tryParse(json['friend_created_at'])
          : null,
      follow: _parseInt(json['follow']),
      beBlacklist: _parseInt(json['be_blacklist']),
      isUploadAvatar: isUploadAvatar,
      flame: _parseInt(json['flame']),
      flameSecond: _parseInt(json['flame_second'] ?? json['flameSecond']),
      chatPwd: json['chat_pwd']?.toString(),
      chatPwdOn: _parseInt(json['chat_pwd_on']),
      category: normalizeCustomerServiceCategory(json['category']?.toString()),
      vipLevel: _parseInt(json['vip_level']) ?? 0,
      vipExpireTime: _parseDateTime(
        json['vip_expire_time'] ?? json['vip_expire_at'],
      ),
      vipStatus: _parseVipStatus(json['vip_status']),
      vipEntitlements: _parseVipEntitlements(
        json['entitlements'] ??
            json['vip_entitlements'] ??
            json['permissions'] ??
            json['vip_permissions'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'phone': phone,
      'sex': sex,
      'short_no': shortNo,
      'short_status': shortStatus,
      'vercode': vercode,
      'source_desc': sourceDesc,
      'join_group_invite_uid': joinGroupInviteUid,
      'join_group_invite_name': joinGroupInviteName,
      'join_group_time': joinGroupTime,
      'zone': zone,
      'status': status,
      'token': token,
      'category': category,
      'username': username,
      'region': region,
      'signature': signature,
      'created_at': createdAt?.toIso8601String(),
      'remark': remark,
      'friend_created_at': friendCreatedAt?.toIso8601String(),
      'follow': follow,
      'be_blacklist': beBlacklist,
      'is_upload_avatar': isUploadAvatar,
      'flame': flame,
      'flame_second': flameSecond,
      'chat_pwd': chatPwd,
      'chat_pwd_on': chatPwdOn,
      'vip_level': vipLevel,
      'vip_expire_time': vipExpireTime == null
          ? null
          : _formatVipExpireTime(vipExpireTime!),
      'vip_status': vipStatus.name,
      'entitlements': vipEntitlements?.toList(growable: false),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserInfo.fromJsonString(String jsonStr) {
    return UserInfo.fromJson(jsonDecode(jsonStr));
  }

  UserInfo copyWith({
    String? uid,
    String? name,
    String? avatar,
    String? phone,
    int? sex,
    String? shortNo,
    int? shortStatus,
    String? vercode,
    String? sourceDesc,
    String? joinGroupInviteUid,
    String? joinGroupInviteName,
    String? joinGroupTime,
    String? zone,
    int? status,
    String? token,
    String? category,
    String? username,
    String? region,
    String? signature,
    DateTime? createdAt,
    String? remark,
    DateTime? friendCreatedAt,
    int? follow,
    int? beBlacklist,
    int? isUploadAvatar,
    int? flame,
    int? flameSecond,
    String? chatPwd,
    int? chatPwdOn,
    int? vipLevel,
    DateTime? vipExpireTime,
    VipStatus? vipStatus,
    Set<String>? vipEntitlements,
  }) {
    return UserInfo(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      sex: sex ?? this.sex,
      shortNo: shortNo ?? this.shortNo,
      shortStatus: shortStatus ?? this.shortStatus,
      vercode: vercode ?? this.vercode,
      sourceDesc: sourceDesc ?? this.sourceDesc,
      joinGroupInviteUid: joinGroupInviteUid ?? this.joinGroupInviteUid,
      joinGroupInviteName: joinGroupInviteName ?? this.joinGroupInviteName,
      joinGroupTime: joinGroupTime ?? this.joinGroupTime,
      zone: zone ?? this.zone,
      status: status ?? this.status,
      token: token ?? this.token,
      category: category == null
          ? this.category
          : normalizePublicAccountCategory(category),
      username: username ?? this.username,
      region: region ?? this.region,
      signature: signature ?? this.signature,
      createdAt: createdAt ?? this.createdAt,
      remark: remark ?? this.remark,
      friendCreatedAt: friendCreatedAt ?? this.friendCreatedAt,
      follow: follow ?? this.follow,
      beBlacklist: beBlacklist ?? this.beBlacklist,
      isUploadAvatar: isUploadAvatar ?? this.isUploadAvatar,
      flame: flame ?? this.flame,
      flameSecond: flameSecond ?? this.flameSecond,
      chatPwd: chatPwd ?? this.chatPwd,
      chatPwdOn: chatPwdOn ?? this.chatPwdOn,
      vipLevel: vipLevel ?? this.vipLevel,
      vipExpireTime: vipExpireTime ?? this.vipExpireTime,
      vipStatus: vipStatus ?? explicitVipStatus,
      vipEntitlements: vipEntitlements ?? this.vipEntitlements,
    );
  }
}

/// User alias for UserInfo
typedef User = UserInfo;

String? _resolveAvatarUrl(dynamic rawAvatar, String uid) {
  return resolveUserAvatarUrl(rawAvatar?.toString(), uid);
}

int? _parseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final unixSeconds = int.tryParse(text);
  if (unixSeconds != null) {
    return DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

VipStatus? _parseVipStatus(dynamic value) {
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) {
    return null;
  }
  switch (text) {
    case 'active':
    case 'valid':
    case '1':
      return VipStatus.active;
    case 'expired':
    case 'expire':
    case '2':
      return VipStatus.expired;
    case 'none':
    case 'normal':
    case '0':
      return VipStatus.none;
    default:
      return null;
  }
}

Set<String>? _parseVipEntitlements(dynamic value) {
  if (value == null) {
    return null;
  }
  final entitlements = <String>{};
  if (value is Iterable) {
    for (final item in value) {
      final entitlement = item?.toString().trim();
      if (entitlement != null && entitlement.isNotEmpty) {
        entitlements.add(entitlement);
      }
    }
    return entitlements;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      final enabled =
          entry.value == true ||
          entry.value == 1 ||
          entry.value?.toString().toLowerCase() == 'true';
      final entitlement = entry.key.toString().trim();
      if (enabled && entitlement.isNotEmpty) {
        entitlements.add(entitlement);
      }
    }
    return entitlements;
  }
  return null;
}

String _formatVipExpireTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-'
      '${twoDigits(value.month)}-'
      '${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:'
      '${twoDigits(value.minute)}:'
      '${twoDigits(value.second)}';
}
