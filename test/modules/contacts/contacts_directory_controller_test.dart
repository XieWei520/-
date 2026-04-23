import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/modules/contacts/contacts_directory_controller.dart';

void main() {
  test('builds sorted sections and letters once per data set', () {
    final controller = ContactsDirectoryController();
    final directory = controller.buildDirectory(<Friend>[
      Friend(uid: 'u_bob', name: 'Bob'),
      Friend(uid: 'u_alice', name: 'Alice'),
    ]);

    expect(directory.letters, <String>['A', 'B']);
    expect(directory.sections.first.entries.single.friend.uid, 'u_alice');
  });
}
