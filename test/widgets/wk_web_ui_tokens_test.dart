import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  test('Web B palette exposes approved warm social colors', () {
    expect(WKWebColors.pageWarm, const Color(0xFFFFFAF5));
    expect(WKWebColors.action, const Color(0xFFC2410C));
    expect(WKWebColors.online, const Color(0xFF0D9488));
    expect(WKWebColors.textPrimary, const Color(0xFF172033));
    expect(WKColors.webPageWarm, WKWebColors.pageWarm);
    expect(WKColors.webSurfaceSoft, WKWebColors.surfaceSoft);
    expect(WKColors.webBorderWarm, WKWebColors.borderWarm);
    expect(WKColors.webAction, WKWebColors.action);
    expect(WKColors.webActionSoft, WKWebColors.actionSoft);
    expect(WKColors.webOnline, WKWebColors.online);
    expect(WKColors.webTextPrimary, WKWebColors.textPrimary);
    expect(WKColors.webTextSecondary, WKWebColors.textSecondary);
  });

  test('warm action colors meet accessibility contrast targets', () {
    expect(
      _contrastRatio(WKColors.white, WKWebColors.action),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(WKWebColors.action, WKWebColors.actionSoft),
      greaterThanOrEqualTo(3.0),
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

  test('Web preview layout tokens expose adaptive pane and bubble limits', () {
    expect(WKWebSizes.railWidth, 72);
    expect(WKWebSizes.conversationListWidth, 350);
    expect(WKWebSizes.conversationListMinWidth, 260);
    expect(WKWebSizes.chatRightContextWidth, 304);
    expect(WKWebSizes.chatPaneMinWidth, 420);
    expect(WKWebSizes.messageBubbleMaxWidth, 560);
    expect(WKWebSizes.messageBubbleWidthRatio, 0.72);
  });

  testWidgets('WKWebPanel paints warm border and stable radius', (
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
