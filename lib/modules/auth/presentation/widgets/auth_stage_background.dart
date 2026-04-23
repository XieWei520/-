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
    return RepaintBoundary(
      child: DecoratedBox(
        key: backgroundKey,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AuthExperienceTokens.stageShellTop,
              AuthExperienceTokens.stageBackgroundBottom,
            ],
          ),
        ),
        child: const Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -84,
              top: -70,
              child: _GlowBubble(
                size: 280,
                color: AuthExperienceTokens.stageGlowPrimary,
              ),
            ),
            Positioned(
              left: -96,
              bottom: -136,
              child: _GlowBubble(
                size: 340,
                color: AuthExperienceTokens.stageGlowSecondary,
              ),
            ),
            Positioned(
              left: 72,
              top: 120,
              child: _GlowBubble(
                size: 120,
                color: AuthExperienceTokens.stageGlowTertiary,
              ),
            ),
            Positioned(
              right: 160,
              bottom: 72,
              child: _MessagePlate(width: 148, height: 72, rotation: -0.08),
            ),
            Positioned(
              left: 120,
              bottom: 150,
              child: _MessagePlate(width: 120, height: 58, rotation: 0.06),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _MessagePlate extends StatelessWidget {
  const _MessagePlate({
    required this.width,
    required this.height,
    required this.rotation,
  });

  final double width;
  final double height;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AuthExperienceTokens.stageShellTop.withOpacity(0.36),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthExperienceTokens.stageShellBorder.withOpacity(0.46),
          ),
        ),
      ),
    );
  }
}
