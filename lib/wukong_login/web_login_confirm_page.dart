import 'package:flutter/widgets.dart';

import '../modules/auth/presentation/pages/auth_web_login_confirm_page.dart';

class WebLoginConfirmPage extends StatelessWidget {
  const WebLoginConfirmPage({
    super.key,
    required this.authCode,
    this.encrypt,
    this.pubKey,
  });

  final String authCode;
  final String? encrypt;
  final String? pubKey;

  @override
  Widget build(BuildContext context) {
    return AuthWebLoginConfirmPage(
      authCode: authCode,
      encrypt: encrypt ?? pubKey,
    );
  }
}
