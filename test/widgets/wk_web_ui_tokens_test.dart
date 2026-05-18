import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  test('Web palette bridges to liquid glass colors', () {
    expect(WKWebColors.pageWarm, LiquidGlassColors.lightBackground);
    expect(WKWebColors.surface, LiquidGlassColors.surfaceSolid);
    expect(WKWebColors.surfaceSoft, const Color(0xFFF3F4F6));
    expect(WKWebColors.borderWarm, LiquidGlassColors.borderStrong);
    expect(WKWebColors.action, LiquidGlassColors.primary);
    expect(WKWebColors.actionHover, LiquidGlassColors.primary2);
    expect(WKWebColors.actionSoft, const Color(0x144F46E5));
    expect(WKWebColors.online, LiquidGlassColors.online);
    expect(WKWebColors.success, LiquidGlassColors.online);
    expect(WKWebColors.danger, LiquidGlassColors.accent);
    expect(WKWebColors.textPrimary, LiquidGlassColors.text);
    expect(WKWebColors.textSecondary, LiquidGlassColors.textSecondary);
    expect(WKWebColors.textTertiary, LiquidGlassColors.textTertiary);
    expect(WKWebColors.shadow, LiquidGlassColors.shadow);
  });

  test('liquid glass web colors meet accessibility contrast targets', () {
    expect(
      _contrastRatio(Colors.white, WKWebColors.action),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(WKWebColors.textPrimary, WKWebColors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('Web breakpoints match the approved responsive contract', () {
    expect(WKWebBreakpoints.mobileMax, 719);
    expect(WKWebBreakpoints.tabletMin, 720);
    expect(WKWebBreakpoints.desktopMin, 1024);
    expect(WKWebBreakpoints.wideMin, 1280);
    expect(WKWebBreakpoints.useDesktopWorkbench(1023), isFalse);
    expect(WKWebBreakpoints.useDesktopWorkbench(1024), isTrue);
    expect(WKWebBreakpoints.showRightContext(1279), isFalse);
    expect(WKWebBreakpoints.showRightContext(1280), isTrue);
  });

  test('Web layout tokens bridge to liquid glass dimensions', () {
    expect(WKWebSizes.railWidth, LiquidGlassSizes.navRailWidth);
    expect(
      WKWebSizes.conversationListWidth,
      LiquidGlassSizes.conversationListWidth,
    );
    expect(
      WKWebSizes.conversationListMinWidth,
      LiquidGlassSizes.conversationListMinWidth,
    );
    expect(
      WKWebSizes.chatRightContextWidth,
      LiquidGlassSizes.detailsDrawerWidth,
    );
    expect(WKWebSizes.chatPaneMinWidth, 420);
    expect(
      WKWebSizes.conversationRowHeight,
      LiquidGlassSizes.conversationRowHeight,
    );
    expect(
      WKWebSizes.messageBubbleMinWidth,
      LiquidGlassSizes.messageBubbleMinWidth,
    );
    expect(
      WKWebSizes.messageBubbleMaxWidth,
      LiquidGlassSizes.messageBubbleMaxWidth,
    );
    expect(
      WKWebSizes.messageBubbleRobotMaxWidth,
      LiquidGlassSizes.messageBubbleRobotMaxWidth,
    );
    expect(
      WKWebSizes.messageBubbleWidthRatio,
      LiquidGlassSizes.messageBubbleDesktopRatio,
    );
    expect(WKWebSizes.conversationRowHeight, 68);
    expect(WKWebSizes.messageBubbleMaxWidth, 460);
    expect(WKWebSizes.messageBubbleWidthRatio, 0.56);
  });

  testWidgets('WKWebPanel paints restrained border radius and shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WKWebPanel(
            key: ValueKey<String>('sample-web-panel'),
            child: SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('sample-web-panel')),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(decoration.color, WKWebColors.surface);
    expect(decoration.borderRadius, BorderRadius.circular(WKWebRadius.panel));
    expect(border.top.color, WKWebColors.borderWarm);
    expect(WKWebRadius.panel, 14);
    expect(decoration.boxShadow!.single.blurRadius, 14);
    expect(decoration.boxShadow!.single.offset, const Offset(0, 4));
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
