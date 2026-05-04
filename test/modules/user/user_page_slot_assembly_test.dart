import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/user/user_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/personal_info_menu.dart';

void main() {
  test('personal center installer exposes ordered rows without moments', () {
    final registry = SlotRegistry();
    final items = resolvePersonalCenterMenus(
      registry,
      const PersonalCenterSlotContext(hasNewVersion: true),
      openSettings: () {},
      openNotifications: () {},
      openFavorites: () {},
      openPrivacySettings: () {},
      openAccountSecurity: () {},
      openWebLogin: () {},
      showWebLoginEntry: true,
    );

    expect(items.map((item) => item.sid).toList(), <String>[
      'personal_center_currency',
      'personal_center_new_msg_notice',
      'personal_center_favorites',
      'personal_center_privacy',
      'personal_center_account_security',
      'personal_center_web_login',
    ]);
    expect(items.any((item) => item.sid == 'personal_center_moments'), isFalse);
    expect(
      items.every((item) => (item.imgResource ?? '').trim().isNotEmpty),
      isTrue,
    );
  });

  test('custom personal-center rows preserve slot click handlers', () {
    final registry = SlotRegistry();
    var customTapCount = 0;
    var webLoginTapCount = 0;

    registry.register(
      personalCenterSlot,
      SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
        id: 'personal_center_custom',
        priority: 999,
        build: (_) => PersonalInfoMenu(
          sid: 'personal_center_custom',
          text: 'Custom',
          onClick: (_) => customTapCount++,
        ),
      ),
    );

    final items = resolvePersonalCenterMenus(
      registry,
      const PersonalCenterSlotContext(hasNewVersion: false),
      openSettings: () {},
      openNotifications: () {},
      openFavorites: () {},
      openPrivacySettings: () {},
      openAccountSecurity: () {},
      openWebLogin: () => webLoginTapCount++,
      showWebLoginEntry: true,
    );

    final customItem = items.firstWhere(
      (item) => item.sid == 'personal_center_custom',
    );
    customItem.onClick?.call(customItem.sid);

    expect(customTapCount, 1);
    expect(webLoginTapCount, 0);
  });

  test(
    'personal-center built-in rows route to dedicated callbacks and not passthrough handlers',
    () {
      final registry = SlotRegistry();
      var fallbackTapCount = 0;
      var settingsTapCount = 0;
      var notificationsTapCount = 0;
      var favoritesTapCount = 0;
      var privacyTapCount = 0;
      var accountSecurityTapCount = 0;
      var webLoginTapCount = 0;

      const routedSids = <String>[
        'personal_center_currency',
        'personal_center_new_msg_notice',
        'personal_center_favorites',
        'personal_center_privacy',
        'personal_center_account_security',
        'personal_center_web_login',
      ];

      for (final sid in routedSids) {
        registry.register(
          personalCenterSlot,
          SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
            id: sid,
            priority: 999,
            build: (_) => PersonalInfoMenu(
              sid: sid,
              text: sid,
              onClick: (_) => fallbackTapCount++,
            ),
          ),
        );
      }

      final items = resolvePersonalCenterMenus(
        registry,
        const PersonalCenterSlotContext(hasNewVersion: false),
        openSettings: () => settingsTapCount++,
        openNotifications: () => notificationsTapCount++,
        openFavorites: () => favoritesTapCount++,
        openPrivacySettings: () => privacyTapCount++,
        openAccountSecurity: () => accountSecurityTapCount++,
        openWebLogin: () => webLoginTapCount++,
        showWebLoginEntry: true,
      );

      for (final sid in routedSids) {
        final item = items.firstWhere((entry) => entry.sid == sid);
        item.onClick?.call(item.sid);
      }

      expect(fallbackTapCount, 0);
      expect(settingsTapCount, 1);
      expect(notificationsTapCount, 1);
      expect(favoritesTapCount, 1);
      expect(privacyTapCount, 1);
      expect(accountSecurityTapCount, 1);
      expect(webLoginTapCount, 1);
    },
  );
}
