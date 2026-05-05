import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_emoji_text.dart';
import 'package:wukong_im_app/wukong_base/emoji/android_emoji_catalog.dart';

class _AlwaysFailAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    return Future<ByteData>.error(
      FlutterError('Simulated missing asset: $key'),
    );
  }
}

void main() {
  group('WKEmojiText', () {
    test('containsAndroidEmoji detects catalog tags', () {
      final entry = androidEmojiCatalog.lookupById('0_0')!;

      expect(
        WKEmojiText.containsAndroidEmoji('hello ${entry.tag} world'),
        isTrue,
      );
      expect(WKEmojiText.containsAndroidEmoji('hello world'), isFalse);
    });

    testWidgets('renders android emoji tag as inline asset image', (
      tester,
    ) async {
      final entry = androidEmojiCatalog.lookupById('0_0')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WKEmojiText(
              text: 'hello ${entry.tag} world',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == entry.assetPath,
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to rendering original emoji tag when asset fails', (
      tester,
    ) async {
      final entry = androidEmojiCatalog.lookupById('0_0')!;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _AlwaysFailAssetBundle(),
            child: Scaffold(
              body: WKEmojiText(
                text: 'hello ${entry.tag} world',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(entry.tag), findsOneWidget);
    });

    testWidgets('renders adjacent repeated emoji tags inline', (tester) async {
      final entry = androidEmojiCatalog.lookupById('0_0')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WKEmojiText(
              text: '${entry.tag}${entry.tag} done',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == entry.assetPath,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('renders leading and trailing emoji tags inline', (
      tester,
    ) async {
      final entry = androidEmojiCatalog.lookupById('0_0')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WKEmojiText(
              text: '${entry.tag}hello${entry.tag}',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == entry.assetPath,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('passes through unknown plain text cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WKEmojiText(
              text: 'plain text only',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      );

      expect(find.text('plain text only'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.startsWith(
                'assets/emoji/android/',
              ),
        ),
        findsNothing,
      );
    });
  });
}
