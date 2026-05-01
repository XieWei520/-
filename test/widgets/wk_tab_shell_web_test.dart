import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      1200 - WKWebSizes.railWidth - 1,
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
