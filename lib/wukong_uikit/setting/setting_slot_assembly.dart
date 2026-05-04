import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/settings_slots.dart';

void ensureSettingsSections(SlotRegistry registry) {
  if (!registry.containsId(settingsSectionSlot, 'settings.appearance')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.appearance',
        priority: 100,
        build: (context) => SettingsSectionItem(
          id: 'settings.appearance',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.dark_mode',
              title: context.strings.darkMode,
              value: context.darkModeStatus,
              onTap: context.openThemeSettings,
            ),
            SettingsCellItem(
              id: 'settings.language',
              title: context.strings.language,
              onTap: context.openLanguageSettings,
            ),
            SettingsCellItem(
              id: 'settings.font_size',
              title: context.strings.fontSize,
              onTap: context.openFontSizeSettings,
            ),
            SettingsCellItem(
              id: 'settings.chat_background',
              title: context.strings.chatBackground,
              onTap: context.openChatBackgroundSettings,
            ),
          ],
        ),
      ),
    );
  }
  if (!registry.containsId(settingsSectionSlot, 'settings.cache')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.cache',
        priority: 90,
        build: (context) => SettingsSectionItem(
          id: 'settings.cache',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.clear_cache',
              title: context.strings.clearImageCache,
              value: context.imageCacheSize,
              onTap: context.clearImageCache,
            ),
            SettingsCellItem(
              id: 'settings.clear_all_chat_history',
              title: context.strings.clearAllChatHistory,
              onTap: context.clearAllChatHistory,
            ),
          ],
        ),
      ),
    );
  }
  if (!registry.containsId(settingsSectionSlot, 'settings.message_backup')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.message_backup',
        priority: 85,
        build: (context) => SettingsSectionItem(
          id: 'settings.message_backup',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.message_backup',
              title: context.strings.messageBackup,
              onTap: context.openMessageBackup,
            ),
            SettingsCellItem(
              id: 'settings.message_recovery',
              title: context.strings.messageRecovery,
              onTap: context.openMessageRecovery,
            ),
          ],
        ),
      ),
    );
  }
  if (!registry.containsId(settingsSectionSlot, 'settings.modules')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.modules',
        priority: 80,
        build: (context) => SettingsSectionItem(
          id: 'settings.modules',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.app_modules',
              title: context.strings.appModules,
              onTap: context.openAppModules,
            ),
            SettingsCellItem(
              id: 'settings.third_party',
              title: context.strings.thirdPartySharing,
              onTap: context.openThirdPartySharing,
            ),
            SettingsCellItem(
              id: 'settings.error_logs',
              title: context.strings.errorLogs,
              onTap: context.openErrorLogs,
            ),
          ],
        ),
      ),
    );
  }
  if (!registry.containsId(settingsSectionSlot, 'settings.about')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.about',
        priority: 70,
        build: (context) => SettingsSectionItem(
          id: 'settings.about',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.about_app',
              title: context.strings.about,
              accessory: SettingsCellAccessory.about,
              showNewVersionBadge: context.hasNewVersion,
              onTap: context.openAbout,
            ),
          ],
        ),
      ),
    );
  }
  if (!registry.containsId(settingsSectionSlot, 'settings.account')) {
    registry.register(
      settingsSectionSlot,
      SlotEntry<SettingsSlotContext, SettingsSectionItem>(
        id: 'settings.account',
        priority: 10,
        build: (context) => SettingsSectionItem(
          id: 'settings.account',
          cells: <SettingsCellItem>[
            SettingsCellItem(
              id: 'settings.logout',
              title: context.strings.logout,
              style: SettingsCellStyle.dangerCentered,
              accessory: SettingsCellAccessory.none,
              onTap: context.logout,
            ),
          ],
        ),
      ),
    );
  }
}

List<SettingsSectionItem> resolveSettingsSections(
  SlotRegistry registry,
  SettingsSlotContext context,
) {
  ensureSettingsSections(registry);
  return registry.resolve(settingsSectionSlot, context);
}
