import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_composer.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  testWidgets('chat composer supports restrained IM shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatComposer(
            webStyle: true,
            inputRow: SizedBox(height: 20),
            toolbarRow: SizedBox(height: 20),
            panel: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-composer-shell')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFF8FAFC));
    expect(decoration.border!.top.color, const Color(0xFFE2E8F0));
    expect(decoration.boxShadow, const <BoxShadow>[
      BoxShadow(color: Color(0x0A111827), blurRadius: 8, offset: Offset(0, -1)),
    ]);
  });

  testWidgets('chat composer resolves liquid shell from dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: ChatComposer(
            webStyle: true,
            inputRow: SizedBox(height: 20),
            toolbarRow: SizedBox(height: 20),
            panel: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('chat-composer-shell')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.darkSurface);
    expect(decoration.border!.top.color, LiquidGlassColors.darkBorder);
  });

  testWidgets('mobile chat composer resolves liquid shell from dark theme', (
    tester,
  ) async {
    final previousOverride = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ChatComposer(
              inputRow: SizedBox(height: 20),
              toolbarRow: SizedBox(height: 20),
              panel: SizedBox.shrink(),
            ),
          ),
        ),
      );

      final decorated = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('chat-composer-shell')),
      );
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, LiquidGlassColors.darkSurface);
      expect(decoration.border!.top.color, LiquidGlassColors.darkBorder);
      expect(decoration.color, isNot(LiquidGlassColors.surface));
      expect(decoration.border!.top.color, isNot(LiquidGlassColors.border));
    } finally {
      debugDefaultTargetPlatformOverride = previousOverride;
    }
  });

  testWidgets('chat composer disables panel switch motion when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: ChatComposer(
              webStyle: true,
              inputRow: SizedBox(height: 20),
              toolbarRow: SizedBox(height: 20),
              panel: SizedBox(key: ValueKey<String>('composer-panel')),
            ),
          ),
        ),
      ),
    );

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, Duration.zero);
  });

  testWidgets('desktop composer send button uses restrained action surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: buildComposerSendButtonForTesting(
              enabled: true,
              webStyle: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('chat-send-button')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(
      decoration.gradient,
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2F80ED), Color(0xFF2563D9)],
      ),
    );
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.boxShadow, const <BoxShadow>[
      BoxShadow(color: Color(0x1A2563D9), blurRadius: 6, offset: Offset(0, 2)),
    ]);
  });

  testWidgets('composer icon controls share hover motion treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildComposerToolbarButtonForTesting(
                  key: const ValueKey<String>('toolbar-action'),
                  asset: '',
                  onTap: () {},
                ),
                buildComposerCallToolbarButtonForTesting(
                  key: const ValueKey<String>('call-action'),
                  onTap: () {},
                ),
                buildComposerSendButtonForTesting(
                  enabled: true,
                  webStyle: true,
                  onTap: () {},
                ),
                buildFunctionItemForTesting(
                  sid: 'chooseImg',
                  asset: '',
                  label: '图片',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('chat-toolbar-action-motion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-call-action-motion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-send-button-motion')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat-function-chooseImg-motion')),
      findsOneWidget,
    );

    final toolbarMotion = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey<String>('chat-toolbar-action-motion')),
    );
    final callMotion = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey<String>('chat-call-action-motion')),
    );
    final sendMotion = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey<String>('chat-send-button-motion')),
    );
    final functionMotion = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey<String>('chat-function-chooseImg-motion')),
    );

    expect(toolbarMotion.duration, sendMotion.duration);
    expect(callMotion.duration, sendMotion.duration);
    expect(functionMotion.duration, sendMotion.duration);
    expect(toolbarMotion.curve, sendMotion.curve);
    expect(callMotion.curve, sendMotion.curve);
    expect(functionMotion.curve, sendMotion.curve);
  });
}
