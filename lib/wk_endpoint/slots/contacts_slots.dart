import 'package:flutter/foundation.dart';

import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class ContactsHeaderSlotContext {
  const ContactsHeaderSlotContext({required this.pendingRequestCount});

  final int pendingRequestCount;
}

const contactsHeaderSlot = SlotDescriptor<
    ContactsHeaderSlotContext,
    ContactsMenu>('contacts.header');
