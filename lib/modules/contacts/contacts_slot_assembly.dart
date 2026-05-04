import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/contacts_slots.dart';
import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import 'contacts_strings.dart';

void ensureContactsHeaderSlots(SlotRegistry registry) {
  if (!registry.containsId(contactsHeaderSlot, 'contacts.friend')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.friend',
        priority: 100,
        build: (context) {
          final strings = resolveContactsStrings();
          return ContactsMenu(
            sid: 'friend',
            imgResource: WKReferenceAssets.newFriend,
            text: strings.newFriends,
            badgeNum: context.pendingRequestCount,
          );
        },
      ),
    );
  }
  if (!registry.containsId(contactsHeaderSlot, 'contacts.group')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.group',
        priority: 90,
        build: (context) {
          final strings = resolveContactsStrings();
          return ContactsMenu(
            sid: 'group',
            imgResource: WKReferenceAssets.savedGroups,
            text: strings.savedGroups,
          );
        },
      ),
    );
  }
  if (!registry.containsId(contactsHeaderSlot, 'contacts.moments')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.moments',
        priority: 80,
        build: (_) {
          return ContactsMenu(
            sid: 'moments',
            imgResource: WKReferenceAssets.moments,
            text: '朋友圈',
          );
        },
      ),
    );
  }
  if (!registry.containsId(contactsHeaderSlot, 'contacts.tag')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.tag',
        priority: 70,
        build: (_) {
          return ContactsMenu(
            sid: 'tag',
            imgResource: WKReferenceAssets.tag,
            text: '标签',
          );
        },
      ),
    );
  }
  if (!registry.containsId(contactsHeaderSlot, 'contacts.customer_service')) {
    registry.register(
      contactsHeaderSlot,
      SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
        id: 'contacts.customer_service',
        priority: 60,
        build: (_) {
          return ContactsMenu(
            sid: 'customer_service',
            imgResource: WKReferenceAssets.customerService,
            text: '客服',
          );
        },
      ),
    );
  }
}

List<ContactsMenu> resolveContactsHeaderMenus(
  SlotRegistry registry,
  ContactsHeaderSlotContext context, {
  required void Function() openNewFriendsPage,
  required void Function() openSavedGroupsPage,
  required void Function() openMomentsPage,
  required void Function() openTagManagePage,
  required void Function() openCustomerService,
}) {
  ensureContactsHeaderSlots(registry);
  final items = registry.resolve(contactsHeaderSlot, context);
  return items
      .map((item) {
        if (item.sid == 'friend') {
          if (item.onClick != null) {
            return item;
          }
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            showRedDot: item.showRedDot,
            uid: item.uid,
            onClick: (_) => openNewFriendsPage(),
          );
        }
        if (item.sid == 'group') {
          if (item.onClick != null) {
            return item;
          }
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            showRedDot: item.showRedDot,
            uid: item.uid,
            onClick: (_) => openSavedGroupsPage(),
          );
        }
        if (item.sid == 'moments') {
          if (item.onClick != null) {
            return item;
          }
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            showRedDot: item.showRedDot,
            uid: item.uid,
            onClick: (_) => openMomentsPage(),
          );
        }
        if (item.sid == 'tag') {
          if (item.onClick != null) {
            return item;
          }
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            showRedDot: item.showRedDot,
            uid: item.uid,
            onClick: (_) => openTagManagePage(),
          );
        }
        if (item.sid == 'customer_service') {
          if (item.onClick != null) {
            return item;
          }
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            showRedDot: item.showRedDot,
            uid: item.uid,
            onClick: (_) => openCustomerService(),
          );
        }
        return item;
      })
      .toList(growable: false);
}
