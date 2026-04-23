import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/modules/contacts/contact_filter.dart';

void main() {
  test('filterVisibleContacts removes current user and deleted friends', () {
    final friends = <Friend>[
      Friend(uid: 'u_self', name: 'Me'),
      Friend(uid: 'u_alice', name: 'Alice'),
      Friend(uid: 'u_deleted', name: 'Deleted', beDeleted: 1),
    ];

    final visible = filterVisibleContacts(friends, currentUid: 'u_self');

    expect(visible.map((friend) => friend.uid), <String>['u_alice']);
  });

  test('filterVisibleContacts trims uid values before comparing self', () {
    final friends = <Friend>[
      Friend(uid: ' u_self ', name: 'Me'),
      Friend(uid: 'u_bob', name: 'Bob'),
    ];

    final visible = filterVisibleContacts(friends, currentUid: ' u_self');

    expect(visible.map((friend) => friend.uid), <String>['u_bob']);
  });
}
