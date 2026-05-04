import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';
import '../core/slot_entry.dart';
import '../core/slot_registry.dart';
import '../slots/contacts_slots.dart';
import '../slots/personal_center_slots.dart';

class LegacyEndpointImporter {
  LegacyEndpointImporter({
    required EndpointManager manager,
    required SlotRegistry registry,
  }) : _manager = manager,
       _registry = registry;

  final EndpointManager _manager;
  final SlotRegistry _registry;

  void importContactsHeader() {
    final endpoints = _manager.getEndpoints('mail_list');
    if (endpoints.isEmpty) {
      return;
    }

    for (final endpoint in endpoints) {
      final entryId = 'legacy/${endpoint.sid}';
      if (_registry.containsId(contactsHeaderSlot, entryId)) {
        continue;
      }
      _registry.register(
        contactsHeaderSlot,
        SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
          id: entryId,
          priority: endpoint.sort,
          build: (context) {
            // Legacy handlers must synchronously return a non-null ContactsMenu.
            final value = endpoint.handler.invoke(context);
            return value as ContactsMenu;
          },
        ),
      );
    }
  }

  void importPersonalCenter() {
    final endpoints = _manager.getEndpoints('personal_center');
    if (endpoints.isEmpty) {
      return;
    }

    for (final endpoint in endpoints) {
      final entryId = 'legacy/${endpoint.sid}';
      if (_registry.containsId(personalCenterSlot, entryId)) {
        continue;
      }
      _registry.register(
        personalCenterSlot,
        SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
          id: entryId,
          priority: endpoint.sort,
          build: (context) {
            // Legacy handlers must synchronously return a non-null PersonalInfoMenu.
            final value = endpoint.handler.invoke(context);
            return value as PersonalInfoMenu;
          },
        ),
      );
    }
  }
}
