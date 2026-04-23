import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthWebLoginConfirmPage extends ConsumerStatefulWidget {
  const AuthWebLoginConfirmPage({
    super.key,
    required this.authCode,
    this.encrypt,
  });

  final String authCode;
  final String? encrypt;

  @override
  ConsumerState<AuthWebLoginConfirmPage> createState() =>
      _AuthWebLoginConfirmPageState();
}

class _AuthWebLoginConfirmPageState
    extends ConsumerState<AuthWebLoginConfirmPage> {
  bool _isSubmitting = false;

  Future<void> _confirmLogin() async {
    if (_isSubmitting || widget.authCode.trim().isEmpty) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .grantWebLogin(authCode: widget.authCode, encrypt: widget.encrypt);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web 登录已确认')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedCode = widget.authCode.trim();
    final canSubmit = !_isSubmitting && normalizedCode.isNotEmpty;
    final webLoginDescription = '请确认本次 ${AppConfig.appName} Web/PC 登录由你本人发起。';

    return AuthPageScaffold(
      title: '确认 Web 登录',
      subtitle: '检测到来自 PC/Web 的登录授权请求',
      statusBanner: normalizedCode.isEmpty
          ? const AuthStatusBanner(
              key: ValueKey<String>('auth-status-banner'),
              message: '未找到有效的 Web 登录授权码',
              tone: AuthStatusBannerTone.warning,
              leadingIcon: Icons.warning_amber_rounded,
            )
          : null,
      body: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Icon(Icons.language_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              webLoginDescription,
              key: const ValueKey<String>('auth-web-login-description'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            SelectableText(
              widget.authCode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey('auth-web-login-confirm'),
        label: '确认登录',
        isLoading: _isSubmitting,
        onPressed: canSubmit ? _confirmLogin : null,
      ),
      secondaryAction: AuthActionButton.secondary(
        key: const ValueKey('auth-web-login-cancel'),
        label: '取消',
        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
      ),
    );
  }
}
