import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/contacts_menu.dart';

void main() {
  test('contacts installer exposes Android header rows with request count', () {
    final registry = SlotRegistry();

    final items = resolveContactsHeaderMenus(
      registry,
      const ContactsHeaderSlotContext(pendingRequestCount: 9),
      openNewFriendsPage: () {},
      openSavedGroupsPage: () {},
      openMomentsPage: () {},
      openTagManagePage: () {},
      openCustomerService: () {},
    );

    expect(items.map((item) => item.sid), <String>[
      'friend',
      'group',
      'moments',
      'tag',
      'customer_service',
    ]);
    expect(items.first.text, '\u65b0\u670b\u53cb');
    expect(items[1].text, '\u4fdd\u5b58\u7684\u7fa4\u804a');
    expect(items[2].text, '\u670b\u53cb\u5708');
    expect(items[3].text, '\u6807\u7b7e');
    expect(items[4].text, '\u5ba2\u670d');
    expect(items.first.badgeNum, 9);
  });

  test(
    'contacts installer preserves friend override metadata and callback while keeping built-in group',
    () {
      final registry = SlotRegistry();
      var customFriendTapped = false;
      var defaultFriendOpened = false;
      var defaultGroupOpened = false;
      registry.register(
        contactsHeaderSlot,
        SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
          id: 'contacts.friend',
          priority: 999,
          build: (_) => ContactsMenu(
            sid: 'friend',
            text: 'Custom friend',
            uid: 'u_custom',
            showRedDot: true,
            badgeNum: 1,
            onClick: (_) {
              customFriendTapped = true;
            },
          ),
        ),
      );

      final items = resolveContactsHeaderMenus(
        registry,
        const ContactsHeaderSlotContext(pendingRequestCount: 7),
        openNewFriendsPage: () {
          defaultFriendOpened = true;
        },
        openSavedGroupsPage: () {
          defaultGroupOpened = true;
        },
        openMomentsPage: () {},
        openTagManagePage: () {},
        openCustomerService: () {},
      );

      expect(items.map((item) => item.sid).toSet(), <String>{
        'friend',
        'group',
        'moments',
        'tag',
        'customer_service',
      });
      expect(items.length, 5);
      final friend = items.firstWhere((item) => item.sid == 'friend');
      final group = items.firstWhere((item) => item.sid == 'group');
      expect(friend.text, 'Custom friend');
      expect(friend.uid, 'u_custom');
      expect(friend.showRedDot, isTrue);

      friend.onClick?.call(friend.sid);
      expect(customFriendTapped, isTrue);
      expect(defaultFriendOpened, isFalse);

      expect(group.text, '\u4fdd\u5b58\u7684\u7fa4\u804a');
      group.onClick?.call(group.sid);
      expect(defaultGroupOpened, isTrue);
    },
  );

  test('contacts installer is idempotent and wires callbacks', () {
    final registry = SlotRegistry();
    var tapped = false;

    resolveContactsHeaderMenus(
      registry,
      const ContactsHeaderSlotContext(pendingRequestCount: 3),
      openNewFriendsPage: () {
        tapped = true;
      },
      openSavedGroupsPage: () {},
      openMomentsPage: () {},
      openTagManagePage: () {},
      openCustomerService: () {},
    );
    final secondPass = resolveContactsHeaderMenus(
      registry,
      const ContactsHeaderSlotContext(pendingRequestCount: 3),
      openNewFriendsPage: () {
        tapped = true;
      },
      openSavedGroupsPage: () {},
      openMomentsPage: () {},
      openTagManagePage: () {},
      openCustomerService: () {},
    );

    expect(secondPass.length, 5);
    final friendMenu = secondPass.firstWhere((item) => item.sid == 'friend');
    friendMenu.onClick?.call(friendMenu.sid);
    expect(tapped, isTrue);
  });
}
