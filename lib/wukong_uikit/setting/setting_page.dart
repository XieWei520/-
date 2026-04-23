import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/conversation_provider.dart';
import '../../modules/auth/login_page.dart';
import '../../modules/settings/account_security_page.dart';
import '../../modules/settings/cache_clean_service.dart';
import '../../modules/settings/message_backup/backup_restore_message_page.dart';
import '../../modules/settings/notification_settings_page.dart';
import '../../modules/settings/privacy_settings_page.dart';
import '../../modules/settings/settings_strings.dart';
import '../../modules/settings/settings_surface_widgets.dart';
import '../../service/api/common_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/settings_slots.dart';
import 'about_page.dart';
import 'app_modules_page.dart';
import 'chat_background_settings_page.dart';
import 'error_logs_page.dart';
import 'font_size_settings_page.dart';
import 'language_settings_page.dart';
import 'setting_preferences.dart';
import 'setting_slot_assembly.dart';
import 'theme_settings_page.dart';
import 'third_party_sharing_page.dart';

@visibleForTesting
bool shouldInsertSettingsGap({
  required String sectionId,
  required String cellId,
}) {
  if (sectionId == 'settings.appearance' && cellId == 'settings.dark_mode') {
    return true;
  }
  if (sectionId == 'settings.modules' && cellId == 'settings.app_modules') {
    return true;
  }
  return false;
}

@visibleForTesting
List<Widget> buildSettingsSectionWidgets({
  required List<SettingsSectionItem> sections,
  required Widget Function(SettingsCellItem cell) buildCell,
}) {
  return <Widget>[
    for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) ...[
      WKSettingsGroup(
        children: [
          for (var cellIndex = 0;
              cellIndex < sections[sectionIndex].cells.length;
              cellIndex++) ...[
            buildCell(sections[sectionIndex].cells[cellIndex]),
            if (shouldInsertSettingsGap(
              sectionId: sections[sectionIndex].id,
              cellId: sections[sectionIndex].cells[cellIndex].id,
            ))
              const WKSectionGap(10),
          ],
        ],
      ),
      if (sectionIndex != sections.length - 1) const WKSectionGap(8),
    ],
  ];
}

@visibleForTesting
Widget buildSettingsAboutTrailing({required bool showNewVersionBadge}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Opacity(
        opacity: showNewVersionBadge ? 1 : 0,
        child: WKReferenceAssets.image(
          WKReferenceAssets.newVersion,
          width: 30,
          height: 20,
        ),
      ),
      const SizedBox(width: 6),
      WKReferenceAssets.image(
        WKReferenceAssets.arrowRight,
        width: 14,
        height: 14,
      ),
    ],
  );
}

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key, this.cacheCleanService});

  final CacheCleanService? cacheCleanService;

  @override
  ConsumerState<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends ConsumerState<SettingPage> {
  late final CacheCleanService _cacheCleanService =
      widget.cacheCleanService ?? CacheCleanService.platform();

  String _imageCacheSize = '0 KB';
  bool _isClearingCache = false;
  bool _isClearingChatHistory = false;
  bool _isLoggingOut = false;
  bool _hasNewVersion = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshCacheSize());
      });
    });
    unawaited(_loadVersionIndicator());
  }

  Future<void> _refreshCacheSize() async {
    try {
      final bytes = await _cacheCleanService.getTotalCacheBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _imageCacheSize = _formatBytes(bytes);
      });
    } catch (error, stackTrace) {
      debugPrint('SettingPage cache size refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadVersionIndicator() async {
    try {
      final version = await CommonApi.instance.getAppNewVersion(
        AppConfig.appVersion,
      );
      if (!mounted) {
        return;
      }
      setState(() => _hasNewVersion = version?.hasDownloadUrl == true);
    } catch (error, stackTrace) {
      debugPrint('SettingPage version check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }

  Future<void> _clearImageCache() async {
    if (_isClearingCache) {
      return;
    }

    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.clearImageCache),
          content: Text(strings.clearImageCacheMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.clear),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isClearingCache = true);
    try {
      await _cacheCleanService.clearAllCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _refreshCacheSize();
      _showMessage(strings.clearImageCacheSuccess);
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.logout),
          content: Text(strings.logoutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                strings.logoutAction,
                style: const TextStyle(color: WKColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isLoggingOut = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await ref.read(authProvider.notifier).logout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      _showMessage(strings.logoutFailed(error));
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _clearAllChatHistory() async {
    if (_isClearingChatHistory) {
      return;
    }

    final strings = _strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.clearAllChatHistory),
          content: Text(strings.clearAllChatHistoryMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                strings.clear,
                style: const TextStyle(color: WKColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isClearingChatHistory = true);
    try {
      await ref.read(conversationProvider.notifier).clearAllChatHistory();
      _showMessage(strings.clearAllChatHistorySuccess);
    } finally {
      if (mounted) {
        setState(() => _isClearingChatHistory = false);
      }
    }
  }

  Future<void> _pushPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      unawaited(_refreshCacheSize());
      unawaited(_loadVersionIndicator());
      setState(() {});
    }
  }

  Widget _buildUnifiedSettingsCell(SettingsCellItem cell) {
    if (cell.style == SettingsCellStyle.dangerCentered) {
      return InkWell(
        onTap: cell.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WKSpace.lg,
            vertical: WKSpace.md,
          ),
          child: Center(
            child: Text(
              cell.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: WKColors.danger,
              ),
            ),
          ),
        ),
      );
    }

    final value = cell.value?.trim() ?? '';
    Widget? trailing;
    if (cell.accessory == SettingsCellAccessory.about) {
      trailing = buildSettingsAboutTrailing(
        showNewVersionBadge: cell.showNewVersionBadge,
      );
    } else if (cell.accessory == SettingsCellAccessory.arrow) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) ...[
            Text(
              value,
              style: const TextStyle(fontSize: 13, color: WKColors.color999),
            ),
            const SizedBox(width: WKSpace.xs),
          ],
          const Icon(Icons.chevron_right_rounded, color: WKColors.color999),
        ],
      );
    } else if (value.isNotEmpty) {
      trailing = Text(
        value,
        style: const TextStyle(fontSize: 13, color: WKColors.color999),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: cell.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WKSpace.lg,
            vertical: WKSpace.md,
          ),
          child: Row(
            children: [
              _SettingsCellIcon(icon: _cellIcon(cell.id)),
              const SizedBox(width: WKSpace.md),
              Expanded(
                child: Text(
                  cell.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  String _sectionTitle(String sectionId, SettingsStrings strings) {
    return switch (sectionId) {
      'settings.appearance' => strings.generalAppearanceSectionTitle,
      'settings.cache' => strings.generalStorageSectionTitle,
      'settings.message_backup' => strings.generalMessagesSectionTitle,
      'settings.modules' => strings.generalModulesSectionTitle,
      'settings.about' => strings.generalSupportSectionTitle,
      'settings.account' => strings.generalAccountSectionTitle,
      _ => strings.settingsTitle,
    };
  }

  IconData _cellIcon(String cellId) {
    return switch (cellId) {
      'settings.dark_mode' => Icons.dark_mode_outlined,
      'settings.language' => Icons.translate_rounded,
      'settings.font_size' => Icons.format_size_rounded,
      'settings.chat_background' => Icons.wallpaper_rounded,
      'settings.clear_cache' => Icons.photo_library_outlined,
      'settings.clear_all_chat_history' => Icons.delete_sweep_outlined,
      'settings.message_backup' => Icons.backup_rounded,
      'settings.message_recovery' => Icons.restore_rounded,
      'settings.app_modules' => Icons.widgets_outlined,
      'settings.third_party' => Icons.share_outlined,
      'settings.error_logs' => Icons.bug_report_outlined,
      'settings.about_app' => Icons.info_outline_rounded,
      'settings.logout' => Icons.logout_rounded,
      _ => Icons.tune_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final sections = resolveSettingsSections(
      ref.read(slotRegistryProvider),
      SettingsSlotContext(
        darkModeStatus: WKSettingPreferences.darkModeStatusText(
          Localizations.localeOf(context),
        ),
        imageCacheSize: _imageCacheSize,
        hasNewVersion: _hasNewVersion,
        strings: strings,
        openThemeSettings: () => _pushPage(const ThemeSettingsPage()),
        openLanguageSettings: () => _pushPage(const LanguageSettingsPage()),
        openFontSizeSettings: () => _pushPage(const FontSizeSettingsPage()),
        openChatBackgroundSettings: () =>
            _pushPage(const ChatBackgroundSettingsPage()),
        openNotificationSettings: () =>
            _pushPage(const NotificationSettingsPage()),
        openPrivacySettings: () => _pushPage(const PrivacySettingsPage()),
        openAccountSecurity: () => _pushPage(const AccountSecurityPage()),
        clearImageCache: _clearImageCache,
        clearAllChatHistory: _clearAllChatHistory,
        openMessageBackup: () => _pushPage(
          const BackupRestoreMessagePage(mode: BackupRestoreMessageMode.backup),
        ),
        openMessageRecovery: () => _pushPage(
          const BackupRestoreMessagePage(
            mode: BackupRestoreMessageMode.restore,
          ),
        ),
        openAppModules: () => _pushPage(AppModulesPage()),
        openThirdPartySharing: () => _pushPage(const ThirdPartySharingPage()),
        openErrorLogs: () => _pushPage(const ErrorLogsPage()),
        openAbout: () => _pushPage(const AboutPage()),
        logout: _logout,
      ),
    );
    return SettingsScaffold(
      title: strings.settingsTitle,
      loading: _isClearingCache || _isClearingChatHistory || _isLoggingOut,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.xl,
        ),
        children: [
          SettingsHero(
            icon: Icons.tune_rounded,
            title: strings.generalHeroTitle,
            subtitle: strings.generalHeroSubtitle,
          ),
          const SizedBox(height: WKSpace.md),
          for (var index = 0; index < sections.length; index++) ...[
            SettingsSection(
              title: _sectionTitle(sections[index].id, strings),
              children: [
                for (final cell in sections[index].cells)
                  _buildUnifiedSettingsCell(cell),
              ],
            ),
            if (index != sections.length - 1) const SizedBox(height: WKSpace.md),
          ],
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsCellIcon extends StatelessWidget {
  const _SettingsCellIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(WKRadius.md),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: WKColors.brand500),
    );
  }
}
