import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/wukong_uikit/user/user_detail_page.dart';

void main() {
  group('resolveUserDetailRelationshipState', () {
    test('prefers follow flag from user detail response', () {
      final state = resolveUserDetailRelationshipState(
        targetUid: 'u_test',
        user: UserInfo(uid: 'u_test', follow: 1),
      );

      expect(state.isFriend, isTrue);
      expect(state.isInBlacklist, isFalse);
      expect(state.isBlockedByPeer, isFalse);
    });

    test('falls back to friend list when follow flag is missing', () {
      final state = resolveUserDetailRelationshipState(
        targetUid: 'u_test',
        friends: [Friend(uid: 'u_test', beDeleted: 0)],
      );

      expect(state.isFriend, isTrue);
      expect(state.isBlockedByPeer, isFalse);
    });

    test('marks blacklist membership from blacklist list', () {
      final state = resolveUserDetailRelationshipState(
        targetUid: 'u_test',
        blacklist: [UserInfo(uid: 'u_test')],
      );

      expect(state.isInBlacklist, isTrue);
      expect(state.isBlockedByPeer, isFalse);
    });

    test('marks peer blacklist from user detail response', () {
      final state = resolveUserDetailRelationshipState(
        targetUid: 'u_test',
        user: UserInfo(uid: 'u_test', beBlacklist: 1),
      );

      expect(state.isBlockedByPeer, isTrue);
    });

    test('marks peer blacklist from friend list response', () {
      final state = resolveUserDetailRelationshipState(
        targetUid: 'u_test',
        friends: [Friend(uid: 'u_test', beDeleted: 0, beBlacklist: 1)],
      );

      expect(state.isBlockedByPeer, isTrue);
    });
  });
}
