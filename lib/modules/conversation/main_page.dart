import 'package:flutter/material.dart';

import '../home/home_shell_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key, this.autoInitializeIM = true});

  final bool autoInitializeIM;

  @override
  Widget build(BuildContext context) {
    return HomeShellPage(autoInitializeIM: autoInitializeIM);
  }
}
