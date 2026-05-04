import 'package:flutter/material.dart';

import '../widgets/wk_avatar.dart';

class WKUserAvatar extends StatelessWidget {
  final String? avatar;
  final String? name;
  final double size;

  const WKUserAvatar({super.key, this.avatar, this.name, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return WKAvatar(url: avatar, name: name, size: size);
  }
}
