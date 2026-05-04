import 'package:flutter/material.dart';

import 'auth_page_scaffold.dart';

class AuthFlowShell extends StatelessWidget {
  const AuthFlowShell({
    super.key,
    required this.title,
    required this.child,
    this.backgroundKey = const ValueKey<String>('auth_flow_background'),
    this.subtitle,
    this.leading,
    this.footer,
    this.topPadding = 70,
    this.bottomPadding = 30,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Key backgroundKey;
  final Widget? leading;
  final Widget? footer;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      title: title,
      subtitle: subtitle,
      leading: leading,
      footer: footer,
      backgroundKey: backgroundKey,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      body: child,
    );
  }
}
