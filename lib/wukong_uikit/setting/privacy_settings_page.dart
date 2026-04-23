import 'package:flutter/material.dart';

import '../../modules/settings/privacy_settings_page.dart' as modules_settings;

@Deprecated(
  'Use PrivacySettingsPage from lib/modules/settings/privacy_settings_page.dart.',
)
class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const modules_settings.PrivacySettingsPage();
  }
}
