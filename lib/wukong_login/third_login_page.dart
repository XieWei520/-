import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_third_login_page.dart';

class ThirdLoginPage extends StatelessWidget {
  const ThirdLoginPage({
    super.key,
    this.onPlatformSelected,
    this.onBack,
  });

  final void Function(String platform)? onPlatformSelected;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => const AuthThirdLoginPage();
}
