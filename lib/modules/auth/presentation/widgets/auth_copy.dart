enum AuthLoginValidationError {
  phoneRequired,
  codeRequired,
  passwordRequired,
  phoneLengthCn,
  agreementRequired,
  passwordLength,
  inviteRequired,
}

class AuthCopy {
  AuthCopy._();

  static const String authDisplayName = '信息平权';

  static const String loginButton = '登录';
  static const String registerEntry = '注册';
  static const String registerButton = '注册';
  static const String forgotPasswordEntry = '忘记密码';
  static const String rememberPasswordToggle = '记住密码';
  static const String autoLoginToggle = '自动登录';
  static const String resetPasswordTitle = '验证您的手机号';
  static const String phoneHint = '请输入手机号';
  static const String codeHint = '请输入验证码';
  static const String passwordHint = '请输入密码';
  static const String getCodeButton = '获取验证码';
  static const String confirmButton = '确定';
  static const String agreementPrefix = '我已阅读并同意';
  static const String privacyPolicy = '《隐私政策》';
  static const String userAgreement = '《用户协议》';
  static const String areaCodePickerTitle = '选择国家或地区';
  static const String openPrivacyFailed = '无法打开隐私政策页面';
  static const String openAgreementFailed = '无法打开用户协议页面';
  static const String forgotPasswordPending = '找回密码功能即将上线';
  static const String accountAlreadyExists = '该账号已存在';

  static String loginTitle(String appName) => '欢迎登录';

  static String registerTitle(String appName) => '创建账号';

  static String loginSubtitle(String appName) => '使用手机号和密码进入$authDisplayName';

  static String registerSubtitle(String appName) => '用手机号创建$authDisplayName账号';

  static String resetPasswordSubtitle(String appName) =>
      '通过短信验证码恢复$appName访问权限';

  static String inviteCodeHint({required bool required}) =>
      required ? '请输入邀请码（必填）' : '请输入邀请码（选填）';

  static const String loginVerificationTitle = '登录验证';
  static const String loginVerificationSubtitle = '为保障账号安全，请先完成验证码验证。';
  static const String loginVerificationPhoneLabel = '手机号：';
  static const String loginVerificationStartButton = '开始验证';
  static const String loginVerificationCodeTitle = '输入验证码';
  static const String loginVerificationCodeHint = '请输入验证码';
  static const String loginVerificationResendButton = '重新发送验证码';
  static const String loginVerificationSubmitButton = '提交验证';
  static const String loginVerificationCodeRequired = '请输入验证码';

  static String loginVerificationMessage(String phone) {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return '为保障账号安全，请先完成验证码验证。';
    }
    return '为保障账号安全，请先完成发送至 $normalizedPhone 的验证码验证。';
  }

  static String loginVerificationCodeSubtitle(String phone) {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return '验证码已发送，请输入收到的验证码。';
    }
    return '验证码已发送至 $normalizedPhone';
  }

  static const Map<AuthLoginValidationError, String> loginValidationMessages = {
    AuthLoginValidationError.phoneRequired: '请输入手机号',
    AuthLoginValidationError.codeRequired: '请输入验证码',
    AuthLoginValidationError.passwordRequired: '请输入密码',
    AuthLoginValidationError.phoneLengthCn: '手机号不合法',
    AuthLoginValidationError.agreementRequired: '请先阅读并同意《隐私政策》和《用户协议》',
    AuthLoginValidationError.passwordLength: '密码长度必须是 6 到 16 位',
    AuthLoginValidationError.inviteRequired: '邀请码不能为空',
  };

  static String validationMessage(AuthLoginValidationError error) {
    return loginValidationMessages[error] ?? '';
  }

  static String get errorPhoneRequired =>
      validationMessage(AuthLoginValidationError.phoneRequired);
  static String get errorCodeRequired =>
      validationMessage(AuthLoginValidationError.codeRequired);
  static String get errorPasswordRequired =>
      validationMessage(AuthLoginValidationError.passwordRequired);
  static String get errorPhoneLengthCn =>
      validationMessage(AuthLoginValidationError.phoneLengthCn);
  static String get errorAgreementRequired =>
      validationMessage(AuthLoginValidationError.agreementRequired);
  static String get errorPasswordLength =>
      validationMessage(AuthLoginValidationError.passwordLength);
  static String get errorInviteRequired =>
      validationMessage(AuthLoginValidationError.inviteRequired);

  static const String validationSummary = '请检查标红的输入项后再试';
  static const String fixedCodeSuccessSummary = '验证码获取成功';
  static const String fixedCodeSuccessDetail = '已自动填入 6 位暗码验证码，可直接继续下一步';
  static const String gatewayFailureSummary = '服务连接暂时中断，请稍后重试';
  static const String networkFailureSummary = '当前网络连接不可用，请检查后重试';
  static const String genericFailureSummary = '请求未完成，请稍后再试';

  static String gatewayFailureDetail(int statusCode) => '错误代码 $statusCode';

  static String loginPageLabel() => '欢迎回来';
  static String registerPageLabel() => '注册';
  static String resetPageLabel() => '找回密码';

  static const String _brandEyebrow = '信息平权';
  static const String _authBrandTitle = authDisplayName;
  static const String _resetBrandTitle = authDisplayName;
  static const String _brandDescription = '让全天下的人没有信息差';
  static const List<String> _brandHighlights = <String>[
    '真实信息更快抵达',
    '统一可信入口',
    '桌面 / 移动 / 网页端一致体验',
  ];

  static String loginBrandEyebrow(String appName) => _brandEyebrow;
  static String registerBrandEyebrow(String appName) => _brandEyebrow;
  static String resetBrandEyebrow(String appName) => _brandEyebrow;

  static String loginBrandTitle(String appName) => _authBrandTitle;
  static String registerBrandTitle(String appName) => _authBrandTitle;
  static String resetBrandTitle(String appName) => _resetBrandTitle;

  static const String loginBrandDescription = _brandDescription;
  static const String registerBrandDescription = _brandDescription;
  static const String resetBrandDescription = _brandDescription;

  static const List<String> loginBrandHighlights = _brandHighlights;
  static const List<String> registerBrandHighlights = _brandHighlights;
  static const List<String> resetBrandHighlights = _brandHighlights;

  static String humanizeFailureSummary(String rawMessage) {
    final normalized = rawMessage.trim();
    if (normalized.contains('502')) {
      return gatewayFailureSummary;
    }
    if (normalized.contains('connection error') ||
        normalized.contains('Network') ||
        normalized.contains('SocketException')) {
      return networkFailureSummary;
    }
    if (normalized.isEmpty) {
      return genericFailureSummary;
    }
    return normalized;
  }

  static String? humanizeFailureDetail(String rawMessage) {
    final normalized = rawMessage.trim();
    final statusCodeMatch = RegExp(r'\b(\d{3})\b').firstMatch(normalized);
    if (statusCodeMatch != null) {
      return '错误代码 ${statusCodeMatch.group(1)}';
    }
    return null;
  }

  static const String registerNicknameHint = '请输入昵称（选填）';
  static const String registerNicknameHelper = '显示用昵称，不作为登录账号。';

  static const String unifiedAuthStageDescription = '桌面端、移动端和网页端共用同一套认证流程。';
}
