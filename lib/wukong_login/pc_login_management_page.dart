import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../core/constants/app_constants.dart';
import '../modules/auth/application/auth_providers.dart';
import '../modules/chat/chat_page.dart';
import '../modules/settings/settings_strings.dart';
import '../service/api/collection_api.dart';
import '../service/api/user_api.dart';
import '../widgets/wk_colors.dart';
import '../widgets/wk_sub_page_scaffold.dart';

typedef PcLoginMuteUpdater = Future<void> Function(int value);
typedef PcOnlineStateLoader = Future<PcOnlineState> Function();

class PCLoginManagementPage extends ConsumerStatefulWidget {
  const PCLoginManagementPage({
    super.key,
    this.updateMuteOfApp,
    this.loadOnlineState,
    this.onRefresh,
    this.onOpenFileHelper,
  });

  final PcLoginMuteUpdater? updateMuteOfApp;
  final PcOnlineStateLoader? loadOnlineState;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpenFileHelper;

  @override
  ConsumerState<PCLoginManagementPage> createState() =>
      _PCLoginManagementPageState();
}

class _PCLoginManagementPageState extends ConsumerState<PCLoginManagementPage>
    with WidgetsBindingObserver {
  static const String _fileHelperUid = 'fileHelper';

  bool _muteOfApp = false;
  bool _isLocked = false;
  bool _isTogglingMute = false;
  bool _isQuittingPc = false;
  String? _errorMessage;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreMuteState());
    unawaited(_syncOnlineState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncOnlineState());
    }
  }

  Future<void> _restoreMuteState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUid = prefs.getString(AppConstants.keyUid) ?? '';
    final storedValue = prefs.getInt(_mutePreferenceKey(rawUid)) ?? 0;
    if (!mounted) {
      return;
    }
    setState(() => _muteOfApp = storedValue == 1);
    widget.onRefresh?.call();
  }

  Future<void> _syncOnlineState() async {
    try {
      final loadOnlineState =
          widget.loadOnlineState ?? UserApi.instance.getPcOnlineState;
      final onlineState = await loadOnlineState();
      final prefs = await SharedPreferences.getInstance();
      final rawUid = prefs.getString(AppConstants.keyUid) ?? '';
      await prefs.setInt(_mutePreferenceKey(rawUid), onlineState.muteOfApp);
      await prefs.setInt(_onlinePreferenceKey(rawUid), onlineState.online);
      if (!mounted) {
        return;
      }
      setState(() => _muteOfApp = onlineState.muteOfApp == 1);
      widget.onRefresh?.call();
    } catch (_) {
      // Keep the page usable even if the foreground sync request fails.
    }
  }

  Future<void> _toggleMuteOfApp() async {
    if (_isTogglingMute || _isQuittingPc) {
      return;
    }
    final nextValue = _muteOfApp ? 0 : 1;
    setState(() {
      _isTogglingMute = true;
      _errorMessage = null;
    });

    try {
      final updateMuteOfApp =
          widget.updateMuteOfApp ??
          (value) =>
              SettingsApi.instance.updateUserSettings({'mute_of_app': value});
      await updateMuteOfApp(nextValue);
      final prefs = await SharedPreferences.getInstance();
      final rawUid = prefs.getString(AppConstants.keyUid) ?? '';
      await prefs.setInt(_mutePreferenceKey(rawUid), nextValue);
      if (!mounted) {
        return;
      }
      setState(() => _muteOfApp = nextValue == 1);
      widget.onRefresh?.call();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isTogglingMute = false);
      }
    }
  }

  Future<void> _quitPcLogin() async {
    if (_isQuittingPc || _isTogglingMute) {
      return;
    }
    setState(() {
      _isQuittingPc = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).quitPcWebSessions();
      widget.onRefresh?.call();
      if (!mounted) {
        return;
      }
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isQuittingPc = false);
      }
    }
  }

  void _openFileHelperChat() {
    final onOpenFileHelper = widget.onOpenFileHelper;
    if (onOpenFileHelper != null) {
      onOpenFileHelper();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatPage(
          channelId: _fileHelperUid,
          channelType: WKChannelType.personal,
          channelName: 'File Helper',
        ),
      ),
    );
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return KeyedSubtree(
      key: const ValueKey<String>('pc-login-management-page'),
      child: WKSubPageScaffold(
        title: strings.pcLoginPageTitle,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            if ((_errorMessage ?? '').trim().isNotEmpty) ...[
              _buildErrorBanner(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _PcLoginActionCard(
                    key: const ValueKey<String>('pc-login-management-mute'),
                    title: strings.phoneMute,
                    subtitle: _muteOfApp ? strings.muted : strings.enabled,
                    onTap: _toggleMuteOfApp,
                    isBusy: _isTogglingMute,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PcLoginActionCard(
                    key: const ValueKey<String>(
                      'pc-login-management-file-helper',
                    ),
                    title: strings.fileHelper,
                    subtitle: strings.openChat,
                    onTap: _openFileHelperChat,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PcLoginActionCard(
              key: const ValueKey<String>('pc-login-management-lock'),
              title: strings.lock,
              subtitle: _isLocked ? strings.locked : strings.unlocked,
              onTap: _toggleLock,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const ValueKey<String>('pc-login-management-quit-all'),
                onPressed: _isQuittingPc ? null : _quitPcLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: WKColors.brand500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE6EAF2)),
                  ),
                ),
                child: _isQuittingPc
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.exitAllPcWebLogin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final strings = _strings;
    final noticeText = _isLocked
        ? strings.pcLoginLockedNotice
        : _muteOfApp
        ? strings.phoneNotificationsMuted
        : strings.phoneNotificationsEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 72,
            decoration: BoxDecoration(
              color: _isLocked
                  ? const Color(0xFFFFF4D6)
                  : _muteOfApp
                  ? WKColors.brand500.withValues(alpha: 0.12)
                  : const Color(0xFFEEF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Icon(
              _isLocked
                  ? Icons.lock_rounded
                  : _muteOfApp
                  ? Icons.volume_off_rounded
                  : Icons.computer_rounded,
              size: 34,
              color: WKColors.brand500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            strings.pcLoginHeroTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            noticeText,
            key: const ValueKey<String>('pc-login-management-notice'),
            style: const TextStyle(fontSize: 15, color: WKColors.color999),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: WKColors.danger),
      ),
    );
  }

  String _mutePreferenceKey(String rawUid) {
    final normalizedUid = rawUid.trim();
    if (normalizedUid.isEmpty) {
      return 'mute_of_app';
    }
    return '${normalizedUid}_mute_of_app';
  }

  String _onlinePreferenceKey(String rawUid) {
    final normalizedUid = rawUid.trim();
    if (normalizedUid.isEmpty) {
      return 'pc_online';
    }
    return '${normalizedUid}_pc_online';
  }
}

class _PcLoginActionCard extends StatelessWidget {
  const _PcLoginActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isBusy = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.circle_rounded,
                  size: 18,
                  color: WKColors.brand500,
                ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WKColors.colorDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: WKColors.color999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
