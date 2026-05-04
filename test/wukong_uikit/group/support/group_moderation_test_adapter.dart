import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/group_forbidden_time_option.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

class GroupModerationTestAdapter implements HttpClientAdapter {
  GroupModerationTestAdapter({
    required this.groupNo,
    required this.currentUid,
    required List<GroupMember> members,
    GroupInfo? group,
    List<GroupForbiddenTimeOption>? forbiddenTimes,
  }) : _members = members.map(_copyMember).toList(),
       _group = _copyGroup(
         group ??
             GroupInfo(
               groupNo: groupNo,
               creator: _resolveOwnerUid(members, currentUid),
               memberCount: members.length,
               role: _resolveCurrentRole(members, currentUid),
               invite: 0,
               mute: 0,
               top: 0,
               save: 1,
               showNick: 1,
               allowViewHistoryMsg: 1,
               joinGroupRemind: 0,
             ),
       ),
       _forbiddenTimes =
           (forbiddenTimes ??
                   const <GroupForbiddenTimeOption>[
                     GroupForbiddenTimeOption(text: '1 minute', key: 1),
                     GroupForbiddenTimeOption(text: '1 hour', key: 3),
                   ])
               .map(_copyForbiddenTime)
               .toList();

  final String groupNo;
  final String currentUid;

  final GroupInfo _group;
  final List<GroupMember> _members;
  final List<GroupForbiddenTimeOption> _forbiddenTimes;
  final List<RequestOptions> requests = <RequestOptions>[];

  String get groupPath => '${ApiConfig.groups}/$groupNo';
  String get membersPath => '$groupPath${ApiConfig.groupMembers}';
  String get blacklistAddPath => '$groupPath/blacklist/add';
  String get blacklistRemovePath => '$groupPath/blacklist/remove';
  String get forbiddenTimesPath => '${ApiConfig.v1}/group/forbidden_times';
  String get forbiddenWithMemberPath => '$groupPath/forbidden_with_member';

  int requestCount(String method, String path) {
    final expectedMethod = method.toUpperCase();
    return requests.where((request) {
      return request.method.toUpperCase() == expectedMethod &&
          request.uri.path == path;
    }).length;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'GET' && path == groupPath) {
      return _jsonResponse(<String, dynamic>{
        'code': 0,
        'data': _group.toJson(),
      });
    }
    if (method == 'GET' && path == membersPath) {
      return _jsonResponse(<String, dynamic>{
        'code': 0,
        'data': _members.map((member) => _memberToJson(member)).toList(),
      });
    }
    if (method == 'GET' && path == forbiddenTimesPath) {
      return _jsonResponse(<String, dynamic>{
        'code': 0,
        'data': _forbiddenTimes
            .map(
              (option) => <String, dynamic>{
                'text': option.text,
                'key': option.key,
              },
            )
            .toList(),
      });
    }
    if (method == 'POST' && path == blacklistAddPath) {
      _setBlacklistStatus(options.data, GroupMemberStatus.blacklist);
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == blacklistRemovePath) {
      _setBlacklistStatus(options.data, GroupMemberStatus.normal);
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }
    if (method == 'POST' && path == forbiddenWithMemberPath) {
      _updateForbiddenState(options.data);
      return _jsonResponse(const <String, dynamic>{'code': 0});
    }

    return _jsonResponse(<String, dynamic>{
      'code': 404,
      'msg': 'Unhandled request: $method $path',
    }, statusCode: 404);
  }

  void _setBlacklistStatus(dynamic rawData, int status) {
    final payload = _asMap(rawData);
    final dynamic rawIds =
        payload['uids'] ?? payload['member_ids'] ?? payload['members'];
    if (rawIds is! List) {
      return;
    }

    final targets = rawIds
        .map((value) => value.toString().trim())
        .where((uid) => uid.isNotEmpty)
        .toSet();
    if (targets.isEmpty) {
      return;
    }

    for (var i = 0; i < _members.length; i++) {
      final member = _members[i];
      if (!targets.contains(member.uid)) {
        continue;
      }
      _members[i] = GroupMember(
        groupNo: member.groupNo,
        uid: member.uid,
        name: member.name,
        avatar: member.avatar,
        role: member.role,
        remark: member.remark,
        status: status,
        version: member.version,
        inviteUid: member.inviteUid,
        forbiddenExpirTime: member.forbiddenExpirTime,
        joinTime: member.joinTime,
      );
    }
  }

  void _updateForbiddenState(dynamic rawData) {
    final payload = _asMap(rawData);
    final memberUid = payload['member_uid']?.toString().trim() ?? '';
    final action = payload['action'] as int? ?? 0;
    if (memberUid.isEmpty) {
      return;
    }

    for (var i = 0; i < _members.length; i++) {
      final member = _members[i];
      if (member.uid != memberUid) {
        continue;
      }
      _members[i] = GroupMember(
        groupNo: member.groupNo,
        uid: member.uid,
        name: member.name,
        avatar: member.avatar,
        role: member.role,
        remark: member.remark,
        status: member.status,
        version: member.version,
        inviteUid: member.inviteUid,
        forbiddenExpirTime: action == 1 ? 2000000000 : 0,
        joinTime: member.joinTime,
      );
      return;
    }
  }

  static String _resolveOwnerUid(
    List<GroupMember> members,
    String fallbackUid,
  ) {
    for (final member in members) {
      if (member.isOwner) {
        return member.uid;
      }
    }
    if (members.isNotEmpty) {
      return members.first.uid;
    }
    return fallbackUid;
  }

  static int _resolveCurrentRole(List<GroupMember> members, String currentUid) {
    for (final member in members) {
      if (member.uid == currentUid) {
        return member.role ?? 0;
      }
    }
    return 0;
  }

  static Map<String, dynamic> _memberToJson(GroupMember member) {
    return <String, dynamic>{
      'group_no': member.groupNo,
      'uid': member.uid,
      'name': member.name,
      'avatar': member.avatar,
      'role': member.role,
      'remark': member.remark,
      'status': member.status,
      'version': member.version,
      'invite_uid': member.inviteUid,
      'forbidden_expir_time': member.forbiddenExpirTime,
      'join_time': member.joinTime,
    };
  }

  static GroupMember _copyMember(GroupMember member) {
    return GroupMember(
      groupNo: member.groupNo,
      uid: member.uid,
      name: member.name,
      avatar: member.avatar,
      role: member.role,
      remark: member.remark,
      status: member.status,
      version: member.version,
      inviteUid: member.inviteUid,
      forbiddenExpirTime: member.forbiddenExpirTime,
      joinTime: member.joinTime,
    );
  }

  static GroupInfo _copyGroup(GroupInfo group) {
    return GroupInfo(
      groupNo: group.groupNo,
      name: group.name,
      avatar: group.avatar,
      creator: group.creator,
      notice: group.notice,
      memberCount: group.memberCount,
      status: group.status,
      version: group.version,
      forbidden: group.forbidden,
      invite: group.invite,
      groupType: group.groupType,
      allowViewHistoryMsg: group.allowViewHistoryMsg,
      joinGroupRemind: group.joinGroupRemind,
      revokeRemind: group.revokeRemind,
      receipt: group.receipt,
      forbiddenAddFriend: group.forbiddenAddFriend,
      screenshot: group.screenshot,
      chatPwdOn: group.chatPwdOn,
      mute: group.mute,
      top: group.top,
      showNick: group.showNick,
      save: group.save,
      flame: group.flame,
      flameSecond: group.flameSecond,
      remark: group.remark,
      role: group.role,
      forbiddenExpirTime: group.forbiddenExpirTime,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    );
  }

  static GroupForbiddenTimeOption _copyForbiddenTime(
    GroupForbiddenTimeOption option,
  ) {
    return GroupForbiddenTimeOption(text: option.text, key: option.key);
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  ResponseBody _jsonResponse(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> bootstrapGroupModerationTestEnvironment({
  required GroupModerationTestAdapter adapter,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await StorageUtils.init();
  await StorageUtils.clear();
  await StorageUtils.setUid(adapter.currentUid);
  ApiClient.instance.dio.httpClientAdapter = adapter;
}
