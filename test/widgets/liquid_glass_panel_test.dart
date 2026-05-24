import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_performance.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  test('shouldDisableLiquidGlassBlur disables blur after Web raster jank', () {
    expect(
      shouldDisableLiquidGlassBlur(
        isWeb: true,
        disableAnimations: false,
        rasterJankCount: 3,
        totalJankCount: 0,
      ),
      isTrue,
    );
  });

  testWidgets('LiquidGlassPanel renders clipped translucent shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiquidGlassPanel(
            key: ValueKey<String>('panel'),
            child: SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsWidgets);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter, isA<ui.ImageFilter>());

    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-panel-decoration')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.surface);
    expect(decoration.borderRadius, LiquidGlassRadii.lg);
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNull);

    final shadowBox = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-panel-shadow')),
    );
    final shadowDecoration = shadowBox.decoration as BoxDecoration;
    expect(shadowDecoration.borderRadius, LiquidGlassRadii.lg);
    expect(shadowDecoration.boxShadow, LiquidGlassShadows.md);
    expect(shadowDecoration.boxShadow!.single.blurRadius, 16);
  });

  testWidgets('LiquidGlassPanel can render without backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiquidGlassPanel(disableBlur: true, child: Text('x')),
        ),
      ),
    );

    expect(find.text('x'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('LiquidGlassStage paints a flat restrained light workbench', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassStage(child: SizedBox(width: 20, height: 20)),
      ),
    );

    final stage = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-stage')),
    );
    final decoration = stage.decoration as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.lightBackground);
    expect(decoration.gradient, isNull);
  });

  testWidgets('LiquidGlassPillButton keeps a 40dp minimum touch target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassPillButton(
            key: const ValueKey<String>('pill'),
            label: 'New',
            icon: Icons.add_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const ValueKey<String>('pill')));
    expect(size.height, greaterThanOrEqualTo(40));
    expect(find.text('New'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
