import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/friend.dart';
import '../../data/models/user.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/user_api.dart';
import '../../wukong_base/db/contacts_db.dart';
import '../../wukong_base/db/friend_apply_db.dart';

/// User info provider
final userInfoProvider = FutureProvider.family<UserInfo?, String>((
  ref,
  uid,
) async {
  return UserApi.instance.getUserInfo(uid);
});

/// Friend list provider
final friendListProvider =
    StateNotifierProvider<FriendListNotifier, AsyncValue<List<Friend>>>((ref) {
      return FriendListNotifier();
    });

typedef QueryCachedFriends = Future<List<Friend>> Function();
typedef SyncFriends = Future<List<Friend>> Function();
typedef PersistFriends = Future<void> Function(List<Friend>);

class FriendListNotifier extends StateNotifier<AsyncValue<List<Friend>>> {
  FriendListNotifier({
    FriendApi? friendApi,
    ContactsDB? contactsDB,
    QueryCachedFriends? queryCachedFriends,
    SyncFriends? syncFriends,
    PersistFriends? persistFriends,
    bool loadOnInit = true,
  }) : _friendApi = friendApi ?? FriendApi.instance,
       _contactsDB = contactsDB ?? ContactsDB.instance,
       _queryCachedFriends = queryCachedFriends,
       _syncFriends = syncFriends,
       _persistFriends = persistFriends,
       super(const AsyncValue.loading()) {
    if (loadOnInit) {
      loadFriends();
    }
  }

  final FriendApi _friendApi;
  final ContactsDB _contactsDB;
  final QueryCachedFriends? _queryCachedFriends;
  final SyncFriends? _syncFriends;
  final PersistFriends? _persistFriends;

  /// Load cached contacts first, then sync from network.
  Future<void> _loadFromCacheThenSync() async {
    if (!StorageUtils.isLoggedIn()) {
      state = const AsyncValue.data(<Friend>[]);
      return;
    }
    try {
      final cached =
          await (_queryCachedFriends?.call() ?? _contactsDB.queryAll());
      if (!mounted) {
        return;
      }
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    } catch (_) {
      // Cache read failure is non-fatal
    }
    await _syncFromNetwork();
  }

  /// Fetch from network, write to DB, and update state.
  Future<void> _syncFromNetwork() async {
    if (!StorageUtils.isLoggedIn()) return;
    try {
      final friends = await (_syncFriends?.call() ?? _friendApi.getFriends());
      if (!mounted) {
        return;
      }
      await (_persistFriends?.call(friends) ??
          _contactsDB.insertOrUpdateAll(friends));
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(friends);
    } catch (e, st) {
      if (!mounted) {
        return;
      }
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Load friend list (full refresh).
  Future<void> loadFriends() async {
    if (!StorageUtils.isLoggedIn()) {
      state = const AsyncValue.data(<Friend>[]);
      return;
    }
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    await _loadFromCacheThenSync();
  }

  /// Add friend
  Future<bool> addFriend(String uid, {String? remark}) async {
    try {
      await _friendApi.addFriend(uid, remark: remark);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete friend
  Future<bool> deleteFriend(String uid) async {
    try {
      await _friendApi.deleteFriend(uid);
      await _contactsDB.markDeleted(uid);
      await loadFriends();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await _syncFromNetwork();
  }
}

/// Friend request list provider
final friendRequestListProvider =
    StateNotifierProvider<
      FriendRequestListNotifier,
      AsyncValue<List<FriendRequest>>
    >((ref) {
      return FriendRequestListNotifier();
    });

typedef QueryCachedRequests = Future<List<FriendRequest>> Function();
typedef SyncRequests = Future<List<FriendRequest>> Function();
typedef PersistRequests = Future<void> Function(List<FriendRequest>);

int countPendingFriendRequests(Iterable<FriendRequest> requests) {
  return requests.where((request) => request.isPending).length;
}

class FriendRequestHandleResult {
  final bool success;
  final String message;
  final bool shouldRefreshFriends;

  const FriendRequestHandleResult({
    required this.success,
    required this.message,
    this.shouldRefreshFriends = false,
  });
}

class FriendRequestListNotifier
    extends StateNotifier<AsyncValue<List<FriendRequest>>> {
  FriendRequestListNotifier({
    FriendApi? friendApi,
    FriendApplyDB? applyDB,
    QueryCachedRequests? queryCachedRequests,
    SyncRequests? syncRequests,
    PersistRequests? persistRequests,
    bool loadOnInit = true,
  }) : _friendApi = friendApi ?? FriendApi.instance,
       _applyDB = applyDB ?? FriendApplyDB.instance,
       _queryCachedRequests = queryCachedRequests,
       _syncRequests = syncRequests,
       _persistRequests = persistRequests,
       super(const AsyncValue.loading()) {
    if (loadOnInit) {
      loadRequests();
    }
  }

  final FriendApi _friendApi;
  final FriendApplyDB _applyDB;
  final QueryCachedRequests? _queryCachedRequests;
  final SyncRequests? _syncRequests;
  final PersistRequests? _persistRequests;

  /// Load cached requests first, then sync from network.
  Future<void> _loadFromCacheThenSync() async {
    if (!StorageUtils.isLoggedIn()) {
      state = const AsyncValue.data(<FriendRequest>[]);
      return;
    }
    try {
      final cached =
          await (_queryCachedRequests?.call() ?? _applyDB.queryAll());
      if (!mounted) {
        return;
      }
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      }
    } catch (_) {
      // Cache read failure is non-fatal
    }
    await _syncFromNetwork();
  }

  /// Fetch from network, write to DB, and update state.
  Future<void> _syncFromNetwork() async {
    if (!StorageUtils.isLoggedIn()) return;
    try {
      final requests =
          await (_syncRequests?.call() ?? _friendApi.getFriendRequests());
      if (!mounted) {
        return;
      }
      await (_persistRequests?.call(requests) ??
          _applyDB.insertOrUpdateAll(requests));
      if (!mounted) {
        return;
      }
      state = AsyncValue.data(requests);
    } catch (e, st) {
      if (!mounted) {
        return;
      }
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Load friend requests (full refresh).
  Future<void> loadRequests() async {
    if (!StorageUtils.isLoggedIn()) {
      state = const AsyncValue.data(<FriendRequest>[]);
      return;
    }
    if (!mounted) {
      return;
    }
    state = const AsyncValue.loading();
    await _loadFromCacheThenSync();
  }

  /// Handle friend request
  Future<FriendRequestHandleResult> handleRequest(
    FriendRequest request,
    bool accept,
  ) async {
    if (!request.isPending) {
      return const FriendRequestHandleResult(
        success: false,
        message: '该好友申请已失效或已处理',
      );
    }

    try {
      if (accept) {
        final token = request.token?.trim() ?? '';
        if (token.isEmpty) {
          throw Exception('好友申请 token 不能为空');
        }
        await _friendApi.acceptFriendRequest(token);
        await _applyDB.updateStatus(request.fromUid, 1);
      } else {
        final fromUid = request.fromUid.trim();
        if (fromUid.isEmpty) {
          throw Exception('发送者身份信息不完整');
        }
        await _friendApi.refuseFriendRequest(fromUid);
        await _applyDB.updateStatus(request.fromUid, 2);
      }

      await loadRequests();
      return FriendRequestHandleResult(
        success: true,
        message: accept ? '已通过好友申请' : '已拒绝好友申请',
        shouldRefreshFriends: accept,
      );
    } catch (e) {
      final rawMessage = e.toString();
      final message = rawMessage.startsWith('Exception: ')
          ? rawMessage.substring('Exception: '.length)
          : rawMessage;
      final isInvalidToken =
          accept &&
          (message.contains('token') ||
              message.contains('ʧЧ') ||
              message.contains('过期') ||
              message.contains('获取token信息错误'));

      if (isInvalidToken) {
        await loadRequests();
        return const FriendRequestHandleResult(
          success: false,
          message: '该好友申请已失效或已处理',
          shouldRefreshFriends: true,
        );
      }

      return FriendRequestHandleResult(
        success: false,
        message: accept ? '通过好友申请失败：$message' : '拒绝好友申请失败：$message',
      );
    }
  }

  /// Refresh data
  Future<void> refresh() async {
    await _syncFromNetwork();
  }
}
