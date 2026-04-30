import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/group.dart';
import '../../service/api/group_api.dart';

/// 缇ょ粍淇℃伅Provider
final groupInfoProvider = FutureProvider.family<GroupInfo?, String>((
  ref,
  groupNo,
) async {
  return await GroupApi.instance.getGroupInfo(groupNo);
});

/// 缇ゆ垚鍛樺垪琛≒rovider
final groupMemberListProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupNo) async {
      return await GroupApi.instance.getGroupMembers(groupNo);
    });

/// 鎴戝姞鍏ョ殑缇ゅ垪琛≒rovider
final myGroupListProvider =
    StateNotifierProvider<MyGroupListNotifier, AsyncValue<List<GroupInfo>>>((
      ref,
    ) {
      return MyGroupListNotifier();
    });

typedef FetchGroups = Future<List<GroupInfo>> Function();

class MyGroupListNotifier extends StateNotifier<AsyncValue<List<GroupInfo>>> {
  MyGroupListNotifier({
    GroupApi? groupApi,
    FetchGroups? fetchGroups,
    bool loadOnInit = true,
  }) : _groupApi = groupApi ?? GroupApi.instance,
       _fetchGroups = fetchGroups,
       super(const AsyncValue.loading()) {
    if (loadOnInit) {
      loadGroups();
    }
  }

  final GroupApi _groupApi;
  final FetchGroups? _fetchGroups;

  /// 鍔犺浇缇ゅ垪琛?
  Future<void> loadGroups() async {
    if (!StorageUtils.isLoggedIn()) {
      state = const AsyncValue.data(<GroupInfo>[]);
      return;
    }
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final groups = await (_fetchGroups?.call() ?? _groupApi.getMyGroups());
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(groups);
    } catch (e, st) {
      if (!mounted) {
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  /// 鍒涘缓缇よ亰
  Future<GroupInfo?> createGroup(List<String> memberIds, {String? name}) async {
    try {
      final group = await _groupApi.createGroup(memberIds, name: name);
      await loadGroups();
      return group;
    } catch (e) {
      return null;
    }
  }

  /// 閫€鍑虹兢鑱?
  Future<bool> quitGroup(String groupNo) async {
    try {
      await _groupApi.quitGroup(groupNo);
      await loadGroups();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 瑙ｆ暎缇よ亰
  Future<bool> dismissGroup(String groupNo) async {
    try {
      await _groupApi.dismissGroup(groupNo);
      await loadGroups();
      return true;
    } catch (e) {
      return false;
    }
  }

  void upsertGroup(GroupInfo group) {
    final groupNo = group.groupNo.trim();
    if (groupNo.isEmpty) {
      return;
    }
    final currentGroups = state.valueOrNull ?? const <GroupInfo>[];
    var replaced = false;
    final updatedGroups = <GroupInfo>[];
    for (final current in currentGroups) {
      if (current.groupNo.trim() == groupNo) {
        updatedGroups.add(group);
        replaced = true;
      } else {
        updatedGroups.add(current);
      }
    }
    if (!replaced) {
      updatedGroups.add(group);
    }
    state = AsyncValue.data(List<GroupInfo>.unmodifiable(updatedGroups));
  }

  /// 鍒锋柊
  Future<void> refresh() async {
    await loadGroups();
  }
}
