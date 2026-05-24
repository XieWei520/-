import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/avatar_utils.dart';
import '../../data/models/group.dart';
import '../../data/models/group_dingtalk_robot_config.dart';
import '../../data/models/group_feishu_robot_config.dart';
import '../../data/models/group_forbidden_time_option.dart';
import '../../data/models/group_notice_history.dart';
import '../../data/models/group_reminder.dart';
import 'api_client.dart';

const String _nonAuthoritativeGroupApiContractWarning =
    'Non-authoritative: local TangSengDaoDaoServer-main source did not '
    'confirm this contract, and it is not wired into production parity flows.';

enum GroupBlacklistAction { add, remove }

enum GroupMemberForbiddenAction { mute, unmute }

extension GroupBlacklistActionPathValue on GroupBlacklistAction {
  String get pathValue => this == GroupBlacklistAction.add ? 'add' : 'remove';
}

extension GroupMemberForbiddenActionApiValue on GroupMemberForbiddenAction {
  int get apiValue => this == GroupMemberForbiddenAction.mute ? 1 : 0;
}

class GroupApi {
  GroupApi._();

  static const String _webhookModeOfficial = 'official';
  static const String _webhookModeImGenerated = 'im_generated';

  static final GroupApi _instance = GroupApi._();
  static GroupApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final Map<String, String> _groupAvatarOverrides = <String, String>{};
  final Map<String, Map<String, String>> _feishuRobotIdentityOverrides =
      <String, Map<String, String>>{};
  final Map<String, Map<String, String>> _dingTalkRobotIdentityOverrides =
      <String, Map<String, String>>{};

  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _resolveBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  String _extractUploadedAvatar(dynamic raw) {
    if (raw is String) {
      return raw.trim();
    }
    if (raw is Map) {
      final data = raw['data'];
      if (data != null && !identical(data, raw)) {
        final avatar = _extractUploadedAvatar(data);
        if (avatar.isNotEmpty) {
          return avatar;
        }
      }
      for (final key in const <String>[
        'avatar',
        'url',
        'path',
        'file_url',
        'fileUrl',
        'src',
        'location',
      ]) {
        final value = raw[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  Map<String, dynamic> _normalizeQrPayload(dynamic raw) {
    if (raw is String) {
      final value = raw.trim();
      return value.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'qrcode': value};
    }

    final body = _resolveBody(raw);
    final data = body['data'];
    if (data is String) {
      final value = data.trim();
      return value.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'qrcode': value};
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }

  void _cacheGroupChannel(GroupInfo group) {
    final groupNo = group.groupNo.trim();
    if (groupNo.isEmpty) {
      return;
    }

    final channel = WKChannel(groupNo, WKChannelType.group)
      ..channelName = (group.name ?? '').trim()
      ..channelRemark = (group.remark ?? '').trim()
      ..avatar = resolveGroupAvatarUrl(group.avatar, groupNo) ?? ''
      ..mute = group.mute ?? 0
      ..top = group.top ?? 0
      ..showNick = group.showNick ?? 1
      ..save = group.save ?? 1
      ..status = group.status ?? 1
      ..forbidden = group.forbidden ?? 0
      ..invite = group.invite ?? 0
      ..version = group.version ?? 0
      ..remoteExtraMap = <String, dynamic>{
        if ((group.memberCount ?? 0) > 0)
          'member_count': group.memberCount ?? 0,
        'allow_member_pinned_message': group.allowMemberPinnedMessage ?? 0,
        'chat_pwd_on': group.chatPwdOn ?? 0,
        'flame': group.flame ?? 0,
        'flame_second': group.flameSecond ?? 0,
        'role': group.role ?? 0,
      }
      ..localExtra = <String, dynamic>{
        'allow_member_pinned_message': group.allowMemberPinnedMessage ?? 0,
        'chat_pwd_on': group.chatPwdOn ?? 0,
        'flame': group.flame ?? 0,
        'flame_second': group.flameSecond ?? 0,
        'role': group.role ?? 0,
      };
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
  }

  List<GroupInfo> _parseGroupList(dynamic raw) {
    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw['data'] != null) {
      list = raw['data'] as List<dynamic>;
    } else {
      list = [];
    }

    return list
        .map(
          (json) => GroupInfo.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .where((group) => group.groupNo.trim().isNotEmpty)
        .toList();
  }

  List<String>? _normalizeMemberNames(
    List<String> memberIds,
    List<String>? memberNames,
  ) {
    if (memberNames == null || memberNames.isEmpty) {
      return null;
    }

    return List<String>.generate(memberIds.length, (index) {
      if (index >= memberNames.length) {
        return memberIds[index];
      }
      final displayName = memberNames[index].trim();
      return displayName.isEmpty ? memberIds[index] : displayName;
    });
  }

  String? _normalizeWebhookModePayload(String? webhookMode) {
    if (webhookMode == null) {
      return null;
    }

    final normalized = webhookMode.trim().toLowerCase();
    if (normalized == _webhookModeOfficial) {
      return _webhookModeOfficial;
    }
    if (normalized == _webhookModeImGenerated) {
      return _webhookModeImGenerated;
    }
    return null;
  }

  void _rememberGroupAvatarOverride(String groupNo, String avatar) {
    final normalizedGroupNo = groupNo.trim();
    final normalizedAvatar = avatar.trim();
    if (normalizedGroupNo.isEmpty || normalizedAvatar.isEmpty) {
      return;
    }
    _groupAvatarOverrides[normalizedGroupNo] = normalizedAvatar;
  }

  GroupInfo _applyGroupAvatarOverride(GroupInfo group) {
    final override = _groupAvatarOverrides[group.groupNo.trim()]?.trim() ?? '';
    if (override.isEmpty) {
      return group;
    }
    return group.copyWith(avatar: override);
  }

  void _rememberRobotIdentityOverride(
    Map<String, Map<String, String>> overrides,
    String groupNo, {
    String? displayName,
    String? displayAvatar,
  }) {
    final normalizedGroupNo = groupNo.trim();
    if (normalizedGroupNo.isEmpty) {
      return;
    }
    if (displayName == null && displayAvatar == null) {
      return;
    }

    final override = overrides.putIfAbsent(
      normalizedGroupNo,
      () => <String, String>{},
    );
    if (displayName != null) {
      override['display_name'] = displayName;
    }
    if (displayAvatar != null) {
      override['display_avatar'] = displayAvatar;
    }
  }

  GroupFeishuRobotConfig _applyFeishuRobotIdentityOverride(
    GroupFeishuRobotConfig config,
  ) {
    final override = _feishuRobotIdentityOverrides[config.groupNo.trim()];
    if (override == null || override.isEmpty) {
      return config;
    }
    return config.copyWith(
      displayName: override.containsKey('display_name')
          ? override['display_name']
          : null,
      displayAvatar: override.containsKey('display_avatar')
          ? override['display_avatar']
          : null,
    );
  }

  GroupDingTalkRobotConfig _applyDingTalkRobotIdentityOverride(
    GroupDingTalkRobotConfig config,
  ) {
    final override = _dingTalkRobotIdentityOverrides[config.groupNo.trim()];
    if (override == null || override.isEmpty) {
      return config;
    }
    return config.copyWith(
      displayName: override.containsKey('display_name')
          ? override['display_name']
          : null,
      displayAvatar: override.containsKey('display_avatar')
          ? override['display_avatar']
          : null,
    );
  }

  dynamic _robotResponsePayload(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }

  Map<String, dynamic> _robotConfigResponseMap(dynamic raw, String groupNo) {
    final payload = _robotResponsePayload(raw);
    final data = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    if ((data['group_no']?.toString().trim() ?? '').isEmpty) {
      data['group_no'] = groupNo;
    }
    return data;
  }

  GroupFeishuRobotConfig _buildFeishuRobotConfigFromResponse(
    String groupNo,
    dynamic raw, {
    required bool enabled,
    String? appId,
    String? appSecret,
    String? webhookMode,
    String? officialWebhookUrl,
    String? officialSecret,
    String? displayName,
    String? displayAvatar,
  }) {
    final data = _robotConfigResponseMap(raw, groupNo);
    data['enabled'] = enabled ? 1 : 0;
    if (appId != null) {
      data['app_id'] = appId;
    }
    if (appSecret != null) {
      data['app_secret'] = appSecret;
    }
    if (webhookMode != null) {
      data['webhook_mode'] = webhookMode;
    }
    if (officialWebhookUrl != null) {
      data['official_webhook_url'] = officialWebhookUrl;
    }
    if (officialSecret != null) {
      data['official_secret'] = officialSecret;
    }
    if (displayName != null) {
      data['display_name'] = displayName;
    }
    if (displayAvatar != null) {
      data['display_avatar'] = displayAvatar;
    }
    return GroupFeishuRobotConfig.fromJson(data);
  }

  GroupDingTalkRobotConfig _buildDingTalkRobotConfigFromResponse(
    String groupNo,
    dynamic raw, {
    required bool enabled,
    String? webhookMode,
    String? officialWebhookUrl,
    String? officialSecret,
    String? displayName,
    String? displayAvatar,
  }) {
    final data = _robotConfigResponseMap(raw, groupNo);
    data['enabled'] = enabled ? 1 : 0;
    if (webhookMode != null) {
      data['webhook_mode'] = webhookMode;
    }
    if (officialWebhookUrl != null) {
      data['official_webhook_url'] = officialWebhookUrl;
    }
    if (officialSecret != null) {
      data['official_secret'] = officialSecret;
    }
    if (displayName != null) {
      data['display_name'] = displayName;
    }
    if (displayAvatar != null) {
      data['display_avatar'] = displayAvatar;
    }
    return GroupDingTalkRobotConfig.fromJson(data);
  }

  Future<GroupInfo> createGroup(
    List<String> memberIds, {
    String? name,
    List<String>? memberNames,
  }) async {
    final data = <String, dynamic>{'members': memberIds, 'uids': memberIds};
    final normalizedMemberNames = _normalizeMemberNames(memberIds, memberNames);
    if (name != null) {
      data['name'] = name;
    }
    if (normalizedMemberNames != null) {
      data['member_names'] = normalizedMemberNames;
      data['names'] = normalizedMemberNames;
    }
    final response = await _client.post(ApiConfig.groupCreate, data: data);
    _ensureSuccess(response, fallback: 'Create group failed');

    var group = GroupInfo.fromJson(
      Map<String, dynamic>.from(
        response.data['data'] ?? response.data ?? <String, dynamic>{},
      ),
    );

    try {
      await updateGroupSetting(group.groupNo, 'save', 1);
    } catch (_) {}

    try {
      group = await getGroupInfo(group.groupNo);
    } catch (_) {}

    _cacheGroupChannel(group);
    return group;
  }

  Future<List<GroupInfo>> getMyGroups() async {
    final response = await _client.get(ApiConfig.groupMy);
    _ensureSuccess(response, fallback: 'Load groups failed');

    final serverGroups = _parseGroupList(response.data);
    final hydratedServerGroups = await Future.wait(
      serverGroups.map((group) async {
        try {
          return await getGroupInfo(group.groupNo);
        } catch (_) {
          return group;
        }
      }),
    );
    for (final group in hydratedServerGroups) {
      _cacheGroupChannel(group);
    }

    return hydratedServerGroups;
  }

  Future<GroupInfo> getGroupInfo(
    String groupNo, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo',
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Load group info failed');

    final group = _applyGroupAvatarOverride(
      GroupInfo.fromJson(
        Map<String, dynamic>.from(
          response.data['data'] ?? response.data ?? <String, dynamic>{},
        ),
      ),
    );
    _cacheGroupChannel(group);
    return group;
  }

  Future<List<GroupMember>> getGroupMembers(String groupNo) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupMembers}',
      queryParameters: const <String, dynamic>{'page': 1, 'limit': 100000},
    );
    _ensureSuccess(response, fallback: 'Load group members failed');

    final List<dynamic> list;
    if (response.data is List) {
      list = response.data as List<dynamic>;
    } else if (response.data is Map && response.data['data'] != null) {
      list = response.data['data'] as List<dynamic>;
    } else {
      list = [];
    }

    return list
        .map(
          (json) =>
              GroupMember.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<void> addGroupMembers(
    String groupNo,
    List<String> memberIds, {
    List<String>? memberNames,
  }) async {
    final normalizedMemberNames = _normalizeMemberNames(memberIds, memberNames);
    final data = <String, dynamic>{'uids': memberIds, 'members': memberIds};
    if (normalizedMemberNames != null) {
      data['names'] = normalizedMemberNames;
      data['member_names'] = normalizedMemberNames;
    }
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupMembers}',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Add group members failed');
  }

  Future<void> removeGroupMembers(
    String groupNo,
    List<String> memberIds,
  ) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupMembers}',
      data: {'uids': memberIds, 'members': memberIds},
    );
    _ensureSuccess(response, fallback: 'Remove group members failed');
  }

  Future<void> updateGroupInfo(
    String groupNo, {
    String? name,
    String? avatar,
    String? notice,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (avatar != null) {
      data['avatar'] = avatar;
    }
    if (notice != null) {
      data['notice'] = notice;
    }
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Update group info failed');
    if (avatar != null) {
      _rememberGroupAvatarOverride(groupNo, avatar);
    }
  }

  Future<void> updateGroupMemberRemark(
    String groupNo,
    String uid,
    String remark,
  ) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupMembers}/$uid',
      data: {'remark': remark},
    );
    _ensureSuccess(response, fallback: 'Update group member remark failed');
  }

  Future<void> quitGroup(String groupNo) async {
    final response = await _client.post('${ApiConfig.groups}/$groupNo/exit');
    _ensureSuccess(response, fallback: 'Quit group failed');
  }

  Future<void> exitGroup(String groupNo) async {
    await quitGroup(groupNo);
  }

  Future<void> updateGroupNotice(String groupNo, String notice) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo',
      data: {'notice': notice},
    );
    _ensureSuccess(response, fallback: 'Update group notice failed');
  }

  Future<List<GroupNoticeHistory>> getGroupNoticeHistory(
    String groupNo, {
    int limit = 20,
  }) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/notice/history',
      queryParameters: {'limit': limit},
    );
    _ensureSuccess(response, fallback: 'Load group notice history failed');

    final rawList = response.data is List
        ? response.data as List<dynamic>
        : response.data is Map && response.data['data'] is List
        ? response.data['data'] as List<dynamic>
        : const <dynamic>[];

    return rawList
        .whereType<Map>()
        .map(
          (item) =>
              GroupNoticeHistory.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<GroupReminder>> getGroupReminders(
    String groupNo, {
    int limit = 50,
  }) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/reminders',
      queryParameters: {'limit': limit},
    );
    _ensureSuccess(response, fallback: 'Load group reminders failed');

    final rawList = response.data is List
        ? response.data as List<dynamic>
        : response.data is Map && response.data['data'] is List
        ? response.data['data'] as List<dynamic>
        : const <dynamic>[];

    return rawList
        .whereType<Map>()
        .map((item) => GroupReminder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GroupReminder> createGroupReminder(
    String groupNo, {
    required String title,
    String content = '',
    required int remindAt,
    List<String> assigneeUids = const <String>[],
  }) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/reminders',
      data: {
        'title': title,
        'content': content,
        'remind_at': remindAt,
        'assignee_uids': assigneeUids,
      },
    );
    _ensureSuccess(response, fallback: 'Create group reminder failed');

    final raw = response.data is Map
        ? (response.data['data'] ?? response.data)
        : response.data;
    if (raw is! Map) {
      throw Exception('Invalid group reminder response');
    }
    return GroupReminder.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<GroupReminder> updateGroupReminder(
    String groupNo,
    int reminderId, {
    required String title,
    String content = '',
    required int remindAt,
    List<String> assigneeUids = const <String>[],
  }) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/reminders/$reminderId',
      data: {
        'title': title,
        'content': content,
        'remind_at': remindAt,
        'assignee_uids': assigneeUids,
      },
    );
    _ensureSuccess(response, fallback: 'Update group reminder failed');

    final raw = response.data is Map
        ? (response.data['data'] ?? response.data)
        : response.data;
    if (raw is! Map) {
      throw Exception('Invalid group reminder response');
    }
    return GroupReminder.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> cancelGroupReminder(String groupNo, int reminderId) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo/reminders/$reminderId',
    );
    _ensureSuccess(response, fallback: 'Cancel group reminder failed');
  }

  Future<void> completeGroupReminder(String groupNo, int reminderId) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/reminders/$reminderId/done',
    );
    _ensureSuccess(response, fallback: 'Complete group reminder failed');
  }

  Future<Map<String, dynamic>> getGroupQrCode(String groupNo) async {
    final response = await _client.get('${ApiConfig.groups}/$groupNo/qrcode');
    _ensureSuccess(response, fallback: 'Load group QR code failed');
    return _normalizeQrPayload(response.data);
  }

  Future<void> updateGroupSetting(
    String groupNo,
    String key,
    Object? value,
  ) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}',
      data: {key: value},
    );
    _ensureSuccess(response, fallback: 'Update group setting failed');
  }

  Future<void> setGroupInviteMode(String groupNo, bool inviteOnly) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}',
      data: {'invite': inviteOnly ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set group invite mode failed');
  }

  Future<void> setGroupJoinGroupRemind(String groupNo, bool enabled) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}',
      data: {'join_group_remind': enabled ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set join group remind failed');
  }

  Future<void> setGroupAllowViewHistory(String groupNo, bool enabled) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}',
      data: {'allow_view_history_msg': enabled ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set allow view history failed');
  }

  Future<void> setGroupAllowMemberPinnedMessage(
    String groupNo,
    bool enabled,
  ) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo${ApiConfig.groupSetting}',
      data: {'allow_member_pinned_message': enabled ? 1 : 0},
    );
    _ensureSuccess(
      response,
      fallback: 'Set allow member pinned message failed',
    );
  }

  Future<void> scanJoinGroup(String groupNo, String authCode) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/scanjoin',
      queryParameters: {'auth_code': authCode},
    );
    _ensureSuccess(response, fallback: 'Scan join group failed');
  }

  Future<void> dismissGroup(String groupNo) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo/disband',
    );
    _ensureSuccess(response, fallback: 'Dismiss group failed');
  }

  Future<void> setGroupManagers(String groupNo, List<String> memberIds) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/managers',
      data: {'uids': memberIds},
    );
    _ensureSuccess(response, fallback: 'Set group managers failed');
  }

  Future<void> removeGroupManagers(
    String groupNo,
    List<String> memberIds,
  ) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo/managers',
      data: {'uids': memberIds},
    );
    _ensureSuccess(response, fallback: 'Remove group managers failed');
  }

  Future<List<GroupForbiddenTimeOption>> getForbiddenTimes() async {
    final response = await _client.get('${ApiConfig.v1}/group/forbidden_times');
    _ensureSuccess(response, fallback: 'Load forbidden times failed');

    final raw = response.data;
    final List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map && raw['data'] is List) {
      list = raw['data'] as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }

    return list
        .whereType<Map>()
        .map(
          (item) => GroupForbiddenTimeOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> updateMemberForbidden(
    String groupNo, {
    required String memberUid,
    required GroupMemberForbiddenAction action,
    int? key,
  }) async {
    if (action == GroupMemberForbiddenAction.mute && key == null) {
      throw ArgumentError.value(
        key,
        'key',
        'key is required when action is mute',
      );
    }

    final data = <String, dynamic>{
      'member_uid': memberUid,
      'action': action.apiValue,
      if (action == GroupMemberForbiddenAction.mute && key != null) 'key': key,
    };
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/forbidden_with_member',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Update member forbidden failed');
  }

  Future<void> updateBlacklist(
    String groupNo, {
    required List<String> uids,
    required GroupBlacklistAction action,
  }) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/blacklist/${action.pathValue}',
      data: {'uids': uids},
    );
    _ensureSuccess(response, fallback: 'Update group blacklist failed');
  }

  Future<void> setGroupMute(String groupNo, bool mute) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/forbidden/${mute ? 1 : 0}',
    );
    _ensureSuccess(response, fallback: 'Set group mute failed');
  }

  Future<void> transferGroupOwner(String groupNo, String newOwnerId) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/transfer/$newOwnerId',
    );
    _ensureSuccess(response, fallback: 'Transfer group owner failed');
  }

  Future<String> uploadGroupAvatar(String groupNo, String filePath) async {
    final response = await _client.uploadFile(
      '${ApiConfig.groups}/$groupNo/avatar',
      filePath,
      name: 'file',
    );
    _ensureSuccess(response, fallback: 'Upload group avatar failed');
    final avatar = _extractUploadedAvatar(response.data);
    if (avatar.isNotEmpty) {
      await updateGroupInfo(groupNo, avatar: avatar);
      _rememberGroupAvatarOverride(groupNo, avatar);
      return avatar;
    }
    final canonicalAvatar = buildGroupAvatarUrl(groupNo) ?? '';
    final cacheBustedAvatar =
        buildGroupAvatarUrl(
          groupNo,
          cacheKey: DateTime.now().millisecondsSinceEpoch.toString(),
        ) ??
        '';
    if (canonicalAvatar.isNotEmpty) {
      await updateGroupInfo(groupNo, avatar: canonicalAvatar);
    }
    final visibleAvatar = cacheBustedAvatar.isNotEmpty
        ? cacheBustedAvatar
        : canonicalAvatar;
    _rememberGroupAvatarOverride(groupNo, visibleAvatar);
    return visibleAvatar;
  }

  Future<GroupFeishuRobotConfig?> getFeishuRobotConfig(String groupNo) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/robot/feishu',
    );
    _ensureSuccess(response, fallback: 'Load Feishu robot config failed');

    final raw = response.data is Map
        ? (response.data['data'] ?? response.data)
        : response.data;
    if (raw is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(raw);
    if ((data['group_no']?.toString() ?? '').trim().isEmpty) {
      return null;
    }
    return _applyFeishuRobotIdentityOverride(
      GroupFeishuRobotConfig.fromJson(data),
    );
  }

  Future<GroupFeishuRobotConfig> updateFeishuRobotConfig(
    String groupNo, {
    bool enabled = true,
    bool regenerateWebhook = false,
    bool regenerateSecret = false,
    String? webhookMode,
    String? officialWebhookUrl,
    String? officialSecret,
    String? appId,
    String? appSecret,
    String? displayName,
    String? displayAvatar,
  }) async {
    final normalizedWebhookMode = _normalizeWebhookModePayload(webhookMode);
    final trimmedOfficialWebhookUrl = officialWebhookUrl?.trim();
    final trimmedOfficialSecret = officialSecret?.trim();
    final trimmedAppId = appId?.trim();
    final trimmedAppSecret = appSecret?.trim();
    final trimmedDisplayName = displayName?.trim();
    final trimmedDisplayAvatar = displayAvatar?.trim();
    final data = <String, dynamic>{
      'enabled': enabled ? 1 : 0,
      if (regenerateWebhook) 'regenerate_webhook': 1,
      if (regenerateSecret) 'regenerate_secret': 1,
    };
    if (normalizedWebhookMode != null) {
      data['webhook_mode'] = normalizedWebhookMode;
    }
    if (trimmedOfficialWebhookUrl != null) {
      data['official_webhook_url'] = trimmedOfficialWebhookUrl;
    }
    if (trimmedOfficialSecret != null) {
      data['official_secret'] = trimmedOfficialSecret;
    }
    if (trimmedAppId != null) {
      data['app_id'] = trimmedAppId;
    }
    if (trimmedAppSecret != null) {
      data['app_secret'] = trimmedAppSecret;
    }
    if (trimmedDisplayName != null) {
      data['display_name'] = trimmedDisplayName;
    }
    if (trimmedDisplayAvatar != null) {
      data['display_avatar'] = trimmedDisplayAvatar;
    }
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/robot/feishu',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Save Feishu robot config failed');

    final saved = _buildFeishuRobotConfigFromResponse(
      groupNo,
      response.data,
      enabled: enabled,
      appId: trimmedAppId,
      appSecret: trimmedAppSecret,
      webhookMode: normalizedWebhookMode,
      officialWebhookUrl: trimmedOfficialWebhookUrl,
      officialSecret: trimmedOfficialSecret,
      displayName: trimmedDisplayName,
      displayAvatar: trimmedDisplayAvatar,
    );
    _rememberRobotIdentityOverride(
      _feishuRobotIdentityOverrides,
      groupNo,
      displayName: trimmedDisplayName,
      displayAvatar: trimmedDisplayAvatar,
    );
    return _applyFeishuRobotIdentityOverride(saved);
  }

  Future<void> deleteFeishuRobotConfig(String groupNo) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo/robot/feishu',
    );
    _ensureSuccess(response, fallback: 'Delete Feishu robot config failed');
  }

  Future<void> testFeishuRobotConfig(String groupNo) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/robot/feishu/test',
    );
    _ensureSuccess(response, fallback: 'Test Feishu robot config failed');
  }

  Future<GroupDingTalkRobotConfig?> getDingTalkRobotConfig(
    String groupNo,
  ) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/robot/dingtalk',
    );
    _ensureSuccess(response, fallback: 'Load DingTalk robot config failed');

    final raw = response.data is Map
        ? (response.data['data'] ?? response.data)
        : response.data;
    if (raw is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(raw);
    if ((data['group_no']?.toString() ?? '').trim().isEmpty) {
      return null;
    }
    return _applyDingTalkRobotIdentityOverride(
      GroupDingTalkRobotConfig.fromJson(data),
    );
  }

  Future<GroupDingTalkRobotConfig> updateDingTalkRobotConfig(
    String groupNo, {
    bool enabled = true,
    bool regenerateWebhook = false,
    bool regenerateSecret = false,
    String? webhookMode,
    String? officialWebhookUrl,
    String? officialSecret,
    String? displayName,
    String? displayAvatar,
  }) async {
    final normalizedWebhookMode = _normalizeWebhookModePayload(webhookMode);
    final trimmedOfficialWebhookUrl = officialWebhookUrl?.trim();
    final trimmedOfficialSecret = officialSecret?.trim();
    final trimmedDisplayName = displayName?.trim();
    final trimmedDisplayAvatar = displayAvatar?.trim();
    final data = <String, dynamic>{
      'enabled': enabled ? 1 : 0,
      if (regenerateWebhook) 'regenerate_webhook': 1,
      if (regenerateSecret) 'regenerate_secret': 1,
    };
    if (normalizedWebhookMode != null) {
      data['webhook_mode'] = normalizedWebhookMode;
    }
    if (trimmedOfficialWebhookUrl != null) {
      data['official_webhook_url'] = trimmedOfficialWebhookUrl;
    }
    if (trimmedOfficialSecret != null) {
      data['official_secret'] = trimmedOfficialSecret;
    }
    if (trimmedDisplayName != null) {
      data['display_name'] = trimmedDisplayName;
    }
    if (trimmedDisplayAvatar != null) {
      data['display_avatar'] = trimmedDisplayAvatar;
    }
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/robot/dingtalk',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Save DingTalk robot config failed');

    final saved = _buildDingTalkRobotConfigFromResponse(
      groupNo,
      response.data,
      enabled: enabled,
      webhookMode: normalizedWebhookMode,
      officialWebhookUrl: trimmedOfficialWebhookUrl,
      officialSecret: trimmedOfficialSecret,
      displayName: trimmedDisplayName,
      displayAvatar: trimmedDisplayAvatar,
    );
    _rememberRobotIdentityOverride(
      _dingTalkRobotIdentityOverrides,
      groupNo,
      displayName: trimmedDisplayName,
      displayAvatar: trimmedDisplayAvatar,
    );
    return _applyDingTalkRobotIdentityOverride(saved);
  }

  Future<void> deleteDingTalkRobotConfig(String groupNo) async {
    final response = await _client.delete(
      '${ApiConfig.groups}/$groupNo/robot/dingtalk',
    );
    _ensureSuccess(response, fallback: 'Delete DingTalk robot config failed');
  }

  Future<void> testDingTalkRobotConfig(String groupNo) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/robot/dingtalk/test',
    );
    _ensureSuccess(response, fallback: 'Test DingTalk robot config failed');
  }

  /// Invites members to join a group.
  ///
  /// [groupNo] - The group number to invite members to.
  /// [memberIds] - List of user IDs to invite.
  ///
  /// Throws exception if the operation fails.
  Future<void> inviteMembers(String groupNo, List<String> memberIds) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/member/invite',
      data: {'uids': memberIds, 'member_ids': memberIds},
    );
    _ensureSuccess(response, fallback: 'Invite members failed');
  }

  /// Applies to join a group.
  ///
  /// [groupNo] - The group number to join.
  /// [reason] - Optional reason for joining (may be required for private groups).
  ///
  /// Throws exception if the operation fails.
  Future<void> joinGroup(String groupNo, {String? reason}) async {
    final data = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) {
      data['reason'] = reason;
    }
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/join',
      data: data,
    );
    _ensureSuccess(response, fallback: 'Join group failed');
  }

  /// Gets group invitation info from a QR code or link.
  ///
  /// [groupNo] - The group number from the QR code.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<Map<String, dynamic>> getGroupInviteInfo(String groupNo) async {
    final response = await _client.get(
      '${ApiConfig.groups}/$groupNo/invite/info',
    );
    _ensureSuccess(response, fallback: 'Get group invite info failed');

    final body = _resolveBody(response.data);
    return Map<String, dynamic>.from(body['data'] ?? body);
  }

  /// Accepts a group invitation.
  ///
  /// [groupNo] - The group number to accept.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<void> acceptGroupInvite(String groupNo) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/invite/accept',
    );
    _ensureSuccess(response, fallback: 'Accept group invite failed');
  }

  /// Declines a group invitation.
  ///
  /// [groupNo] - The group number to decline.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<void> declineGroupInvite(String groupNo) async {
    final response = await _client.post(
      '${ApiConfig.groups}/$groupNo/invite/decline',
    );
    _ensureSuccess(response, fallback: 'Decline group invite failed');
  }

  /// Sets whether members need owner approval to join.
  ///
  /// [groupNo] - The group number.
  /// [needApproval] - True if approval is required.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<void> setGroupJoinApproval(String groupNo, bool needApproval) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/setting',
      data: {'need_approval': needApproval ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set group join approval failed');
  }

  /// Sets whether members can invite others to the group.
  ///
  /// [groupNo] - The group number.
  /// [canInvite] - True if members can invite others.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<void> setGroupMemberInvitePermission(
    String groupNo,
    bool canInvite,
  ) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/setting',
      data: {'member_invite': canInvite ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set group invite permission failed');
  }

  /// Sets whether members can edit group info.
  ///
  /// [groupNo] - The group number.
  /// [canEdit] - True if members can edit group info.
  // Non-authoritative: local TangSengDaoDaoServer-main source did not confirm
  // this contract, and this wrapper is not wired into production parity flows.
  @Deprecated(_nonAuthoritativeGroupApiContractWarning)
  Future<void> setGroupMemberEditPermission(
    String groupNo,
    bool canEdit,
  ) async {
    final response = await _client.put(
      '${ApiConfig.groups}/$groupNo/setting',
      data: {'member_edit': canEdit ? 1 : 0},
    );
    _ensureSuccess(response, fallback: 'Set group edit permission failed');
  }
}
