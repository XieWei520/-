import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_providers.dart';
import '../../domain/auth_fixed_code.dart';
import '../../domain/auth_flow_models.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_page_scaffold.dart';

class AuthLoginVerificationCodePage extends ConsumerStatefulWidget {
  const AuthLoginVerificationCodePage({super.key});

  @override
  ConsumerState<AuthLoginVerificationCodePage> createState() =>
      _AuthLoginVerificationCodePageState();
}

class _AuthLoginVerificationCodePageState
    extends ConsumerState<AuthLoginVerificationCodePage> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _obscureCode = false;
  bool _showingAlert = false;
  AuthLoginVerificationContext? _lastAppliedPrefilledContext;

  @override
  void initState() {
    super.initState();
    final verificationContext = ref
        .read(authFlowControllerProvider)
        .loginVerificationContext;
    if (verificationContext?.step == AuthLoginVerificationStep.codeEntry) {
      _startCountdown();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applyPrefilledCode(
        ref.read(authFlowControllerProvider).loginVerificationContext,
      );
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);
    final verificationContext = authState.loginVerificationContext;
    final phone = verificationContext?.phone?.trim() ?? '';

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      _applyPrefilledCode(next.loginVerificationContext);
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      unawaited(_showAlert(message));
      ref.read(authFlowControllerProvider.notifier).clearError();
    });

    return AuthPageScaffold(
      title: AuthCopy.loginVerificationCodeTitle,
      subtitle: AuthCopy.loginVerificationCodeSubtitle(phone),
      leading: IconButton(
        key: const ValueKey('auth-login-verification-code-back'),
        onPressed: authState.isLoading || verificationContext == null
            ? null
            : () => ref
                  .read(authFlowControllerProvider.notifier)
                  .returnToLoginVerificationIntroduction(),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: '返回',
      ),
      body: AuthFormField(
        fieldKey: const ValueKey<String>('auth-login-verification-code-field'),
        controller: _codeController,
        obscureText: _obscureCode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: authState.isLoading || verificationContext == null
            ? null
            : (_) => _handleSubmit(verificationContext.uid),
        hintText: AuthCopy.loginVerificationCodeHint,
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey<String>('auth-login-verification-submit'),
        label: AuthCopy.loginVerificationSubmitButton,
        isLoading: authState.isLoading,
        onPressed: authState.isLoading || verificationContext == null
            ? null
            : () => _handleSubmit(verificationContext.uid),
      ),
      secondaryAction: AuthActionButton.secondary(
        key: const ValueKey<String>('auth-login-verification-resend'),
        label: _countdownSeconds > 0
            ? '$_countdownSeconds'
            : AuthCopy.loginVerificationResendButton,
        onPressed:
            authState.isLoading ||
                verificationContext == null ||
                _countdownSeconds > 0
            ? null
            : () => _handleSendCode(verificationContext.uid),
      ),
    );
  }

  Future<void> _handleSubmit(String uid) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      await _showAlert(AuthCopy.loginVerificationCodeRequired);
      return;
    }

    await ref
        .read(authFlowControllerProvider.notifier)
        .verifyLoginCode(uid: uid, code: code);
  }

  Future<void> _handleSendCode(String uid) async {
    final previousContext = ref
        .read(authFlowControllerProvider)
        .loginVerificationContext;
    await ref
        .read(authFlowControllerProvider.notifier)
        .sendLoginVerificationCode(
          uid: uid,
          prefilledCode: AuthFixedCode.enabledCode,
        );
    if (!mounted) {
      return;
    }
    final nextContext = ref
        .read(authFlowControllerProvider)
        .loginVerificationContext;
    final resendSucceeded =
        !identical(previousContext, nextContext) &&
        nextContext?.step == AuthLoginVerificationStep.codeEntry;
    if (resendSucceeded) {
      _startCountdown();
    }
  }

  void _applyPrefilledCode(AuthLoginVerificationContext? context) {
    final code = context?.prefilledCode?.trim() ?? '';
    if (context == null ||
        code.isEmpty ||
        identical(context, _lastAppliedPrefilledContext)) {
      return;
    }
    _lastAppliedPrefilledContext = context;
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    if (mounted) {
      setState(() => _obscureCode = true);
    }
    unawaited(_showAlert(AuthFixedCode.successMessage));
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
