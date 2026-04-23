import 'package:flutter/material.dart';
import '../entity/group.dart';

/// Group list state
class GroupListState {
  final List<GroupInfo> groups;
  final bool isLoading;
  final String? error;

  const GroupListState({
    this.groups = const [],
    this.isLoading = false,
    this.error,
  });

  GroupListState copyWith({
    List<GroupInfo>? groups,
    bool? isLoading,
    String? error,
  }) {
    return GroupListState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Group list notifier
class GroupListNotifier extends ChangeNotifier {
  GroupListState _state = const GroupListState();
  final Map<String, GroupInfo> _groupMap = {};

  GroupListState get state => _state;
  List<GroupInfo> get groups => _state.groups;
  bool get isLoading => _state.isLoading;

  /// Get group by groupNo
  GroupInfo? getGroup(String groupNo) => _groupMap[groupNo];

  /// Initialize groups
  void initGroups(List<GroupInfo> groups) {
    _state = _state.copyWith(groups: groups);
    _updateGroupMap();
    notifyListeners();
  }

  /// Add or update group
  void updateGroup(GroupInfo group) {
    final index = _state.groups.indexWhere((g) => g.groupNo == group.groupNo);
    List<GroupInfo> newGroups;

    if (index == -1) {
      newGroups = [..._state.groups, group];
    } else {
      newGroups = List<GroupInfo>.from(_state.groups);
      newGroups[index] = group;
    }

    _state = _state.copyWith(groups: newGroups);
    _updateGroupMap();
    notifyListeners();
  }

  /// Remove group
  void removeGroup(String groupNo) {
    final newGroups = _state.groups.where((g) => g.groupNo != groupNo).toList();
    _state = _state.copyWith(groups: newGroups);
    _groupMap.remove(groupNo);
    notifyListeners();
  }

  /// Update group info
  void updateGroupInfo(String groupNo, {
    String? name,
    String? avatar,
    String? notice,
    int? forbidden,
  }) {
    final group = _groupMap[groupNo];
    if (group == null) return;

    updateGroup(GroupInfo(
      groupNo: group.groupNo,
      name: name ?? group.name,
      avatar: avatar ?? group.avatar,
      notice: notice ?? group.notice,
      forbidden: forbidden ?? group.forbidden,
      creator: group.creator,
      status: group.status,
      groupType: group.groupType,
      version: group.version,
    ));
  }

  /// Clear all
  void clear() {
    _state = const GroupListState();
    _groupMap.clear();
    notifyListeners();
  }

  /// Set loading
  void setLoading(bool loading) {
    _state = _state.copyWith(isLoading: loading);
    notifyListeners();
  }

  void _updateGroupMap() {
    _groupMap.clear();
    for (final g in _state.groups) {
      _groupMap[g.groupNo] = g;
    }
  }
}

/// Group member state
class GroupMemberState {
  final String groupNo;
  final List<GroupMember> members;
  final bool isLoading;
  final bool hasMore;

  const GroupMemberState({
    required this.groupNo,
    this.members = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  GroupMemberState copyWith({
    String? groupNo,
    List<GroupMember>? members,
    bool? isLoading,
    bool? hasMore,
  }) {
    return GroupMemberState(
      groupNo: groupNo ?? this.groupNo,
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Group member notifier
class GroupMemberNotifier extends ChangeNotifier {
  final Map<String, GroupMemberState> _groupMembers = {};

  /// Get members for a group
  GroupMemberState? getMembers(String groupNo) => _groupMembers[groupNo];

  /// Initialize members
  void initMembers(String groupNo, List<GroupMember> members) {
    _groupMembers[groupNo] = GroupMemberState(
      groupNo: groupNo,
      members: members,
    );
    notifyListeners();
  }

  /// Load more members
  void loadMore(String groupNo, List<GroupMember> members) {
    final state = _groupMembers[groupNo];
    if (state == null) return;

    _groupMembers[groupNo] = state.copyWith(
      members: [...state.members, ...members],
      hasMore: members.isNotEmpty,
    );
    notifyListeners();
  }

  /// Add member
  void addMember(String groupNo, GroupMember member) {
    final state = _groupMembers[groupNo];
    if (state == null) return;

    final exists = state.members.any((m) => m.uid == member.uid);
    if (exists) return;

    _groupMembers[groupNo] = state.copyWith(
      members: [...state.members, member],
    );
    notifyListeners();
  }

  /// Remove member
  void removeMember(String groupNo, String uid) {
    final state = _groupMembers[groupNo];
    if (state == null) return;

    _groupMembers[groupNo] = state.copyWith(
      members: state.members.where((m) => m.uid != uid).toList(),
    );
    notifyListeners();
  }

  /// Update member
  void updateMember(String groupNo, GroupMember member) {
    final state = _groupMembers[groupNo];
    if (state == null) return;

    final index = state.members.indexWhere((m) => m.uid == member.uid);
    if (index == -1) return;

    final newMembers = List<GroupMember>.from(state.members);
    newMembers[index] = member;
    _groupMembers[groupNo] = state.copyWith(members: newMembers);
    notifyListeners();
  }

  /// Get member by UID
  GroupMember? getMember(String groupNo, String uid) {
    final state = _groupMembers[groupNo];
    if (state == null) return null;
    return state.members.cast<GroupMember?>().firstWhere(
      (m) => m?.uid == uid,
      orElse: () => null,
    );
  }

  /// Clear members for a group
  void clearMembers(String groupNo) {
    _groupMembers.remove(groupNo);
    notifyListeners();
  }
}
