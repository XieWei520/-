import '../../../data/models/user.dart';
import 'auth_login_preferences.dart';

abstract class AuthLoginPreferencesStore {
  Future<AuthLoginPreferences> load();
  Future<void> save(AuthLoginPreferences preferences);
  Future<void> clearSavedSecret({bool keepPhone = true});
  Future<void> disableAutoLogin();
}

Future<void> reconcileAuthenticatedLoginPreferences(
  AuthLoginPreferencesStore store,
  UserInfo user,
) async {
  final resolvedPhone = user.phone?.trim() ?? '';
  final resolvedZoneCode = user.zone?.trim() ?? '';
  if (resolvedPhone.isEmpty && resolvedZoneCode.isEmpty) {
    return;
  }

  final current = (await store.load()).normalize();
  await store.save(
    AuthLoginPreferences(
      zoneCode: resolvedZoneCode.isNotEmpty
          ? resolvedZoneCode
          : current.zoneCode,
      phone: resolvedPhone.isNotEmpty ? resolvedPhone : current.phone,
      password: current.rememberPassword ? current.password : '',
      rememberPassword: current.rememberPassword,
      autoLogin: current.autoLogin,
    ),
  );
}
