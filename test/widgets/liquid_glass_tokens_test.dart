import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  test(
    'liquid glass tokens expose restrained IM palette and desktop metrics',
    () {
      expect(LiquidGlassColors.primary, const Color(0xFF4F46E5));
      expect(LiquidGlassColors.primary2, const Color(0xFF0284C7));
      expect(LiquidGlassColors.darkPrimary, const Color(0xFF6366F1));
      expect(LiquidGlassColors.darkPrimary2, const Color(0xFF0EA5E9));
      expect(LiquidGlassColors.accent, const Color(0xFFEF4444));
      expect(LiquidGlassColors.lightBackground, const Color(0xFFF7F8FA));
      expect(LiquidGlassColors.darkBackground, const Color(0xFF0B0E14));
      expect(LiquidGlassColors.online, const Color(0xFF10B981));
      expect(LiquidGlassColors.warning, const Color(0xFFF59E0B));
      expect(LiquidGlassGradients.primary.colors, const <Color>[
        Color(0xFF4F46E5),
        Color(0xFF0284C7),
      ]);
      expect(LiquidGlassRadii.sm, BorderRadius.circular(8));
      expect(LiquidGlassRadii.md, BorderRadius.circular(12));
      expect(LiquidGlassRadii.lg, BorderRadius.circular(14));
      expect(LiquidGlassRadii.xl, BorderRadius.circular(16));
      expect(LiquidGlassSizes.navRailWidth, 72);
      expect(LiquidGlassSizes.pageContentMaxWidth, 920);
      expect(LiquidGlassSizes.pageContentPadding, 20);
      expect(LiquidGlassSizes.sectionGap, 12);
      expect(LiquidGlassSizes.listRowHeight, 64);
      expect(LiquidGlassSizes.listIconSize, 40);
      expect(LiquidGlassSizes.listAvatarSize, 44);
      expect(LiquidGlassSizes.conversationListWidth, 328);
      expect(LiquidGlassSizes.detailsDrawerWidth, 300);
      expect(LiquidGlassSizes.conversationRowHeight, 68);
      expect(LiquidGlassSizes.messageBubbleMaxWidth, 460);
      expect(LiquidGlassSizes.messageBubbleDesktopRatio, 0.56);
      expect(LiquidGlassPanelBlur.sigmaX, 12);
      expect(LiquidGlassPanelBlur.sigmaY, 12);
      expect(LiquidGlassShadows.lg.single.blurRadius, 22);
      expect(LiquidGlassShadows.glow.single.color, const Color(0x144F46E5));
    },
  );

  test('liquid glass text contrast is accessible on solid surfaces', () {
    expect(
      _contrastRatio(LiquidGlassColors.text, LiquidGlassColors.surfaceSolid),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        LiquidGlassColors.darkText,
        LiquidGlassColors.darkSurfaceSolid,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('LiquidGlassTokens.of resolves light theme values', (
    tester,
  ) async {
    late LiquidGlassTokens tokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Builder(
          builder: (context) {
            tokens = LiquidGlassTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tokens.surface, LiquidGlassColors.surface);
    expect(tokens.surfaceSolid, LiquidGlassColors.surfaceSolid);
    expect(tokens.text, LiquidGlassColors.text);
    expect(tokens.border, LiquidGlassColors.border);
    expect(tokens.primaryGradient, LiquidGlassGradients.primary);
  });

  testWidgets('LiquidGlassTokens.of resolves dark theme values', (
    tester,
  ) async {
    late LiquidGlassTokens tokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            tokens = LiquidGlassTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(tokens.surface, LiquidGlassColors.darkSurface);
    expect(tokens.surfaceSolid, LiquidGlassColors.darkSurfaceSolid);
    expect(tokens.text, LiquidGlassColors.darkText);
    expect(tokens.border, LiquidGlassColors.darkBorder);
    expect(tokens.primaryGradient, LiquidGlassGradients.primaryDark);
  });

  test('liquid glass motion resolves reduced animation preference', () {
    expect(
      LiquidGlassMotion.panelEnter.resolve(disableAnimations: true),
      Duration.zero,
    );
    expect(
      LiquidGlassMotion.panelEnter.resolve(disableAnimations: false),
      const Duration(milliseconds: 250),
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
