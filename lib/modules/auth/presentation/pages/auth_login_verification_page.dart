import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../widgets/wk_colors.dart';
import '../../../../widgets/wk_design_tokens.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_fixed_code.dart';
import '../../domain/auth_flow_models.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthLoginVerificationPage extends ConsumerStatefulWidget {
  const AuthLoginVerificationPage({super.key});

  @override
  ConsumerState<AuthLoginVerificationPage> createState() =>
      _AuthLoginVerificationPageState();
}

class _AuthLoginVerificationPageState
    extends ConsumerState<AuthLoginVerificationPage> {
  bool _showingAlert = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);
    final verificationContext = authState.loginVerificationContext;
    final phone = verificationContext?.phone?.trim() ?? '';
    final verificationMessage = AuthCopy.loginVerificationMessage(phone);

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      unawaited(_showAlert(message));
      ref.read(authFlowControllerProvider.notifier).clearError();
    });

    return AuthPageScaffold(
      title: AuthCopy.loginVerificationTitle,
      subtitle: AuthCopy.loginVerificationSubtitle,
      leading: IconButton(
        key: const ValueKey('auth-login-verification-back'),
        onPressed: authState.isLoading
            ? null
            : () => ref
                  .read(authFlowControllerProvider.notifier)
                  .cancelLoginVerification(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: '返回',
      ),
      statusBanner: AuthStatusBanner(
        key: const ValueKey<String>('auth-status-banner'),
        message: verificationMessage,
        leadingIcon: Icons.verified_user_outlined,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: WKColors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(WKRadius.xl),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.verified_user_outlined,
              size: 64,
              color: WKColors.brand500,
            ),
            const SizedBox(height: 16),
            Text(
              verificationMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 15,
                color: WKColors.color999,
                height: 1.6,
              ),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AuthCopy.loginVerificationPhoneLabel,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 15,
                      color: WKColors.color999,
                    ),
                  ),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WKColors.colorDark,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey<String>('auth-login-verification-start'),
        label: AuthCopy.loginVerificationStartButton,
        isLoading: authState.isLoading,
        onPressed: authState.isLoading || verificationContext == null
            ? null
            : () async {
                await ref
                    .read(authFlowControllerProvider.notifier)
                    .sendLoginVerificationCode(
                      uid: verificationContext.uid,
                      prefilledCode: AuthFixedCode.enabledCode,
                    );
              },
      ),
    );
  }

  Future<void> _showAlert(String message) async {
    if (!mounted || _showingAlert) {
      return;
    }
    _showingAlert = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    _showingAlert = false;
  }
}
