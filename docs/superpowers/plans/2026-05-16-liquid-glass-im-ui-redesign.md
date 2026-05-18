# Liquid Glass IM UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Web, Windows, and Android IM interface with the liquid-glass UI defined in `docs/superpowers/specs/2026-05-16-liquid-glass-im-ui-redesign-design.md`.

**Architecture:** Implement shared Flutter design tokens and primitives first, then migrate existing surfaces without changing IM business behavior. Keep production state, routing, providers, message action dispatch, and platform integrations in place; only replace visual structure and interaction polish slice by slice.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, existing WuKong IM SDK, existing widget tests under `test/`, no new dependencies unless explicitly approved.

---

## Scope Decisions

- Implement Web, Windows desktop, and Android. Do not expand scope to iOS/macOS/Linux unless requested later.
- Replace the existing warm orange Web theme with the reference indigo/sky liquid-glass palette for the redesigned IM surfaces.
- Use widget tests plus manual screenshots/smoke checks for this phase. Do not introduce golden-test infrastructure in the first pass.
- Preserve existing behavior and user data paths. The reference HTML is a visual target, not runtime code.

## File Structure

Create:

- `lib/widgets/liquid_glass_tokens.dart` -> shared color, radius, shadow, gradient, blur, and responsive size tokens.
- `lib/widgets/liquid_glass_panel.dart` -> reusable glass panel, app stage, pill button, gradient icon/action surfaces.
- `test/widgets/liquid_glass_tokens_test.dart` -> token contrast, dimensions, reduced-motion hooks.
- `test/widgets/liquid_glass_panel_test.dart` -> panel decoration, clipping, and semantic hit targets.

Modify:

- `lib/widgets/wk_web_ui_tokens.dart` -> point Web workbench dimensions and palette aliases to liquid-glass values.
- `lib/widgets/wk_colors.dart` -> update app-level brand aliases only where existing code expects them.
- `lib/core/theme/chat_bubble_theme.dart` -> outgoing/incoming bubble tokens.
- `lib/core/theme/chat_micro_interactions.dart` -> badge/read receipt colors and motion.
- `lib/core/motion/chat_motion.dart` -> add named durations/curves for drawer, toast, panel, and wave motion.
- `lib/widgets/message_bubble.dart` -> message body styling, metadata, file/voice/reply/media surfaces.
- `lib/modules/chat/widgets/chat_composer.dart` -> composer glass shell.
- `lib/modules/chat/chat_page_shell.dart` -> top bar, banner, composer row controls, panels, snack/toast surfaces.
- `lib/modules/chat/chat_desktop_drop_target.dart` -> dashed drag/drop overlay.
- `lib/modules/conversation/web_conversation_workspace.dart` -> desktop three-column stage and right drawer treatment.
- `lib/modules/conversation/conversation_list_page.dart` -> list header, embedded panel shell, search field.
- `lib/widgets/wk_conversation_item.dart` -> conversation row visuals and unread badge animation.
- `lib/modules/home/home_shell_page.dart` -> nav shell colors and badges where the workbench uses shared tabs.
- `lib/modules/auth/presentation/widgets/auth_experience_tokens.dart` -> auth/login liquid-glass palette and sizes.
- `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart` -> brand/form glass layout and network visual space.
- `lib/modules/contacts/contacts_page.dart` and `lib/modules/contacts/widgets/contacts_list_viewport.dart` -> contacts visual treatment.
- `lib/wukong_uikit/setting/setting_page.dart` -> settings page shell/card treatment.

Tests to update or add:

- `test/core/motion/chat_motion_test.dart`
- `test/modules/chat/message_bubble_experience_test.dart`
- `test/modules/chat/chat_composer_web_style_test.dart`
- `test/modules/chat/chat_desktop_drop_target_test.dart`
- `test/modules/chat/chat_pages_compile_test.dart`
- `test/modules/conversation/web_conversation_workspace_test.dart` if present, otherwise create it.
- `test/modules/contacts/contacts_page_parity_test.dart`
- `test/wukong_uikit/setting/setting_page_test.dart`
- `test/modules/auth/auth_page_scaffold_test.dart`

## Task 1: Liquid-Glass Tokens and Shared Primitives

**Files:**
- Create: `lib/widgets/liquid_glass_tokens.dart`
- Create: `lib/widgets/liquid_glass_panel.dart`
- Create: `test/widgets/liquid_glass_tokens_test.dart`
- Create: `test/widgets/liquid_glass_panel_test.dart`
- Modify: `lib/widgets/wk_web_ui_tokens.dart`

**Acceptance:**
- Shared tokens expose the reference colors, gradients, radii, shell dimensions, and panel blur values.
- `LiquidGlassPanel` renders a clipped translucent panel with border, blur, and shadow.
- Existing Web token names remain available so current code compiles.

- [ ] **Step 1: Write failing token tests**

Add `test/widgets/liquid_glass_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  test('liquid glass tokens expose reference palette and desktop metrics', () {
    expect(LiquidGlassColors.primary, const Color(0xFF4F46E5));
    expect(LiquidGlassColors.primary2, const Color(0xFF0284C7));
    expect(LiquidGlassColors.lightBackground, const Color(0xFFF0F4F8));
    expect(LiquidGlassColors.darkBackground, const Color(0xFF0B0E14));
    expect(LiquidGlassSizes.navRailWidth, 72);
    expect(LiquidGlassSizes.conversationListWidth, 340);
    expect(LiquidGlassSizes.detailsDrawerWidth, 300);
  });

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
```

- [ ] **Step 2: Write failing panel tests**

Add `test/widgets/liquid_glass_panel_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/liquid_glass_panel.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
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
    final decorated = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('liquid-glass-panel-decoration')),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, LiquidGlassColors.surface);
    expect(decoration.borderRadius, LiquidGlassRadii.xl);
    expect(decoration.border, isNotNull);
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
  });

  test('LiquidGlassTokens resolve reduced motion durations', () {
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
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```powershell
flutter test test/widgets/liquid_glass_tokens_test.dart test/widgets/liquid_glass_panel_test.dart
```

Expected: FAIL because `liquid_glass_tokens.dart`, `liquid_glass_panel.dart`, and related classes do not exist.

- [ ] **Step 4: Implement tokens**

Create `lib/widgets/liquid_glass_tokens.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LiquidGlassColors {
  LiquidGlassColors._();

  static const Color primary = Color(0xFF4F46E5);
  static const Color primary2 = Color(0xFF0284C7);
  static const Color darkPrimary = Color(0xFF6366F1);
  static const Color darkPrimary2 = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFFEF4444);
  static const Color lightBackground = Color(0xFFF0F4F8);
  static const Color darkBackground = Color(0xFF0B0E14);
  static const Color surface = Color(0xA6FFFFFF);
  static const Color surfaceSolid = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0x991E293B);
  static const Color darkSurfaceSolid = Color(0xFF1E293B);
  static const Color muted = Color(0x0A0F172A);
  static const Color darkMuted = Color(0x08FFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color border = Color(0x120F172A);
  static const Color borderStrong = Color(0x1F0F172A);
  static const Color darkBorder = Color(0x0FFFFFFF);
  static const Color darkBorderStrong = Color(0x1AFFFFFF);
  static const Color online = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color bubbleOtherDark = Color(0xFF1E293B);
  static const Color bubbleOtherDarker = Color(0xFF27272A);
}

class LiquidGlassGradients {
  LiquidGlassGradients._();

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[LiquidGlassColors.primary, LiquidGlassColors.primary2],
  );

  static const LinearGradient primaryDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      LiquidGlassColors.darkPrimary,
      LiquidGlassColors.darkPrimary2,
    ],
  );
}

class LiquidGlassRadii {
  LiquidGlassRadii._();

  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

class LiquidGlassSizes {
  LiquidGlassSizes._();

  static const double navRailWidth = 72;
  static const double conversationListWidth = 340;
  static const double conversationListMinWidth = 260;
  static const double detailsDrawerWidth = 300;
  static const double appMaxWidth = 1280;
  static const double conversationRowHeight = 76;
  static const double messageBubbleMaxWidth = 520;
  static const double messageBubbleDesktopRatio = 0.68;
  static const double messageBubbleMobileRatio = 0.82;
}

class LiquidGlassShadows {
  LiquidGlassShadows._();

  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A0F172A),
      blurRadius: 80,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(
      color: Color(0x334F46E5),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x1A4F46E5),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
}

class LiquidGlassMotionDuration {
  const LiquidGlassMotionDuration(this.value);

  final Duration value;

  Duration resolve({required bool disableAnimations}) {
    return disableAnimations ? Duration.zero : value;
  }
}

class LiquidGlassMotion {
  LiquidGlassMotion._();

  static const LiquidGlassMotionDuration fast = LiquidGlassMotionDuration(
    Duration(milliseconds: 180),
  );
  static const LiquidGlassMotionDuration normal = LiquidGlassMotionDuration(
    Duration(milliseconds: 220),
  );
  static const LiquidGlassMotionDuration panelEnter =
      LiquidGlassMotionDuration(Duration(milliseconds: 250));
  static const LiquidGlassMotionDuration toast =
      LiquidGlassMotionDuration(Duration(milliseconds: 350));

  static const Curve spring = Curves.easeOutBack;
  static const Curve standard = Curves.easeOutCubic;
}

class LiquidGlassTokens {
  const LiquidGlassTokens({
    required this.surface,
    required this.surfaceSolid,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.primaryGradient,
    required this.backdropFilter,
  });

  final Color surface;
  final Color surfaceSolid;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderStrong;
  final Gradient primaryGradient;
  final ui.ImageFilter backdropFilter;

  static LiquidGlassTokens of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassTokens(
      surface: dark ? LiquidGlassColors.darkSurface : LiquidGlassColors.surface,
      surfaceSolid: dark
          ? LiquidGlassColors.darkSurfaceSolid
          : LiquidGlassColors.surfaceSolid,
      text: dark ? LiquidGlassColors.darkText : LiquidGlassColors.text,
      textSecondary: dark
          ? LiquidGlassColors.darkTextSecondary
          : LiquidGlassColors.textSecondary,
      textTertiary: dark
          ? LiquidGlassColors.darkTextTertiary
          : LiquidGlassColors.textTertiary,
      border: dark ? LiquidGlassColors.darkBorder : LiquidGlassColors.border,
      borderStrong: dark
          ? LiquidGlassColors.darkBorderStrong
          : LiquidGlassColors.borderStrong,
      primaryGradient: dark
          ? LiquidGlassGradients.primaryDark
          : LiquidGlassGradients.primary,
      backdropFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
    );
  }
}
```

- [ ] **Step 5: Implement shared primitives**

Create `lib/widgets/liquid_glass_panel.dart`:

```dart
import 'package:flutter/material.dart';

import 'liquid_glass_tokens.dart';
import 'wk_design_tokens.dart';

class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = LiquidGlassRadii.xl,
    this.shadow = LiquidGlassShadows.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: tokens.backdropFilter,
          child: DecoratedBox(
            key: const ValueKey<String>('liquid-glass-panel-decoration'),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: borderRadius,
              border: Border.all(color: tokens.border),
              boxShadow: shadow,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassPillButton extends StatelessWidget {
  const LiquidGlassPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: LiquidGlassRadii.pill,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.surfaceSolid,
            borderRadius: LiquidGlassRadii.pill,
            border: Border.all(color: tokens.border),
            boxShadow: LiquidGlassShadows.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: tokens.text),
                const SizedBox(width: WKSpace.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassStage extends StatelessWidget {
  const LiquidGlassStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark
        ? LiquidGlassColors.darkBackground
        : LiquidGlassColors.lightBackground;
    return DecoratedBox(
      key: const ValueKey<String>('liquid-glass-stage'),
      decoration: BoxDecoration(
        color: base,
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.8),
          radius: 1.2,
          colors: [
            LiquidGlassColors.primary.withValues(alpha: dark ? 0.26 : 0.18),
            base,
          ],
        ),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 6: Bridge existing Web tokens**

Modify `lib/widgets/wk_web_ui_tokens.dart` so these constants match the new token system:

```dart
import 'liquid_glass_tokens.dart';
```

Then update values:

```dart
class WKWebColors {
  WKWebColors._();

  static const Color pageWarm = LiquidGlassColors.lightBackground;
  static const Color surface = LiquidGlassColors.surfaceSolid;
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color borderWarm = LiquidGlassColors.borderStrong;
  static const Color action = LiquidGlassColors.primary;
  static const Color actionHover = Color(0xFF4338CA);
  static const Color actionSoft = Color(0x1F4F46E5);
  static const Color online = LiquidGlassColors.online;
  static const Color success = LiquidGlassColors.online;
  static const Color danger = LiquidGlassColors.accent;
  static const Color textPrimary = LiquidGlassColors.text;
  static const Color textSecondary = LiquidGlassColors.textSecondary;
  static const Color textTertiary = LiquidGlassColors.textTertiary;
  static const Color overlayScrim = Color(0x33000000);
  static const Color shadow = Color(0x17172433);
}

class WKWebSizes {
  WKWebSizes._();

  static const double railWidth = LiquidGlassSizes.navRailWidth;
  static const double conversationListWidth =
      LiquidGlassSizes.conversationListWidth;
  static const double conversationListMinWidth =
      LiquidGlassSizes.conversationListMinWidth;
  static const double chatRightContextWidth =
      LiquidGlassSizes.detailsDrawerWidth;
  static const double chatPaneMinWidth = 420;
  static const double conversationRowHeight =
      LiquidGlassSizes.conversationRowHeight;
  static const double composerMinHeight = 72;
  static const double messageBubbleMinWidth = 96;
  static const double messageBubbleMaxWidth =
      LiquidGlassSizes.messageBubbleMaxWidth;
  static const double messageBubbleRobotMaxWidth = 460;
  static const double messageBubbleWidthRatio =
      LiquidGlassSizes.messageBubbleDesktopRatio;
}
```

- [ ] **Step 7: Run focused tests**

Run:

```powershell
flutter test test/widgets/liquid_glass_tokens_test.dart test/widgets/liquid_glass_panel_test.dart test/modules/chat/message_bubble_experience_test.dart
```

Expected: PASS for new token/panel tests; existing message tests may still fail only if old warm Web color assertions have not yet been updated in Task 2.

- [ ] **Step 8: Commit**

Commit only files from this task:

```powershell
git add lib/widgets/liquid_glass_tokens.dart lib/widgets/liquid_glass_panel.dart lib/widgets/wk_web_ui_tokens.dart test/widgets/liquid_glass_tokens_test.dart test/widgets/liquid_glass_panel_test.dart
git commit -m "feat: add liquid glass UI tokens"
```

## Task 2: Message Bubble Visual Redesign

**Files:**
- Modify: `lib/core/theme/chat_bubble_theme.dart`
- Modify: `lib/core/theme/chat_micro_interactions.dart`
- Modify: `lib/widgets/message_bubble.dart`
- Modify: `test/modules/chat/message_bubble_experience_test.dart`

**Acceptance:**
- Outgoing text bubbles use the indigo-to-sky gradient, white text, 16px/4px asymmetric radius, and glow shadow.
- Incoming text bubbles use solid surface, border, soft shadow, and 16px/4px asymmetric radius.
- Quote, file, voice, and metadata treatments match the reference style without breaking current content support.

- [ ] **Step 1: Add failing bubble visual tests**

Append to `test/modules/chat/message_bubble_experience_test.dart` inside the existing `group('message bubble presentation', () { ... })`:

```dart
testWidgets('liquid glass outgoing text bubble uses primary gradient', (
  tester,
) async {
  final message = WKMsg()
    ..fromUID = 'u_me'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('liquid glass')
    ..status = WKSendMsgResult.sendSuccess;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          model: ChatMessageMapper().map(message, currentUid: 'u_me'),
        ),
      ),
    ),
  );

  final body = tester.widget<Container>(
    find.byKey(const ValueKey<String>('message-bubble-body')),
  );
  final decoration = body.decoration! as BoxDecoration;
  final gradient = decoration.gradient! as LinearGradient;
  expect(gradient.colors, const [Color(0xFF4F46E5), Color(0xFF0284C7)]);
  expect(decoration.boxShadow, isNotEmpty);
});

testWidgets('liquid glass incoming text bubble uses solid bordered surface', (
  tester,
) async {
  final message = WKMsg()
    ..fromUID = 'u_peer'
    ..channelType = WKChannelType.personal
    ..contentType = WkMessageContentType.text
    ..messageContent = WKTextContent('hello')
    ..status = WKSendMsgResult.sendSuccess;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessageBubble(
          model: ChatMessageMapper().map(message, currentUid: 'u_me'),
        ),
      ),
    ),
  );

  final body = tester.widget<Container>(
    find.byKey(const ValueKey<String>('message-bubble-body')),
  );
  final decoration = body.decoration! as BoxDecoration;
  expect(decoration.color, const Color(0xFFFFFFFF));
  expect(decoration.border, isNotNull);
  expect(decoration.boxShadow, isNotEmpty);
});
```

Update existing warm Web tests in the same file:

```dart
expect(gradient.colors, const [Color(0xFF4F46E5), Color(0xFF0284C7)]);
expect(contentText.style?.color, Colors.white);
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/modules/chat/message_bubble_experience_test.dart --plain-name "liquid glass outgoing text bubble uses primary gradient"
```

Expected: FAIL because current bubbles still use old/warm colors or older blue values.

- [ ] **Step 3: Update chat bubble theme tokens**

Modify `lib/core/theme/chat_bubble_theme.dart` to import liquid tokens and set:

```dart
import '../../widgets/liquid_glass_tokens.dart';
```

Use:

```dart
static const LinearGradient outgoingGradientLight =
    LiquidGlassGradients.primary;
static const LinearGradient outgoingGradientDark =
    LiquidGlassGradients.primaryDark;

static const Color incomingBgLight = LiquidGlassColors.surfaceSolid;
static const Color incomingBgDark = LiquidGlassColors.bubbleOtherDark;
static const Color outgoingTextLight = Colors.white;
static const Color outgoingTextDark = Colors.white;
static const Color incomingTextLight = LiquidGlassColors.text;
static const Color incomingTextDark = LiquidGlassColors.darkText;
static const Color readTickColor = Color(0xFF60A5FA);
```

Keep public method names unchanged.

- [ ] **Step 4: Update `MessageBubble._bubbleDecoration`**

In `lib/widgets/message_bubble.dart`, import:

```dart
import 'liquid_glass_tokens.dart';
```

Replace the non-robot `_bubbleDecoration` branch with logic equivalent to:

```dart
final borderRadius = BorderRadius.only(
  topLeft: const Radius.circular(16),
  topRight: const Radius.circular(16),
  bottomLeft: Radius.circular(isSelf ? 16 : 4),
  bottomRight: Radius.circular(isSelf ? 4 : 16),
);

if (isSelf) {
  return BoxDecoration(
    gradient: LiquidGlassGradients.primary,
    borderRadius: borderRadius,
    boxShadow: LiquidGlassShadows.glow,
  );
}

return BoxDecoration(
  color: LiquidGlassColors.surfaceSolid,
  borderRadius: borderRadius,
  border: Border.all(color: LiquidGlassColors.border),
  boxShadow: LiquidGlassShadows.sm,
);
```

Remove the special `webStyle && _isTextLikeContent` warm-color branch.

- [ ] **Step 5: Update text and metadata colors**

In `lib/widgets/message_bubble.dart`, set:

```dart
const Color _warmWebBubbleMetaColor = Color(0xB3FFFFFF);
```

Update text-like outgoing content to use white when `isSelf`, including the existing `useWarmTextColors` branch. Incoming text remains `LiquidGlassColors.text`.

- [ ] **Step 6: Update file and voice card sub-surfaces**

In `_buildFileContent()` and `_buildVoiceContent()` in `lib/widgets/message_bubble.dart`:

- Outgoing nested file card background: `Colors.white.withValues(alpha: 0.20)`
- Outgoing nested borders: `Colors.white.withValues(alpha: 0.15)`
- Incoming nested file card background: `LiquidGlassColors.surfaceSolid`
- Incoming nested borders: `LiquidGlassColors.border`
- Voice play button outgoing: `Colors.white.withValues(alpha: 0.25)`
- Voice play button incoming: `LiquidGlassColors.primary`

Keep existing parsing and tap behavior unchanged.

- [ ] **Step 7: Run focused bubble tests**

Run:

```powershell
flutter test test/modules/chat/message_bubble_experience_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add lib/core/theme/chat_bubble_theme.dart lib/core/theme/chat_micro_interactions.dart lib/widgets/message_bubble.dart test/modules/chat/message_bubble_experience_test.dart
git commit -m "feat: restyle chat message bubbles"
```

## Task 3: Composer and Expression Panels

**Files:**
- Modify: `lib/modules/chat/widgets/chat_composer.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `test/modules/chat/chat_composer_web_style_test.dart`

**Acceptance:**
- Composer shell uses a glass surface, subtle top border, and reference spacing.
- Send button is circular with primary gradient and press scale.
- Emoji/expression/more/robot panels use rounded glass or solid surfaces with 8px grid rhythm.
- Send, emoji insertion, voice mode, file/image actions, robot menu, and flame panel behavior remain unchanged.

- [ ] **Step 1: Add failing composer visual tests**

Replace `test/modules/chat/chat_composer_web_style_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/widgets/chat_composer.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  testWidgets('chat composer supports liquid glass shell', (tester) async {
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
    expect(decoration.color, LiquidGlassColors.surface);
    expect(decoration.border!.top.color, LiquidGlassColors.border);
    expect(decoration.boxShadow, LiquidGlassShadows.md);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/modules/chat/chat_composer_web_style_test.dart
```

Expected: FAIL because composer still uses `WKWebColors.surface` and warm border/shadow.

- [ ] **Step 3: Update `ChatComposer` shell decoration**

In `lib/modules/chat/widgets/chat_composer.dart`, import liquid tokens:

```dart
import '../../../widgets/liquid_glass_tokens.dart';
```

Change the `DecoratedBox` decoration to:

```dart
decoration: BoxDecoration(
  color: webStyle || isMobileWarmStyle
      ? LiquidGlassColors.surface
      : Colors.white,
  border: const Border(
    top: BorderSide(color: LiquidGlassColors.border, width: 1),
  ),
  boxShadow: webStyle || isMobileWarmStyle ? LiquidGlassShadows.md : null,
),
```

Do not change child order or `AnimatedSwitcher`.

- [ ] **Step 4: Update send button style**

In `_ComposerSendButtonState.build` in `lib/modules/chat/chat_page_shell.dart`, import liquid tokens:

```dart
import '../../widgets/liquid_glass_tokens.dart';
```

In the `widget.warmStyle` branch, replace the square-ish decoration with:

```dart
decoration: BoxDecoration(
  gradient: widget.enabled ? LiquidGlassGradients.primary : null,
  color: widget.enabled ? null : LiquidGlassColors.muted,
  shape: BoxShape.circle,
  boxShadow: widget.enabled ? LiquidGlassShadows.glow : null,
),
```

Set `borderRadius` usage in this branch to a circular `DecoratedBox` with `SizedBox(width: widget.width, height: widget.height)` and keep `IconButton` key `chat-send-button`.

- [ ] **Step 5: Update function/panel surfaces**

In `lib/modules/chat/chat_page_shell.dart`:

- `_buildFunctionPanel`: background `LiquidGlassColors.surfaceSolid`, padding `EdgeInsets.fromLTRB(18, 12, 18, 18)`.
- `_buildRobotGifPanel`: background `LiquidGlassColors.surfaceSolid`, border top `LiquidGlassColors.border`.
- `_buildRobotMenuPanel`: background `LiquidGlassColors.surfaceSolid`.
- `_buildFlamePanel`: background `LiquidGlassColors.surfaceSolid`.
- `_FunctionIconStyle` gradients should keep their domain colors unless a direct reference match is needed; do not remove icons.

- [ ] **Step 6: Run composer and action tests**

Run:

```powershell
flutter test test/modules/chat/chat_composer_web_style_test.dart test/modules/chat/chat_action_dispatcher_test.dart test/modules/chat/chat_toolbar_slot_assembly_test.dart test/modules/chat/chat_expression_panel_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/modules/chat/widgets/chat_composer.dart lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_composer_web_style_test.dart
git commit -m "feat: restyle chat composer"
```

## Task 4: Chat Shell, Top Bar, Drawer, Toast, and Drag/Drop

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Modify: `lib/modules/chat/chat_desktop_drop_target.dart`
- Modify: `test/modules/chat/chat_desktop_drop_target_test.dart`
- Modify: `test/modules/chat/chat_pages_compile_test.dart`

**Acceptance:**
- Chat page background uses the reference liquid stage/surface language on Web/Windows and compatible mobile background on Android.
- Top bar uses glass surface, 68dp desktop height, avatar/title/status layout, and pill details action.
- Pinned/group banner uses reference translucent gradient styling.
- Drag/drop overlay uses dashed-look primary border and centered upload prompt.
- Snack/toast feedback uses floating rounded glass style where supported.

- [ ] **Step 1: Add failing drag overlay test**

In `test/modules/chat/chat_desktop_drop_target_test.dart`, add:

```dart
testWidgets('desktop drop overlay uses liquid glass upload prompt', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            SizedBox.expand(),
            Positioned.fill(child: ChatDesktopDropOverlayForTesting()),
          ],
        ),
      ),
    ),
  );

  final overlay = tester.widget<DecoratedBox>(
    find.byKey(const ValueKey<String>('chat-desktop-drop-overlay')),
  );
  final decoration = overlay.decoration as BoxDecoration;
  expect(decoration.color, const Color(0x140284C7));
  expect(decoration.border!.top.color, const Color(0xFF0284C7));
  expect(find.text('\u91ca\u653e\u6587\u4ef6\u5373\u53ef\u53d1\u9001'), findsOneWidget);
});
```

Expose the overlay for tests in `lib/modules/chat/chat_desktop_drop_target.dart` by adding later:

```dart
@visibleForTesting
class ChatDesktopDropOverlayForTesting extends StatelessWidget {
  const ChatDesktopDropOverlayForTesting({super.key});

  @override
  Widget build(BuildContext context) => const _ChatDesktopDropOverlay();
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/modules/chat/chat_desktop_drop_target_test.dart --plain-name "desktop drop overlay uses liquid glass upload prompt"
```

Expected: FAIL because `ChatDesktopDropOverlayForTesting` does not exist and overlay text/style differs.

- [ ] **Step 3: Update chat scaffold background and top bar**

In `lib/modules/chat/chat_page_shell.dart`:

- Replace warm-page background usage with `LiquidGlassColors.lightBackground` for light and `LiquidGlassColors.darkBackground` through theme-aware surfaces when practical.
- Wrap the top header container with glass-like decoration using `LiquidGlassColors.surface`, `LiquidGlassColors.border`, and `BackdropFilter` if the header already clips.
- Preserve title/subtitle/tag/action logic exactly.
- Keep existing `ValueKey`s used by tests.

Use this decoration pattern for header containers:

```dart
BoxDecoration(
  color: LiquidGlassColors.surface,
  border: const Border(
    bottom: BorderSide(color: LiquidGlassColors.border),
  ),
)
```

- [ ] **Step 4: Update pinned/group banner**

Where pinned messages or group announcement banner is built, apply:

```dart
BoxDecoration(
  gradient: LinearGradient(
    colors: [
      LiquidGlassColors.primary2.withValues(alpha: 0.10),
      LiquidGlassColors.primary.withValues(alpha: 0.08),
    ],
  ),
  borderRadius: LiquidGlassRadii.lg,
  border: Border.all(color: LiquidGlassColors.primary2.withValues(alpha: 0.15)),
)
```

Do not change pinned-message actions or routing.

- [ ] **Step 5: Update drag/drop overlay**

In `lib/modules/chat/chat_desktop_drop_target.dart`, import:

```dart
import 'package:flutter/foundation.dart';
import '../../widgets/liquid_glass_tokens.dart';
```

Update `_ChatDesktopDropOverlay` decoration:

```dart
decoration: BoxDecoration(
  color: LiquidGlassColors.primary2.withValues(alpha: 0.08),
  border: Border.all(color: LiquidGlassColors.primary2, width: 2),
  borderRadius: LiquidGlassRadii.xl,
),
```

Update centered prompt text to `释放文件即可发送`.

Add the `ChatDesktopDropOverlayForTesting` class from Step 1.

- [ ] **Step 6: Update snack/toast feedback surfaces**

In `lib/modules/chat/chat_page_shell.dart`, for existing `ScaffoldMessenger.showSnackBar` calls within chat feedback methods, use:

```dart
SnackBar(
  content: Text(message),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  backgroundColor: LiquidGlassColors.darkSurfaceSolid,
)
```

For const messages, keep const only if the shape/background is not used; otherwise remove const.

- [ ] **Step 7: Run focused chat shell tests**

Run:

```powershell
flutter test test/modules/chat/chat_desktop_drop_target_test.dart test/modules/chat/chat_pages_compile_test.dart test/modules/chat/chat_page_android_parity_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add lib/modules/chat/chat_page_shell.dart lib/modules/chat/chat_desktop_drop_target.dart test/modules/chat/chat_desktop_drop_target_test.dart test/modules/chat/chat_pages_compile_test.dart
git commit -m "feat: restyle chat shell surfaces"
```

## Task 5: Conversation Workbench and Conversation List

**Files:**
- Modify: `lib/modules/conversation/web_conversation_workspace.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Modify: `lib/widgets/wk_conversation_item.dart`
- Create: `test/modules/conversation/web_conversation_workspace_test.dart` if missing
- Modify: existing conversation tests as needed

**Acceptance:**
- Desktop/Web/Windows workbench uses a centered liquid stage and the 72/340/chat structure where the shell owns nav/list/chat.
- Conversation list uses solid/glass surface, rounded search, active row indicator, avatar ring, and bounce unread badge.
- Mobile list remains single-pane and avoids overflow.

- [ ] **Step 1: Add or update workspace tests**

If `test/modules/conversation/web_conversation_workspace_test.dart` is absent, create it:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/web_conversation_workspace.dart';
import 'package:wukong_im_app/widgets/liquid_glass_tokens.dart';

void main() {
  test('desktop workspace is enabled for Windows-sized viewports', () {
    expect(
      shouldUseDesktopConversationWorkspace(
        isWeb: false,
        platform: TargetPlatform.windows,
        viewportWidth: 1280,
      ),
      isTrue,
    );
  });

  testWidgets('workspace scaffold uses liquid conversation width', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: WebConversationWorkspaceScaffold(
          listPane: SizedBox(),
          chatPane: SizedBox(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('web-conversation-workspace')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('web-conversation-list-pane'))).width,
      LiquidGlassSizes.conversationListWidth,
    );
  });
}
```

- [ ] **Step 2: Add failing conversation item tests**

In the existing `test/widgets` or a nearby conversation-item test file, add:

```dart
testWidgets('web conversation item uses active liquid glass indicator', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: WKConversationItem(
          webStyle: true,
          selected: true,
          data: WKConversationItemData(
            channelId: 'u_1',
            channelType: 1,
            title: 'Alice',
            lastMsgContent: 'Hello',
            unreadCount: 3,
          ),
        ),
      ),
    ),
  );

  final shell = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey<String>('wk-conversation-item-web-shell')),
  );
  final decoration = shell.decoration! as BoxDecoration;
  expect(decoration.color, const Color(0x1A4F46E5));
  expect(decoration.border, isNotNull);
  expect(find.text('3'), findsOneWidget);
});
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```powershell
flutter test test/modules/conversation/web_conversation_workspace_test.dart
```

Expected: FAIL if file/classes are not updated to the new fixed 340px list width and liquid colors.

- [ ] **Step 4: Update workspace scaffold**

In `lib/modules/conversation/web_conversation_workspace.dart`:

- Use `LiquidGlassStage` or `LiquidGlassColors.lightBackground` for root background.
- `_resolveConversationListWidth` should return `LiquidGlassSizes.conversationListWidth` when width permits, clamped down only for narrow windows.
- Right context width should use `LiquidGlassSizes.detailsDrawerWidth`.
- Replace `WKWebPanel` empty pane with `LiquidGlassPanel`.
- Preserve selection state and `ChatPage` creation.

- [ ] **Step 5: Update conversation list header/search**

In `lib/modules/conversation/conversation_list_page.dart`:

- Embedded root `Material` color: `LiquidGlassColors.surface`.
- Header title uses 18px/700.
- Search bar decoration: pill radius, `LiquidGlassColors.surfaceSolid`, border `LiquidGlassColors.border`, focus/hover color if available.
- New/top menu button uses `LiquidGlassPillButton` where behavior maps cleanly.
- Do not change provider/data loading logic.

- [ ] **Step 6: Update conversation row visuals**

In `lib/widgets/wk_conversation_item.dart`:

- Import liquid tokens and `UnreadBadgeBounce`.
- For `webStyle`, use selected color `LiquidGlassColors.primary.withValues(alpha: 0.10)`.
- Add active left indicator with width 3 and pill radius when selected.
- Wrap unread badge count with `UnreadBadgeBounce(count: data.unreadCount)`.
- Keep muted badge color logic if muted.
- Preserve tap/long-press behavior.

- [ ] **Step 7: Run conversation tests**

Run:

```powershell
flutter test test/modules/conversation test/modules/chat/chat_overflow_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add lib/modules/conversation/web_conversation_workspace.dart lib/modules/conversation/conversation_list_page.dart lib/widgets/wk_conversation_item.dart test/modules/conversation
git commit -m "feat: restyle conversation workbench"
```

## Task 6: Auth/Login Liquid-Glass Page

**Files:**
- Modify: `lib/modules/auth/presentation/widgets/auth_experience_tokens.dart`
- Modify: `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart`
- Modify: `test/modules/auth/auth_page_scaffold_test.dart`

**Acceptance:**
- Login/auth scaffold uses the reference split brand/form glass layout on desktop.
- Android keeps a compact single-column layout with no overflow.
- Existing login validation, preferences, agreement, custom API URL, register, and reset flows remain intact.

- [ ] **Step 1: Update failing auth token expectations**

In `test/modules/auth/auth_page_scaffold_test.dart`, update token contrast test to assert:

```dart
expect(AuthExperienceTokens.brandAccent, const Color(0xFF4F46E5));
expect(AuthExperienceTokens.stageBackgroundBottom, const Color(0xFFF0F4F8));
```

Add:

```dart
testWidgets('AuthPageScaffold liquid glass desktop shell keeps 20px radius', (
  tester,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 960));

  await tester.pumpWidget(
    const MaterialApp(
      home: AuthPageScaffold(
        title: '登录',
        pageLabel: '登录',
        brandTitle: '连接每一次重要沟通',
        brandDescription: '支持手机号、邮箱、验证码或密码登录。',
        body: SizedBox(height: 240),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final shell = tester.widget<Container>(
    find.byKey(const ValueKey<String>('auth-stage-shell')),
  );
  final decoration = shell.decoration! as BoxDecoration;
  expect(decoration.borderRadius, BorderRadius.circular(20));
});
```

- [ ] **Step 2: Run auth scaffold test and verify failure**

Run:

```powershell
flutter test test/modules/auth/auth_page_scaffold_test.dart --plain-name "AuthPageScaffold liquid glass desktop shell keeps 20px radius"
```

Expected: FAIL because current radius/palette still uses warm tokens.

- [ ] **Step 3: Update auth tokens**

In `lib/modules/auth/presentation/widgets/auth_experience_tokens.dart`, set the stage and panel tokens:

```dart
static const double panelBorderRadius = 20;
static const double brandPanelBorderRadius = 20;
static const double stageShellRadius = 20;
static const Color stageBackgroundTop = Color(0xFFF0F4F8);
static const Color stageBackgroundBottom = Color(0xFFF0F4F8);
static const Color stageGlowPrimary = Color(0x334F46E5);
static const Color stageGlowSecondary = Color(0x260284C7);
static const Color stageShellBorder = Color(0x120F172A);
static const Color panelBorder = Color(0x120F172A);
static const Color brandPanelBackground = Color(0xA6FFFFFF);
static const Color brandPanelOverlay = Color(0x1F4F46E5);
static const Color brandAccent = Color(0xFF4F46E5);
static const Color brandAccentStrong = Color(0xFF4338CA);
static const Color brandChipBackground = Color(0x1F4F46E5);
static const Color brandChipBorder = Color(0x334F46E5);
static const Color inputFill = Color(0xFFFFFFFF);
static const Color inputBorder = Color(0x1F0F172A);
static const Color inputBorderFocus = Color(0xFF0284C7);
```

Keep contrast test passing; adjust foreground values if the contrast test catches a regression.

- [ ] **Step 4: Update auth scaffold brand visual**

In `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart`:

- Use `ClipRRect` + `BackdropFilter` for the stage shell if practical.
- Keep existing `AuthPageScaffold` public API.
- In `_buildBrandPanel`, add a flexible visual area at the bottom for network nodes when not compact:

```dart
if (!compact) ...[
  const SizedBox(height: 28),
  const Expanded(child: _AuthNetworkVisual()),
],
```

Define private `_AuthNetworkVisual` in the same file using positioned rounded nodes and connector lines. Do not add assets.

- [ ] **Step 5: Run auth tests**

Run:

```powershell
flutter test test/modules/auth
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/modules/auth/presentation/widgets/auth_experience_tokens.dart lib/modules/auth/presentation/widgets/auth_page_scaffold.dart test/modules/auth/auth_page_scaffold_test.dart
git commit -m "feat: restyle auth login surfaces"
```

## Task 7: Contacts and Settings Surfaces

**Files:**
- Modify: `lib/modules/contacts/contacts_page.dart`
- Modify: `lib/modules/contacts/widgets/contacts_list_viewport.dart`
- Modify: `lib/wukong_uikit/setting/setting_page.dart`
- Modify: `test/modules/contacts/contacts_page_parity_test.dart`
- Modify: `test/wukong_uikit/setting/setting_page_test.dart`

**Acceptance:**
- Contacts list, grouped headings, friend rows, and detail areas follow liquid-glass tokens.
- Settings page cards, rows, switches, and side/menu layout follow the same token system.
- Existing contacts and settings behavior remains intact.

- [ ] **Step 1: Add failing contacts/settings visual assertions**

In `test/modules/contacts/contacts_page_parity_test.dart`, add an assertion around the main contacts scaffold key already used by that test. If no key exists, add a test expectation for a new key:

```dart
expect(find.byKey(const ValueKey<String>('contacts-liquid-shell')), findsOneWidget);
```

In `test/wukong_uikit/setting/setting_page_test.dart`, add:

```dart
expect(find.byKey(const ValueKey<String>('settings-liquid-shell')), findsOneWidget);
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/modules/contacts/contacts_page_parity_test.dart test/wukong_uikit/setting/setting_page_test.dart
```

Expected: FAIL because new liquid-shell keys do not exist.

- [ ] **Step 3: Update contacts shell**

In `lib/modules/contacts/contacts_page.dart`:

- Wrap top-level content in `LiquidGlassStage` or a container keyed `contacts-liquid-shell`.
- Use `LiquidGlassPanel` for list/detail surfaces where the current layout has panels.
- Keep controllers, slot assembly, and navigation unchanged.

In `lib/modules/contacts/widgets/contacts_list_viewport.dart`:

- Use 48px avatars, 12px row gap, 16px radius hover/pressed row surfaces.
- Group headings use 13px/700 secondary text.
- Preserve alphabet index behavior.

- [ ] **Step 4: Update settings shell**

In `lib/wukong_uikit/setting/setting_page.dart`:

- Wrap top-level content in a widget keyed `settings-liquid-shell`.
- Replace warm/flat card backgrounds with `LiquidGlassPanel` or `LiquidGlassColors.surfaceSolid`.
- Keep setting item routes and `WKSettingPreferences` behavior unchanged.

- [ ] **Step 5: Run contacts/settings tests**

Run:

```powershell
flutter test test/modules/contacts test/wukong_uikit/setting
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/modules/contacts/contacts_page.dart lib/modules/contacts/widgets/contacts_list_viewport.dart lib/wukong_uikit/setting/setting_page.dart test/modules/contacts/contacts_page_parity_test.dart test/wukong_uikit/setting/setting_page_test.dart
git commit -m "feat: restyle contacts and settings"
```

## Task 8: Cross-Platform Verification and Review Fixes

**Files:**
- Modify only files required by failures found in verification.
- Update tests only when expectations legitimately changed because of the approved UI spec.

**Acceptance:**
- Analyze passes.
- Focused tests pass.
- App builds for Web and Android debug APK.
- Windows build or run is attempted and failures are documented if caused by local environment.
- Manual smoke checks cover 1440px, 1024px, 375px Web/mobile width, Windows normal/narrow, and Android portrait.

- [ ] **Step 1: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: PASS. Fix all issues introduced by this redesign.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/widgets test/core/motion test/core/transitions test/modules/chat test/modules/conversation test/modules/auth test/modules/contacts test/wukong_uikit/setting
```

Expected: PASS.

- [ ] **Step 3: Build Web**

Run:

```powershell
flutter build web
```

Expected: PASS.

- [ ] **Step 4: Build Android debug APK**

Run:

```powershell
flutter build apk --debug
```

Expected: PASS.

- [ ] **Step 5: Build Windows**

Run:

```powershell
flutter build windows
```

Expected: PASS, unless local Windows toolchain setup blocks it. If blocked, record the exact error in the final verification note.

- [ ] **Step 6: Manual smoke Web**

Run:

```powershell
flutter run -d chrome
```

Check:

- Desktop 1440px: stage, nav, list, chat, drawer, composer match reference structure.
- 1024px: two-column layout remains usable.
- 375px browser width: single-pane chat/list behavior has no overflow.
- Console has no Flutter framework overflow exceptions.

- [ ] **Step 7: Manual smoke Windows**

Run:

```powershell
flutter run -d windows
```

Check:

- Normal window: desktop workbench.
- Narrow window: no text overlap, composer remains usable.
- Drag/drop overlay appears and clears.

- [ ] **Step 8: Manual smoke Android**

Run:

```powershell
flutter run -d android
```

Check:

- Conversation list opens first.
- Chat opens full screen with back affordance.
- Keyboard does not cover composer incorrectly.
- Send, emoji, image/file, voice controls remain reachable.

- [ ] **Step 9: Code review**

Use code-review-and-quality. Review for:

- Correctness: no business behavior regressions.
- Readability: token usage instead of scattered hex values.
- Architecture: no WebView/HTML shortcut, no duplicated IM logic.
- Security: no new secrets, no untrusted file/drop handling regression.
- Performance: blur usage limited to major panels, no excessive rebuilds in message list.

- [ ] **Step 10: Final commit**

If fixes were needed:

```powershell
git add <fixed files>
git commit -m "fix: complete liquid glass UI verification"
```

## Checkpoints

### Checkpoint A: After Tasks 1-2
- [ ] Token tests pass.
- [ ] Message bubble tests pass.
- [ ] Existing message content support remains intact.

### Checkpoint B: After Tasks 3-5
- [ ] Composer and chat shell tests pass.
- [ ] Conversation workbench tests pass.
- [ ] Desktop/Web/Windows structure is visually coherent.

### Checkpoint C: After Tasks 6-7
- [ ] Auth, contacts, and settings tests pass.
- [ ] Shared visual system is used across core surfaces.

### Checkpoint D: After Task 8
- [ ] `flutter analyze` passes.
- [ ] Focused tests pass.
- [ ] Web, Android, and Windows builds/runs are verified or environment blockers are documented.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `BackdropFilter` and large shadows hurt scroll performance | High | Use blur only on shell/panel surfaces, not every message row; keep message rows mostly solid decorations. |
| Existing tests assume old warm Web colors | Medium | Update tests only when the assertion is visual, not behavioral. Keep behavior assertions intact. |
| Large `chat_page_shell.dart` edits become hard to review | High | Keep changes localized to decoration helpers and existing widget branches; do not refactor unrelated logic. |
| Android layout overflows after desktop styling | High | Run narrow widget tests and Android parity tests after each mobile-affecting slice. |
| Dirty worktree contains unrelated user changes | High | Stage and commit only files explicitly touched by each task. Never reset or checkout unrelated files. |

## Self-Review

- Spec coverage: Tasks cover tokens, shell, navigation/workbench, conversation list, messages, composer, drawer/overlays, auth/login, contacts/settings, dark/reduced-motion through tokens, and verification.
- Placeholder scan: no `TBD`, `TODO`, or "implement later" placeholders are used.
- Type consistency: token names introduced in Task 1 are reused consistently in later tasks.
- Scope check: this is large but sliced into independently verifiable UI layers; implementation should proceed task-by-task, not as a single patch.
