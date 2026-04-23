import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_strings.dart';

void main() {
  group('resolveContactsStrings', () {
    test('returns simplified Chinese defaults when locale is omitted', () {
      final strings = resolveContactsStrings();

      expect(strings.newFriends, '新朋友');
      expect(strings.savedGroups, '保存的群聊');
      expect(strings.contactsTitle, '通讯录');
      expect(strings.newFriendsTitle, '新朋友');
      expect(strings.selectContactsTitle, '选择联系人');
      expect(strings.confirmWithCount(2), '确定(2)');
      expect(strings.contactsCount(5), '5位联系人');
    });

    test(
      'falls back to simplified Chinese defaults for unsupported locale',
      () {
        final strings = resolveContactsStrings(locale: const Locale('en'));

        expect(strings.newFriends, '新朋友');
        expect(strings.savedGroups, '保存的群聊');
        expect(strings.contactsTitle, '通讯录');
        expect(strings.newFriendsTitle, '新朋友');
        expect(strings.selectContactsTitle, '选择联系人');
        expect(strings.confirmWithCount(2), '确定(2)');
        expect(strings.contactsCount(5), '5位联系人');
      },
    );
  });
}
