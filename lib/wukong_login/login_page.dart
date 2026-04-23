import 'package:flutter/widgets.dart';

import '../data/models/user.dart';
import '../modules/auth/presentation/pages/auth_login_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    this.onLoginSuccess,
    this.onRegisterTap,
    this.onForgetPasswordTap,
  });

  final Function(UserInfo)? onLoginSuccess;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onForgetPasswordTap;

  @override
  Widget build(BuildContext context) => const AuthLoginPage();
}
