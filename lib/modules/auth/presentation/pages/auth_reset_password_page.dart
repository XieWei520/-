import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../widgets/wk_design_tokens.dart';
import '../../../../wk_foundation/logging/app_logger.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_fixed_code.dart';
import '../../domain/auth_flow_models.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_experience_tokens.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthResetPasswordPage extends ConsumerStatefulWidget {
  const AuthResetPasswordPage({super.key});

  @override
  ConsumerState<AuthResetPasswordPage> createState() =>
      _AuthResetPasswordPageState();
}

class _AuthResetPasswordPageState extends ConsumerState<AuthResetPasswordPage> {
  static const AppLogger _logger = AppLogger('auth/reset-page');

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Timer? _countdownTimer;
  bool _obscureCode = false;
  bool _obscurePassword = true;
  int _countdownSeconds = 0;
  String _zoneCode = AuthAreaCodePicker.mainlandChinaZoneCode;
  AuthLoginValidationError? _validationError;
  String? _statusMessage;
  String? _statusDetail;
  AuthStatusBannerTone _statusTone = AuthStatusBannerTone.info;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      _presentRemoteFailure(message);
    });

    return AuthPageScaffold(
      pageLabel: AuthCopy.resetPageLabel(),
      brandEyebrow: AuthCopy.resetBrandEyebrow(AppConfig.appName),
      brandTitle: AuthCopy.resetBrandTitle(AppConfig.appName),
      brandDescription: AuthCopy.resetBrandDescription,
      brandHighlights: AuthCopy.resetBrandHighlights,
      title: AuthCopy.resetPasswordTitle,
      subtitle: AuthCopy.resetPasswordSubtitle(AppConfig.appName),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      statusBanner: _buildStatusBanner(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhoneInputField(),
          const SizedBox(height: 14),
          _buildCodeInputField(isLoading: authState.isLoading),
          const SizedBox(height: 14),
          _buildPasswordInputField(isLoading: authState.isLoading),
        ],
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey<String>('auth_reset_submit_button'),
        label: AuthCopy.confirmButton,
        isLoading: authState.isLoading,
        onPressed: authState.isLoading ? null : _handleSubmit,
      ),
    );
  }

  Widget _buildStatusBanner() {
    final message = (_statusMessage ?? '').trim().isEmpty
        ? AuthCopy.resetPasswordSubtitle(AppConfig.appName)
        : _statusMessage!.trim();
    final detail = (_statusMessage ?? '').trim().isEmpty
        ? null
        : (_statusDetail ?? '').trim().isEmpty
        ? null
        : _statusDetail;
    final tone = (_statusMessage ?? '').trim().isEmpty
        ? AuthStatusBannerTone.info
        : _statusTone;
    return AuthStatusBanner(
      key: const ValueKey<String>('auth-status-banner'),
      message: message,
      detail: detail,
      tone: tone,
      leadingIcon: tone == AuthStatusBannerTone.info
          ? Icons.security_rounded
          : null,
      onDismiss: (_statusMessage ?? '').trim().isEmpty
          ? null
          : _clearPresentationFeedback,
    );
  }

  Widget _buildPhoneInputField() {
    return AuthFormField(
      fieldKey: const ValueKey('auth_reset_phone_field'),
      errorKey: const ValueKey('auth_reset_phone_error'),
      controller: _phoneController,
      enabled: _countdownSeconds <= 0,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.phoneHint,
      errorText: _phoneErrorText,
      onChanged: (_) => _handleFieldEdited(),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthAreaCodePicker(
            selectedZoneCode: _zoneCode,
            onChanged: (option) {
              setState(() => _zoneCode = option.normalizedZoneCode);
            },
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AuthExperienceTokens.fieldBorder),
        ],
      ),
    );
  }

  Widget _buildCodeInputField({required bool isLoading}) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_reset_code_field'),
      errorKey: const ValueKey('auth_reset_code_error'),
      controller: _codeController,
      obscureText: _obscureCode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.codeHint,
      errorText: _codeErrorText,
      onChanged: (_) => _handleFieldEdited(),
      trailing: AuthActionButton.secondary(
        key: const ValueKey<String>('auth-reset-send-code-action'),
        label: _countdownSeconds > 0
            ? '$_countdownSeconds'
            : AuthCopy.getCodeButton,
        height: 36,
        fullWidth: false,
        onPressed: isLoading || _countdownSeconds > 0 ? null : _handleSendCode,
      ),
    );
  }

  Widget _buildPasswordInputField({required bool isLoading}) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_reset_password_field'),
      errorKey: const ValueKey('auth_reset_password_error'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onChanged: (_) => _handleFieldEdited(),
      onSubmitted: isLoading ? null : (_) => _handleSubmit(),
      hintText: AuthCopy.passwordHint,
      errorText: _passwordErrorText,
      trailing: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(WKRadius.pill),
          onTap: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: Icon(Icons.remove_red_eye_outlined, size: 20),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    _logger.info(
      'tap getCode phone=${_maskPhone(phone)} zone=$_zoneCode fixedEnabled=${AuthFixedCode.isEnabled}',
    );
    final validationError = _validatePhone(phone);
    if (validationError != null) {
      _logger.info('getCode validation blocked error=$validationError');
      _presentValidation(validationError);
      return;
    }

    if (AuthFixedCode.isEnabled) {
      _logger.info('getCode using fixed code');
      _applyFixedCode();
      _startCountdown();
      setState(() {
        _validationError = null;
        _statusTone = AuthStatusBannerTone.success;
        _statusMessage = AuthCopy.fixedCodeSuccessSummary;
        _statusDetail = AuthCopy.fixedCodeSuccessDetail;
      });
      return;
    }

    await ref
        .read(authFlowControllerProvider.notifier)
        .sendResetPasswordCode(zone: _zoneCode, phone: phone);
    if (!mounted) {
      return;
    }
    if (ref.read(authFlowControllerProvider).stage !=
        AuthStage.awaitingPasswordResetCode) {
      return;
    }
    _startCountdown();
  }

  void _applyFixedCode() {
    final code = AuthFixedCode.enabledCode ?? '';
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _obscureCode = true);
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

  Future<void> _handleSubmit() async {
    if (ref.read(authFlowControllerProvider).isLoading) {
      _logger.info('submit ignored because loading');
      return;
    }

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final validationError = _validateForReset(
      phone: phone,
      code: code,
      password: password,
    );
    if (validationError != null) {
      _logger.info('submit validation blocked error=$validationError');
      _presentValidation(validationError);
      return;
    }

    _logger.info(
      'submit reset phone=${_maskPhone(phone)} codeLength=${code.length} passwordLength=${password.length}',
    );
    _clearPresentationFeedback();
    setState(() {
      _statusTone = AuthStatusBannerTone.info;
      _statusMessage = '正在更新密码';
      _statusDetail = null;
    });

    await ref
        .read(authFlowControllerProvider.notifier)
        .resetPassword(
          zone: _zoneCode,
          phone: phone,
          code: code,
          newPassword: password,
        );
    if (!mounted) {
      return;
    }
    _logger.info(
      'submit reset finished stage=${ref.read(authFlowControllerProvider).stage}',
    );
    if (ref.read(authFlowControllerProvider).stage !=
        AuthStage.unauthenticated) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  AuthLoginValidationError? _validatePhone(String phone) {
    if (phone.isEmpty) {
      return AuthLoginValidationError.phoneRequired;
    }
    if (_zoneCode == AuthAreaCodePicker.mainlandChinaZoneCode &&
        phone.length != 11) {
      return AuthLoginValidationError.phoneLengthCn;
    }
    return null;
  }

  AuthLoginValidationError? _validateForReset({
    required String phone,
    required String code,
    required String password,
  }) {
    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      return phoneError;
    }
    if (code.isEmpty) {
      return AuthLoginValidationError.codeRequired;
    }
    if (password.isEmpty) {
      return AuthLoginValidationError.passwordRequired;
    }
    if (password.length < 6 || password.length > 16) {
      return AuthLoginValidationError.passwordLength;
    }
    return null;
  }

  void _presentValidation(AuthLoginValidationError error) {
    setState(() {
      _validationError = error;
      _statusTone = AuthStatusBannerTone.error;
      _statusMessage = AuthCopy.validationSummary;
      _statusDetail = AuthCopy.validationMessage(error);
    });
  }

  void _presentRemoteFailure(String rawMessage) {
    setState(() {
      _validationError = null;
      _statusTone = AuthStatusBannerTone.error;
      _statusMessage = AuthCopy.humanizeFailureSummary(rawMessage);
      _statusDetail = AuthCopy.humanizeFailureDetail(rawMessage);
    });
  }

  void _clearPresentationFeedback() {
    final notifier = ref.read(authFlowControllerProvider.notifier);
    notifier.clearError();
    if (!mounted) {
      return;
    }
    setState(() {
      _validationError = null;
      _statusMessage = null;
      _statusDetail = null;
    });
  }

  void _handleFieldEdited() {
    if (_validationError == null) {
      return;
    }
    setState(() => _validationError = null);
  }

  String? get _phoneErrorText {
    switch (_validationError) {
      case AuthLoginValidationError.phoneRequired:
      case AuthLoginValidationError.phoneLengthCn:
        return AuthCopy.validationMessage(_validationError!);
      default:
        return null;
    }
  }

  String? get _codeErrorText {
    if (_validationError == AuthLoginValidationError.codeRequired) {
      return AuthCopy.validationMessage(_validationError!);
    }
    return null;
  }

  String? get _passwordErrorText {
    switch (_validationError) {
      case AuthLoginValidationError.passwordRequired:
      case AuthLoginValidationError.passwordLength:
        return AuthCopy.validationMessage(_validationError!);
      default:
        return null;
    }
  }

  static String _maskPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.length <= 4) {
      return trimmed;
    }
    return '${trimmed.substring(0, 3)}***${trimmed.substring(trimmed.length - 2)}';
  }
}
