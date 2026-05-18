import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_agreement_block.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_action_button.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_experience_tokens.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_flow_shell.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_form_field.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_page_scaffold.dart';
import 'package:wukong_im_app/modules/auth/presentation/widgets/auth_status_banner.dart';

void main() {
  test('auth control tokens meet rendered accessible contrast thresholds', () {
    expect(AuthExperienceTokens.brandAccent, const Color(0xFF4F46E5));
    expect(AuthExperienceTokens.stageBackgroundBottom, const Color(0xFFF0F4F8));
    expect(
      _contrastRatio(Colors.white, AuthExperienceTokens.brandAccent),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        AuthExperienceTokens.inputHint,
        AuthExperienceTokens.inputFill,
      ),
      greaterThanOrEqualTo(4.5),
    );
    final renderedInputBorder = _compositeOver(
      AuthExperienceTokens.inputBorder,
      AuthExperienceTokens.inputFill,
    );
    expect(
      _contrastRatio(renderedInputBorder, AuthExperienceTokens.inputFill),
      greaterThanOrEqualTo(3.0),
    );
    expect(
      _contrastRatio(
        AuthExperienceTokens.inputBorderFocus,
        AuthExperienceTokens.inputFill,
      ),
      greaterThanOrEqualTo(3.0),
    );
  });

  testWidgets('AuthPageScaffold renders premium desktop stage shell split', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1440, 960));

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthPageScaffold(
          title: '欢迎登录',
          pageLabel: '欢迎登录',
          brandEyebrow: '信息平权',
          brandTitle: '信息平权',
          brandDescription: '让全天下的人没有信息差',
          brandHighlights: ['真实信息更快抵达', '统一可信入口', '桌面 / 移动 / Web 一致体验'],
          body: SizedBox(height: 320, child: Placeholder()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stageFinder = find.byKey(const ValueKey<String>('auth-stage-shell'));
    final brandFinder = find.byKey(const ValueKey<String>('auth-brand-panel'));
    final formFinder = find.byKey(const ValueKey<String>('auth-form-panel'));
    final networkVisualFinder = find.byKey(
      const ValueKey<String>('auth-brand-network-visual'),
    );

    expect(stageFinder, findsOneWidget);
    expect(brandFinder, findsOneWidget);
    expect(formFinder, findsOneWidget);
    expect(networkVisualFinder, findsOneWidget);

    final stage = tester.widget<Container>(stageFinder);
    final stageDecoration = stage.decoration! as BoxDecoration;
    expect(stageDecoration.borderRadius, BorderRadius.circular(20));

    final brandWidth = tester.getSize(brandFinder).width;
    final formWidth = tester.getSize(formFinder).width;
    expect(brandWidth, greaterThan(formWidth));
    expect(brandWidth / formWidth, lessThan(1.35));
    expect(find.text('让全天下的人没有信息差'), findsOneWidget);
    expect(find.text('统一可信入口'), findsOneWidget);
  });

  testWidgets(
    'AuthPageScaffold keeps generic pages single-pane without branded fallback copy',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1366, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPageScaffold(
            title: 'Device sessions',
            subtitle: 'Review and confirm active sign-ins.',
            body: SizedBox(height: 180, child: Placeholder()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-stage-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-form-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-brand-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-mobile-brand-header')),
        findsNothing,
      );
      expect(find.text('Device sessions'), findsOneWidget);
    },
  );

  testWidgets('AuthPageScaffold resolves dark stage and panel surfaces', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1024, 800));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const AuthPageScaffold(
          title: 'Sign in',
          subtitle: 'Continue securely.',
          body: SizedBox(height: 120, child: Placeholder()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('auth-stage-background')),
    );
    final backgroundDecoration = background.decoration as BoxDecoration;
    expect(
      backgroundDecoration.color,
      AuthExperiencePalette.dark.stageBackgroundBottom,
    );

    final stage = tester.widget<Container>(
      find.byKey(const ValueKey<String>('auth-stage-shell')),
    );
    final stageDecoration = stage.decoration! as BoxDecoration;
    expect(
      stageDecoration.border,
      Border.all(color: AuthExperiencePalette.dark.stageShellBorder),
    );

    final formPanel = tester.widget<Container>(
      find.byKey(const ValueKey<String>('auth-page-panel')),
    );
    final formDecoration = formPanel.decoration! as BoxDecoration;
    expect(formDecoration.color, AuthExperiencePalette.dark.panelBackground);

    final title = tester.widget<Text>(find.text('Sign in'));
    expect(title.style?.color, AuthExperiencePalette.dark.panelInk);
  });

  testWidgets(
    'AuthPageScaffold falls back to stacked layout on short-wide viewports',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(800, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: AuthPageScaffold(
            title: '欢迎登录',
            pageLabel: '欢迎登录',
            brandEyebrow: '信息平权',
            brandTitle: '信息平权',
            brandDescription: '让全天下的人没有信息差',
            brandHighlights: ['真实信息更快抵达', '统一可信入口', '桌面 / 移动 / Web 一致体验'],
            statusBanner: const SizedBox(height: 48),
            body: const SizedBox(height: 220, child: Placeholder()),
            primaryAction: const SizedBox(
              key: ValueKey<String>('short-wide-primary-action'),
              height: 44,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-mobile-brand-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-brand-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-form-panel')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AuthPageScaffold compresses the brand header on mobile without overflow',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 480));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPageScaffold(
            title: '欢迎登录',
            pageLabel: '欢迎登录',
            brandEyebrow: '信息平权',
            brandTitle: '信息平权',
            brandDescription: '让全天下的人没有信息差',
            brandHighlights: ['真实信息更快抵达', '统一可信入口', '桌面 / 移动 / Web 一致体验'],
            body: SizedBox(height: 960, child: Placeholder()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('auth-mobile-brand-header')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AuthPageScaffold renders dedicated status and action slots in order',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthPageScaffold(
            title: 'Sign in',
            statusBanner: const SizedBox(
              key: ValueKey<String>('slot-status'),
              height: 20,
            ),
            body: const SizedBox(
              key: ValueKey<String>('slot-body'),
              height: 20,
            ),
            primaryAction: const SizedBox(
              key: ValueKey<String>('slot-primary-action'),
              height: 20,
            ),
            secondaryAction: const SizedBox(
              key: ValueKey<String>('slot-secondary-action'),
              height: 20,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final statusFinder = find.byKey(const ValueKey<String>('slot-status'));
      final bodyFinder = find.byKey(const ValueKey<String>('slot-body'));
      final primaryActionFinder = find.byKey(
        const ValueKey<String>('slot-primary-action'),
      );
      final secondaryActionFinder = find.byKey(
        const ValueKey<String>('slot-secondary-action'),
      );

      expect(statusFinder, findsOneWidget);
      expect(bodyFinder, findsOneWidget);
      expect(primaryActionFinder, findsOneWidget);
      expect(secondaryActionFinder, findsOneWidget);

      expect(
        tester.getTopLeft(statusFinder).dy,
        lessThan(tester.getTopLeft(bodyFinder).dy),
      );
      expect(
        tester.getTopLeft(bodyFinder).dy,
        lessThan(tester.getTopLeft(primaryActionFinder).dy),
      );
      expect(
        tester.getTopLeft(primaryActionFinder).dy,
        lessThan(tester.getTopLeft(secondaryActionFinder).dy),
      );
    },
  );

  testWidgets('AuthAgreementBlock toggle hit target is touch-friendly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthAgreementBlock(
            value: false,
            toggleKey: const ValueKey<String>('agreement-toggle'),
            onChanged: (_) {},
            prefixText: 'I agree to',
            links: const [
              AuthAgreementLink(label: 'Privacy Policy', onTap: _noop),
              AuthAgreementLink(label: 'Terms', onTap: _noop),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggleFinder = find.byKey(const ValueKey<String>('agreement-toggle'));
    expect(toggleFinder, findsOneWidget);

    final size = tester.getSize(toggleFinder);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('AuthActionButton adapts long labels without layout overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: AuthActionButton(
                label: 'Continue with secure device handoff',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AuthActionButton)),
      const Size(120, AuthExperienceTokens.actionButtonHeight),
    );
  });

  testWidgets('AuthActionButton resolves dark palette control colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Column(
            children: [
              AuthActionButton(
                key: const ValueKey<String>('dark-primary-action'),
                label: 'Continue',
                onPressed: () {},
              ),
              const AuthActionButton(
                key: ValueKey<String>('dark-disabled-primary-action'),
                label: 'Disabled',
                onPressed: null,
              ),
              AuthActionButton.secondary(
                key: const ValueKey<String>('dark-secondary-action'),
                label: 'Cancel',
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final primaryButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dark-primary-action')),
        matching: find.byType(ElevatedButton),
      ),
    );
    final primaryStyle = primaryButton.style!;
    expect(
      primaryStyle.backgroundColor?.resolve(<WidgetState>{}),
      AuthExperiencePalette.dark.brandAccent,
    );
    expect(
      primaryStyle.foregroundColor?.resolve(<WidgetState>{}),
      Colors.white,
    );

    final disabledPrimaryButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dark-disabled-primary-action')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(
      disabledPrimaryButton.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      AuthExperiencePalette.dark.brandMuted,
    );

    final secondaryButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('dark-secondary-action')),
        matching: find.byType(OutlinedButton),
      ),
    );
    final secondaryStyle = secondaryButton.style!;
    expect(
      secondaryStyle.backgroundColor?.resolve(<WidgetState>{}),
      AuthExperiencePalette.dark.stageShellTop.withValues(alpha: 0.88),
    );
    expect(
      secondaryStyle.foregroundColor?.resolve(<WidgetState>{}),
      AuthExperiencePalette.dark.brandAccentStrong,
    );
    expect(
      secondaryStyle.side?.resolve(<WidgetState>{})?.color,
      AuthExperiencePalette.dark.stageShellBorder,
    );
  });

  testWidgets('AuthAgreementBlock renders links as focusable controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthAgreementBlock(
            value: false,
            onChanged: (_) {},
            prefixText: 'I agree to',
            links: const [
              AuthAgreementLink(label: 'Privacy Policy', onTap: _noop),
              AuthAgreementLink(label: 'Terms', onTap: _noop),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Privacy Policy'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Terms'), findsOneWidget);
  });

  testWidgets('AuthAgreementBlock keeps link tap targets touch-friendly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthAgreementBlock(
            value: false,
            onChanged: (_) {},
            prefixText: 'I agree to',
            links: const [
              AuthAgreementLink(label: 'Privacy Policy', onTap: _noop),
              AuthAgreementLink(label: 'Terms', onTap: _noop),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final privacyFinder = find.widgetWithText(TextButton, 'Privacy Policy');
    final termsFinder = find.widgetWithText(TextButton, 'Terms');
    expect(privacyFinder, findsOneWidget);
    expect(termsFinder, findsOneWidget);

    final privacySize = tester.getSize(privacyFinder);
    final termsSize = tester.getSize(termsFinder);
    expect(
      privacySize.height,
      greaterThanOrEqualTo(AuthExperienceTokens.minimumTouchTarget),
    );
    expect(
      termsSize.height,
      greaterThanOrEqualTo(AuthExperienceTokens.minimumTouchTarget),
    );
    expect(
      privacySize.width,
      greaterThanOrEqualTo(AuthExperienceTokens.minimumTouchTarget),
    );
    expect(
      termsSize.width,
      greaterThanOrEqualTo(AuthExperienceTokens.minimumTouchTarget),
    );
  });

  testWidgets('AuthAgreementBlock exposes checkbox semantics state', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AuthAgreementBlock(
                  value: value,
                  toggleKey: const ValueKey<String>(
                    'agreement-toggle-semantics',
                  ),
                  onChanged: (next) => setState(() => value = next),
                  prefixText: 'I agree to',
                  links: const [
                    AuthAgreementLink(label: 'Privacy Policy', onTap: _noop),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(
        const ValueKey<String>('agreement-toggle-semantics'),
      );
      final beforeTap = tester.getSemantics(toggleFinder);
      expect(beforeTap.flagsCollection.isChecked, isNot(ui.CheckedState.none));
      expect(beforeTap.flagsCollection.isChecked, ui.CheckedState.isFalse);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      final afterTap = tester.getSemantics(toggleFinder);
      expect(afterTap.flagsCollection.isChecked, isNot(ui.CheckedState.none));
      expect(afterTap.flagsCollection.isChecked, ui.CheckedState.isTrue);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('AuthFormField surface tap focuses inner field', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: AuthFormField(
                key: const ValueKey<String>('auth-form-field'),
                focusNode: focusNode,
                hintText: 'Phone',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);

    final fieldRect = tester.getRect(
      find.byKey(const ValueKey<String>('auth-form-field')),
    );
    await tester.tapAt(
      Offset(fieldRect.left + 4, fieldRect.top + fieldRect.height / 2),
    );
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('AuthFormField preserves light palette control colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AuthFormField(
            fieldKey: ValueKey<String>('light-auth-field'),
            hintText: 'Phone',
            helperText: 'Use your phone number',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('light-auth-field')),
    );
    final decoration = field.decoration!;
    expect(decoration.fillColor, AuthExperienceTokens.inputFill);
    expect(field.style?.color, AuthExperienceTokens.inputText);
    expect(field.cursorColor, AuthExperienceTokens.inputText);
    expect(decoration.hintStyle?.color, AuthExperienceTokens.inputHint);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      AuthExperienceTokens.inputBorder,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AuthExperienceTokens.inputBorderFocus,
    );

    final helper = tester.widget<Text>(find.text('Use your phone number'));
    expect(helper.style?.color, AuthExperienceTokens.helperText);
  });

  testWidgets('AuthFormField resolves dark palette control colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: AuthFormField(
            fieldKey: ValueKey<String>('dark-auth-field'),
            hintText: 'Phone',
            helperText: 'Use your phone number',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('dark-auth-field')),
    );
    final decoration = field.decoration!;
    expect(decoration.fillColor, AuthExperiencePalette.dark.inputFill);
    expect(field.style?.color, AuthExperiencePalette.dark.inputText);
    expect(field.cursorColor, AuthExperiencePalette.dark.inputText);
    expect(decoration.hintStyle?.color, AuthExperiencePalette.dark.inputHint);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      AuthExperiencePalette.dark.inputBorder,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AuthExperiencePalette.dark.inputBorderFocus,
    );

    final helper = tester.widget<Text>(find.text('Use your phone number'));
    expect(helper.style?.color, AuthExperiencePalette.dark.helperText);
  });

  testWidgets('AuthFormField trailing actions remain tappable', (tester) async {
    var trailingTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: AuthFormField(
                hintText: 'Password',
                trailing: IconButton(
                  key: const ValueKey<String>('auth-form-field-trailing'),
                  onPressed: () => trailingTapCount += 1,
                  icon: const Icon(Icons.remove_red_eye_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('auth-form-field-trailing')),
    );
    await tester.pump();
    expect(trailingTapCount, 1);
  });

  testWidgets('AuthFlowShell forwards legacy layout boundary args', (
    tester,
  ) async {
    const backgroundKey = ValueKey<String>('legacy-auth-background');

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthFlowShell(
          title: 'Legacy login',
          subtitle: 'compatibility',
          backgroundKey: backgroundKey,
          topPadding: 42,
          bottomPadding: 18,
          leading: SizedBox(key: ValueKey<String>('legacy-leading'), width: 10),
          footer: SizedBox(key: ValueKey<String>('legacy-footer'), width: 10),
          child: SizedBox(key: ValueKey<String>('legacy-body'), height: 120),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(backgroundKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('legacy-leading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('legacy-body')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('legacy-footer')), findsOneWidget);

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final padding = scrollView.padding! as EdgeInsets;
    expect(padding.top, 42);
    expect(padding.bottom, 18);
  });

  testWidgets('AuthStatusBanner dismiss button has adequate touch target', (
    tester,
  ) async {
    var dismissCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthStatusBanner(
            message: 'Signed in on another device',
            onDismiss: () => dismissCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dismissButtonFinder = find.byKey(
      const ValueKey<String>('auth-status-banner-dismiss'),
    );
    expect(dismissButtonFinder, findsOneWidget);

    final dismissSize = tester.getSize(dismissButtonFinder);
    expect(dismissSize.width, greaterThanOrEqualTo(44));
    expect(dismissSize.height, greaterThanOrEqualTo(44));

    await tester.tap(dismissButtonFinder);
    await tester.pump();
    expect(dismissCount, 1);
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

Color _compositeOver(Color foreground, Color background) {
  final foregroundAlpha = foreground.a;
  final backgroundAlpha = background.a * (1 - foregroundAlpha);
  final compositeAlpha = foregroundAlpha + backgroundAlpha;

  double compositeChannel(double foregroundChannel, double backgroundChannel) {
    if (compositeAlpha == 0) {
      return 0;
    }
    return (foregroundChannel * foregroundAlpha +
            backgroundChannel * backgroundAlpha) /
        compositeAlpha;
  }

  return Color.from(
    alpha: compositeAlpha,
    red: compositeChannel(foreground.r, background.r),
    green: compositeChannel(foreground.g, background.g),
    blue: compositeChannel(foreground.b, background.b),
  );
}

void _noop() {}
