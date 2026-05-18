import '../../core/utils/avatar_utils.dart';
import '../../modules/customer_service/customer_service_identity.dart';

class Friend {
  final String uid;
  final String? name;
  final String? avatar;
  final String? remark;
  final int? status;
  final String? category;
  final int? robot;
  final int? beDeleted;
  final int? beBlacklist;
  final int? isUploadAvatar;
  final int? createdAt;
  final int? updatedAt;
  final int vipLevel;

  bool get isVip => vipLevel == 1;
  bool get isCustomerService => isCustomerServiceCategory(category);

  Friend({
    required this.uid,
    this.name,
    this.avatar,
    this.remark,
    this.status,
    String? category,
    this.robot,
    this.beDeleted,
    this.beBlacklist,
    this.isUploadAvatar,
    this.createdAt,
    this.updatedAt,
    this.vipLevel = 0,
  }) : category = normalizePublicAccountCategory(category);

  factory Friend.fromJson(Map<String, dynamic> json) {
    // 服务器返回 uid 在 to_uid 字段中
    final uid = json['uid'] ?? json['to_uid'] ?? '';
    final nestedUser = _firstMap(
      json['to_user'],
      json['user'],
      json['channel'],
    );
    final isUploadAvatar = _parseTimestamp(json['is_upload_avatar']);
    final name = _normalizeBuiltInName(
      uid.toString(),
      _firstNonEmptyText(
        json['name'],
        json['to_name'],
        json['nickname'],
        json['display_name'],
        json['channel_name'],
        nestedUser?['name'],
        nestedUser?['nickname'],
        nestedUser?['display_name'],
        nestedUser?['channel_name'],
      ),
    );
    return Friend(
      uid: uid,
      name: name,
      avatar: _resolveAvatarUrl(
        _firstNonEmptyText(
          json['avatar'],
          json['to_avatar'],
          json['channel_avatar'],
          nestedUser?['avatar'],
          nestedUser?['channel_avatar'],
        ),
        uid.toString(),
        isUploadAvatar: isUploadAvatar,
      ),
      remark: _firstNonEmptyText(
        json['remark'],
        json['to_remark'],
        json['friend_remark'],
        json['channel_remark'],
        nestedUser?['remark'],
        nestedUser?['friend_remark'],
        nestedUser?['channel_remark'],
      ),
      status: _parseTimestamp(json['status']),
      category: normalizePublicAccountCategory(json['category']?.toString()),
      robot: _parseTimestamp(json['robot']),
      beDeleted: _parseTimestamp(json['be_deleted']),
      beBlacklist: _parseTimestamp(json['be_blacklist']),
      isUploadAvatar: isUploadAvatar,
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      vipLevel: _parseTimestamp(json['vip_level']) ?? 0,
    );
  }

  static Map<String, dynamic>? _firstMap(
    Object? first, [
    Object? second,
    Object? third,
  ]) {
    for (final value in <Object?>[first, second, third]) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  static String? _firstNonEmptyText(
    Object? first, [
    Object? second,
    Object? third,
    Object? fourth,
    Object? fifth,
    Object? sixth,
    Object? seventh,
    Object? eighth,
    Object? ninth,
  ]) {
    for (final value in <Object?>[
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
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String && value.isNotEmpty) {
      // 处理时间戳字符串
      try {
        return int.tryParse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'remark': remark,
      'status': status,
      'category': category,
      'robot': robot,
      'be_deleted': beDeleted,
      'be_blacklist': beBlacklist,
      'is_upload_avatar': isUploadAvatar,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'vip_level': vipLevel,
    };
  }

  bool get isSystemAccount {
    final normalizedCategory = normalizePublicAccountCategory(category) ?? '';
    return normalizedCategory == 'system' ||
        (robot ?? 0) == 1 ||
        uid == 'u_10000' ||
        uid == 'fileHelper';
  }
}

String? _resolveAvatarUrl(
  dynamic rawAvatar,
  String uid, {
  int? isUploadAvatar,
}) {
  return resolveUserAvatarUrl(rawAvatar?.toString(), uid);
}

class FriendRequest {
  final int id;
  final String fromUid;
  final String? fromName;
  final String? fromAvatar;
  final String? toUid;
  final String? toName;
  final String? toAvatar;
  final int? status;
  final String? token;
  final String? extra;
  final int? createdAt;

  FriendRequest({
    required this.id,
    required this.fromUid,
    this.fromName,
    this.fromAvatar,
    this.toUid,
    this.toName,
    this.toAvatar,
    this.status,
    this.token,
    this.extra,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final fromUid =
        json['to_uid']?.toString() ??
        json['from_uid']?.toString() ??
        json['uid']?.toString() ??
        '';
    final toUid = json['uid']?.toString() ?? json['receiver_uid']?.toString();
    return FriendRequest(
      id: _parseTimestamp(json['id']) ?? 0,
      fromUid: fromUid,
      fromName: _normalizeBuiltInName(
        fromUid,
        json['to_name']?.toString() ?? json['from_name']?.toString(),
      ),
      fromAvatar:
          json['to_avatar']?.toString() ?? json['from_avatar']?.toString(),
      toUid: toUid,
      toName: _normalizeBuiltInName(toUid ?? '', json['name']?.toString()),
      toAvatar: json['avatar']?.toString(),
      status: _parseTimestamp(json['status']),
      token: json['token']?.toString(),
      extra: json['remark'] ?? json['extra'],
      createdAt: _parseTimestamp(json['created_at']),
    );
  }

  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return int.tryParse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool get isPending => (status ?? 0) == 0;

  bool get isAccepted => (status ?? 0) == 1;

  bool get isRejected => (status ?? 0) == 2;
}

String? _normalizeBuiltInName(String uid, String? raw) {
  final normalized = raw?.trim();
  if (uid == 'u_10000') {
    return '系统账号';
  }
  if (uid == 'fileHelper') {
    return '文件传输助手';
  }
  if (normalized == null || normalized.isEmpty) {
    return normalized;
  }
  const replacements = {'系统账号': '系统账号', '文件传输助手': '文件传输助手'};
  return replacements[normalized] ?? normalized;
}
