import 'friend.dart';
import 'user.dart';

class UserRelationshipState {
  final bool isFriend;
  final bool isInBlacklist;
  final bool isBlockedByPeer;

  const UserRelationshipState({
    required this.isFriend,
    required this.isInBlacklist,
    required this.isBlockedByPeer,
  });
}

UserRelationshipState resolveUserRelationshipState({
  required String targetUid,
  User? user,
  Iterable<Friend> friends = const <Friend>[],
  Iterable<UserInfo> blacklist = const <UserInfo>[],
}) {
  final normalizedTargetUid = targetUid.trim();
  if (normalizedTargetUid.isEmpty) {
    return const UserRelationshipState(
      isFriend: false,
      isInBlacklist: false,
      isBlockedByPeer: false,
    );
  }

  final followedByUser = (user?.follow ?? 0) == 1;
  final foundInFriends = friends.any(
    (item) =>
        item.uid.trim() == normalizedTargetUid && (item.beDeleted ?? 0) == 0,
  );
  final blockedByPeerInFriends = friends.any(
    (item) =>
        item.uid.trim() == normalizedTargetUid && (item.beBlacklist ?? 0) == 1,
  );
  final foundInBlacklist = blacklist.any(
    (item) => item.uid.trim() == normalizedTargetUid,
  );
  final blockedByPeer = (user?.beBlacklist ?? 0) == 1 || blockedByPeerInFriends;

  return UserRelationshipState(
    isFriend: followedByUser || foundInFriends,
    isInBlacklist: foundInBlacklist,
    isBlockedByPeer: blockedByPeer,
  );
}
