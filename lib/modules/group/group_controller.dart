import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../data/models/group.dart';
import '../../service/api/group_api.dart';

/// Group system message content types (1002-1009).
class GroupSystemMsgType {
  static const int memberJoin = 1002;
  static const int memberQuit = 1003;
  static const int nameUpdated = 1004;
  static const int systemInfo = 1005;
  static const int memberRemoved = 1006;
  static const int noticeUpdated = 1007;
  static const int avatarUpdated = 1008;
  static const int memberApprove = 1009;
}

/// Group detail state: info + members.
class GroupDetailState {
  final GroupInfo? group;
  final List<GroupMember> members;
  final bool isLoadingInfo;
  final bool isLoadingMembers;
  final String? error;

  const GroupDetailState({
    this.group,
    this.members = const [],
    this.isLoadingInfo = false,
    this.isLoadingMembers = false,
    this.error,
  });

  GroupDetailState copyWith({
    GroupInfo? group,
    List<GroupMember>? members,
    bool? isLoadingInfo,
    bool? isLoadingMembers,
    String? error,
  }) {
    return GroupDetailState(
      group: group ?? this.group,
      members: members ?? this.members,
      isLoadingInfo: isLoadingInfo ?? this.isLoadingInfo,
      isLoadingMembers: isLoadingMembers ?? this.isLoadingMembers,
      error: error,
    );
  }
}

/// Group detail notifier — manages group info and member list.
class GroupDetailNotifier extends StateNotifier<GroupDetailState> {
  final GroupApi _groupApi = GroupApi.instance;
  final String groupNo;

  GroupDetailNotifier(this.groupNo) : super(const GroupDetailState()) {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([loadGroupInfo(), loadMembers()]);
  }

  Future<void> loadGroupInfo() async {
    state = state.copyWith(isLoadingInfo: true, error: null);
    try {
      final group = await _groupApi.getGroupInfo(groupNo);
      state = state.copyWith(group: group, isLoadingInfo: false);
    } catch (e) {
      state = state.copyWith(isLoadingInfo: false, error: e.toString());
    }
  }

  Future<void> loadMembers() async {
    state = state.copyWith(isLoadingMembers: true);
    try {
      final members = await _groupApi.getGroupMembers(groupNo);
      state = state.copyWith(members: members, isLoadingMembers: false);
    } catch (e) {
      state = state.copyWith(isLoadingMembers: false, error: e.toString());
    }
  }

  Future<bool> updateGroupName(String name) async {
    try {
      await _groupApi.updateGroupInfo(groupNo, name: name);
      await loadGroupInfo();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateGroupNotice(String notice) async {
    try {
      await _groupApi.updateGroupNotice(groupNo, notice);
      await loadGroupInfo();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addMembers(List<String> uids) async {
    try {
      await _groupApi.addGroupMembers(groupNo, uids);
      await loadMembers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeMembers(List<String> uids) async {
    try {
      await _groupApi.removeGroupMembers(groupNo, uids);
      await loadMembers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setManagers(List<String> uids) async {
    try {
      await _groupApi.setGroupManagers(groupNo, uids);
      await loadMembers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeManagers(List<String> uids) async {
    try {
      await _groupApi.removeGroupManagers(groupNo, uids);
      await loadMembers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> transferOwner(String newOwnerUid) async {
    try {
      await _groupApi.transferGroupOwner(groupNo, newOwnerUid);
      await Future.wait([loadGroupInfo(), loadMembers()]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setMute(bool mute) async {
    try {
      await _groupApi.setGroupMute(groupNo, mute);
      await loadGroupInfo();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSetting(String key, Object? value) async {
    try {
      await _groupApi.updateGroupSetting(groupNo, key, value);
      await loadGroupInfo();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Group settings state.
class GroupSettingsState {
  final bool inviteOnly;
  final bool joinGroupRemind;
  final bool allowViewHistory;
  final bool forbidden;
  final bool isLoading;

  const GroupSettingsState({
    this.inviteOnly = false,
    this.joinGroupRemind = false,
    this.allowViewHistory = false,
    this.forbidden = false,
    this.isLoading = false,
  });

  GroupSettingsState copyWith({
    bool? inviteOnly,
    bool? joinGroupRemind,
    bool? allowViewHistory,
    bool? forbidden,
    bool? isLoading,
  }) {
    return GroupSettingsState(
      inviteOnly: inviteOnly ?? this.inviteOnly,
      joinGroupRemind: joinGroupRemind ?? this.joinGroupRemind,
      allowViewHistory: allowViewHistory ?? this.allowViewHistory,
      forbidden: forbidden ?? this.forbidden,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  factory GroupSettingsState.fromGroupInfo(GroupInfo? group) {
    if (group == null) return const GroupSettingsState();
    return GroupSettingsState(
      inviteOnly: (group.invite ?? 0) == 1,
      joinGroupRemind: (group.joinGroupRemind ?? 0) == 1,
      allowViewHistory: (group.allowViewHistoryMsg ?? 0) == 1,
      forbidden: (group.forbidden ?? 0) == 1,
    );
  }
}

/// Provider family for group detail (keyed by groupNo).
final groupDetailProvider =
    StateNotifierProvider.family<GroupDetailNotifier, GroupDetailState, String>(
  (ref, groupNo) => GroupDetailNotifier(groupNo),
);

// ---------------------------------------------------------------------------
// Group member approval (type 1009)
// ---------------------------------------------------------------------------

/// A pending group member approval request.
class GroupApprovalRequest {
  final String uid;
  final String? name;
  final String? avatar;
  final String? reason;
  final int timestamp;

  const GroupApprovalRequest({
    required this.uid,
    this.name,
    this.avatar,
    this.reason,
    this.timestamp = 0,
  });

  factory GroupApprovalRequest.fromJson(Map<String, dynamic> json) {
    return GroupApprovalRequest(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString(),
      avatar: json['avatar']?.toString(),
      reason: json['reason']?.toString(),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }
}

/// State for the group approval list.
class GroupApprovalState {
  final List<GroupApprovalRequest> pending;
  final bool isLoading;
  final String? error;

  const GroupApprovalState({
    this.pending = const [],
    this.isLoading = false,
    this.error,
  });

  GroupApprovalState copyWith({
    List<GroupApprovalRequest>? pending,
    bool? isLoading,
    String? error,
  }) {
    return GroupApprovalState(
      pending: pending ?? this.pending,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for group member approval workflow.
class GroupApprovalNotifier extends StateNotifier<GroupApprovalState> {
  final GroupApi _groupApi = GroupApi.instance;
  final String groupNo;

  GroupApprovalNotifier(this.groupNo) : super(const GroupApprovalState());

  /// Parse a type-1009 system message and add to pending list.
  void onApprovalMessage(WKMsg msg) {
    if (msg.contentType != GroupSystemMsgType.memberApprove) return;
    try {
      final raw = msg.content;
      if (raw.isEmpty) return;
      final data = Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
      final extra = data['extra'];
      if (extra is List) {
        for (final item in extra) {
          if (item is Map) {
            final request = GroupApprovalRequest.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (request.uid.isNotEmpty) {
              _addPending(request);
            }
          }
        }
      }
    } catch (_) {
      // Malformed approval message — ignore
    }
  }

  void _addPending(GroupApprovalRequest request) {
    final existing = state.pending.any((r) => r.uid == request.uid);
    if (!existing) {
      state = state.copyWith(
        pending: [...state.pending, request],
      );
    }
  }

  /// Approve a pending member join request.
  Future<bool> approve(String uid) async {
    try {
      await _groupApi.addGroupMembers(groupNo, [uid]);
      state = state.copyWith(
        pending: state.pending.where((r) => r.uid != uid).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Reject a pending member join request.
  void reject(String uid) {
    state = state.copyWith(
      pending: state.pending.where((r) => r.uid != uid).toList(),
    );
  }

  /// Set whether the group requires approval for new members.
  Future<bool> setJoinApproval(bool needApproval) async {
    state = state.copyWith(isLoading: true);
    try {
      // ignore: deprecated_member_use
      await _groupApi.setGroupJoinApproval(groupNo, needApproval);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Provider family for group approval (keyed by groupNo).
final groupApprovalProvider = StateNotifierProvider.family<
    GroupApprovalNotifier, GroupApprovalState, String>(
  (ref, groupNo) => GroupApprovalNotifier(groupNo),
);
