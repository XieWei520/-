import 'package:flutter/material.dart';

import '../wukong_uikit/setting/setting_preferences.dart';

class AppDisplayPreferences extends StatelessWidget {
  const AppDisplayPreferences({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return child;
    }

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(WKSettingPreferences.getFontScale()),
      ),
      child: child,
    );
  }
}
