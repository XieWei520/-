class AuthFixedCode {
  AuthFixedCode._();

  static const String universalSmsCode = '123456';
  static const String successMessage =
      '\u9a8c\u8bc1\u7801\u83b7\u53d6\u6210\u529f';

  static bool get isEnabled => universalSmsCode.trim().isNotEmpty;

  static String? get enabledCode => isEnabled ? universalSmsCode.trim() : null;
}
