import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/providers/channel_provider.dart';
import 'package:wukong_im_app/data/providers/user_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.uid': 'u_owner',
      'flutter.token': 'token_owner',
    });
    await StorageUtils.init();
  });

  test('friend list notifier ignores late results after dispose', () async {
    final syncCompleter = Completer<List<Friend>>();
    final notifier = FriendListNotifier(
      loadOnInit: false,
      queryCachedFriends: () async => const <Friend>[],
      syncFriends: () => syncCompleter.future,
      persistFriends: (_) async {},
    );

    final future = notifier.loadFriends();
    await Future<void>.delayed(Duration.zero);

    notifier.dispose();
    syncCompleter.complete(<Friend>[Friend(uid: 'u_friend', name: 'Friend')]);

    await expectLater(future, completes);
  });

  test('friend request notifier ignores late results after dispose', () async {
    final syncCompleter = Completer<List<FriendRequest>>();
    final notifier = FriendRequestListNotifier(
      loadOnInit: false,
      queryCachedRequests: () async => const <FriendRequest>[],
      syncRequests: () => syncCompleter.future,
      persistRequests: (_) async {},
    );

    final future = notifier.loadRequests();
    await Future<void>.delayed(Duration.zero);

    notifier.dispose();
    syncCompleter.complete(<FriendRequest>[
      FriendRequest(id: 1, fromUid: 'u_friend', toUid: 'u_owner', status: 0),
    ]);

    await expectLater(future, completes);
  });

  test('group list notifier ignores late results after dispose', () async {
    final syncCompleter = Completer<List<GroupInfo>>();
    final notifier = MyGroupListNotifier(
      loadOnInit: false,
      fetchGroups: () => syncCompleter.future,
    );

    final future = notifier.loadGroups();
    await Future<void>.delayed(Duration.zero);

    notifier.dispose();
    syncCompleter.complete(<GroupInfo>[GroupInfo(groupNo: 'g1', name: 'G1')]);

    await expectLater(future, completes);
  });
}
