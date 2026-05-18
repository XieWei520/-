import 'package:flutter/material.dart';

import 'auth_experience_tokens.dart';

class AuthStageBackground extends StatelessWidget {
  const AuthStageBackground({
    super.key,
    this.backgroundKey = const ValueKey<String>(
      AuthExperienceTokens.stageBackgroundKey,
    ),
  });

  final Key backgroundKey;

  @override
  Widget build(BuildContext context) {
    final palette = AuthExperiencePalette.of(context);
    return RepaintBoundary(
      child: DecoratedBox(
        key: backgroundKey,
        decoration: BoxDecoration(color: palette.stageBackgroundBottom),
      ),
    );
  }
}
