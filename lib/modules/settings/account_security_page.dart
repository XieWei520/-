import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/crypto_utils.dart';
import '../../data/providers/auth_provider.dart';
import '../../service/api/user_api.dart';
import '../../service/api/collection_api.dart';
import '../../widgets/wk_design_tokens.dart';
import 'device_list_page.dart';
import 'settings_strings.dart';
import 'settings_surface_widgets.dart';

class AccountSecurityPage extends ConsumerStatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  ConsumerState<AccountSecurityPage> createState() =>
      _AccountSecurityPageState();
}

class _AccountSecurityPageState extends ConsumerState<AccountSecurityPage> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  String get _chatPasswordTitle => '聊天密码';

  String get _chatPasswordSubtitle => '设置或更新聊天密码，用于受保护会话。';

  String get _chatPasswordUpdated => '聊天密码已更新';

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await SettingsApi.instance.getDevices();
      if (!mounted) {
        return;
      }
      setState(() => _devices = devices);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _devices = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openDeviceList() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeviceListPage()));
    if (!mounted) {
      return;
    }
    await _loadDevices();
  }

  Future<void> _openDestroyAccountDialog() async {
    final destroyed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DestroyAccountDialog(),
    );
    if (destroyed != true || !mounted) {
      return;
    }
    _showSnackBar(_strings.destroyAccountSuccess);
    await ref.read(authProvider.notifier).logout();
  }

  Future<void> _openChatPasswordDialog() async {
    final uid = ref.read(authProvider).userInfo?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ChatPasswordDialog(uid: uid),
    );
    if (updated == true && mounted) {
      _showSnackBar(_chatPasswordUpdated);
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return SettingsScaffold(
      title: strings.accountSecurityTitle,
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
            icon: Icons.shield_outlined,
            title: strings.accountAndDevicesTitle,
            subtitle: strings.accountAndDevicesSubtitleWithCount(
              _devices.length,
            ),
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.signedInDevicesSection,
            children: [
              ActionSettingTile(
                icon: Icons.devices_outlined,
                title: strings.deviceListTitle,
                subtitle: strings.devicesCount(_devices.length),
                onTap: _openDeviceList,
              ),
            ],
          ),
          const SizedBox(height: WKSpace.md),
          SettingsSection(
            title: strings.accountActionsSection,
            children: [
              ActionSettingTile(
                key: const ValueKey<String>('account-security-chat-password'),
                icon: Icons.password_rounded,
                title: _chatPasswordTitle,
                subtitle: _chatPasswordSubtitle,
                onTap: _openChatPasswordDialog,
              ),
              ActionSettingTile(
                key: const ValueKey<String>('account-security-destroy-account'),
                icon: Icons.delete_outline_rounded,
                title: strings.destroyAccountTitle,
                subtitle: strings.destroyAccountSubtitle,
                onTap: _openDestroyAccountDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatPasswordDialog extends ConsumerStatefulWidget {
  const _ChatPasswordDialog({required this.uid});

  final String uid;

  @override
  ConsumerState<_ChatPasswordDialog> createState() =>
      _ChatPasswordDialogState();
}

class _ChatPasswordDialogState extends ConsumerState<_ChatPasswordDialog> {
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _chatPasswordController = TextEditingController();
  final TextEditingController _confirmChatPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  String get _title => '设置聊天密码';

  String get _description => '更新聊天密码前，请先验证当前登录密码。';

  String get _loginPasswordLabel => '登录密码';

  String get _chatPasswordLabel => '聊天密码';

  String get _confirmChatPasswordLabel => '确认聊天密码';

  String get _requiredFieldsError => '请完整填写所有密码项';

  String get _passwordMismatchError => '两次输入的聊天密码不一致';

  String get _confirmAction => '保存密码';

  String _submitFailed(Object error) => '更新聊天密码失败: $error';

  @override
  void dispose() {
    _loginPasswordController.dispose();
    _chatPasswordController.dispose();
    _confirmChatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_description),
          const SizedBox(height: WKSpace.md),
          TextField(
            key: const ValueKey<String>(
              'account-security-login-password-field',
            ),
            controller: _loginPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: _loginPasswordLabel),
          ),
          const SizedBox(height: WKSpace.sm),
          TextField(
            key: const ValueKey<String>('account-security-chat-password-field'),
            controller: _chatPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: _chatPasswordLabel),
          ),
          const SizedBox(height: WKSpace.sm),
          TextField(
            key: const ValueKey<String>(
              'account-security-confirm-chat-password-field',
            ),
            controller: _confirmChatPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: _confirmChatPasswordLabel),
          ),
          if ((_errorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: WKSpace.sm),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            resolveSettingsStrings(
              locale: Localizations.localeOf(context),
            ).cancel,
          ),
        ),
        TextButton(
          key: const ValueKey<String>('account-security-chat-password-confirm'),
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: Text(_confirmAction),
        ),
      ],
    );
  }

  Future<void> _handleConfirm() async {
    final loginPassword = _loginPasswordController.text.trim();
    final chatPassword = _chatPasswordController.text.trim();
    final confirmChatPassword = _confirmChatPasswordController.text.trim();

    if (loginPassword.isEmpty ||
        chatPassword.isEmpty ||
        confirmChatPassword.isEmpty) {
      setState(() => _errorMessage = _requiredFieldsError);
      return;
    }
    if (chatPassword != confirmChatPassword) {
      setState(() => _errorMessage = _passwordMismatchError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await UserApi.instance.setChatPassword(
        uid: widget.uid,
        chatPassword: chatPassword,
        loginPassword: loginPassword,
      );
      final currentUser = ref.read(authProvider).userInfo;
      if (currentUser != null) {
        ref
            .read(authProvider.notifier)
            .updateCurrentUser(
              currentUser.copyWith(
                chatPwd: CryptoUtils.md5('$chatPassword${widget.uid}'),
              ),
            );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _submitFailed(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _DestroyAccountDialog extends ConsumerStatefulWidget {
  const _DestroyAccountDialog();

  @override
  ConsumerState<_DestroyAccountDialog> createState() =>
      _DestroyAccountDialogState();
}

class _DestroyAccountDialogState extends ConsumerState<_DestroyAccountDialog> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return AlertDialog(
      title: Text(strings.destroyAccountDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.destroyAccountDialogMessage),
          const SizedBox(height: WKSpace.md),
          TextField(
            key: const ValueKey<String>('account-security-destroy-code-field'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: strings.destroyAccountVerificationHint,
            ),
          ),
          const SizedBox(height: WKSpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('account-security-destroy-send-code'),
              onPressed:
                  _isSendingCode || _countdownSeconds > 0 || _isSubmitting
                  ? null
                  : _handleSendCode,
              child: Text(
                _countdownSeconds > 0
                    ? '$_countdownSeconds'
                    : (_isSendingCode
                          ? strings.destroyAccountSending
                          : strings.destroyAccountSendCode),
              ),
            ),
          ),
          if ((_errorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: WKSpace.xs),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          key: const ValueKey<String>('account-security-destroy-confirm'),
          onPressed: _isSubmitting ? null : _handleConfirm,
          child: Text(strings.destroyAccountConfirmAction),
        ),
      ],
    );
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });
    try {
      await UserApi.instance.sendDestroySmsCode();
      if (!mounted) {
        return;
      }
      _startCountdown();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _errorMessage = _strings.destroyAccountSendCodeFailed(error),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _handleConfirm() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = _strings.destroyAccountCodeRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await UserApi.instance.destroyAccount(code);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = _strings.destroyAccountFailed(error));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 59);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdownSeconds -= 1);
    });
  }
}
