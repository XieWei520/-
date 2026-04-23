import 'package:flutter/material.dart';
import '../entity/friend.dart';

/// Friend list state
class FriendListState {
  final List<Friend> friends;
  final List<FriendApply> friendRequests;
  final bool isLoading;
  final String? error;

  const FriendListState({
    this.friends = const [],
    this.friendRequests = const [],
    this.isLoading = false,
    this.error,
  });

  FriendListState copyWith({
    List<Friend>? friends,
    List<FriendApply>? friendRequests,
    bool? isLoading,
    String? error,
  }) {
    return FriendListState(
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Friend list notifier
class FriendListNotifier extends ChangeNotifier {
  FriendListState _state = const FriendListState();
  final Map<String, Friend> _friendMap = {};

  FriendListState get state => _state;
  List<Friend> get friends => _state.friends;
  List<FriendApply> get friendRequests => _state.friendRequests;
  bool get isLoading => _state.isLoading;

  /// Get friend by UID
  Friend? getFriend(String uid) => _friendMap[uid];

  /// Initialize friends
  void initFriends(List<Friend> friends) {
    _state = _state.copyWith(friends: friends);
    _updateFriendMap();
    notifyListeners();
  }

  /// Add or update friend
  void updateFriend(Friend friend) {
    final index = _state.friends.indexWhere((f) => f.uid == friend.uid);
    List<Friend> newFriends;

    if (index == -1) {
      newFriends = [..._state.friends, friend];
    } else {
      newFriends = List<Friend>.from(_state.friends);
      newFriends[index] = friend;
    }

    _state = _state.copyWith(friends: newFriends);
    _updateFriendMap();
    notifyListeners();
  }

  /// Remove friend
  void removeFriend(String uid) {
    final newFriends = _state.friends.where((f) => f.uid != uid).toList();
    _state = _state.copyWith(friends: newFriends);
    _friendMap.remove(uid);
    notifyListeners();
  }

  /// Update friend remark
  void updateFriendRemark(String uid, String remark) {
    final friend = _friendMap[uid];
    if (friend == null) return;

    updateFriend(friend.copyWith(remark: remark));
  }

  /// Update friend mute status
  void updateFriendMute(String uid, bool mute) {
    final friend = _friendMap[uid];
    if (friend == null) return;

    updateFriend(friend.copyWith(mute: mute ? 1 : 0));
  }

  /// Update friend top status
  void updateFriendTop(String uid, bool top) {
    final friend = _friendMap[uid];
    if (friend == null) return;

    updateFriend(friend.copyWith(top: top ? 1 : 0));
  }

  /// Set friend requests
  void setFriendRequests(List<FriendApply> requests) {
    _state = _state.copyWith(friendRequests: requests);
    notifyListeners();
  }

  /// Add friend request
  void addFriendRequest(FriendApply request) {
    final newRequests = [..._state.friendRequests, request];
    _state = _state.copyWith(friendRequests: newRequests);
    notifyListeners();
  }

  /// Remove friend request
  void removeFriendRequest(String toUid) {
    final newRequests = _state.friendRequests.where((r) => r.toUid != toUid).toList();
    _state = _state.copyWith(friendRequests: newRequests);
    notifyListeners();
  }

  /// Clear all
  void clear() {
    _state = const FriendListState();
    _friendMap.clear();
    notifyListeners();
  }

  /// Set loading
  void setLoading(bool loading) {
    _state = _state.copyWith(isLoading: loading);
    notifyListeners();
  }

  void _updateFriendMap() {
    _friendMap.clear();
    for (final f in _state.friends) {
      _friendMap[f.uid] = f;
    }
  }
}
