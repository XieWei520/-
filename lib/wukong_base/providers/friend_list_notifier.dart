import 'package:flutter/foundation.dart';
import '../entity/friend.dart';

/// Friend list state notifier
class FriendListNotifier extends ChangeNotifier {
  List<Friend> _friends = [];

  List<Friend> get friends => _friends;

  void setFriends(List<Friend> friends) {
    _friends = friends;
    notifyListeners();
  }

  void addFriend(Friend friend) {
    _friends.add(friend);
    notifyListeners();
  }

  void updateFriend(Friend friend) {
    final index = _friends.indexWhere((f) => f.uid == friend.uid);
    if (index >= 0) {
      _friends[index] = friend;
      notifyListeners();
    }
  }
}
