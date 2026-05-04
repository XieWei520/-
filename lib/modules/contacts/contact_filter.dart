import '../../data/models/friend.dart';

List<Friend> filterVisibleContacts(
  List<Friend> friends, {
  required String currentUid,
}) {
  final normalizedCurrentUid = currentUid.trim();
  return friends
      .where((friend) {
        if ((friend.beDeleted ?? 0) != 0) {
          return false;
        }
        if (normalizedCurrentUid.isEmpty) {
          return true;
        }
        return friend.uid.trim() != normalizedCurrentUid;
      })
      .toList(growable: false);
}
