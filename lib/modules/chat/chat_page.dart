import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_provider.dart';
import '../settings/account_security_page.dart';
import '../favorites/favorites_page.dart' as favorites_module;
import '../favorites/favorite_record_navigation.dart';
import '../search/presentation/message_record_search_page.dart';
import 'chat_password_runtime.dart';
import 'chat_page_shell.dart';

export 'chat_contact_picker_dialog.dart' show ContactPickerDialog;
export 'chat_page_shell.dart' show ChatPageShell, shouldUseWarmWorkbenchStyle;
export 'forward_message_page.dart' show ForwardMessagePage;

class ChatPage extends ConsumerStatefulWidget {
  final String channelId;
  final int channelType;
  final String? channelName;
  final String? channelCategory;
  final int initialVipLevel;
  final int? initialAroundOrderSeq;
  final int? initialLocateMessageSeq;

  const ChatPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.channelCategory,
    this.initialVipLevel = 0,
    this.initialAroundOrderSeq,
    this.initialLocateMessageSeq,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _guardResolved = false;
  bool _requiresPassword = false;
  bool _unlocked = false;
  bool _showingPasswordDialog = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolvePasswordGuard());
  }

  Future<void> _resolvePasswordGuard() async {
    final requiresPassword = await ref
        .read(chatPasswordRuntimeProvider)
        .requiresPassword(
          channelId: widget.channelId,
          channelType: widget.channelType,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _guardResolved = true;
      _requiresPassword = requiresPassword;
      _unlocked = !requiresPassword;
    });

    if (!requiresPassword) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_presentPasswordDialog());
      }
    });
  }

  Future<void> _presentPasswordDialog() async {
    if (_showingPasswordDialog || _unlocked || !_requiresPassword) {
      return;
    }
    _showingPasswordDialog = true;
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChatPasswordGateDialog(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
      ),
    );
    _showingPasswordDialog = false;

    if (!mounted) {
      return;
    }
    if (unlocked == true) {
      setState(() => _unlocked = true);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_guardResolved || (_requiresPassword && !_unlocked)) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
      );
    }
    return ChatPageShell(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      channelCategory: widget.channelCategory,
      initialVipLevel: widget.initialVipLevel,
      initialAroundOrderSeq: widget.initialAroundOrderSeq,
      initialLocateMessageSeq: widget.initialLocateMessageSeq,
    );
  }
}

class _ChatPasswordGateDialog extends ConsumerStatefulWidget {
  const _ChatPasswordGateDialog({
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  ConsumerState<_ChatPasswordGateDialog> createState() =>
      _ChatPasswordGateDialogState();
}

class _ChatPasswordGateDialogState
    extends ConsumerState<_ChatPasswordGateDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  String get _title => '聊天密码';

  String get _description {
    final channelName = widget.channelName?.trim();
    if (channelName != null && channelName.isNotEmpty) {
      return '请输入聊天密码以打开“$channelName”。';
    }
    return '请输入聊天密码以打开当前会话。';
  }

  String get _passwordLabel => '聊天密码';
  String get _unlockAction => '解锁';
  String get _resetAction => '重置密码';
  String get _cancelAction => '取消';
  String get _emptyPasswordError => '请输入聊天密码。';
  String get _missingPasswordError => '当前账号还没有可用的聊天密码，请先重置。';

  String _incorrectPasswordError(int remainingAttempts) {
    return '密码错误，剩余尝试次数：$remainingAttempts。';
  }

  String get _attemptsExhaustedError => '尝试次数已耗尽，当前会话本地消息已清空，请先重置密码。';

  @override
  void dispose() {
    _passwordController.dispose();
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
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey<String>('chat-password-gate-field'),
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: _passwordLabel),
            onSubmitted: (_) =>
                _isSubmitting ? null : unawaited(_handleUnlock()),
          ),
          if ((_errorMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('chat-password-gate-cancel'),
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(_cancelAction),
        ),
        TextButton(
          key: const ValueKey<String>('chat-password-gate-reset'),
          onPressed: _isSubmitting ? null : _handleResetPassword,
          child: Text(_resetAction),
        ),
        TextButton(
          key: const ValueKey<String>('chat-password-gate-confirm'),
          onPressed: _isSubmitting ? null : _handleUnlock,
          child: Text(_unlockAction),
        ),
      ],
    );
  }

  Future<void> _handleResetPassword() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountSecurityPage()));
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _handleUnlock() async {
    final user = ref.read(authProvider).userInfo;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(chatPasswordRuntimeProvider)
        .unlockChat(
          channelId: widget.channelId,
          channelType: widget.channelType,
          password: _passwordController.text,
          uid: user?.uid ?? '',
          storedChatPasswordHash: user?.chatPwd,
        );

    if (!mounted) {
      return;
    }

    if (result.unlocked) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = switch (result.failure) {
        ChatPasswordUnlockFailure.emptyPassword => _emptyPasswordError,
        ChatPasswordUnlockFailure.missingPassword => _missingPasswordError,
        ChatPasswordUnlockFailure.incorrectPassword => _incorrectPasswordError(
          result.remainingAttempts,
        ),
        ChatPasswordUnlockFailure.attemptsExhausted => _attemptsExhaustedError,
        null => _incorrectPasswordError(result.remainingAttempts),
      };
    });
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return favorites_module.FavoritesPage(
      onOpenRecord: (record) => openFavoriteRecordInContext(context, record),
    );
  }
}

@Deprecated('Use MessageRecordSearchPage for production chat-record entry.')
class ChatSearchPage extends StatelessWidget {
  final String channelId;
  final int channelType;
  final String? channelName;

  const ChatSearchPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  @override
  Widget build(BuildContext context) {
    return MessageRecordSearchPage(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }
}
