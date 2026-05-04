import 'package:flutter/foundation.dart';
import '../entity/group_info.dart';

/// Group list state notifier
class GroupListNotifier extends ChangeNotifier {
  List<WKGroupInfo> _groups = [];

  List<WKGroupInfo> get groups => _groups;

  void setGroups(List<WKGroupInfo> groups) {
    _groups = groups;
    notifyListeners();
  }

  void addGroup(WKGroupInfo group) {
    _groups.add(group);
    notifyListeners();
  }

  void updateGroup(WKGroupInfo group) {
    final index = _groups.indexWhere((g) => g.groupId == group.groupId);
    if (index >= 0) {
      _groups[index] = group;
      notifyListeners();
    }
  }
}
