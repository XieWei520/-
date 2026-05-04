import 'package:flutter/material.dart';

import '../../service/api/collection_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import 'blacklist_page.dart';
import 'settings_strings.dart';
import 'settings_surface_widgets.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _phoneSearchOff = false;
  bool _deviceLockEnabled = false;
  bool _showOnlineStatus = true;
  bool _showMessagePreview = true;
  bool _isLoading = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await SettingsApi.instance.getUserSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _phoneSearchOff = settings['search_by_phone'] == 0;
        _deviceLockEnabled = settings['device_lock'] == 1;
        _showOnlineStatus = settings['show_online_status'] != 0;
        _showMessagePreview =
            settings['show_push_detail'] != 0 ||
            settings['msg_show_detail'] != 0;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final strings = _strings;
    try {
      await SettingsApi.instance.updateUserSettings({
        'search_by_phone': _phoneSearchOff ? 0 : 1,
        'device_lock': _deviceLockEnabled ? 1 : 0,
        'show_online_status': _showOnlineStatus ? 1 : 0,
        'show_push_detail': _showMessagePreview ? 1 : 0,
        'msg_show_detail': _showMessagePreview ? 1 : 0,
      });
      _showSnackBar(strings.settingsSaved);
    } catch (error) {
      _showSnackBar(strings.saveFailed(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return SettingsScaffold(
      title: strings.privacySettingsTitle,
      onSave: _saveSettings,
      loading: _isLoading,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.xl,
        ),
        children: [
          SettingsHero(
            icon: Icons.privacy_tip_outlined,
            title: strings.privacyHeroTitle,
            subtitle: strings.privacyHeroSubtitle,
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.visibilitySectionTitle,
            children: [
              SwitchSettingTile(
                icon: Icons.phone_disabled_outlined,
                title: strings.disablePhoneSearchTitle,
                subtitle: strings.disablePhoneSearchSubtitle,
                value: _phoneSearchOff,
                onChanged: (value) => setState(() => _phoneSearchOff = value),
              ),
              SwitchSettingTile(
                icon: Icons.circle_outlined,
                title: strings.showOnlineStatusTitle,
                subtitle: strings.showOnlineStatusSubtitle,
                value: _showOnlineStatus,
                onChanged: (value) => setState(() => _showOnlineStatus = value),
              ),
              SwitchSettingTile(
                icon: Icons.message_outlined,
                title: strings.showMessagePreviewTitle,
                subtitle: strings.showMessagePreviewSubtitle,
                value: _showMessagePreview,
                onChanged: (value) =>
                    setState(() => _showMessagePreview = value),
              ),
            ],
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.securitySectionTitle,
            children: [
              SwitchSettingTile(
                icon: Icons.lock_outline_rounded,
                title: strings.deviceLockTitle,
                subtitle: strings.deviceLockSubtitle,
                value: _deviceLockEnabled,
                onChanged: (value) {
                  if (value) {
                    _showSetDeviceLockDialog();
                  } else {
                    _disableDeviceLock();
                  }
                },
              ),
              ActionSettingTile(
                icon: Icons.block_outlined,
                title: strings.blacklistTitle,
                subtitle: strings.blacklistSubtitle,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BlacklistPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSetDeviceLockDialog() {
    final strings = _strings;
    final pwdController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.setDeviceLock),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pwdController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: strings.enterPassword,
                  hintText: strings.passwordHint6Digits,
                ),
              ),
              const SizedBox(height: WKSpace.sm),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: strings.confirmPassword,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () async {
                final pwd = pwdController.text.trim();
                final confirm = confirmController.text.trim();

                if (pwd.length != 6 || int.tryParse(pwd) == null) {
                  _showSnackBar(
                    strings.deviceLockPasswordMustBe6Digits,
                    isError: true,
                  );
                  return;
                }
                if (pwd != confirm) {
                  _showSnackBar(strings.passwordsDoNotMatch, isError: true);
                  return;
                }

                Navigator.pop(context);
                try {
                  await SettingsApi.instance.setDeviceLock(
                    password: pwd,
                    enabled: true,
                  );
                  if (!mounted) {
                    return;
                  }
                  setState(() => _deviceLockEnabled = true);
                  await _saveSettings();
                } catch (error) {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _deviceLockEnabled = false);
                  _showSnackBar(
                    strings.enableDeviceLockFailed(error),
                    isError: true,
                  );
                }
              },
              child: Text(
                strings.confirm,
                style: const TextStyle(color: WKColors.brand500),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WKColors.danger : null,
      ),
    );
  }

  Future<void> _disableDeviceLock() async {
    final strings = _strings;
    try {
      await SettingsApi.instance.setDeviceLock(password: '', enabled: false);
      if (!mounted) {
        return;
      }
      setState(() => _deviceLockEnabled = false);
      await _saveSettings();
    } catch (error) {
      _showSnackBar(strings.disableDeviceLockFailed(error), isError: true);
    }
  }
}
