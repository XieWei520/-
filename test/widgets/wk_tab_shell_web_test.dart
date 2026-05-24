import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_frame_jank_monitor.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';
import 'package:wukong_im_app/widgets/wk_tab_shell.dart';
import 'package:wukong_im_app/widgets/wk_web_ui_tokens.dart';

void main() {
  final items = <WKTabShellItemData>[
    const WKTabShellItemData(label: 'Chat', normalIcon: '', selectedIcon: ''),
    const WKTabShellItemData(
      label: 'Contacts',
      normalIcon: '',
      selectedIcon: '',
    ),
    const WKTabShellItemData(label: 'Me', normalIcon: '', selectedIcon: ''),
  ];

  test('desktop rail policy includes native Windows workspaces', () {
    expect(
      shouldUseDesktopRailShell(
        isWeb: false,
        platform: TargetPlatform.windows,
        viewportWidth: 1200,
      ),
      isTrue,
    );
    expect(
      shouldUseDesktopRailShell(
        isWeb: false,
        platform: TargetPlatform.android,
        viewportWidth: 1200,
      ),
      isFalse,
    );
    expect(
      shouldUseDesktopRailShell(
        isWeb: true,
        platform: TargetPlatform.android,
        viewportWidth: 1200,
      ),
      isTrue,
    );
  });

  testWidgets('desktop Web rail replaces bottom tabs when forced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 1,
            items: items,
            pages: const <Widget>[
              Text('chat page'),
              Text('contacts page'),
              Text('mine page'),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wk_tab_shell_bottom_bar')),
      findsNothing,
    );
    expect(find.text('contacts page'), findsOneWidget);
    expect(find.byTooltip('Contacts'), findsOneWidget);
  });

  testWidgets(
    'desktop Web rail uses 信息平权 brand mark without explanatory copy',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1200,
            height: 800,
            child: WKTabShell(
              currentIndex: 0,
              items: items,
              pages: const <Widget>[
                Text('chat page'),
                Text('contacts page'),
                Text('mine page'),
              ],
              onTap: (_) {},
              forceDesktopRailForTesting: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wk_tab_shell_brand_mark')),
        findsOneWidget,
      );
      expect(find.text('信息\n平权'), findsOneWidget);
      expect(find.text('WK'), findsNothing);
      expect(find.text('品牌入口'), findsNothing);
      expect(find.byTooltip('信息平权'), findsOneWidget);
    },
  );

  testWidgets('desktop Web brand mark has passive semantics', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1200,
            height: 800,
            child: WKTabShell(
              currentIndex: 0,
              items: items,
              pages: const <Widget>[
                Text('chat page'),
                Text('contacts page'),
                Text('mine page'),
              ],
              onTap: (_) {},
              forceDesktopRailForTesting: true,
            ),
          ),
        ),
      );

      final brandSemantics = tester
          .getSemantics(
            find.byKey(const ValueKey<String>('wk_tab_shell_brand_mark')),
          )
          .getSemanticsData();

      expect(brandSemantics.label, '信息平权');
      expect(brandSemantics.flagsCollection.isButton, isFalse);
      expect(brandSemantics.hasAction(SemanticsAction.tap), isFalse);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('desktop Web rail follows the approved adaptive preview sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 0,
            items: items,
            pages: const <Widget>[
              Text('chat page'),
              Text('contacts page'),
              Text('mine page'),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')))
          .width,
      WKWebSizes.railWidth,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('wk_tab_shell_brand_mark')),
      ),
      const Size(50, 50),
    );
  });

  testWidgets('desktop Web shell fills wide viewport in liquid stage', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1440,
          height: 800,
          child: WKTabShell(
            currentIndex: 0,
            items: items,
            pages: const <Widget>[
              ColoredBox(
                key: ValueKey<String>('desktop-liquid-page'),
                color: Colors.red,
              ),
              SizedBox(),
              SizedBox(),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    expect(find.byType(LiquidGlassStage), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('wk_tab_shell_web_liquid_shell')),
      ),
      const Size(1440, 760),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')),
          )
          .dx,
      0,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')),
          )
          .dy,
      LiquidGlassSizes.appFrameViewportInset,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')))
          .width,
      LiquidGlassSizes.navRailWidth,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('wk_tab_shell_web_page_host')),
          )
          .width,
      1440 - LiquidGlassSizes.navRailWidth - 1,
    );

    final shadowBox = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-panel-shadow')),
    );
    final shadowDecoration = shadowBox.decoration as BoxDecoration;
    expect(shadowDecoration.borderRadius, LiquidGlassRadii.lg);
    expect(shadowDecoration.boxShadow, LiquidGlassShadows.md);

    final frameClip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('wk_tab_shell_web_liquid_shell'),
            ),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(frameClip.borderRadius, LiquidGlassRadii.lg);

    final frameDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-panel-decoration')),
    );
    final decoration = frameDecoration.decoration as BoxDecoration;
    expect(decoration.borderRadius, LiquidGlassRadii.lg);
    expect(decoration.border, Border.all(color: LiquidGlassColors.border));
  });

  testWidgets('desktop Web shell disables backdrop blur when jank fallback flips', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatLiquidGlassFallbackProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          home: SizedBox(
            width: 1200,
            height: 800,
            child: WKTabShell(
              currentIndex: 0,
              items: items,
              pages: const <Widget>[
                Text('chat page'),
                Text('contacts page'),
                Text('mine page'),
              ],
              onTap: (_) {},
              forceDesktopRailForTesting: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LiquidGlassAppFrame), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('desktop Web rail uses dark liquid shell colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 0,
            items: items,
            pages: const <Widget>[
              Text('chat page'),
              Text('contacts page'),
              Text('mine page'),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, LiquidGlassColors.darkBackground);

    final rail = tester.widget<Container>(
      find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')),
    );
    expect(rail.color, LiquidGlassColors.darkSurface);

    final divider = tester.widget<VerticalDivider>(
      find.byType(VerticalDivider),
    );
    expect(divider.color, LiquidGlassColors.darkBorder);

    final selectedItemContainer = tester.widget<Container>(
      find.descendant(
        of: find.byTooltip('Chat'),
        matching: find.byWidgetPredicate((widget) {
          return widget is Container &&
              widget.alignment == Alignment.center &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(WKWebRadius.control);
        }),
      ),
    );
    final decoration = selectedItemContainer.decoration! as BoxDecoration;
    expect(
      decoration.color,
      LiquidGlassColors.darkPrimary.withValues(alpha: 0.16),
    );

    final selectedIcon = tester.widget<Icon>(
      find.descendant(of: find.byTooltip('Chat'), matching: find.byType(Icon)),
    );
    expect(selectedIcon.color, LiquidGlassColors.darkPrimary);
  });

  testWidgets('desktop rail constrains pages to the remaining host width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1200,
          height: 800,
          child: WKTabShell(
            currentIndex: 0,
            items: items,
            pages: const <Widget>[
              ColoredBox(
                key: ValueKey<String>('desktop-constrained-page'),
                color: Colors.red,
              ),
              SizedBox(),
              SizedBox(),
            ],
            onTap: (_) {},
            forceDesktopRailForTesting: true,
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('desktop-constrained-page')),
          )
          .width,
      1200 - LiquidGlassSizes.navRailWidth - 1,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('desktop-constrained-page')),
          )
          .height,
      760,
    );
  });

  testWidgets('bottom tabs remain available when desktop rail is not used', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WKTabShell(
          currentIndex: 0,
          items: items,
          pages: const <Widget>[
            Text('chat page'),
            Text('contacts page'),
            Text('mine page'),
          ],
          onTap: (_) {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('wk_tab_shell_bottom_bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wk_tab_shell_web_rail')),
      findsNothing,
    );
  });
}
