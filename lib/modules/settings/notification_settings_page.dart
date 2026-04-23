import 'package:flutter/material.dart';

import '../../service/api/collection_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import 'notification_channel_settings_bridge.dart';
import 'settings_strings.dart';
import 'settings_surface_widgets.dart';

class NotificationSettingsPage extends StatefulWidget {
  final NotificationChannelSettingsBridge? notificationBridge;
  final EndpointManager? endpointManager;

  const NotificationSettingsPage({
    super.key,
    this.notificationBridge,
    this.endpointManager,
  });

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _newMsgNotice = true;
  bool _showMessageDetail = true;
  bool _voiceOn = true;
  bool _shockOn = true;
  bool _isLoading = false;
  bool _isSaving = false;

  NotificationChannelSettingsBridge get _notificationBridge =>
      widget.notificationBridge ??
      const DefaultNotificationChannelSettingsBridge();
  EndpointManager get _endpointManager =>
      widget.endpointManager ?? EndpointManager.getInstance();
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
        _newMsgNotice = settings['new_msg_notice'] == 1;
        _showMessageDetail =
            settings['show_push_detail'] != 0 ||
            settings['msg_show_detail'] != 0;
        _voiceOn = settings['voice_on'] != 0;
        _shockOn = settings['shock_on'] != 0;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _saveSettings() async {
    final strings = _strings;
    try {
      await SettingsApi.instance.updateUserSettings({
        'new_msg_notice': _newMsgNotice ? 1 : 0,
        'show_push_detail': _showMessageDetail ? 1 : 0,
        'msg_show_detail': _showMessageDetail ? 1 : 0,
        'voice_on': _voiceOn ? 1 : 0,
        'shock_on': _shockOn ? 1 : 0,
      });
      _showSnackBar(strings.notificationSaveSuccess);
      return true;
    } catch (error) {
      _showSnackBar(strings.notificationSaveFailed(error), isError: true);
      return false;
    }
  }

  Future<void> _updateToggle(
    bool value,
    void Function(bool value) apply,
  ) async {
    if (_isSaving) {
      return;
    }

    final previousNewMsgNotice = _newMsgNotice;
    final previousShowMessageDetail = _showMessageDetail;
    final previousVoiceOn = _voiceOn;
    final previousShockOn = _shockOn;
    setState(() {
      apply(value);
      _isSaving = true;
    });
    final saved = await _saveSettings();
    if (!mounted) {
      return;
    }

    setState(() {
      if (!saved) {
        _newMsgNotice = previousNewMsgNotice;
        _showMessageDetail = previousShowMessageDetail;
        _voiceOn = previousVoiceOn;
        _shockOn = previousShockOn;
      }
      _isSaving = false;
    });
  }

  Future<void> _openSystemSettings(
    String title,
    NotificationSettingsChannel channel,
  ) async {
    final opened = await _notificationBridge.openChannelSettings(channel);
    if (!opened && mounted) {
      _showSnackBar(
        _strings.openNotificationSettingsFailed(title),
        isError: true,
      );
    }
  }

  List<Widget> _buildKeepAliveWidgets(BuildContext context) {
    final result = _endpointManager.invoke('show_keep_alive_item', context);
    if (result is Widget) {
      return <Widget>[result];
    }
    if (result is Iterable<Widget>) {
      return result.toList(growable: false);
    }
    return const <Widget>[];
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final keepAliveWidgets = _buildKeepAliveWidgets(context);

    return SettingsScaffold(
      title: strings.notificationSettingsTitle,
      loading: _isLoading || _isSaving,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          WKSpace.md,
          WKSpace.md,
          WKSpace.md,
          WKSpace.xl,
        ),
        children: [
          SettingsHero(
            icon: Icons.notifications_active_outlined,
            title: strings.notificationHeroTitle,
            subtitle: strings.notificationHeroSubtitle,
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.notificationPreferencesSectionTitle,
            children: [
              SwitchSettingTile(
                icon: Icons.notifications_outlined,
                title: strings.notificationMasterSwitchTitle,
                subtitle: strings.notificationMasterSwitchDescription,
                value: _newMsgNotice,
                onChanged: _isSaving
                    ? null
                    : (value) => _updateToggle(
                        value,
                        (next) => _newMsgNotice = next,
                      ),
              ),
              SwitchSettingTile(
                icon: Icons.message_outlined,
                title: strings.showMessageDetailsTitle,
                subtitle: strings.showMessagePreviewSubtitle,
                value: _showMessageDetail,
                onChanged: _newMsgNotice && !_isSaving
                    ? (value) => _updateToggle(
                        value,
                        (next) => _showMessageDetail = next,
                      )
                    : null,
              ),
              SwitchSettingTile(
                icon: Icons.volume_up_outlined,
                title: strings.sound,
                subtitle: strings.notificationSoundDescription,
                value: _voiceOn,
                onChanged: _newMsgNotice && !_isSaving
                    ? (value) => _updateToggle(value, (next) => _voiceOn = next)
                    : null,
              ),
              SwitchSettingTile(
                icon: Icons.vibration_outlined,
                title: strings.vibration,
                subtitle: strings.notificationSoundDescription,
                value: _shockOn,
                onChanged: _newMsgNotice && !_isSaving
                    ? (value) => _updateToggle(value, (next) => _shockOn = next)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.notificationSystemSectionTitle,
            children: [
              ...keepAliveWidgets,
              ActionSettingTile(
                icon: Icons.tune_rounded,
                title: strings.openMessageNotificationSettings,
                subtitle: strings.notificationPermissionHint,
                onTap: () => _openSystemSettings(
                  strings.openMessageNotificationSettings,
                  NotificationSettingsChannel.message,
                ),
              ),
              ActionSettingTile(
                icon: Icons.ring_volume_outlined,
                title: strings.openCallInvitationNotificationSettings,
                subtitle: strings.callPermissionHint,
                onTap: () => _openSystemSettings(
                  strings.openCallInvitationNotificationSettings,
                  NotificationSettingsChannel.rtc,
                ),
              ),
            ],
          ),
          const SizedBox(height: WKSpace.md),
          SettingsInfoCard(
            icon: Icons.info_outline_rounded,
            title: strings.notificationHelpSectionTitle,
            subtitle: _newMsgNotice
                ? strings.notificationSystemSettingsHint
                : strings.notificationDisabledHint,
          ),
        ],
      ),
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
}
