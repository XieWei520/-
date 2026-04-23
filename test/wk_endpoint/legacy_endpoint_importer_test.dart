import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/legacy/legacy_endpoint_importer.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/contacts_menu.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/personal_info_menu.dart';

void main() {
  final manager = EndpointManager.getInstance();

  setUp(() {
    manager.clear();
  });

  test('legacy importer moves contacts mail_list entries into typed slots', () {
    manager.register(
      'mail_list_groups',
      'mail_list',
      90,
      SimpleFunctionHandler(([dynamic _]) {
        return ContactsMenu(sid: 'group', text: 'Saved groups');
      }),
    );
    manager.register(
      'mail_list_friend',
      'mail_list',
      100,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as ContactsHeaderSlotContext;
        return ContactsMenu(
          sid: 'friend',
          text: 'New friends',
          badgeNum: context.pendingRequestCount,
        );
      }),
    );

    final registry = SlotRegistry();
    LegacyEndpointImporter(manager: manager, registry: registry)
        .importContactsHeader();

    final items = registry.resolve(
      contactsHeaderSlot,
      const ContactsHeaderSlotContext(pendingRequestCount: 5),
    );

    expect(items.map((item) => item.sid), <String>['friend', 'group']);
    expect(items.first.badgeNum, 5);
  });

  test('legacy importer does not duplicate contacts entries', () {
    manager.register(
      'mail_list_groups',
      'mail_list',
      90,
      SimpleFunctionHandler(([dynamic _]) {
        return ContactsMenu(sid: 'group', text: 'Saved groups');
      }),
    );
    manager.register(
      'mail_list_friend',
      'mail_list',
      100,
      SimpleFunctionHandler(([dynamic _]) {
        return ContactsMenu(sid: 'friend', text: 'New friends');
      }),
    );

    final registry = SlotRegistry();
    final importer = LegacyEndpointImporter(manager: manager, registry: registry);
    importer.importContactsHeader();
    importer.importContactsHeader();

    final items = registry.resolve(
      contactsHeaderSlot,
      const ContactsHeaderSlotContext(pendingRequestCount: 0),
    );

    expect(items.map((item) => item.sid), <String>['friend', 'group']);
  });

  test('legacy importer adds new contacts entries on subsequent import', () {
    manager.register(
      'mail_list_groups',
      'mail_list',
      90,
      SimpleFunctionHandler(([dynamic _]) {
        return ContactsMenu(sid: 'group', text: 'Saved groups');
      }),
    );

    final registry = SlotRegistry();
    final importer = LegacyEndpointImporter(manager: manager, registry: registry);
    importer.importContactsHeader();

    manager.register(
      'mail_list_friend',
      'mail_list',
      100,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as ContactsHeaderSlotContext;
        return ContactsMenu(
          sid: 'friend',
          text: 'New friends',
          badgeNum: context.pendingRequestCount,
        );
      }),
    );

    importer.importContactsHeader();

    final items = registry.resolve(
      contactsHeaderSlot,
      const ContactsHeaderSlotContext(pendingRequestCount: 3),
    );

    expect(items.map((item) => item.sid), <String>['friend', 'group']);
    expect(items.first.badgeNum, 3);
  });

  test('legacy importer moves personal_center entries into typed slots', () {
    manager.register(
      'personal_center_currency',
      'personal_center',
      2,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as PersonalCenterSlotContext;
        return PersonalInfoMenu(
          sid: 'personal_center_currency',
          text: 'General',
          isNewVersion: context.hasNewVersion,
        );
      }),
    );

    final registry = SlotRegistry();
    LegacyEndpointImporter(manager: manager, registry: registry)
        .importPersonalCenter();

    final items = registry.resolve(
      personalCenterSlot,
      const PersonalCenterSlotContext(hasNewVersion: true),
    );

    expect(items.single.sid, 'personal_center_currency');
    expect(items.single.isNewVersion, isTrue);
  });

  test('legacy importer adds new personal_center entries on subsequent import',
      () {
    manager.register(
      'personal_center_currency',
      'personal_center',
      2,
      SimpleFunctionHandler(([dynamic _]) {
        return PersonalInfoMenu(
          sid: 'personal_center_currency',
          text: 'General',
        );
      }),
    );

    final registry = SlotRegistry();
    final importer = LegacyEndpointImporter(manager: manager, registry: registry);
    importer.importPersonalCenter();

    manager.register(
      'personal_center_support',
      'personal_center',
      10,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as PersonalCenterSlotContext;
        return PersonalInfoMenu(
          sid: 'personal_center_support',
          text: 'Support',
          isNewVersion: context.hasNewVersion,
        );
      }),
    );

    importer.importPersonalCenter();

    final items = registry.resolve(
      personalCenterSlot,
      const PersonalCenterSlotContext(hasNewVersion: true),
    );

    expect(
      items.map((item) => item.sid),
      <String>['personal_center_support', 'personal_center_currency'],
    );
    expect(items.first.isNewVersion, isTrue);
  });
}
