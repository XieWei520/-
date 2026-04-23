import 'package:flutter/foundation.dart';

@immutable
class AuthLoginPreferences {
  const AuthLoginPreferences({
    this.zoneCode = '0086',
    this.phone = '',
    this.password = '',
    this.rememberPassword = false,
    this.autoLogin = false,
  });

  final String zoneCode;
  final String phone;
  final String password;
  final bool rememberPassword;
  final bool autoLogin;

  bool get hasUsableCredentials =>
      phone.trim().isNotEmpty && password.isNotEmpty;

  AuthLoginPreferences normalize() {
    final normalizedRemember = rememberPassword || autoLogin;
    final normalizedAutoLogin = autoLogin && hasUsableCredentials;
    return AuthLoginPreferences(
      zoneCode: zoneCode.trim().isEmpty ? '0086' : zoneCode.trim(),
      phone: phone.trim(),
      password: password,
      rememberPassword: normalizedRemember,
      autoLogin: normalizedAutoLogin,
    );
  }
}
