import 'package:flutter/foundation.dart';

import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/personal_center_slots.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';

void ensurePersonalCenterSlots(SlotRegistry registry) {
  if (!registry.containsId(personalCenterSlot, 'personal_center_currency')) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_currency',
        priority: 700,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_currency',
          imgResource: WKReferenceAssets.setting,
          text: context.strings.generalMenu,
          isNewVersion: context.hasNewVersion,
        ),
      ),
    );
  }
  if (!registry.containsId(
    personalCenterSlot,
    'personal_center_new_msg_notice',
  )) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_new_msg_notice',
        priority: 600,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_new_msg_notice',
          imgResource: WKReferenceAssets.notice,
          text: context.strings.notificationsMenu,
        ),
      ),
    );
  }
  if (!registry.containsId(personalCenterSlot, 'personal_center_favorites')) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_favorites',
        priority: 500,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_favorites',
          imgResource: WKReferenceAssets.favorites,
          text: context.strings.favoritesMenu,
        ),
      ),
    );
  }
  if (!registry.containsId(personalCenterSlot, 'personal_center_privacy')) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_privacy',
        priority: 300,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_privacy',
          imgResource: WKReferenceAssets.privacy,
          text: context.strings.privacyMenu,
        ),
      ),
    );
  }
  if (!registry.containsId(
    personalCenterSlot,
    'personal_center_account_security',
  )) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_account_security',
        priority: 200,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_account_security',
          imgResource: WKReferenceAssets.accountSecurity,
          text: context.strings.accountSecurityMenu,
        ),
      ),
    );
  }
  if (!registry.containsId(personalCenterSlot, 'personal_center_web_login')) {
    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_web_login',
        priority: 100,
        build: (context) => PersonalInfoMenu(
          sid: 'personal_center_web_login',
          imgResource: WKReferenceAssets.webLogin,
          text: context.strings.pcLoginMenu,
        ),
      ),
    );
  }
}

List<PersonalInfoMenu> resolvePersonalCenterMenus(
  SlotRegistry registry,
  PersonalCenterSlotContext context, {
  required VoidCallback openSettings,
  required VoidCallback openNotifications,
  required VoidCallback openFavorites,
  required VoidCallback openPrivacySettings,
  required VoidCallback openAccountSecurity,
  required VoidCallback openWebLogin,
  required bool showWebLoginEntry,
}) {
  ensurePersonalCenterSlots(registry);
  final items = registry.resolve(personalCenterSlot, context);
  return items
      .where(
        (item) => showWebLoginEntry || item.sid != 'personal_center_web_login',
      )
      .map((item) {
        if (item.sid == 'personal_center_currency') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openSettings(),
          );
        }
        if (item.sid == 'personal_center_new_msg_notice') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openNotifications(),
          );
        }
        if (item.sid == 'personal_center_favorites') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openFavorites(),
          );
        }
        if (item.sid == 'personal_center_privacy') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openPrivacySettings(),
          );
        }
        if (item.sid == 'personal_center_account_security') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openAccountSecurity(),
          );
        }
        if (item.sid == 'personal_center_web_login') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openWebLogin(),
          );
        }
        return PersonalInfoMenu(
          sid: item.sid,
          imgResource: item.imgResource,
          text: item.text,
          isNewVersion: item.isNewVersion,
          onClick: item.onClick,
        );
      })
      .toList(growable: false);
}
