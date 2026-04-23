import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/navigation/app_route_location.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/config/app_config.dart';
import '../../../../data/providers/runtime_capabilities_provider.dart';
import '../../../../widgets/wk_design_tokens.dart';
import '../../../../widgets/wk_reference_assets.dart';
import '../../../../wk_foundation/logging/app_logger.dart';
import '../../../conversation/main_page.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_fixed_code.dart';
import '../../domain/auth_flow_models.dart';
import 'auth_login_page.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_agreement_block.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_experience_tokens.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthRegisterPage extends ConsumerStatefulWidget {
  const AuthRegisterPage({super.key});

  @override
  ConsumerState<AuthRegisterPage> createState() => _AuthRegisterPageState();
}

class _AuthRegisterPageState extends ConsumerState<AuthRegisterPage> {
  static const AppLogger _logger = AppLogger('auth/register-page');

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  Timer? _countdownTimer;
  bool _agreedToTerms = false;
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
    _nicknameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);
    final capabilitiesAsync = ref.watch(runtimeCapabilitiesProvider);
    final capabilities = capabilitiesAsync.valueOrNull;
    final showInvite = capabilities?.registerInviteEnabled ?? false;
    final inviteRequired = capabilities?.registerInviteRequired ?? false;
    final canSubmitRegister =
        _phoneController.text.trim().isNotEmpty &&
        _codeController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    final canSendCode =
        _phoneController.text.trim().isNotEmpty && _countdownSeconds <= 0;

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      _presentRemoteFailure(message);
    });

    return AuthPageScaffold(
      pageLabel: AuthCopy.registerPageLabel(),
      brandEyebrow: AuthCopy.registerBrandEyebrow(AppConfig.appName),
      brandTitle: AuthCopy.registerBrandTitle(AppConfig.appName),
      brandDescription: AuthCopy.registerBrandDescription,
      brandHighlights: AuthCopy.registerBrandHighlights,
      title: AuthCopy.registerTitle(AppConfig.appName),
      subtitle: AuthCopy.registerSubtitle(AppConfig.appName),
      statusBanner: _buildStatusBanner(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhoneInputField(),
          const SizedBox(height: 10),
          _buildNicknameInputField(),
          const SizedBox(height: 10),
          _buildCodeInputField(
            isLoading: authState.isLoading,
            canSendCode: canSendCode,
          ),
          const SizedBox(height: 10),
          _buildPasswordInputField(
            isLoading: authState.isLoading,
            inviteRequired: inviteRequired,
          ),
          if (showInvite) ...[
            const SizedBox(height: 10),
            _buildInviteCodeInputField(inviteRequired: inviteRequired),
          ],
          const SizedBox(height: 10),
          _buildAgreementSection(),
        ],
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey<String>('auth-register-primary-action'),
        label: AuthCopy.registerButton,
        height: 46,
        isLoading: authState.isLoading,
        onPressed: authState.isLoading || !canSubmitRegister
            ? null
            : () => _handleSubmit(inviteRequired: inviteRequired),
      ),
      secondaryAction: AuthActionButton.secondary(
        key: const ValueKey<String>('auth-register-secondary-action'),
        label: AuthCopy.loginButton,
        height: 42,
        onPressed: _handleBackToLogin,
      ),
    );
  }

  Widget? _buildStatusBanner() {
    final summary = (_statusMessage ?? '').trim();
    if (summary.isEmpty) {
      return null;
    }
    return AuthStatusBanner(
      key: const ValueKey<String>('auth-status-banner'),
      message: summary,
      detail: (_statusDetail ?? '').trim().isEmpty ? null : _statusDetail,
      tone: _statusTone,
      onDismiss: _clearPresentationFeedback,
    );
  }

  Widget _buildPhoneInputField() {
    return AuthFormField(
      fieldKey: const ValueKey('auth_register_phone_field'),
      errorKey: const ValueKey('auth_register_phone_error'),
      controller: _phoneController,
      enabled: _countdownSeconds <= 0,
      onChanged: (_) {
        setState(() {});
        _handleFieldEdited();
      },
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.phoneHint,
      minHeight: 48,
      errorText: _phoneErrorText,
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

  Widget _buildCodeInputField({
    required bool isLoading,
    required bool canSendCode,
  }) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_register_code_field'),
      errorKey: const ValueKey('auth_register_code_error'),
      controller: _codeController,
      obscureText: _obscureCode,
      onChanged: (_) {
        setState(() {});
        _handleFieldEdited();
      },
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.codeHint,
      minHeight: 48,
      errorText: _codeErrorText,
      trailing: _buildSendCodeAction(
        isLoading: isLoading,
        canSendCode: canSendCode,
      ),
    );
  }

  Widget _buildNicknameInputField() {
    return AuthFormField(
      fieldKey: const ValueKey('auth_register_nickname_field'),
      controller: _nicknameController,
      onChanged: (_) => _handleFieldEdited(),
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.registerNicknameHint,
      helperText: AuthCopy.registerNicknameHelper,
      minHeight: 48,
    );
  }

  Widget _buildSendCodeAction({
    required bool isLoading,
    required bool canSendCode,
  }) {
    final enabled = !isLoading && canSendCode;
    return AuthActionButton.secondary(
      key: const ValueKey<String>('auth-register-send-code-action'),
      label: _countdownSeconds > 0
          ? '$_countdownSeconds'
          : AuthCopy.getCodeButton,
      height: 34,
      fullWidth: false,
      onPressed: enabled ? _handleSendCode : null,
    );
  }

  Widget _buildPasswordInputField({
    required bool isLoading,
    required bool inviteRequired,
  }) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_register_password_field'),
      errorKey: const ValueKey('auth_register_password_error'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (_) {
        setState(() {});
        _handleFieldEdited();
      },
      textInputAction: TextInputAction.done,
      onSubmitted: isLoading
          ? null
          : (_) => _handleSubmit(inviteRequired: inviteRequired),
      hintText: AuthCopy.passwordHint,
      minHeight: 48,
      errorText: _passwordErrorText,
      trailing: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(WKRadius.pill),
          onTap: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: WKReferenceAssets.image(
              _obscurePassword
                  ? WKReferenceAssets.passwordInvisible
                  : WKReferenceAssets.passwordVisible,
              width: 20,
              height: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCodeInputField({required bool inviteRequired}) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_register_invite_field'),
      errorKey: const ValueKey('auth_register_invite_error'),
      controller: _inviteCodeController,
      onChanged: (_) => _handleFieldEdited(),
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.inviteCodeHint(required: inviteRequired),
      minHeight: 48,
      errorText: _inviteErrorText,
    );
  }

  Widget _buildAgreementSection() {
    final agreementError = _agreementErrorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthAgreementBlock(
          toggleKey: const ValueKey<String>('auth_login_terms_toggle'),
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() => _agreedToTerms = value);
            _handleFieldEdited();
          },
          prefixText: AuthCopy.agreementPrefix,
          links: [
            AuthAgreementLink(
              label: AuthCopy.privacyPolicy,
              onTap: () {
                _openAgreementPage(
                  path: 'privacy_policy.html',
                  errorText: AuthCopy.openPrivacyFailed,
                );
              },
            ),
            AuthAgreementLink(
              label: AuthCopy.userAgreement,
              onTap: () {
                _openAgreementPage(
                  path: 'user_agreement.html',
                  errorText: AuthCopy.openAgreementFailed,
                );
              },
            ),
          ],
        ),
        if (agreementError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              agreementError,
              key: const ValueKey('auth_register_agreement_error'),
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 12,
                color: AuthExperienceTokens.errorText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleSendCode() async {
    final phone = _phoneController.text.trim();
    _logger.info(
      'tap getCode phone=${_maskPhone(phone)} zone=$_zoneCode fixedEnabled=${AuthFixedCode.isEnabled}',
    );
    final validationError = _validateForCode(phone: phone);
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
        .sendRegisterCode(zone: _zoneCode, phone: phone);
    if (!mounted) {
      return;
    }
    if (ref.read(authFlowControllerProvider).stage !=
        AuthStage.unauthenticated) {
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

  Future<void> _handleSubmit({bool inviteRequired = false}) async {
    if (ref.read(authFlowControllerProvider).isLoading) {
      _logger.info('submit ignored because loading');
      return;
    }

    final phone = _phoneController.text.trim();
    final displayName = _nicknameController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final inviteCode = _inviteCodeController.text.trim();

    final validationError = _validateForRegister(
      phone: phone,
      code: code,
      password: password,
      inviteCode: inviteCode,
      inviteRequired: inviteRequired,
    );
    if (validationError != null) {
      _logger.info('submit validation blocked error=$validationError');
      _presentValidation(validationError);
      return;
    }

    _logger.info(
      'submit register phone=${_maskPhone(phone)} codeLength=${code.length} passwordLength=${password.length} agreed=$_agreedToTerms inviteProvided=${inviteCode.isNotEmpty} displayNameProvided=${displayName.isNotEmpty}',
    );
    _clearPresentationFeedback();
    setState(() {
      _statusTone = AuthStatusBannerTone.info;
      _statusMessage = '正在创建账号';
      _statusDetail = null;
    });

    await ref
        .read(authFlowControllerProvider.notifier)
        .registerWithPhone(
          zone: _zoneCode,
          phone: phone,
          code: code,
          password: password,
          inviteCode: inviteCode.isEmpty ? null : inviteCode,
          displayName: displayName.isEmpty ? null : displayName,
        );

    if (!mounted) {
      return;
    }

    final stage = ref.read(authFlowControllerProvider).stage;
    _logger.info('submit register finished stage=$stage');
    if (stage != AuthStage.authenticatedReady) {
      return;
    }

    FocusScope.of(context).unfocus();
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null) {
      goRouter.go(AppRouteLocation.home);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  AuthLoginValidationError? _validateForCode({required String phone}) {
    if (phone.isEmpty) {
      return AuthLoginValidationError.phoneRequired;
    }
    if (_zoneCode == AuthAreaCodePicker.mainlandChinaZoneCode &&
        phone.length != 11) {
      return AuthLoginValidationError.phoneLengthCn;
    }
    return null;
  }

  AuthLoginValidationError? _validateForRegister({
    required String phone,
    required String code,
    required String password,
    required String inviteCode,
    required bool inviteRequired,
  }) {
    if (phone.isEmpty) {
      return AuthLoginValidationError.phoneRequired;
    }
    if (code.isEmpty) {
      return AuthLoginValidationError.codeRequired;
    }
    if (password.isEmpty) {
      return AuthLoginValidationError.passwordRequired;
    }
    if (_zoneCode == AuthAreaCodePicker.mainlandChinaZoneCode &&
        phone.length != 11) {
      return AuthLoginValidationError.phoneLengthCn;
    }
    if (!_agreedToTerms) {
      return AuthLoginValidationError.agreementRequired;
    }
    if (password.length < 6 || password.length > 16) {
      return AuthLoginValidationError.passwordLength;
    }
    if (inviteRequired && inviteCode.isEmpty) {
      return AuthLoginValidationError.inviteRequired;
    }
    return null;
  }

  void _handleBackToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null) {
      goRouter.go(AppRouteLocation.login);
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthLoginPage()),
    );
  }

  Future<void> _openAgreementPage({
    required String path,
    required String errorText,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/web/$path');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    setState(() {
      _statusTone = AuthStatusBannerTone.error;
      _statusMessage = errorText;
      _statusDetail = null;
    });
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

  String? get _inviteErrorText {
    if (_validationError == AuthLoginValidationError.inviteRequired) {
      return AuthCopy.validationMessage(_validationError!);
    }
    return null;
  }

  String? get _agreementErrorText {
    if (_validationError == AuthLoginValidationError.agreementRequired) {
      return AuthCopy.validationMessage(_validationError!);
    }
    return null;
  }

  static String _maskPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.length <= 4) {
      return trimmed;
    }
    return '${trimmed.substring(0, 3)}***${trimmed.substring(trimmed.length - 2)}';
  }
}
