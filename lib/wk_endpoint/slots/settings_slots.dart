import 'package:flutter/foundation.dart';

import '../../modules/settings/settings_strings.dart';
import '../core/slot_descriptor.dart';

enum SettingsCellStyle { normal, dangerCentered }

enum SettingsCellAccessory { arrow, none, about }

@immutable
class SettingsCellItem {
  const SettingsCellItem({
    required this.id,
    required this.title,
    required this.onTap,
    this.value,
    this.style = SettingsCellStyle.normal,
    this.accessory = SettingsCellAccessory.arrow,
    this.showNewVersionBadge = false,
  });

  final String id;
  final String title;
  final String? value;
  final SettingsCellStyle style;
  final SettingsCellAccessory accessory;
  final bool showNewVersionBadge;
  final VoidCallback onTap;
}

@immutable
class SettingsSectionItem {
  const SettingsSectionItem({required this.id, required this.cells});

  final String id;
  final List<SettingsCellItem> cells;
}

@immutable
class SettingsSlotContext {
  const SettingsSlotContext({
    required this.darkModeStatus,
    required this.imageCacheSize,
    required this.hasNewVersion,
    this.strings = zhHansSettingsStrings,
    required this.openThemeSettings,
    required this.openLanguageSettings,
    required this.openFontSizeSettings,
    required this.openChatBackgroundSettings,
    required this.openNotificationSettings,
    required this.openPrivacySettings,
    required this.openAccountSecurity,
    required this.clearImageCache,
    required this.clearAllChatHistory,
    required this.openMessageBackup,
    required this.openMessageRecovery,
    required this.openAppModules,
    required this.openThirdPartySharing,
    required this.openErrorLogs,
    required this.openAbout,
    required this.logout,
  });

  final String darkModeStatus;
  final String imageCacheSize;
  final bool hasNewVersion;
  final SettingsStrings strings;
  final VoidCallback openThemeSettings;
  final VoidCallback openLanguageSettings;
  final VoidCallback openFontSizeSettings;
  final VoidCallback openChatBackgroundSettings;
  final VoidCallback openNotificationSettings;
  final VoidCallback openPrivacySettings;
  final VoidCallback openAccountSecurity;
  final VoidCallback clearImageCache;
  final VoidCallback clearAllChatHistory;
  final VoidCallback openMessageBackup;
  final VoidCallback openMessageRecovery;
  final VoidCallback openAppModules;
  final VoidCallback openThirdPartySharing;
  final VoidCallback openErrorLogs;
  final VoidCallback openAbout;
  final VoidCallback logout;
}

const settingsSectionSlot =
    SlotDescriptor<SettingsSlotContext, SettingsSectionItem>(
      'settings.section',
    );
