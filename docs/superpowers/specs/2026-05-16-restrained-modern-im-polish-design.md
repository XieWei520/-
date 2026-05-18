# Spec: Restrained Modern IM Polish - Worker A

## Objective
Update the global visual token and shell foundation toward a production IM style: light gray-white workbench backgrounds, thin borders, smaller radii, lighter shadows, and tighter conversation/message density. Existing public API names remain stable so other UI workers can continue integrating against the same classes.

## Tech Stack
Flutter/Dart UI tokens and widget tests in the WuKong Flutter application.

## Commands
- Test touched widgets: `flutter test test/widgets/liquid_glass_tokens_test.dart test/widgets/liquid_glass_panel_test.dart test/widgets/wk_web_ui_tokens_test.dart`

## Project Structure
- `lib/widgets/liquid_glass_tokens.dart` -> global palette, radius, shadow, blur, and layout metrics
- `lib/widgets/liquid_glass_panel.dart` -> shared panel/app-frame/stage shell widgets
- `lib/widgets/wk_web_ui_tokens.dart` -> web-facing bridge tokens and panel shell
- `test/widgets/*` -> focused widget/token regression tests

## Code Style
```dart
static const Color lightBackground = Color(0xFFF7F8FA);
static const double conversationRowHeight = 68;
```
Keep changes as token-level constants where possible, preserve existing class and field names, and avoid adding new dependencies.

## Testing Strategy
Use focused Flutter widget tests for the touched token and shell files. Assertions should verify concrete visual contract values, especially background, radius, shadow, row height, and bubble width tokens.

## Boundaries
- Always: preserve existing API names, keep changes inside worker-A files, run the touched widget tests.
- Ask first: adding dependencies, changing unrelated UI modules, changing CI/build config.
- Never: submit git commits, revert other workers' changes, expand scope into feature pages.

## Success Criteria
- Light stage background is a flat gray-white workbench color without purple/blue radial wash.
- Shared panels use smaller radius, thin border, and light shadow by default.
- Conversation row height is about 68-70dp.
- Desktop message bubble ratio is about 0.56 and max width is about 460dp.
- WK web panel radius, shadow, and soft colors match the restrained direction.
- Touched widget tests pass.

## Open Questions
None for worker-A token scope.
