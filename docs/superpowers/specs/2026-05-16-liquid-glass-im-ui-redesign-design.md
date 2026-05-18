# Spec: Liquid Glass IM UI Redesign

## Assumptions
1. The app remains a Flutter multi-platform app; Web, Windows desktop, and Android share the same Dart UI implementation where practical.
2. The uploaded reference file `C:/Users/COLORFUL/Desktop/im-ui-preview.html` is the visual source of truth for the target style, layout, and micro-interactions.
3. "Full replication" means reproducing the reference's visible behavior in Flutter, not embedding the HTML file or replacing the app with a WebView.
4. Existing IM business behavior, routing, persistence, push, voice, file, image, search, and robot integrations must keep working.
5. Existing user changes in the working tree are preserved; this redesign should be implemented in focused slices.

## Objective
Replace the current IM interface with a liquid-glass, high-fidelity UI matching the supplied preview across:

- Web (`flutter run -d chrome`)
- Windows desktop (`flutter run -d windows`)
- Android (`flutter run -d android`)

The target user experience is a polished instant messaging workbench: glass panels, indigo-to-sky action gradients, soft shadows, 8px spacing rhythm, asymmetric message bubbles, responsive desktop/mobile layouts, dark mode parity, and visible micro-interactions for send status, unread badges, drawers, overlays, drag-and-drop, and voice playback.

## Tech Stack
- Flutter/Dart from `pubspec.yaml`, SDK constraint `^3.11.1`
- Riverpod for state management
- GoRouter for navigation
- Existing WuKong IM SDK integration
- Existing assets and fonts under `assets/reference_ui/`
- Existing UI token files:
  - `lib/widgets/wk_design_tokens.dart`
  - `lib/widgets/wk_colors.dart`
  - `lib/widgets/wk_web_ui_tokens.dart`
  - `lib/core/theme/chat_bubble_theme.dart`
  - `lib/core/motion/chat_motion.dart`

No new dependency is assumed for the first implementation pass. If blur performance, icons, or animation requirements cannot be met with existing Flutter APIs, adding dependencies requires approval.

## Commands
Install dependencies:

```powershell
flutter pub get
```

Analyze:

```powershell
flutter analyze
```

Focused chat tests:

```powershell
flutter test test/modules/chat test/core/motion test/core/transitions
```

Focused auth/login tests:

```powershell
flutter test test/modules/auth
```

Focused shell/home tests:

```powershell
flutter test test/modules/conversation test/app
```

Full test suite:

```powershell
flutter test
```

Run Web:

```powershell
flutter run -d chrome
```

Run Windows:

```powershell
flutter run -d windows
```

Run Android:

```powershell
flutter run -d android
```

Build Web:

```powershell
flutter build web
```

Build Windows:

```powershell
flutter build windows
```

Build Android APK:

```powershell
flutter build apk --debug
```

## Project Structure
- `lib/app/` -> app shell, theme mode wiring, router integration
- `lib/modules/home/` -> desktop/mobile main shell and app-level navigation
- `lib/modules/conversation/` -> conversation entry and list surfaces
- `lib/modules/chat/` -> chat page orchestration, actions, drag/drop, voice, details
- `lib/modules/chat/widgets/` -> composer, message viewport, toolbars, overlays, pinned/search bars
- `lib/widgets/message_bubble.dart` -> message bubble rendering for text, media, file, voice, card, robot content
- `lib/modules/auth/presentation/` -> login/register/auth UI
- `lib/core/theme/` -> chat visual tokens and micro-interactions
- `lib/core/motion/` -> shared animation durations and curves
- `test/modules/chat/` -> chat widget, behavior, and parity tests
- `test/modules/auth/` -> login and auth UI tests
- `test/core/` -> token, motion, transition, utility tests
- `docs/superpowers/specs/` -> approved design specs
- `docs/superpowers/plans/` -> implementation plans after approval

## Target UI Translation

### Visual Tokens
Create or update shared Flutter tokens to mirror the HTML CSS variables:

- Primary gradient: `#4F46E5` to `#0284C7`
- Dark primary gradient: `#6366F1` to `#0EA5E9`
- Accent/error: `#EF4444`
- Light background: `#F0F4F8`
- Dark background: `#0B0E14`
- Light text: `#0F172A`, secondary `#64748B`, tertiary `#94A3B8`
- Dark text: `#F8FAFC`, secondary `#94A3B8`, tertiary `#64748B`
- Online: `#10B981`
- Warning: `#F59E0B`
- Radius scale: 8, 12, 16, 20, pill
- Desktop shell widths: navigation rail 72px, conversation list 340px, details drawer 300px
- Bubble max width: 68% on desktop, 82% on mobile, capped around 520 logical px
- Glass panel effect: translucent surface + blur/saturate approximation using Flutter `BackdropFilter` and opacity

### App Shell
Desktop and web at widths >= 1024px:

- Centered app frame with max width near 1280px and height `viewport - 40px`
- Three-column layout: 72px nav rail, 340px conversation list, remaining chat pane
- Background radial gradients matching the reference stage
- Main shell clips to 20px radius with soft large shadow

Tablet width 681-1023px:

- Two-column layout: conversation list and chat pane
- Bottom navigation bar instead of left rail
- Chat and list remain side-by-side where width allows

Android/mobile <= 680px:

- Single-pane navigation: conversation list first, chat opens full-screen
- Bottom nav height about 60px
- Back action visible in chat top bar
- Bubble max width increases to 82%

### Navigation
Replicate the reference nav concepts:

- Logo tile with chat icon and primary gradient
- Message, Contacts, Groups/Login, Settings destinations
- Active destination has translucent primary background and side indicator on desktop
- Hover/pointer states on Web/Windows; pressed states on Android
- Maintain existing routing and auth guards

### Conversation List
Apply the reference list treatment:

- Header title and pill "new conversation" action
- Rounded search field with focus ring
- 48px circular avatars with gradient fallback colors and online badge
- Active conversation row with primary-tinted background, left indicator, and avatar ring
- Unread badge pop/bounce animation
- Scrollbars visible and subtle on desktop/web
- Preserve existing conversation data and unread counts

### Chat Top Bar
The top bar must include:

- Avatar, channel title, presence/typing status
- Group member stack for group chats
- Details pill action that opens the right drawer
- Group pinned announcement banner under top bar when applicable

### Messages
Message rendering must match the reference while preserving current content support:

- Incoming bubbles: solid surface, border, soft shadow, bottom-left tail radius
- Outgoing bubbles: indigo-to-sky gradient, white text, glow shadow, bottom-right tail radius
- Grouped consecutive messages should tighten adjacent radii where current message grouping data permits
- Inline metadata: time, sending spinner, sent/delivered/read double ticks, failed retry affordance
- Quote/reply block: left accent bar, muted tinted background
- Image/video previews: rounded media with caption/overlay where metadata exists
- File cards: icon tile, filename, size, type, state color adapted for incoming/outgoing
- Voice messages: play button, waveform bars, duration, playback progress animation
- System messages: centered pill
- Robot cards, stickers, GIFs, location, rich text, and sensitive word notices must remain functional

### Composer
The input area must replicate:

- Glass top border surface
- Toolbar row with emoji, image, file, screenshot, voice/call actions using existing action policy
- Rounded textarea/input with focus ring
- Circular gradient send button with press/hover scale
- Emoji/expression panel styled like the reference panel
- More/action panel styled with 8px grid and gradient icons
- Enter-to-send behavior on desktop/web must preserve existing logic; Android keyboard behavior must remain native

### Details Drawer and Overlays
Implement the reference overlay style for:

- Right details drawer: 300px wide on desktop, near-full width on mobile, glass surface, slide-in motion
- Message context menu/action sheet: rounded glass or solid surface with clear danger action
- Multi-select toolbar: pill floating bar on desktop, bottom-safe toolbar on Android if platform conventions require it
- Toast/snackbar: glass rounded card on desktop/web; Android may use the same visual via `ScaffoldMessenger` as long as it does not block system gestures
- Drag/drop cover on desktop/web: dashed primary border and centered upload prompt

### Auth/Login
Bring the login page toward the reference:

- Split layout on desktop/web: brand/network visual pane + form pane
- Single-column form on Android
- Glass cards, rounded fields, primary gradient continue button
- Existing phone/password, remember password, auto login, agreement, custom API URL, register, and reset flows remain intact

### Contacts and Settings
Apply the same token system to:

- Contacts list, grouped headings, friend rows, and detail panel
- Settings side menu/cards, switches, rows, language/font controls
- Dark mode switch and existing theme preference logic

## Code Style
Use small composable widgets and semantic tokens. Avoid copying CSS names directly into business widgets; keep design constants in token/theme files.

Example:

```dart
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(WKRadius.xl)),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: tokens.backdropFilter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: borderRadius,
            border: Border.all(color: tokens.border),
            boxShadow: tokens.shadowLg,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
```

Conventions:

- Prefer `const` widgets and constructors when possible.
- Use `ValueKey` for UI surfaces already covered by tests.
- Do not place business logic in theme or token classes.
- Use `MediaQuery.disableAnimationsOf(context)` and existing `ChatMotion` token resolution for reduced-motion support.
- Avoid hardcoded Chinese text changes unless the current UI copy is already being touched for the target screen.
- Keep files focused; split visual primitives into shared widgets when multiple modules need them.

## Testing Strategy
Use test-driven implementation for every behavior-affecting slice.

Widget tests:

- Conversation list renders active/hover/selected/unread states from model data.
- Message bubbles render incoming/outgoing text, quote, file, image, voice, system notice, robot card.
- Send status resolves sending, sent, delivered, read, failed without regressing existing tests.
- Composer actions preserve send, emoji, file/image, voice, and panel behavior.
- Login validation, preferences, custom API URL, and navigation still pass after visual changes.
- Responsive shell switches desktop/two-column/mobile layouts at target breakpoints.
- Dark mode tokens change surfaces, text, borders, and bubble colors.
- Reduced motion disables non-essential animations.

Golden or screenshot tests should be added only where the repo already supports stable rendering. If not available, use targeted widget assertions and manual screenshots.

Manual verification:

- Web desktop: 1440px and 1024px
- Web/mobile browser width: 375px
- Windows desktop app: normal and narrow window
- Android emulator/device: portrait at 360-430dp width
- Keyboard navigation on Web/Windows
- Android back navigation and input method behavior
- Drag-and-drop only on desktop/web

## Boundaries
- Always: preserve existing IM behavior and current tests unless the spec explicitly changes visible UI only.
- Always: write or update tests before behavior changes.
- Always: use existing Flutter architecture, routing, providers, and action policies.
- Always: honor dark mode and reduced-motion preferences.
- Always: verify Web, Windows, and Android impact for any shared UI change.
- Ask first: adding dependencies.
- Ask first: removing or rewriting existing major modules.
- Ask first: changing API contracts, data models, storage, push, or IM SDK behavior.
- Ask first: changing CI, build scripts, or platform runner code.
- Never: embed secrets, credentials, tokens, or server URLs in UI code.
- Never: replace the Flutter app with a WebView of the reference HTML.
- Never: delete unrelated dirty worktree changes.
- Never: remove tests to make the suite pass.

## Success Criteria
1. Web, Windows, and Android all use the new liquid-glass design tokens for core IM surfaces.
2. Desktop/Web chat shell visually matches the reference structure: stage background, 72px nav, 340px conversation list, chat pane, drawer, composer, and overlay styling.
3. Android presents the same design language with mobile-appropriate single-pane navigation and no desktop-only controls.
4. Message bubble rendering supports the current content matrix and visibly matches the reference for text, quotes, images, files, voice, status metadata, and system messages.
5. Composer, emoji/expression panels, send button, and toolbar interactions remain functional and receive the new visual and motion treatment.
6. Dark mode and reduced-motion behavior work without contrast or readability regressions.
7. Existing focused tests for chat, auth, app shell, motion, and transitions pass after the redesign slices they cover.
8. `flutter analyze` passes.
9. Manual smoke checks are completed for Web, Windows, and Android.

## Implementation Approach Options

### Option A: Shared Token-First Redesign
Add liquid-glass tokens and primitives, then migrate existing screens slice by slice.

Pros:
- Lowest risk to IM behavior.
- Preserves existing tests and module boundaries.
- Works naturally for shared Flutter Web/Windows/Android code.

Cons:
- Takes several vertical slices before the full app looks complete.

Recommendation: Use this approach.

### Option B: Build a New Parallel Shell
Create a new app shell/chat shell from scratch and route users to it.

Pros:
- Easier to visually match the reference quickly.
- Can isolate new layout experiments.

Cons:
- High risk of duplicating chat behavior, breaking edge cases, and drifting from existing providers/actions.
- More code to maintain.

### Option C: Embed the HTML Preview
Show the supplied HTML through WebView or a Web-only route.

Pros:
- Fastest visual copy for a static demo.

Cons:
- Does not satisfy Android/Windows native Flutter parity.
- Breaks production IM behavior and testability.
- Not acceptable for this project unless the goal changes to a prototype only.

## Recommended Plan
Use Option A. Implement in this order after approval:

1. Add liquid-glass design tokens and shared primitives.
2. Migrate message bubbles and send status visuals.
3. Migrate composer and expression/action panels.
4. Migrate chat shell top bar, background, banner, drawer, drag/drop, and overlays.
5. Migrate conversation list and app navigation shell.
6. Migrate login/auth, contacts, and settings surfaces.
7. Run cross-platform verification and a final code review.

## Open Questions
1. Should this redesign include iOS/macOS/Linux too, since the Flutter project supports them, or strictly Web/Windows/Android?
2. Should the old warm orange web theme be fully replaced by the indigo/sky reference palette, or kept for a specific mode/brand variant?
3. Do you want pixel-level visual regression tests/goldens added, or are widget tests plus manual screenshots enough for this phase?
4. Which screen should be implemented first after approval: chat page, conversation list/home shell, or login?
