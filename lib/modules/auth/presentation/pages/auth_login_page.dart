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
import '../../../../widgets/wk_sub_page_scaffold.dart';
import '../../../../wk_foundation/logging/app_logger.dart';
import '../../../../wk_foundation/net/wk_http_client.dart';
import '../../../../wukong_push/notification/web_notification_manager.dart';
import '../../../conversation/main_page.dart';
import '../../application/auth_providers.dart';
import '../../data/shared_prefs_auth_login_preferences_store.dart';
import '../../domain/auth_flow_models.dart';
import '../../domain/auth_login_preferences.dart';
import '../../domain/auth_login_preferences_store.dart';
import '../../register_page.dart';
import 'auth_reset_password_page.dart';
import '../widgets/auth_action_button.dart';
import '../widgets/auth_agreement_block.dart';
import '../widgets/auth_area_code_picker.dart';
import '../widgets/auth_copy.dart';
import '../widgets/auth_experience_tokens.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  static const AppLogger _logger = AppLogger('auth/login-page');
  static const String _icpFilingNumber = '\u6e58ICP\u59072026016828\u53f7';
  static final Uri _icpFilingUri = Uri.parse('https://beian.miit.gov.cn/');

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _rememberPassword = false;
  bool _autoLogin = false;
  String _zoneCode = AuthAreaCodePicker.mainlandChinaZoneCode;
  AuthLoginValidationError? _validationError;
  String? _statusMessage;
  String? _statusDetail;
  AuthStatusBannerTone _statusTone = AuthStatusBannerTone.info;
  bool _autoLoginAttemptScheduled = false;
  bool _autoLoginAttempted = false;
  bool _didUserEditPreferences = false;
  String _customApiBaseUrl = '';
  final AuthApiBaseUrlPreferencesStore _apiBaseUrlStore =
      AuthApiBaseUrlPreferencesStore();

  AuthLoginPreferencesStore get _preferencesStore =>
      ref.read(authLoginPreferencesStoreProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSavedPreferences());
    unawaited(_restoreCustomApiBaseUrl());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowControllerProvider);
    final runtimeCapabilities = ref.watch(runtimeCapabilitiesProvider);
    final stageTitle = AuthCopy.loginTitle(AppConfig.appName);
    final canModifyApiUrl = runtimeCapabilities.maybeWhen(
      data: (value) => value.canModifyApiUrl,
      orElse: () => false,
    );

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final message = next.errorMessage?.trim() ?? '';
      final previousMessage = previous?.errorMessage?.trim() ?? '';
      if (message.isEmpty || message == previousMessage) {
        return;
      }
      _presentRemoteFailure(message);
    });

    return AuthPageScaffold(
      backgroundKey: const ValueKey<String>('wk_login_background'),
      pageLabel: AuthCopy.loginPageLabel(),
      brandEyebrow: AuthCopy.loginBrandEyebrow(AppConfig.appName),
      brandTitle: AuthCopy.loginBrandTitle(AppConfig.appName),
      brandDescription: AuthCopy.loginBrandDescription,
      brandHighlights: AuthCopy.loginBrandHighlights,
      title: stageTitle,
      subtitle: AuthCopy.loginSubtitle(AppConfig.appName),
      statusBanner: _buildStatusBanner(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            key: const ValueKey<String>('auth-stage-title'),
            label: stageTitle,
            child: const SizedBox.shrink(),
          ),
          _buildPhoneInputField(),
          const SizedBox(height: 14),
          _buildPasswordInputField(isLoading: authState.isLoading),
          const SizedBox(height: 8),
          _buildPreferenceControls(),
          const SizedBox(height: 8),
          _buildAgreementSection(),
        ],
      ),
      primaryAction: AuthActionButton(
        key: const ValueKey<String>('auth-login-primary-action'),
        label: AuthCopy.loginButton,
        isLoading: authState.isLoading,
        onPressed: authState.isLoading ? null : _handleSubmit,
      ),
      secondaryAction: _buildSecondaryActionSection(
        canModifyApiUrl: canModifyApiUrl,
      ),
      footer: _buildIcpFooter(),
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
      fieldKey: const ValueKey('auth_login_phone_field'),
      errorKey: const ValueKey('auth_login_phone_error'),
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      hintText: AuthCopy.phoneHint,
      errorText: _phoneErrorText,
      onChanged: (_) {
        _markPreferencesEdited();
        _handleFieldEdited(persistPreferences: true);
      },
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthAreaCodePicker(
            selectedZoneCode: _zoneCode,
            onChanged: (option) {
              _markPreferencesEdited();
              setState(() => _zoneCode = option.normalizedZoneCode);
              unawaited(_persistLoginPreferences());
            },
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 20,
            color: AuthExperienceTokens.fieldBorder,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInputField({required bool isLoading}) {
    return AuthFormField(
      fieldKey: const ValueKey('auth_login_password_field'),
      errorKey: const ValueKey('auth_login_password_error'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onChanged: (_) {
        _markPreferencesEdited();
        _handleFieldEdited(persistPreferences: true);
      },
      onSubmitted: isLoading ? null : (_) => _handleSubmit(),
      hintText: AuthCopy.passwordHint,
      errorText: _passwordErrorText,
      trailing: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('auth_login_password_visibility_toggle'),
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

  Widget _buildPreferenceControls() {
    return Row(
      children: [
        Expanded(
          child: _buildPreferenceRow(
            label: AuthCopy.rememberPasswordToggle,
            switchKey: const ValueKey<String>(
              'auth_login_remember_password_switch',
            ),
            value: _rememberPassword,
            onChanged: (value) {
              _markPreferencesEdited();
              setState(() {
                _rememberPassword = value;
                if (!value) {
                  _autoLogin = false;
                }
              });
              unawaited(_persistLoginPreferences());
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPreferenceRow(
            label: AuthCopy.autoLoginToggle,
            switchKey: const ValueKey<String>('auth_login_auto_login_switch'),
            value: _autoLogin,
            onChanged: (value) {
              _markPreferencesEdited();
              setState(() {
                _autoLogin = value;
                if (value) {
                  _rememberPassword = true;
                }
              });
              unawaited(_persistLoginPreferences());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceRow({
    required String label,
    required ValueKey<String> switchKey,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 13,
              color: AuthExperienceTokens.brandMuted,
            ),
          ),
        ),
        WKAndroidSwitch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildAgreementSection() {
    final agreementError = _agreementErrorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const ValueKey<String>('wk_login_terms_toggle'),
          child: AuthAgreementBlock(
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
        ),
        if (agreementError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              agreementError,
              key: const ValueKey('auth_login_agreement_error'),
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

  Widget _buildSecondaryActionSection({required bool canModifyApiUrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
              },
              child: const Text(AuthCopy.registerEntry),
            ),
            Container(
              width: 1,
              height: 16,
              color: AuthExperienceTokens.fieldBorder.withValues(alpha: 0.65),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AuthResetPasswordPage(),
                  ),
                );
              },
              child: const Text(AuthCopy.forgotPasswordEntry),
            ),
          ],
        ),
        if (canModifyApiUrl) ...[
          const SizedBox(height: 8),
          _buildApiBaseUrlSurface(),
        ],
      ],
    );
  }

  Widget _buildIcpFooter() {
    return Center(
      child: TextButton(
        key: const ValueKey<String>('auth_login_icp_link'),
        onPressed: () => unawaited(_openIcpFilingPage()),
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AuthExperienceTokens.brandMuted,
          textStyle: const TextStyle(
            fontFamily: WKFontFamily.chinese,
            fontFamilyFallback: WKTypography.nativeFontFamilyFallback,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: const Text(_icpFilingNumber),
      ),
    );
  }

  Widget _buildApiBaseUrlSurface() {
    final hasCustomBaseUrl = _customApiBaseUrl.isNotEmpty;
    final displayValue = hasCustomBaseUrl ? _customApiBaseUrl : '修改服务器地址';

    return Wrap(
      key: const ValueKey<String>('auth_login_base_url_surface'),
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          key: const ValueKey<String>('auth_login_base_url_edit'),
          onPressed: _showApiBaseUrlEditDialog,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              displayValue,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        if (hasCustomBaseUrl)
          TextButton(
            key: const ValueKey<String>('auth_login_base_url_reset'),
            onPressed: _resetCustomApiBaseUrl,
            child: const Text('重置'),
          ),
      ],
    );
  }

  Future<void> _handleSubmit({bool triggeredByAutoLogin = false}) async {
    if (ref.read(authFlowControllerProvider).isLoading) {
      _logger.info('submit ignored because loading');
      return;
    }

    if (!triggeredByAutoLogin) {
      // 必须在用户点击“登录”这一类手势中触发，才能最大概率解锁 Web
      // 音频自动播放限制，并让浏览器接受 Notification 权限请求。
      unawaited(WebNotificationManager.instance.init());
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final validationError = _validate(
      phone: phone,
      password: password,
      requireAgreement: !triggeredByAutoLogin,
    );
    if (validationError != null) {
      if (triggeredByAutoLogin && _autoLogin) {
        await _disablePersistedAutoLogin();
      }
      _logger.info('submit validation blocked error=$validationError');
      _presentValidation(validationError);
      return;
    }

    _logger.info(
      'submit login phone=${_maskPhone(phone)} zone=$_zoneCode passwordLength=${password.length} agreed=$_agreedToTerms',
    );
    _clearPresentationFeedback();
    setState(() {
      _statusTone = AuthStatusBannerTone.info;
      _statusMessage = '正在验证登录信息';
      _statusDetail = null;
    });

    final persistPreferencesFuture = _persistLoginPreferences();
    unawaited(persistPreferencesFuture);
    await ref
        .read(authFlowControllerProvider.notifier)
        .loginWithPhone(zone: _zoneCode, phone: phone, password: password);

    if (!mounted) {
      return;
    }

    final stage = ref.read(authFlowControllerProvider).stage;
    _logger.info('submit login finished stage=$stage');
    if (stage != AuthStage.authenticatedReady) {
      if (triggeredByAutoLogin &&
          _autoLogin &&
          stage == AuthStage.unauthenticated) {
        try {
          await persistPreferencesFuture;
        } catch (_) {}
        await _disablePersistedAutoLogin();
      }
      return;
    }

    _navigateToHome();
  }

  void _navigateToHome() {
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

  Future<void> _restoreSavedPreferences() async {
    final restored = await _preferencesStore.load();
    if (!mounted || _didUserEditPreferences) {
      return;
    }
    _phoneController.text = restored.phone;
    _passwordController.text = restored.password;
    setState(() {
      _zoneCode = restored.zoneCode;
      _rememberPassword = restored.rememberPassword;
      _autoLogin = restored.autoLogin;
    });
    _scheduleAutoLoginIfNeeded(restored);
  }

  Future<void> _restoreCustomApiBaseUrl() async {
    final customBaseUrl = await _apiBaseUrlStore.load();
    if (!mounted) {
      return;
    }
    setState(() => _customApiBaseUrl = customBaseUrl);
  }

  Future<void> _showApiBaseUrlEditDialog() async {
    final controller = TextEditingController(text: _customApiBaseUrl);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('修改服务器地址'),
          content: TextField(
            key: const ValueKey<String>('auth_login_base_url_input'),
            controller: controller,
            decoration: const InputDecoration(hintText: 'http://example.com'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              key: const ValueKey<String>('auth_login_base_url_confirm'),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(_normalizeCustomApiBaseUrl(controller.text));
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (updated == null || !mounted) {
      return;
    }
    await _apiBaseUrlStore.save(updated);
    WkHttpClient.instance.syncBaseUrlWithConfig();
    if (!mounted) {
      return;
    }
    setState(() => _customApiBaseUrl = updated);
  }

  Future<void> _resetCustomApiBaseUrl() async {
    await _apiBaseUrlStore.save('');
    WkHttpClient.instance.syncBaseUrlWithConfig();
    if (!mounted) {
      return;
    }
    setState(() => _customApiBaseUrl = '');
  }

  void _scheduleAutoLoginIfNeeded(AuthLoginPreferences restored) {
    if (_autoLoginAttemptScheduled || !restored.autoLogin) {
      return;
    }
    if (!restored.hasUsableCredentials) {
      return;
    }
    _autoLoginAttemptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_attemptAutoLoginOnce());
    });
  }

  Future<void> _attemptAutoLoginOnce() async {
    if (!mounted || _autoLoginAttempted) {
      return;
    }
    _autoLoginAttempted = true;
    if (ref.read(authFlowControllerProvider).isLoading) {
      return;
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (!_autoLogin || phone.isEmpty || password.isEmpty) {
      return;
    }
    await _handleSubmit(triggeredByAutoLogin: true);
  }

  Future<void> _persistLoginPreferences() async {
    final preferences = AuthLoginPreferences(
      zoneCode: _zoneCode,
      phone: _phoneController.text.trim(),
      password: _rememberPassword ? _passwordController.text : '',
      rememberPassword: _rememberPassword,
      autoLogin: _autoLogin,
    );
    await _preferencesStore.save(preferences);
  }

  Future<void> _disablePersistedAutoLogin() async {
    await _preferencesStore.disableAutoLogin();
    if (!mounted) {
      return;
    }
    setState(() => _autoLogin = false);
  }

  void _markPreferencesEdited() {
    _didUserEditPreferences = true;
  }

  AuthLoginValidationError? _validate({
    required String phone,
    required String password,
    bool requireAgreement = true,
  }) {
    if (phone.isEmpty) {
      return AuthLoginValidationError.phoneRequired;
    }
    if (password.isEmpty) {
      return AuthLoginValidationError.passwordRequired;
    }
    if (_zoneCode == AuthAreaCodePicker.mainlandChinaZoneCode &&
        phone.length != 11) {
      return AuthLoginValidationError.phoneLengthCn;
    }
    if (requireAgreement && !_agreedToTerms) {
      return AuthLoginValidationError.agreementRequired;
    }
    if (password.length < 6 || password.length > 16) {
      return AuthLoginValidationError.passwordLength;
    }
    return null;
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

  Future<void> _openIcpFilingPage() async {
    final opened = await launchUrl(
      _icpFilingUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) {
      return;
    }
    setState(() {
      _statusTone = AuthStatusBannerTone.error;
      _statusMessage =
          '\u65e0\u6cd5\u6253\u5f00\u5907\u6848\u67e5\u8be2\u9875\u9762';
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

  void _handleFieldEdited({bool persistPreferences = false}) {
    if (persistPreferences) {
      unawaited(_persistLoginPreferences());
    }
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

  String? get _passwordErrorText {
    switch (_validationError) {
      case AuthLoginValidationError.passwordRequired:
      case AuthLoginValidationError.passwordLength:
        return AuthCopy.validationMessage(_validationError!);
      default:
        return null;
    }
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

  static String _normalizeCustomApiBaseUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }
    return 'http://$value';
  }
}
