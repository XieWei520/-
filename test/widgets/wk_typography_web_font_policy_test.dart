import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_design_tokens.dart';
import 'package:wukong_im_app/widgets/wk_main_top_bar.dart';

void main() {
  test('web typography keeps bundled Chinese fallback for CanvasKit', () {
    const fallback = WKTypography.webFontFamilyFallback;

    expect(fallback, contains('WKChineseWebSubset'));
    expect(fallback, isNot(contains('WKNotoEmoji')));
    expect(fallback, isNot(contains('WKNotoSansSC')));
    expect(fallback, contains('Microsoft YaHei UI'));
    expect(fallback, contains('Microsoft YaHei'));
    expect(fallback, contains('PingFang SC'));
    expect(fallback, contains('Hiragino Sans GB'));
    expect(
      fallback.indexOf('WKChineseWebSubset'),
      lessThan(fallback.indexOf('Microsoft YaHei UI')),
    );
    expect(
      fallback.indexOf('Microsoft YaHei UI'),
      lessThan(fallback.indexOf('Segoe UI')),
    );
    expect(fallback, isNot(contains('Noto Sans SC')));
    expect(fallback, isNot(contains('Noto Sans CJK SC')));
    expect(fallback, isNot(contains('Source Han Sans SC')));
    expect(fallback, isNot(contains('Roboto')));
    expect(fallback.first, 'Noto Color Emoji');
    expect(fallback, contains('Noto Color Emoji'));
    expect(
      fallback.indexOf('Noto Color Emoji'),
      lessThan(fallback.indexOf('WKChineseWebSubset')),
    );
    expect(
      fallback.indexOf('Noto Color Emoji'),
      lessThan(fallback.indexOf('Segoe UI')),
    );
  });

  test(
    'native typography keeps bundled Chinese fallback for offline clients',
    () {
      const fallback = WKTypography.nativeFontFamilyFallback;

      expect(fallback, contains('WKNotoSansSC'));
      expect(fallback, isNot(contains('Noto Sans SC')));
      expect(fallback, isNot(contains('Noto Sans CJK SC')));
      expect(fallback, isNot(contains('Source Han Sans SC')));
      expect(fallback, isNot(contains('Roboto')));
      expect(fallback, contains('Noto Color Emoji'));
      expect(WKTypography.fontFamilyFallback, same(fallback));
    },
  );

  test('pubspec registers native and web Chinese fallback families', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('family: WKNotoSansSC'));
    expect(
      pubspec,
      contains('asset: assets/reference_ui/fonts/noto_sans_sc_vf.ttf'),
    );
    expect(pubspec, contains('family: WKChineseWebSubset'));
    expect(
      pubspec,
      contains('asset: assets/reference_ui/fonts/noto_sans_sc_web_subset.ttf'),
    );
    expect(pubspec, isNot(contains('family: WKNotoEmoji')));
    expect(pubspec, isNot(contains('family: Noto Sans SC')));
    expect(pubspec, contains('family: Roboto'));
    expect(pubspec, contains('asset: assets/reference_ui/fonts/rmedium.ttf'));
  });

  testWidgets('main top bar title keeps bundled Chinese fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WKMainTopBar(title: Text('聊天'))),
      ),
    );

    final defaultStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('聊天'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );

    expect(defaultStyle.style.fontFamily, WKFontFamily.title);
    expect(defaultStyle.style.fontFamilyFallback, contains('WKNotoSansSC'));
    expect(defaultStyle.style.fontFamilyFallback, contains('Segoe UI Emoji'));
  });

  test('chat composer input explicitly keeps Chinese and emoji fallback', () {
    final source = File(
      'lib/modules/chat/panes/chat_composer_pane.dart',
    ).readAsStringSync();

    expect(source, contains("key: const ValueKey<String>('chat-input-field')"));
    expect(source, contains('style: Theme.of(context).textTheme.bodyLarge'));
    expect(
      source,
      matches(
        RegExp(r'fontFamilyFallback:\s*WKTypography\.fontFamilyFallback'),
      ),
    );
  });
}
